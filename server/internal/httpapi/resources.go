package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/store"
)

func (s *Server) me(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	user, err := s.store.GetUser(r.Context(), id)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"id": user.ID, "email": user.Email})
}

func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	if err := s.store.RevokeUserTokens(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "delete_failed"})
		return
	}
	if err := s.store.DeleteUser(r.Context(), id); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "delete_failed"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listBabies(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	babies, err := s.store.ListBabies(r.Context(), id)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "list_failed"})
		return
	}
	if babies == nil {
		babies = []store.Baby{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"babies": babies})
}

func (s *Server) createBaby(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	var body struct {
		ID        string  `json:"id"`
		Name      string  `json:"name"`
		BirthDate *string `json:"birth_date"`
	}
	if err := readJSON(r, &body); err != nil || !validUUID(body.ID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	name := strings.TrimSpace(body.Name)
	if name == "" || len(name) > 80 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_name"})
		return
	}
	if body.BirthDate != nil {
		if _, err := time.Parse("2006-01-02", *body.BirthDate); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_birth_date"})
			return
		}
	}
	baby, err := s.store.CreateBaby(r.Context(), id, body.ID, name, body.BirthDate)
	if errors.Is(err, store.ErrConflict) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "conflict"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "create_failed"})
		return
	}
	writeJSON(w, http.StatusOK, baby)
}

// updateBaby takes "name" and/or "birth_date" (YYYY-MM-DD, or null to clear).
func (s *Server) updateBaby(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	babyID := r.PathValue("id")
	if !validUUID(babyID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	var body map[string]json.RawMessage
	if err := readJSON(r, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	var name *string
	if raw, ok := body["name"]; ok {
		var v string
		if err := json.Unmarshal(raw, &v); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_name"})
			return
		}
		v = strings.TrimSpace(v)
		if v == "" || len(v) > 80 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_name"})
			return
		}
		name = &v
	}
	raw, setBirth := body["birth_date"]
	var birth *string
	if setBirth && string(raw) != "null" {
		var v string
		if err := json.Unmarshal(raw, &v); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_birth_date"})
			return
		}
		d, err := time.Parse("2006-01-02", v)
		if err != nil || d.After(time.Now().UTC().Add(24*time.Hour)) {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_birth_date"})
			return
		}
		birth = &v
	}
	if name == nil && !setBirth {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "nothing_to_change"})
		return
	}
	baby, err := s.store.UpdateBaby(r.Context(), id, babyID, name, setBirth, birth)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "update_failed"})
		return
	}
	writeJSON(w, http.StatusOK, baby)
}

func (s *Server) listEntries(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	if !validUUID(babyID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	var since int64
	if raw := r.URL.Query().Get("since"); raw != "" {
		var err error
		since, err = parseInt(raw)
		if err != nil || since < 0 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_since"})
			return
		}
	}
	list, next, err := s.store.EntriesSince(r.Context(), userID, babyID, since)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "list_failed"})
		return
	}
	out := make([]map[string]any, 0, len(list))
	for _, e := range list {
		out = append(out, entryJSON(e))
	}
	writeJSON(w, http.StatusOK, map[string]any{"entries": out, "sync_token": next})
}

func (s *Server) putEntry(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	entryID := r.PathValue("entryId")
	if !validUUID(babyID) || !validUUID(entryID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_id"})
		return
	}
	var body entryIn
	if err := readJSON(r, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_entry"})
		return
	}
	e, err := body.toEntry(babyID, entryID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	saved, err := s.store.UpsertEntry(r.Context(), userID, e)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if errors.Is(err, store.ErrConflict) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "conflict"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "save_failed"})
		return
	}
	writeJSON(w, http.StatusOK, entryJSON(saved))
}

func (s *Server) deleteEntry(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	entryID := r.PathValue("entryId")
	if !validUUID(babyID) || !validUUID(entryID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_id"})
		return
	}
	saved, err := s.store.DeleteEntry(r.Context(), userID, babyID, entryID, time.Now().UTC())
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "delete_failed"})
		return
	}
	writeJSON(w, http.StatusOK, entryJSON(saved))
}

