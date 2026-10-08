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
	FirebaseAPIKey        string
	FirebaseAuthDomain    string
	FirebaseProjectID     string
	FirebaseAppID         string
	FirebaseSenderID      string
	FirebaseStorageBucket string
	FirebaseKeysURL       string
	WebRoot               string
	ExportDir             string
}

func FromEnv() Config {
	return Config{
		Addr:           env("OHBABY_ADDR", ":47220"),
		DBPath:         env("OHBABY_DB", "data/ohbaby.duckdb"),
		JWTSecret:      env("OHBABY_JWT_SECRET", "dev-only-not-for-production"),
		AllowedOrigins: split(env("OHBABY_ALLOWED_ORIGINS", "http://127.0.0.1:47219,http://localhost:47219,http://127.0.0.1:47221,http://localhost:47221")),
		AppOrigins:     split(env("OHBABY_APP_ORIGINS", "http://127.0.0.1:47219,http://localhost:47219,http://127.0.0.1:47221,http://localhost:47221")),
		FirebaseAPIKey:        os.Getenv("FIREBASE_API_KEY"),
		FirebaseAuthDomain:    os.Getenv("FIREBASE_AUTH_DOMAIN"),
		FirebaseProjectID:     os.Getenv("FIREBASE_PROJECT_ID"),
		FirebaseAppID:         os.Getenv("FIREBASE_APP_ID"),
		FirebaseSenderID:      os.Getenv("FIREBASE_MESSAGING_SENDER_ID"),
		FirebaseStorageBucket: os.Getenv("FIREBASE_STORAGE_BUCKET"),
		FirebaseKeysURL:       env("FIREBASE_JWKS_URL", "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
		WebRoot:               os.Getenv("OHBABY_WEB_ROOT"),
		ExportDir:             os.Getenv("OHBABY_EXPORT_DIR"),
	}
}

func (c Config) FirebaseConfigured() bool {
	return len(c.MissingFirebase()) == 0
}

func (c Config) MissingFirebase() []string {
	need := []struct{ key, val string }{
		{"FIREBASE_API_KEY", c.FirebaseAPIKey},
		{"FIREBASE_AUTH_DOMAIN", c.FirebaseAuthDomain},
		{"FIREBASE_PROJECT_ID", c.FirebaseProjectID},
		{"FIREBASE_APP_ID", c.FirebaseAppID},
		{"FIREBASE_MESSAGING_SENDER_ID", c.FirebaseSenderID},
	}
	var missing []string
	for _, item := range need {
		if strings.TrimSpace(item.val) == "" {
			missing = append(missing, item.key)
		}
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
