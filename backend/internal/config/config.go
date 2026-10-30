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
	MaxVideoMB   int
	AIModel      string // Claude model for the writing assistant
	TokenTTLDays int
	// TrustedProxies lists proxy IPs/CIDRs whose X-Forwarded-For is trusted
	// (e.g. the Next.js server). "private" trusts loopback and private networks.
	TrustedProxies []string
	// First admin, ensured on startup (created when missing and a password is given).
	AdminUsername string
	AdminPassword string
	// Defaults for GET /api/config until the admin sets them in the panel.
	PublicAPIURL string
	PublicWebURL string
	// Wikimedia Commons API used by the admin photo import.
	CommonsAPIURL string
	// ChatEncryptionKey encrypts chat messages and files at rest; when empty
	// it is derived from JWTSecret. Changing it makes older messages unreadable.
	ChatEncryptionKey string
}

func Load() Config {
	return Config{
		Port:              env("PORT", "8080"),
		DBDriver:          env("DB_DRIVER", "sqlite"),
		DatabaseURL:       env("DATABASE_URL", "modahouse.db"),
		JWTSecret:         env("JWT_SECRET", "dev-secret-change-me"),
		UploadDir:         env("UPLOAD_DIR", "uploads"),
		CORSOrigins:       strings.Split(env("CORS_ORIGINS", "*"), ","),
		Seed:              env("SEED", "true") == "true",
		MaxUploadMB:       envInt("MAX_UPLOAD_MB", 20),
		MaxVideoMB:        envInt("MAX_VIDEO_MB", 60),
		AIModel:           env("AI_MODEL", "claude-opus-5-5"),
		TokenTTLDays:      envInt("TOKEN_TTL_DAYS", 30),
		TrustedProxies:    strings.Split(env("TRUSTED_PROXIES", "127.0.0.1,::1"), ","),
		AdminUsername:     strings.ToLower(env("ADMIN_USERNAME", "")),
		AdminPassword:     os.Getenv("ADMIN_PASSWORD"),
		PublicAPIURL:      env("PUBLIC_API_URL", ""),
		PublicWebURL:      env("PUBLIC_WEB_URL", ""),
		CommonsAPIURL:     env("COMMONS_API_URL", "https://commons.wikimedia.org/w/api.php"),
		ChatEncryptionKey: os.Getenv("CHAT_ENCRYPTION_KEY"),
	}
}

// ChatKey is the secret chat encryption is derived from.
func (c Config) ChatKey() string {
	if c.ChatEncryptionKey != "" {
		return c.ChatEncryptionKey
	}
	return c.JWTSecret
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
