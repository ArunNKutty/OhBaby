package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

func (s *Server) googleStatus(w http.ResponseWriter, r *http.Request) {
	missing := s.cfg.MissingGoogle()
	if missing == nil {
		missing = []string{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"configured":   s.cfg.GoogleConfigured(),
		"redirect_uri": s.cfg.GoogleRedirect,
		"missing":      missing,
	})
}

func (s *Server) googleStart(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.GoogleConfigured() {
		missing := s.cfg.MissingGoogle()
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"error":        "google_not_configured",
			"configured":   false,
			"redirect_uri": s.cfg.GoogleRedirect,
			"missing":      missing,
			"message":      "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET. Register this exact redirect URI on the Google OAuth client.",
		})
		return
	}
	if !s.allowHit("google-start:" + r.RemoteAddr) {
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate_limited"})
		return
	}
	returnTo := r.URL.Query().Get("return_to")
	if returnTo == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "return_to_required"})
		return
	}
	if !s.allowReturn(returnTo, r.Host) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "return_to_not_allowed"})
		return
	}
	state := randomHex(16)
	s.mu.Lock()
	s.states[state] = oauthState{ReturnTo: returnTo, Expires: time.Now().Add(10 * time.Minute)}
	s.mu.Unlock()

	q := url.Values{}
	q.Set("client_id", s.cfg.GoogleClientID)
	q.Set("redirect_uri", s.cfg.GoogleRedirect)
	q.Set("response_type", "code")
	q.Set("scope", "openid email profile")
	q.Set("state", state)
	q.Set("prompt", "select_account")
	http.Redirect(w, r, "https://accounts.google.com/o/oauth2/v2/auth?"+q.Encode(), http.StatusFound)
}

func (s *Server) googleCallback(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	state := q.Get("state")
	s.mu.Lock()
	saved, ok := s.states[state]
	if ok {
		delete(s.states, state)
	}
	s.mu.Unlock()
	if !ok || time.Now().After(saved.Expires) || !s.allowReturn(saved.ReturnTo, r.Host) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_state"})
		return
	}
	if q.Get("error") != "" {
		s.redirectErr(w, r, saved.ReturnTo, "google_denied")
		return
	}
	email, sub, err := s.exchangeGoogleCode(r.Context(), q.Get("code"))
	if err != nil {
		s.redirectErr(w, r, saved.ReturnTo, "google_exchange_failed")
		return
	}
	userID, err := s.store.UpsertGoogleUser(r.Context(), newID(), email, sub)
	if err != nil {
		s.redirectErr(w, r, saved.ReturnTo, "account_failed")
		return
	}
	code := randomHex(24)
	s.mu.Lock()
	s.codes[code] = exchangeCode{UserID: userID, Expires: time.Now().Add(2 * time.Minute)}
	s.mu.Unlock()
	http.Redirect(w, r, appendQuery(saved.ReturnTo, "auth_code", code), http.StatusFound)
}

func (s *Server) googleExchange(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Code string `json:"code"`
	}
	if err := readJSON(r, &body); err != nil || body.Code == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "code_required"})
		return
	}
	s.mu.Lock()
	saved, ok := s.codes[body.Code]
	if ok {
		delete(s.codes, body.Code)
	}
	s.mu.Unlock()
	if !ok || time.Now().After(saved.Expires) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_code"})
		return
	}
	tokens, err := s.issueTokens(r.Context(), saved.UserID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token_failed"})
		return
	}
	writeJSON(w, http.StatusOK, tokens)
}

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

func (s *Server) exchangeGoogleCode(ctx context.Context, code string) (email, sub string, err error) {
	form := url.Values{}
	form.Set("code", code)
	form.Set("client_id", s.cfg.GoogleClientID)
	form.Set("client_secret", s.cfg.GoogleSecret)
	form.Set("redirect_uri", s.cfg.GoogleRedirect)
	form.Set("grant_type", "authorization_code")
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://oauth2.googleapis.com/token", strings.NewReader(form.Encode()))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	client := &http.Client{Timeout: 10 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return "", "", err
	}
	defer res.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("token status %d", res.StatusCode)
	}
	var tok struct {
		IDToken string `json:"id_token"`
	}
	if err := json.Unmarshal(body, &tok); err != nil || tok.IDToken == "" {
		return "", "", fmt.Errorf("missing id_token")
	}
	infoReq, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://oauth2.googleapis.com/tokeninfo?id_token="+url.QueryEscape(tok.IDToken), nil)
	if err != nil {
		return "", "", err
	}
	infoRes, err := client.Do(infoReq)
	if err != nil {
		return "", "", err
	}
	defer infoRes.Body.Close()
	infoBody, _ := io.ReadAll(io.LimitReader(infoRes.Body, 1<<20))
	if infoRes.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("tokeninfo status %d", infoRes.StatusCode)
	}
	var info struct {
		Aud           string `json:"aud"`
		Email         string `json:"email"`
		EmailVerified string `json:"email_verified"`
		Sub           string `json:"sub"`
	}
	if err := json.Unmarshal(infoBody, &info); err != nil {
		return "", "", err
	}
	if info.Aud != s.cfg.GoogleClientID || info.Sub == "" || info.Email == "" || info.EmailVerified != "true" {
		return "", "", fmt.Errorf("unverified google identity")
	}
	return strings.ToLower(info.Email), info.Sub, nil
}

func (s *Server) allowReturn(raw, host string) bool {
	u, err := url.Parse(raw)
	if err != nil || u.User != nil || u.Host == "" || (u.Scheme != "https" && u.Scheme != "http") {
		return false
	}
	origin := u.Scheme + "://" + u.Host
	for _, allowed := range s.cfg.AppOrigins {
		if origin == allowed {
			return true
		}
	}
	return origin == "https://"+host || origin == "http://"+host
}

func (s *Server) redirectErr(w http.ResponseWriter, r *http.Request, returnTo, code string) {
	http.Redirect(w, r, appendQuery(returnTo, "auth_error", code), http.StatusFound)
}

func appendQuery(raw, key, value string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return raw
	}
	q := u.Query()
	q.Set(key, value)
	u.RawQuery = q.Encode()
	return u.String()
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
