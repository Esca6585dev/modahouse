package api

import (
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/golang-jwt/jwt/v5"
)

const localUserID = "uid"

func (h *Handler) issueToken(userID uint) (string, error) {
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Subject:   strconv.FormatUint(uint64(userID), 10),
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(h.cfg.TokenTTLDays) * 24 * time.Hour)),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(h.cfg.JWTSecret))
}

func (h *Handler) parseToken(raw string) (uint, bool) {
	claims := &jwt.RegisteredClaims{}
	tok, err := jwt.ParseWithClaims(raw, claims, func(t *jwt.Token) (any, error) {
		return []byte(h.cfg.JWTSecret), nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	if err != nil || !tok.Valid {
		return 0, false
	}
	id, err := strconv.ParseUint(claims.Subject, 10, 64)
	if err != nil || id == 0 {
		return 0, false
	}
	return uint(id), true
}

// optionalAuth stores the user id in locals when a valid Bearer token is sent.
// It never rejects the request; requireAuth does that.
func (h *Handler) optionalAuth(c fiber.Ctx) error {
	header := c.Get(fiber.HeaderAuthorization)
	if raw, ok := strings.CutPrefix(header, "Bearer "); ok {
		if id, ok := h.parseToken(strings.TrimSpace(raw)); ok {
			var exists int64
			h.db.Table("users").Where("id = ?", id).Count(&exists)
			if exists > 0 {
				c.Locals(localUserID, id)
			}
		}
	}
	return c.Next()
}

func requireAuth(c fiber.Ctx) error {
	if viewerID(c) == 0 {
		return fail(c, fiber.StatusUnauthorized, "Ilki ulgama giriň")
	}
	return c.Next()
}
