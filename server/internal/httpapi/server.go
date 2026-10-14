package httpapi

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log"
	"mime"
	"net/http"
	"path"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/config"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/store"
	"github.com/golang-jwt/jwt/v5"
)

var uuidRe = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

func init() {
	_ = mime.AddExtensionType(".wasm", "application/wasm")
}

type Server struct {
	cfg   config.Config
	store *store.Store
	mux   *http.ServeMux

	mu   sync.Mutex
	hits map[string][]time.Time
}

func New(cfg config.Config, st *store.Store) *Server {
	s := &Server{
		cfg:    cfg,
		store:  st,
		mux:  http.NewServeMux(),
		hits: map[string][]time.Time{},
	}
	s.routes()
	return s
}

func (s *Server) Handler() http.Handler {
	return s.withLog(s.withCORS(s.withAuth(s.mux)))
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /healthz", s.health)
	s.mux.HandleFunc("GET /v1/auth/firebase/status", s.firebaseStatus)
	s.mux.HandleFunc("POST /v1/auth/firebase/exchange", s.firebaseExchange)
	s.mux.HandleFunc("POST /v1/auth/refresh", s.refresh)
	s.mux.HandleFunc("GET /v1/me", s.me)
	s.mux.HandleFunc("DELETE /v1/me", s.deleteMe)
	s.mux.HandleFunc("GET /v1/babies", s.listBabies)
	s.mux.HandleFunc("POST /v1/babies", s.createBaby)
	s.mux.HandleFunc("PATCH /v1/babies/{id}", s.updateBaby)
	s.mux.HandleFunc("GET /v1/babies/{id}/entries", s.listEntries)
	s.mux.HandleFunc("PUT /v1/babies/{id}/entries/{entryId}", s.putEntry)
	s.mux.HandleFunc("DELETE /v1/babies/{id}/entries/{entryId}", s.deleteEntry)
	s.mux.HandleFunc("POST /v1/events", s.postEvents)
	if s.cfg.WebRoot != "" {
		s.mux.Handle("/", s.staticHandler())
	}
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.store.Ping(r.Context()); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "error", "duckdb": "error"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "duckdb": "ok"})
}

func (s *Server) withLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if id == "" {
			id = randomHex(8)
		}
		rw := &statusWriter{ResponseWriter: w, status: 200}
		rw.Header().Set("X-Request-Id", id)
		start := time.Now()
		next.ServeHTTP(rw, r)
		log.Printf("request_id=%s method=%s path=%s status=%d ms=%d", id, r.Method, r.URL.Path, rw.status, time.Since(start).Milliseconds())
	})
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func (s *Server) withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && s.originAllowed(origin, r.Host) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) originAllowed(origin, host string) bool {
	for _, o := range s.cfg.AllowedOrigins {
		if origin == o {
			return true
		}
	}
	return origin == "https://"+host || origin == "http://"+host
}

func (s *Server) withAuth(next http.Handler) http.Handler {
	public := map[string]bool{
		"/healthz":                 true,
		"/v1/auth/firebase/status":   true,
		"/v1/auth/firebase/exchange": true,
		"/v1/auth/refresh":         true,
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if public[r.URL.Path] || r.URL.Path == "/v1/events" || !strings.HasPrefix(r.URL.Path, "/v1/") {
			next.ServeHTTP(w, r)
			return
		}
		if _, err := s.userID(r); err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *Server) userID(r *http.Request) (string, error) {
	h := r.Header.Get("Authorization")
	if !strings.HasPrefix(h, "Bearer ") {
		return "", errors.New("missing bearer")
	}
	token := strings.TrimPrefix(h, "Bearer ")
	parsed, err := jwt.Parse(token, func(t *jwt.Token) (any, error) {
		if t.Method != jwt.SigningMethodHS256 {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(s.cfg.JWTSecret), nil
	})
	if err != nil || !parsed.Valid {
		return "", errors.New("invalid token")
	}
	claims, ok := parsed.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("claims")
	}
	sub, _ := claims["sub"].(string)
	if !uuidRe.MatchString(sub) {
		return "", errors.New("sub")
	}
	return sub, nil
}

func (s *Server) signAccess(userID string) (string, time.Time, error) {
	exp := time.Now().UTC().Add(15 * time.Minute)
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": userID,
		"exp": exp.Unix(),
		"iat": time.Now().UTC().Unix(),
	})
	signed, err := t.SignedString([]byte(s.cfg.JWTSecret))
	return signed, exp, err
}

func (s *Server) issueTokens(ctx context.Context, userID string) (map[string]any, error) {
	access, exp, err := s.signAccess(userID)
	if err != nil {
		return nil, err
	}
	raw := randomHex(32)
	id := newID()
	expires := time.Now().UTC().Add(30 * 24 * time.Hour)
	if err := s.store.SaveRefreshToken(ctx, id, userID, hashToken(raw), expires); err != nil {
		return nil, err
	}
	user, err := s.store.GetUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"access_token":  access,
		"refresh_token": raw,
		"expires_in":    int(time.Until(exp).Seconds()),
		"token_type":    "Bearer",
		"user": map[string]string{
			"id":    user.ID,
			"email": user.Email,
		},
	}, nil
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func newID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	enc := hex.EncodeToString(b)
	return enc[0:8] + "-" + enc[8:12] + "-" + enc[12:16] + "-" + enc[16:20] + "-" + enc[20:32]
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func readJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		return err
	}
	if len(body) == 0 {
		return errors.New("empty body")
	}
	return json.Unmarshal(body, dst)
}

func validUUID(id string) bool { return uuidRe.MatchString(id) }

func (s *Server) staticHandler() http.Handler {
	root := s.cfg.WebRoot
	files := http.Dir(root)
	fileServer := withGzip(http.FileServer(files))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/v1/") || r.URL.Path == "/healthz" {
			http.NotFound(w, r)
			return
		}
		clean := path.Clean(r.URL.Path)
		setCache(w, clean)
		f, err := files.Open(clean)
		if err != nil {
			r.URL.Path = "/"
			setCache(w, "/index.html")
			fileServer.ServeHTTP(w, r)
			return
		}
		stat, err := f.Stat()
		_ = f.Close()
		if err != nil || stat.IsDir() {
			r.URL.Path = "/"
			setCache(w, "/index.html")
			fileServer.ServeHTTP(w, r)
			return
		}
		fileServer.ServeHTTP(w, r)
	})
}

func setCache(w http.ResponseWriter, name string) {
	base := path.Base(name)
	switch base {
	case "index.html", "flutter_bootstrap.js", "flutter_service_worker.js", "manifest.json", "version.json":
		w.Header().Set("Cache-Control", "no-cache")
		return
	}
	if strings.Contains(name, "/canvaskit/") || regexp.MustCompile(`[0-9a-f]{8,}`).MatchString(base) {
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=300")
}
