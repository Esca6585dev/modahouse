// Package api wires the HTTP routes for the ModaHouse REST API.
package api

import (
	"errors"
	"log"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/limiter"
	"github.com/gofiber/fiber/v3/middleware/logger"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/static"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

type Options struct {
	Quiet bool // disable request logging (tests)
}

func New(db *gorm.DB, store *storage.Storage, cfg config.Config, opts Options) *fiber.App {
	h := &Handler{db: db, store: store, cfg: cfg}

	app := fiber.New(fiber.Config{
		AppName:   "ModaHouse API",
		BodyLimit: cfg.MaxUploadMB * 1024 * 1024,
		ErrorHandler: func(c fiber.Ctx, err error) error {
			var fe *fiber.Error
			if errors.As(err, &fe) {
				return fail(c, fe.Code, fe.Message)
			}
			log.Printf("error %s %s: %v", c.Method(), c.Path(), err)
			return fail(c, fiber.StatusInternalServerError, "Serwerde ýalňyşlyk ýüze çykdy")
		},
	})

	app.Use(recover.New())
	if !opts.Quiet {
		app.Use(logger.New())
	}
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSOrigins,
		AllowHeaders: []string{"Origin", "Content-Type", "Accept", "Authorization"},
		AllowMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
	}))

	app.Get("/uploads/*", func(c fiber.Ctx) error {
		// Seed images are SVG: forbid scripts if one is opened directly.
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; sandbox")
		return c.Next()
	}, static.New(store.Dir, static.Config{MaxAge: 86400}))

	api := app.Group("/api", h.optionalAuth)
	api.Get("/health", func(c fiber.Ctx) error { return c.JSON(fiber.Map{"status": "ok"}) })
	api.Get("/categories", listCategories)

	auth := api.Group("/auth")
	if !opts.Quiet {
		auth.Use(limiter.New(limiter.Config{Max: 20, Expiration: time.Minute}))
	}
	auth.Post("/register", h.register)
	auth.Post("/login", h.login)
	auth.Get("/me", requireAuth, h.getMe)

	me := api.Group("/me", requireAuth)
	me.Put("/", h.updateMe)
	me.Put("/password", h.changePassword)
	me.Post("/avatar", h.uploadAvatar)
	me.Delete("/avatar", h.deleteAvatar)
	me.Get("/boards", h.myBoards)

	users := api.Group("/users/:username")
	users.Get("/", h.getUser)
	users.Get("/pins", h.userPins)
	users.Get("/boards", h.userBoards)
	users.Get("/followers", h.followList(true))
	users.Get("/following", h.followList(false))
	users.Post("/follow", requireAuth, h.follow)
	users.Delete("/follow", requireAuth, h.unfollow)

	pins := api.Group("/pins")
	pins.Get("/", h.listPins)
	pins.Post("/", requireAuth, h.createPin)
	pins.Get("/:id", h.getPin)
	pins.Put("/:id", requireAuth, h.updatePin)
	pins.Delete("/:id", requireAuth, h.deletePin)
	pins.Get("/:id/similar", h.similarPins)
	pins.Post("/:id/like", requireAuth, h.likePin)
	pins.Delete("/:id/like", requireAuth, h.unlikePin)
	pins.Get("/:id/comments", h.listComments)
	pins.Post("/:id/comments", requireAuth, h.addComment)
	api.Delete("/comments/:id", requireAuth, h.deleteComment)

	boards := api.Group("/boards")
	boards.Post("/", requireAuth, h.createBoard)
	boards.Get("/:id", h.getBoard)
	boards.Put("/:id", requireAuth, h.updateBoard)
	boards.Delete("/:id", requireAuth, h.deleteBoard)
	boards.Get("/:id/pins", h.boardPins)
	boards.Post("/:id/pins/:pinId", requireAuth, h.savePin)
	boards.Delete("/:id/pins/:pinId", requireAuth, h.unsavePin)

	notes := api.Group("/notifications", requireAuth)
	notes.Get("/", h.listNotifications)
	notes.Get("/unread-count", h.unreadCount)
	notes.Post("/read-all", h.readAll)

	api.Use(func(c fiber.Ctx) error { return notFound(c) })
	return app
}