var allowedEvents = map[string]bool{
	"app_opened": true, "feeding_add_started": true, "feeding_saved": true,
	"feeding_deleted": true, "timer_started": true, "day_changed": true,
	"week_viewed": true, "sign_in_started": true, "sign_in_completed": true,
	"sync_failed": true, "client_error": true,
	"entry_saved": true, "entry_deleted": true, "quick_add": true, "trends_viewed": true,
}

func (s *Server) postEvents(w http.ResponseWriter, r *http.Request) {
	var userID *string
	if r.Header.Get("Authorization") != "" {
		id, err := s.userID(r)
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		userID = &id
	}
	var body struct {
		Events []struct {
			EventID    string         `json:"event_id"`
			Name       string         `json:"name"`
			ClientTS   string         `json:"client_ts"`
			AnonID     string         `json:"anon_id"`
			SessionID  string         `json:"session_id"`
			Platform   string         `json:"platform"`
			AppVersion string         `json:"app_version"`
			Props      map[string]any `json:"props"`
		} `json:"events"`
	}
	if err := readJSON(r, &body); err != nil || len(body.Events) == 0 || len(body.Events) > 50 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_batch"})
		return
	}
	batch := make([]store.Event, 0, len(body.Events))
	for _, e := range body.Events {
		if !validUUID(e.EventID) || !validUUID(e.AnonID) || !validUUID(e.SessionID) || !allowedEvents[e.Name] {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_event"})
			return
		}
		ts, err := time.Parse(time.RFC3339, e.ClientTS)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_event"})
			return
		}
		props := sanitizeProps(e.Props)
		raw, _ := json.Marshal(props)
		platform := e.Platform
		if platform == "" {
			platform = "web"
		}
		version := e.AppVersion
		if version == "" {
			version = "0.1.0"
		}
		batch = append(batch, store.Event{
			ID: e.EventID, Name: e.Name, ClientTS: ts, AnonID: e.AnonID,
			UserID: userID, SessionID: e.SessionID, Platform: platform,
			AppVersion: version, PropsJSON: string(raw),
		})
	}
	if err := s.store.AppendEvents(r.Context(), batch); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "append_failed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"accepted": len(batch)})
}

func sanitizeProps(in map[string]any) map[string]any {
	if in == nil {
		return map[string]any{}
	}
	blocked := map[string]bool{
		"name": true, "notes": true, "email": true, "baby_name": true,
		"amount_ml": true, "start": true, "end": true,
	}
	out := map[string]any{}
	for k, v := range in {
		if blocked[strings.ToLower(k)] {
			continue
		}
		switch n := v.(type) {
		case string:
			if len(n) > 80 {
				n = n[:80]
			}
			out[k] = n
		default:
			out[k] = v
		}
	}
	return out
}

type entryIn struct {
	Type      string  `json:"type"`
	Start     string  `json:"start_utc"`
	End       string  `json:"end_utc"`
	Offset    int     `json:"utc_offset_min"`
	Left      int     `json:"left_ms"`
	Right     int     `json:"right_ms"`
	EndSide   *string `json:"end_side"`
	Amount    int     `json:"amount_ml"`
	LeftMl    int     `json:"left_ml"`
	RightMl   int     `json:"right_ml"`
	Diaper    *string `json:"diaper"`
	Rash      bool    `json:"rash"`
	Title     string  `json:"title"`
	Value     string  `json:"value"`
	Unit      string  `json:"unit"`
	Notes     string  `json:"notes"`
	UpdatedAt string  `json:"updated_at"`
}

