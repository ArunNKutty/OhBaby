package main

import (
	"log"
	"net/http"

	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/config"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/httpapi"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/store"
)

func main() {
	cfg := config.FromEnv()
	if cfg.JWTSecret == "dev-only-not-for-production" {
		log.Print("OHBABY_JWT_SECRET is the development default. Set a long random secret before sharing this server.")
	}
	if !cfg.GoogleConfigured() {
		log.Printf("Google sign-in is not configured. Missing %v. Register this redirect URI on the Google OAuth client: %s", cfg.MissingGoogle(), cfg.GoogleRedirect)
	}
	st, err := store.Open(cfg.DBPath)
	if err != nil {
		log.Fatal(err)
	}
	defer st.Close()
	srv := &http.Server{
		Addr:    cfg.Addr,
		Handler: httpapi.New(cfg, st).Handler(),
	}
	log.Printf("Oh baby baby! API listening on %s", cfg.Addr)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
