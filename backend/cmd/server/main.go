package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/esca6585dev/modahouse/backend/internal/api"
	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/database"
	"github.com/esca6585dev/modahouse/backend/internal/seed"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

func main() {
	cfg := config.Load()
	if cfg.JWTSecret == "dev-secret-change-me" {
		log.Println("WARNING: JWT_SECRET is not set; using an insecure development secret")
	}

	db, err := database.Open(cfg.DBDriver, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	store, err := storage.New(cfg.UploadDir)
	if err != nil {
		log.Fatalf("storage: %v", err)
	}
	if cfg.Seed {
		if err := seed.Run(db, store); err != nil {
			log.Fatalf("seed: %v", err)
		}
	}

	app := api.New(db, store, cfg, api.Options{})

	go func() {
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
		<-quit
		_ = app.Shutdown()
	}()

	log.Printf("ModaHouse API listening on :%s (db=%s)", cfg.Port, cfg.DBDriver)
	if err := app.Listen(":"+cfg.Port, fiberListenConfig()); err != nil {
		log.Fatal(err)
	}
}
