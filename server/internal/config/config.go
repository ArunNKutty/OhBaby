package config

import (
	"os"
	"strings"
)

// Config is process configuration. Secrets come only from the environment.
type Config struct {
	Addr           string
	DBPath         string
	JWTSecret      string
	AllowedOrigins []string
	AppOrigins     []string
	GoogleClientID string
	GoogleSecret   string
	GoogleRedirect string
	WebRoot        string
	ExportDir      string
}

func FromEnv() Config {
	return Config{
		Addr:           env("OHBABY_ADDR", ":47220"),
		DBPath:         env("OHBABY_DB", "data/ohbaby.duckdb"),
		JWTSecret:      env("OHBABY_JWT_SECRET", "dev-only-not-for-production"),
		AllowedOrigins: split(env("OHBABY_ALLOWED_ORIGINS", "http://127.0.0.1:47219,http://localhost:47219,http://127.0.0.1:47221,http://localhost:47221")),
		AppOrigins:     split(env("OHBABY_APP_ORIGINS", "http://127.0.0.1:47219,http://localhost:47219,http://127.0.0.1:47221,http://localhost:47221")),
		GoogleClientID: os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleSecret:   os.Getenv("GOOGLE_CLIENT_SECRET"),
		GoogleRedirect: env("GOOGLE_REDIRECT_URI", "http://127.0.0.1:47220/v1/auth/google/callback"),
		WebRoot:        os.Getenv("OHBABY_WEB_ROOT"),
		ExportDir:      os.Getenv("OHBABY_EXPORT_DIR"),
	}
}

func (c Config) GoogleConfigured() bool {
	return strings.TrimSpace(c.GoogleClientID) != "" && strings.TrimSpace(c.GoogleSecret) != ""
}

func (c Config) MissingGoogle() []string {
	var missing []string
	if strings.TrimSpace(c.GoogleClientID) == "" {
		missing = append(missing, "GOOGLE_CLIENT_ID")
	}
	if strings.TrimSpace(c.GoogleSecret) == "" {
		missing = append(missing, "GOOGLE_CLIENT_SECRET")
	}
	return missing
}

func env(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func split(v string) []string {
	parts := strings.Split(v, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
