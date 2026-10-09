package httpapi

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func (s *Server) firebaseStatus(w http.ResponseWriter, r *http.Request) {
	missing := s.cfg.MissingFirebase()
	if missing == nil {
		missing = []string{}
	}
	body := map[string]any{
		"configured": s.cfg.FirebaseConfigured(),
		"missing":    missing,
		"provider":   "google",
		"setup": []string{
			"In Firebase Console, open Authentication and enable the Google sign-in provider.",
			"Under Authentication → Settings → Authorized domains, add localhost, 127.0.0.1, and the Railway web hostname (no scheme, no port).",
			"Create a Web app in Project settings and copy its config into the environment variables listed here. These values are public in the browser; do not invent them.",
		},
	}
	if s.cfg.FirebaseConfigured() {
		web := map[string]string{
			"apiKey":            s.cfg.FirebaseAPIKey,
			"authDomain":        s.cfg.FirebaseAuthDomain,
			"projectId":         s.cfg.FirebaseProjectID,
			"appId":             s.cfg.FirebaseAppID,
			"messagingSenderId": s.cfg.FirebaseSenderID,
		}
		if strings.TrimSpace(s.cfg.FirebaseStorageBucket) != "" {
			web["storageBucket"] = s.cfg.FirebaseStorageBucket
		}
		body["web"] = web
	}
	writeJSON(w, http.StatusOK, body)
}

func (s *Server) firebaseExchange(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.FirebaseConfigured() {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"error":   "firebase_not_configured",
			"missing": s.cfg.MissingFirebase(),
		})
		return
	}
	if !s.allowHit("firebase-exchange:" + r.RemoteAddr) {
		writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "rate_limited"})
		return
	}
	var body struct {
		IDToken string `json:"id_token"`
	}
	if err := readJSON(r, &body); err != nil || strings.TrimSpace(body.IDToken) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "id_token_required"})
		return
	}
	email, uid, err := verifyFirebaseIDToken(r.Context(), body.IDToken, s.cfg.FirebaseProjectID, s.cfg.FirebaseKeysURL)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_id_token"})
		return
	}
	userID, err := s.store.UpsertFirebaseUser(r.Context(), newID(), email, uid)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "user_failed"})
		return
	}
	tokens, err := s.issueTokens(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "token_failed"})
		return
	}
	writeJSON(w, http.StatusOK, tokens)
}

type firebaseKeySet struct {
	mu      sync.Mutex
	url     string
	expires time.Time
	keys    map[string]*rsa.PublicKey
}

var firebaseKeys firebaseKeySet

func verifyFirebaseIDToken(ctx context.Context, raw, projectID, keysURL string) (email, uid string, err error) {
	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithIssuer("https://securetoken.google.com/"+projectID),
		jwt.WithAudience(projectID),
		jwt.WithExpirationRequired(),
	)
	claims := jwt.MapClaims{}
	token, err := parser.ParseWithClaims(raw, claims, func(token *jwt.Token) (any, error) {
		kid, _ := token.Header["kid"].(string)
		if kid == "" {
			return nil, errors.New("missing kid")
		}
		return firebasePublicKey(ctx, keysURL, kid)
	})
	if err != nil || !token.Valid {
		return "", "", fmt.Errorf("verify: %w", err)
	}
	sub, _ := claims["sub"].(string)
	emailVal, _ := claims["email"].(string)
	if sub == "" || emailVal == "" || !claimVerified(claims["email_verified"]) {
		return "", "", errors.New("unverified firebase identity")
	}
	return strings.ToLower(emailVal), sub, nil
}

func claimVerified(v any) bool {
	switch t := v.(type) {
	case bool:
		return t
	case string:
		return t == "true"
	default:
		return false
	}
}

func firebasePublicKey(ctx context.Context, keysURL, kid string) (*rsa.PublicKey, error) {
	firebaseKeys.mu.Lock()
	defer firebaseKeys.mu.Unlock()
	if firebaseKeys.url != keysURL || time.Now().After(firebaseKeys.expires) || firebaseKeys.keys == nil {
		keys, err := fetchFirebaseKeys(ctx, keysURL)
		if err != nil {
			return nil, err
		}
		firebaseKeys.url = keysURL
		firebaseKeys.keys = keys
		firebaseKeys.expires = time.Now().Add(time.Hour)
	}
	key := firebaseKeys.keys[kid]
	if key == nil {
		return nil, errors.New("unknown kid")
	}
	return key, nil
}

func fetchFirebaseKeys(ctx context.Context, keysURL string) (map[string]*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, keysURL, nil)
	if err != nil {
		return nil, err
	}
	client := &http.Client{Timeout: 10 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("jwks status %d", res.StatusCode)
	}
	var doc struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(res.Body).Decode(&doc); err != nil {
		return nil, err
	}
	out := map[string]*rsa.PublicKey{}
	for _, k := range doc.Keys {
		if k.Kty != "RSA" || k.Kid == "" {
			continue
		}
		pub, err := rsaFromJWK(k.N, k.E)
		if err != nil {
			continue
		}
		out[k.Kid] = pub
	}
	if len(out) == 0 {
		return nil, errors.New("no rsa keys")
	}
	return out, nil
}

func rsaFromJWK(nB64, eB64 string) (*rsa.PublicKey, error) {
	nb, err := base64.RawURLEncoding.DecodeString(nB64)
	if err != nil {
		return nil, err
	}
	eb, err := base64.RawURLEncoding.DecodeString(eB64)
	if err != nil {
		return nil, err
	}
	n := new(big.Int).SetBytes(nb)
	e := new(big.Int).SetBytes(eb)
	if !e.IsInt64() || e.Int64() < 2 {
		return nil, errors.New("bad exponent")
	}
	return &rsa.PublicKey{N: n, E: int(e.Int64())}, nil
}
