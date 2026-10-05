// Package config loads runtime settings from environment variables.
package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Port         string
	DBDriver     string // "postgres" or "sqlite"
	DatabaseURL  string // DSN for postgres, file path for sqlite
	JWTSecret    string
	UploadDir    string
	CORSOrigins  []string
	Seed         bool
	MaxUploadMB  int
	TokenTTLDays int
}

func Load() Config {
	return Config{
		Port:         env("PORT", "8080"),
		DBDriver:     env("DB_DRIVER", "sqlite"),
		DatabaseURL:  env("DATABASE_URL", "modahouse.db"),
		JWTSecret:    env("JWT_SECRET", "dev-secret-change-me"),
		UploadDir:    env("UPLOAD_DIR", "uploads"),
		CORSOrigins:  strings.Split(env("CORS_ORIGINS", "*"), ","),
		Seed:         env("SEED", "true") == "true",
		MaxUploadMB:  envInt("MAX_UPLOAD_MB", 20),
		TokenTTLDays: envInt("TOKEN_TTL_DAYS", 30),
	}
}

func env(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if n, err := strconv.Atoi(os.Getenv(key)); err == nil && n > 0 {
		return n
	}
	return def
}
