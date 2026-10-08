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

func (s *Server) renameBaby(w http.ResponseWriter, r *http.Request) {
	id, _ := s.userID(r)
	babyID := r.PathValue("id")
	if !validUUID(babyID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	var body struct {
		Name string `json:"name"`
	}
	if err := readJSON(r, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_name"})
		return
	}
	name := strings.TrimSpace(body.Name)
	if name == "" || len(name) > 80 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_name"})
		return
	}
	baby, err := s.store.RenameBaby(r.Context(), id, babyID, name)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "rename_failed"})
		return
	}
	writeJSON(w, http.StatusOK, baby)
}

func (s *Server) listFeedings(w http.ResponseWriter, r *http.Request) {
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
	list, next, err := s.store.FeedingsSince(r.Context(), userID, babyID, since)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "list_failed"})
		return
	}
	out := make([]map[string]any, 0, len(list))
	for _, f := range list {
		out = append(out, feedingJSON(f))
	}
	writeJSON(w, http.StatusOK, map[string]any{"feedings": out, "sync_token": next})
}

func (s *Server) putFeeding(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	feedingID := r.PathValue("feedingId")
	if !validUUID(babyID) || !validUUID(feedingID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_id"})
		return
	}
	var body feedingIn
	if err := readJSON(r, &body); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_feeding"})
		return
	}
	f, err := body.toFeeding(babyID, feedingID)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	saved, err := s.store.UpsertFeeding(r.Context(), userID, f)
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
	writeJSON(w, http.StatusOK, feedingJSON(saved))
}

func (s *Server) deleteFeeding(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	feedingID := r.PathValue("feedingId")
	if !validUUID(babyID) || !validUUID(feedingID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_id"})
		return
	}
	saved, err := s.store.DeleteFeeding(r.Context(), userID, babyID, feedingID, time.Now().UTC())
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "delete_failed"})
		return
	}
	writeJSON(w, http.StatusOK, feedingJSON(saved))
}

func (s *Server) weekSummary(w http.ResponseWriter, r *http.Request) {
	userID, _ := s.userID(r)
	babyID := r.PathValue("id")
	if !validUUID(babyID) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_baby"})
		return
	}
	start, err := time.Parse("2006-01-02", r.URL.Query().Get("start"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_start"})
		return
	}
	today := start
	if raw := r.URL.Query().Get("today"); raw != "" {
		today, err = time.Parse("2006-01-02", raw)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_today"})
			return
		}
	}
	list, err := s.store.FeedingsForBaby(r.Context(), userID, babyID)
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "summary_failed"})
		return
	}
	writeJSON(w, http.StatusOK, store.SummarizeWeek(list, start, today))
}

var allowedEvents = map[string]bool{
	"app_opened": true, "feeding_add_started": true, "feeding_saved": true,
	"feeding_deleted": true, "timer_started": true, "day_changed": true,
	"week_viewed": true, "sign_in_started": true, "sign_in_completed": true,
	"sync_failed": true, "client_error": true,
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

type feedingIn struct {
	Type      string  `json:"type"`
	Start     string  `json:"start_utc"`
	End       string  `json:"end_utc"`
	Offset    int     `json:"utc_offset_min"`
	Left      int     `json:"left_ms"`
	Right     int     `json:"right_ms"`
	EndSide   *string `json:"end_side"`
	Amount    int     `json:"amount_ml"`
	Notes     string  `json:"notes"`
	UpdatedAt string  `json:"updated_at"`
}

func (in feedingIn) toFeeding(babyID, id string) (store.Feeding, error) {
	kind := in.Type
	if kind == "bottle" {
		kind = "formula"
	}
	switch kind {
	case "breast", "formula", "breast_milk":
	default:
		return store.Feeding{}, errors.New("invalid_type")
	}
	start, err := time.Parse(time.RFC3339, in.Start)
	if err != nil {
		return store.Feeding{}, errors.New("invalid_time")
	}
	end, err := time.Parse(time.RFC3339, in.End)
	if err != nil {
		return store.Feeding{}, errors.New("invalid_time")
	}
	if end.Before(start) {
		return store.Feeding{}, errors.New("invalid_time")
	}
	if in.Offset < -14*60 || in.Offset > 14*60 {
		return store.Feeding{}, errors.New("invalid_offset")
	}
	if kind == "breast" {
		if in.EndSide == nil || (*in.EndSide != "left" && *in.EndSide != "right") {
			return store.Feeding{}, errors.New("end_side_required")
		}
	} else {
		in.EndSide = nil
		in.Left = 0
		in.Right = 0
	}
	if in.Amount < 0 || in.Amount > 2000 || in.Left < 0 || in.Right < 0 {
		return store.Feeding{}, errors.New("invalid_amount")
	}
	notes := strings.TrimSpace(in.Notes)
	if len(notes) > 4000 {
		return store.Feeding{}, errors.New("notes_too_long")
	}
	updated := time.Now().UTC()
	if in.UpdatedAt != "" {
		parsed, err := time.Parse(time.RFC3339, in.UpdatedAt)
		if err != nil {
			return store.Feeding{}, errors.New("invalid_time")
		}
		updated = parsed.UTC()
	}
	return store.Feeding{
		ID: id, BabyID: babyID, Type: kind, StartUTC: start.UTC(), EndUTC: end.UTC(),
		OffsetMin: in.Offset, LeftMs: in.Left, RightMs: in.Right, EndSide: in.EndSide,
		AmountMl: in.Amount, Notes: notes, UpdatedAt: updated,
	}, nil
}

func feedingJSON(f store.Feeding) map[string]any {
	var deleted any
	if f.DeletedAt != nil {
		deleted = f.DeletedAt.UTC().Format(time.RFC3339)
	}
	return map[string]any{
		"id":             f.ID,
		"baby_id":        f.BabyID,
		"type":           f.Type,
		"start_utc":      f.StartUTC.UTC().Format(time.RFC3339),
		"end_utc":        f.EndUTC.UTC().Format(time.RFC3339),
		"utc_offset_min": f.OffsetMin,
		"left_ms":        f.LeftMs,
		"right_ms":       f.RightMs,
		"end_side":       f.EndSide,
		"amount_ml":      f.AmountMl,
		"notes":          f.Notes,
		"updated_at":     f.UpdatedAt.UTC().Format(time.RFC3339),
		"deleted_at":     deleted,
		"change_no":      f.ChangeNo,
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
