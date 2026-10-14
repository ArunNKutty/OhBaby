import 'entry.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

enum Period {
  week('week'),
  month('month');

  const Period(this.noun);

  final String noun;

  /// First day of the period containing [d].
  DateTime startOf(DateTime d) => this == week ? startOfWeek(d) : DateTime(d.year, d.month);

  /// [start] moved by [n] periods (negative goes back).
  DateTime shift(DateTime start, int n) =>
      this == week ? DateTime(start.year, start.month, start.day + 7 * n) : DateTime(start.year, start.month + n);

  DateTime endOf(DateTime start) => shift(start, 1);
}

/// Entries that started on [day], earliest first.
List<Entry> entriesOnDay(Iterable<Entry> all, DateTime day) =>
    all.where((e) => isSameDay(e.start, day)).toList()..sort((a, b) => a.start.compareTo(b.start));

List<Entry> entriesBetween(Iterable<Entry> all, DateTime from, DateTime to) =>
    all.where((e) => !e.start.isBefore(from) && e.start.isBefore(to)).toList();

/// What one day (or several) adds up to.
class Totals {
  const Totals({
    this.breast = Duration.zero,
    this.formulaMl = 0,
    this.breastMilkMl = 0,
    this.pumpedMl = 0,
    this.diapers = 0,
  });

  final Duration breast;
  final int formulaMl;
  final int breastMilkMl;
  final int pumpedMl;
  final int diapers;

  int get bottleMl => formulaMl + breastMilkMl;

  factory Totals.of(Iterable<Entry> entries) {
    var breast = Duration.zero;
    var formula = 0, milk = 0, pumped = 0, diapers = 0;
    for (final e in entries) {
      switch (e.type) {
        case EntryType.breast:
          breast += e.breastDuration;
        case EntryType.bottle:
          formula += e.amountMl;
        case EntryType.breastMilk:
          milk += e.amountMl;
        case EntryType.pump:
          pumped += e.amountMl;
        case EntryType.diaper:
          diapers++;
        case EntryType.routine || EntryType.other:
          break;
      }
    }
    return Totals(breast: breast, formulaMl: formula, breastMilkMl: milk, pumpedMl: pumped, diapers: diapers);
  }
}

/// The rows under "Average per day".
enum Metric {
  breastfeeding('Breastfeeding'),
  formula('Formula'),
  breastMilk('Breast milk by bottle'),
  pumped('Pumped'),
  diapers('Diapers');

  const Metric(this.label);

  final String label;

  EntryType get type => switch (this) {
        breastfeeding => EntryType.breast,
        formula => EntryType.bottle,
        breastMilk => EntryType.breastMilk,
        pumped => EntryType.pump,
        diapers => EntryType.diaper,
      };

  /// Minutes for breastfeeding, ml for bottles and pumping, a count for diapers.
  double of(Totals t) => switch (this) {
        breastfeeding => t.breast.inSeconds / 60,
        formula => t.formulaMl.toDouble(),
        breastMilk => t.breastMilkMl.toDouble(),
        pumped => t.pumpedMl.toDouble(),
        diapers => t.diapers.toDouble(),
      };

  /// "59 m", "290 ml", "6 a day".
  String format(double v) => switch (this) {
        breastfeeding => formatDuration(Duration(seconds: (v * 60).round())),
        diapers => '${v.round()} a day',
        _ => '${v.round()} ml',
      };

  /// The value alone, for chart lists: "59 m", "290 ml", "6".
  String formatShort(double v) => this == diapers ? '${v.round()}' : format(v);
}

/// Days of a period that count towards its average: every day once it's over,
/// and only the finished days of the current one ("Today is added once it's over").
int countedDays(DateTime start, Period p, DateTime today) {
  final end = p.endOf(start);
  final until = end.isAfter(dateOnly(today)) ? dateOnly(today) : end;
  var days = 0;
  // Counted by calendar day, so a clock change in the period does not skew it.
  for (var d = start; d.isBefore(until); d = DateTime(d.year, d.month, d.day + 1)) {
    days++;
  }
  return days;
}

/// Average per day of [metric] over the counted days of the period at [start].
double averagePerDay(Iterable<Entry> all, Metric metric, DateTime start, Period p, DateTime today) {
  final days = countedDays(start, p, today);
  if (days == 0) return 0;
  final until = DateTime(start.year, start.month, start.day + days);
  return metric.of(Totals.of(entriesBetween(all, start, until))) / days;
}

/// "Up 3% on last week", "Down 2% on last month", "Same as last week", "New this week".
String changeLabel(double current, double previous, Period p) {
  if (previous <= 0) return current > 0 ? 'New this ${p.noun}' : 'Same as last ${p.noun}';
  final pct = ((current - previous) / previous * 100).round();
  if (pct == 0) return 'Same as last ${p.noun}';
  return pct > 0 ? 'Up $pct% on last ${p.noun}' : 'Down ${-pct}% on last ${p.noun}';
}

