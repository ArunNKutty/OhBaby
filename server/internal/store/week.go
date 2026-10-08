package store

import "time"

// WeekSummary matches the Week tab: averages per finished day, change on last
// week, and an 8-week trend. Dates are the device's civil dates.
type WeekSummary struct {
	Start            string       `json:"start"`
	Averages         TypeTotals   `json:"averages"`
	PreviousAverages TypeTotals   `json:"previous_averages"`
	Change           TypeTotals   `json:"change"`
	Trend            []TrendPoint `json:"trend"`
	Days             []DayTotals  `json:"days"`
}

type TypeTotals struct {
	BreastMs     int64 `json:"breast_ms"`
	FormulaMl    int   `json:"formula_ml"`
	BreastMilkMl int   `json:"breast_milk_ml"`
}

type TrendPoint struct {
	WeekStart    string `json:"week_start"`
	BreastMs     int64  `json:"breast_ms"`
	FormulaMl    int    `json:"formula_ml"`
	BreastMilkMl int    `json:"breast_milk_ml"`
}

type DayTotals struct {
	Date         string `json:"date"`
	Count        int    `json:"count"`
	BreastMs     int64  `json:"breast_ms"`
	FormulaMl    int    `json:"formula_ml"`
	BreastMilkMl int    `json:"breast_milk_ml"`
}

func SummarizeWeek(feedings []Feeding, weekStart, today time.Time) WeekSummary {
	weekStart = dateOnly(weekStart)
	today = dateOnly(today)
	var days []DayTotals
	for i := 0; i < 7; i++ {
		d := weekStart.AddDate(0, 0, i)
		days = append(days, totalsOn(feedings, d))
	}
	avg := averageFor(feedings, weekStart, today)
	prevStart := weekStart.AddDate(0, 0, -7)
	prev := averageFor(feedings, prevStart, today)
	trend := make([]TrendPoint, 0, 8)
	for i := 7; i >= 0; i-- {
		ws := weekStart.AddDate(0, 0, -7*i)
		a := averageFor(feedings, ws, today)
		trend = append(trend, TrendPoint{
			WeekStart:    ws.Format("2006-01-02"),
			BreastMs:     a.BreastMs,
			FormulaMl:    a.FormulaMl,
			BreastMilkMl: a.BreastMilkMl,
		})
	}
	return WeekSummary{
		Start:            weekStart.Format("2006-01-02"),
		Averages:         avg,
		PreviousAverages: prev,
		Change: TypeTotals{
			BreastMs:     avg.BreastMs - prev.BreastMs,
			FormulaMl:    avg.FormulaMl - prev.FormulaMl,
			BreastMilkMl: avg.BreastMilkMl - prev.BreastMilkMl,
		},
		Trend: trend,
		Days:  days,
	}
}

func averageFor(feedings []Feeding, weekStart, today time.Time) TypeTotals {
	weekStart = dateOnly(weekStart)
	today = dateOnly(today)
	inWeek := feedingsInWeek(feedings, weekStart)
	if !sameDate(weekStart, startOfWeek(today)) {
		return totalsOf(inWeek).dividedBy(7)
	}
	elapsed := int(today.Sub(weekStart).Hours()/24) + 1
	if elapsed < 1 {
		elapsed = 1
	}
	if elapsed == 1 {
		return totalsOf(inWeek).dividedBy(1)
	}
	var finished []Feeding
	for _, f := range inWeek {
		if !sameDate(localDate(f), today) {
			finished = append(finished, f)
		}
	}
	return totalsOf(finished).dividedBy(elapsed - 1)
}

func feedingsInWeek(all []Feeding, weekStart time.Time) []Feeding {
	from := dateOnly(weekStart)
	to := from.AddDate(0, 0, 7)
	var out []Feeding
	for _, f := range all {
		d := localDate(f)
		if !d.Before(from) && d.Before(to) {
			out = append(out, f)
		}
	}
	return out
}

func totalsOn(all []Feeding, day time.Time) DayTotals {
	day = dateOnly(day)
	var list []Feeding
	for _, f := range all {
		if sameDate(localDate(f), day) {
			list = append(list, f)
		}
	}
	t := totalsOf(list)
	return DayTotals{
		Date:         day.Format("2006-01-02"),
		Count:        len(list),
		BreastMs:     t.breastMs,
		FormulaMl:    t.formulaMl,
		BreastMilkMl: t.breastMilkMl,
	}
}

type acc struct {
	count        int
	breastMs     int64
	formulaMl    int
	breastMilkMl int
}

func totalsOf(list []Feeding) acc {
	var a acc
	for _, f := range list {
		a.count++
		switch f.Type {
		case "breast":
			a.breastMs += breastMs(f)
		case "formula":
			a.formulaMl += f.AmountMl
		case "breast_milk":
			a.breastMilkMl += f.AmountMl
		}
	}
	return a
}

func (a acc) dividedBy(days int) TypeTotals {
	if days <= 0 {
		days = 1
	}
	d := int64(days)
	return TypeTotals{
		BreastMs:     divRound(a.breastMs, d),
		FormulaMl:    int(divRound(int64(a.formulaMl), d)),
		BreastMilkMl: int(divRound(int64(a.breastMilkMl), d)),
	}
}

func divRound(n, d int64) int64 {
	if d <= 0 {
		return n
	}
	if n >= 0 {
		return (n + d/2) / d
	}
	return (n - d/2) / d
}

func breastMs(f Feeding) int64 {
	sides := int64(f.LeftMs + f.RightMs)
	if sides > 0 {
		return sides
	}
	d := f.EndUTC.Sub(f.StartUTC)
	if d < 0 {
		return 0
	}
	return d.Milliseconds()
}

func localDate(f Feeding) time.Time {
	shifted := f.StartUTC.UTC().Add(time.Duration(f.OffsetMin) * time.Minute)
	y, m, d := shifted.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func dateOnly(t time.Time) time.Time {
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func startOfWeek(t time.Time) time.Time {
	d := dateOnly(t)
	wd := int(d.Weekday())
	if wd == 0 {
		wd = 7
	}
	return d.AddDate(0, 0, -(wd - 1))
}

func sameDate(a, b time.Time) bool {
	ay, am, ad := a.Date()
	by, bm, bd := b.Date()
	return ay == by && am == bm && ad == bd
}
