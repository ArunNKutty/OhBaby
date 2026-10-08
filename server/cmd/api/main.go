package main

import (
	"log"
	"net/http"
	"strings"

	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/config"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/httpapi"
	"github.com/ArunNKutty/Baby-Feed-Tracker/server/internal/store"
)

func main() {
	cfg := config.FromEnv()
	if cfg.JWTSecret == "dev-only-not-for-production" {
		log.Print("OHBABY_JWT_SECRET is the development default. Set a long random secret before sharing this server.")
	}
	if !cfg.FirebaseConfigured() {
		log.Printf("Firebase sign-in is not configured. Missing %v. Enable Google in Firebase Authentication and set the web app config.", cfg.MissingFirebase())
	}
	var (
		st  *store.Store
		err error
	)
	if strings.HasPrefix(cfg.DBPath, "quack:") {
		if cfg.DuckDBToken == "" || cfg.DuckDBToken == "dev-only-not-for-production" {
			log.Print("DUCKDB_QUACK_TOKEN is missing or the development default. Set a long random token before sharing the DuckDB server.")
		}
		st, err = store.OpenRemote(cfg.DBPath, cfg.DuckDBToken)
	} else {
		st, err = store.Open(cfg.DBPath)
	}
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
