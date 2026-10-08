package httpapi

import (
	"net/http"
	"time"
)

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := readJSON(r, &body); err != nil || body.RefreshToken == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "refresh_token_required"})
		return
	}
	newRaw := randomHex(32)
	newID := newID()
	expires := time.Now().UTC().Add(30 * 24 * time.Hour)
	userID, err := s.store.RotateRefresh(r.Context(), hashToken(body.RefreshToken), newID, hashToken(newRaw), expires)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_refresh"})
		return
	}
	access, exp, err := s.signAccess(userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token_failed"})
		return
	}
	user, err := s.store.GetUser(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_refresh"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"access_token":  access,
		"refresh_token": newRaw,
		"expires_in":    int(time.Until(exp).Seconds()),
		"token_type":    "Bearer",
		"user":          map[string]string{"id": user.ID, "email": user.Email},
	})
}

func (s *Server) allowHit(key string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	cut := now.Add(-time.Hour)
	prev := s.hits[key]
	kept := prev[:0]
	for _, t := range prev {
		if t.After(cut) {
			kept = append(kept, t)
		}
	}
	if len(kept) >= 30 {
		s.hits[key] = kept
		return false
	}
	s.hits[key] = append(kept, now)
	return true
}