class PeriodValue {
  const PeriodValue(this.start, this.value);

  final DateTime start;
  final double value;
}

/// Averages for the [count] periods ending with the one at [lastStart], oldest first.
List<PeriodValue> series(Iterable<Entry> all, Metric metric, DateTime lastStart, Period p, int count, DateTime today) => [
      for (var i = count - 1; i >= 0; i--)
        PeriodValue(p.shift(lastStart, -i), averagePerDay(all, metric, p.shift(lastStart, -i), p, today)),
    ];

class RoutineCount {
  const RoutineCount(this.title, this.thisPeriod, this.lastPeriod);

  final String title;
  final int thisPeriod;
  final int lastPeriod;
}

/// Routines done in the period at [start] so far, against the whole previous period.
List<RoutineCount> routineCounts(Iterable<Entry> all, DateTime start, Period p) {
  final routines = all.where((e) => e.type == EntryType.routine);
  Map<String, int> count(Iterable<Entry> list) {
    final out = <String, int>{};
    for (final e in list) {
      out[e.title] = (out[e.title] ?? 0) + 1;
    }
    return out;
  }

  final now = count(entriesBetween(routines, start, p.endOf(start)));
  final before = count(entriesBetween(routines, p.shift(start, -1), start));
  final titles = {...now.keys, ...before.keys}.toList()
    ..sort((a, b) {
      final byUse = ((now[b] ?? 0) + (before[b] ?? 0)).compareTo((now[a] ?? 0) + (before[a] ?? 0));
      return byUse != 0 ? byUse : a.compareTo(b);
    });
  return [for (final t in titles) RoutineCount(t, now[t] ?? 0, before[t] ?? 0)];
}

class Reading {
  const Reading(this.at, this.value);

  final DateTime at;
  final double value;
}

/// The latest numbers logged under Other for one title, such as weight.
class Measurement {
  const Measurement({required this.title, required this.unit, required this.readings});

  final String title;
  final String unit;

  /// Every reading, oldest first.
  final List<Reading> readings;

  Reading get latest => readings.last;

  /// The reading before the latest, which the change is measured from.
  Reading? get previous => readings.length < 2 ? null : readings[readings.length - 2];

  double? get change => previous == null ? null : latest.value - previous!.value;
}

const measurementOrder = ['Weight', 'Height', 'Head size', 'Temperature'];

/// Numbers logged under Other, grouped by title. The usual growth readings come first.
List<Measurement> measurements(Iterable<Entry> all) {
  final byTitle = <String, List<Entry>>{};
  for (final e in all) {
    if (e.type != EntryType.other || e.numericValue == null || e.title.isEmpty) continue;
    byTitle.putIfAbsent(e.title, () => []).add(e);
  }
  final out = [
    for (final MapEntry(key: title, value: list) in byTitle.entries)
      Measurement(
        title: title,
        unit: (list..sort((a, b) => a.start.compareTo(b.start))).last.unit,
        readings: [for (final e in list) Reading(e.start, e.numericValue!)],
      ),
  ];
  int rank(String t) {
    final i = measurementOrder.indexOf(t);
    return i < 0 ? measurementOrder.length : i;
  }

  return out..sort((a, b) => rank(a.title) != rank(b.title) ? rank(a.title).compareTo(rank(b.title)) : a.title.compareTo(b.title));
}

class DayRow {
  DayRow(this.day, this.entries) : totals = Totals.of(entries);

  final DateTime day;

  /// What was logged that day, earliest first.
  final List<Entry> entries;
  final Totals totals;
}

/// One row per day of the period at [start] up to [today], newest first.
List<DayRow> dayRows(Iterable<Entry> all, DateTime start, Period p, DateTime today) {
  final end = p.endOf(start);
  final rows = <DayRow>[];
  for (var d = start; d.isBefore(end) && !d.isAfter(dateOnly(today)); d = DateTime(d.year, d.month, d.day + 1)) {
    rows.add(DayRow(d, entriesOnDay(all, d)));
  }
  return rows.reversed.toList();
}

/// "1h 6m", "59m", "0m" for tight rows.
String formatCompact(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "05:07" for a running timer.
String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// "+0.2 kg", "−0.3 °C", "+1.5 cm".
String formatChange(double change, String unit) {
  final rounded = (change * 100).round() / 100;
  final abs = rounded.abs();
  final text = abs == abs.roundToDouble() ? abs.toStringAsFixed(0) : abs.toString();
  final sign = rounded < 0 ? '−' : '+';
  return unit.isEmpty ? '$sign$text' : '$sign$text $unit';
}
