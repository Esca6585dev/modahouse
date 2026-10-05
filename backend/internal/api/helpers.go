package api

import (
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

type Handler struct {
	db    *gorm.DB
	store *storage.Storage
	cfg   config.Config
}

type Page[T any] struct {
	Items   []T  `json:"items"`
	Page    int  `json:"page"`
	Limit   int  `json:"limit"`
	HasMore bool `json:"hasMore"`
}

// fail writes {"error": msg} with the given status.
func fail(c fiber.Ctx, status int, msg string) error {
	return c.Status(status).JSON(fiber.Map{"error": msg})
}

func notFound(c fiber.Ctx) error { return fail(c, fiber.StatusNotFound, "Tapylmady") }
func forbidden(c fiber.Ctx) error {
	return fail(c, fiber.StatusForbidden, "Bu hereket üçin rugsadyňyz ýok")
}
func badRequest(c fiber.Ctx, msg string) error {
	return fail(c, fiber.StatusBadRequest, msg)
}

// Returned (not written) by loaders so callers stop; the app ErrorHandler renders them as JSON.
var (
	errNotFound  = fiber.NewError(fiber.StatusNotFound, "Tapylmady")
	errForbidden = fiber.NewError(fiber.StatusForbidden, "Bu hereket üçin rugsadyňyz ýok")
)

// viewerID returns the authenticated user id, or 0 for guests.
func viewerID(c fiber.Ctx) uint {
	return fiber.Locals[uint](c, localUserID)
}

func idParam(c fiber.Ctx, name string) (uint, bool) {
	n, err := strconv.ParseUint(c.Params(name), 10, 64)
	if err != nil || n == 0 {
		return 0, false
	}
	return uint(n), true
}

// paging reads ?page (1-based) and ?limit (1..50).
func paging(c fiber.Ctx, defLimit int) (page, limit, offset int) {
	page = fiber.Query[int](c, "page", 1)
	limit = fiber.Query[int](c, "limit", defLimit)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = defLimit
	}
	return page, limit, (page - 1) * limit
}

// trimPage fetches limit+1 rows upstream; this trims the extra row and reports hasMore.
func trimPage[T any](rows []T, limit int) ([]T, bool) {
	if len(rows) > limit {
		return rows[:limit], true
	}
	return rows, false
}

func clean(s string, max int) string {
	s = strings.TrimSpace(s)
	if r := []rune(s); len(r) > max {
		s = string(r[:max])
	}
	return s
}

func splitTags(s string) []string {
	out := []string{}
	seen := map[string]bool{}
	for _, t := range strings.Split(s, ",") {
		t = strings.ToLower(strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(t), "#")))
		if t != "" && !seen[t] && len(out) < 10 {
			seen[t] = true
			out = append(out, t)
		}
	}
	return out
}