// toEntry checks the fields the type uses and clears the ones it does not.
func (in entryIn) toEntry(babyID, id string) (store.Entry, error) {
	start, err := time.Parse(time.RFC3339, in.Start)
	if err != nil {
		return store.Entry{}, errors.New("invalid_time")
	}
	end, err := time.Parse(time.RFC3339, in.End)
	if err != nil {
		return store.Entry{}, errors.New("invalid_time")
	}
	if end.Before(start) {
		return store.Entry{}, errors.New("invalid_time")
	}
	if in.Offset < -14*60 || in.Offset > 14*60 {
		return store.Entry{}, errors.New("invalid_offset")
	}
	if in.Left < 0 || in.Right < 0 || in.Amount < 0 || in.Amount > 2000 ||
		in.LeftMl < 0 || in.LeftMl > 2000 || in.RightMl < 0 || in.RightMl > 2000 {
		return store.Entry{}, errors.New("invalid_amount")
	}
	e := store.Entry{ID: id, BabyID: babyID, Type: in.Type, StartUTC: start.UTC(), EndUTC: end.UTC(), OffsetMin: in.Offset}
	title := strings.TrimSpace(in.Title)
	value := strings.TrimSpace(in.Value)
	unit := strings.TrimSpace(in.Unit)
	switch in.Type {
	case "breast":
		if in.EndSide == nil || (*in.EndSide != "left" && *in.EndSide != "right") {
			return store.Entry{}, errors.New("end_side_required")
		}
		e.LeftMs, e.RightMs, e.EndSide = in.Left, in.Right, in.EndSide
	case "formula", "breast_milk":
		e.AmountMl = in.Amount
	case "pump":
		e.LeftMl, e.RightMl, e.AmountMl = in.LeftMl, in.RightMl, in.Amount
		if in.LeftMl+in.RightMl > 0 {
			e.AmountMl = in.LeftMl + in.RightMl
		}
		if e.AmountMl == 0 && !end.After(start) {
			return store.Entry{}, errors.New("pump_empty")
		}
	case "diaper":
		if in.Diaper == nil {
			return store.Entry{}, errors.New("diaper_required")
		}
		switch *in.Diaper {
		case "wet", "dirty", "both", "dry":
		default:
			return store.Entry{}, errors.New("diaper_required")
		}
		e.Diaper, e.Rash = in.Diaper, in.Rash
	case "routine", "other":
		if title == "" || len(title) > 80 {
			return store.Entry{}, errors.New("title_required")
		}
		if len(value) > 200 || len(unit) > 16 {
			return store.Entry{}, errors.New("value_too_long")
		}
		e.Title = title
		if in.Type == "other" {
			e.Value, e.Unit = value, unit
		}
	default:
		return store.Entry{}, errors.New("invalid_type")
	}
	notes := strings.TrimSpace(in.Notes)
	if len(notes) > 4000 {
		return store.Entry{}, errors.New("notes_too_long")
	}
	e.Notes = notes
	e.UpdatedAt = time.Now().UTC()
	if in.UpdatedAt != "" {
		parsed, err := time.Parse(time.RFC3339, in.UpdatedAt)
		if err != nil {
			return store.Entry{}, errors.New("invalid_time")
		}
		e.UpdatedAt = parsed.UTC()
	}
	return e, nil
}

func entryJSON(e store.Entry) map[string]any {
	var deleted any
	if e.DeletedAt != nil {
		deleted = e.DeletedAt.UTC().Format(time.RFC3339)
	}
	return map[string]any{
		"id":             e.ID,
		"baby_id":        e.BabyID,
		"type":           e.Type,
		"start_utc":      e.StartUTC.UTC().Format(time.RFC3339),
		"end_utc":        e.EndUTC.UTC().Format(time.RFC3339),
		"utc_offset_min": e.OffsetMin,
		"left_ms":        e.LeftMs,
		"right_ms":       e.RightMs,
		"end_side":       e.EndSide,
		"amount_ml":      e.AmountMl,
		"left_ml":        e.LeftMl,
		"right_ml":       e.RightMl,
		"diaper":         e.Diaper,
		"rash":           e.Rash,
		"title":          e.Title,
		"value":          e.Value,
		"unit":           e.Unit,
		"notes":          e.Notes,
		"updated_at":     e.UpdatedAt.UTC().Format(time.RFC3339),
		"deleted_at":     deleted,
		"change_no":      e.ChangeNo,
	}
}

func parseInt(raw string) (int64, error) {
	var n int64
	for _, c := range raw {
		if c < '0' || c > '9' {
			return 0, errors.New("nan")
		}
		n = n*10 + int64(c-'0')
	}
	return n, nil
}
