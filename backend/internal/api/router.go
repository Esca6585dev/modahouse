// Package api wires the HTTP routes for the ModaHouse REST API.
package api

import (
	"errors"
	"log"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/cors"
	"github.com/gofiber/fiber/v3/middleware/limiter"
	"github.com/gofiber/fiber/v3/middleware/logger"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/static"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/ai"
	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

type Options struct {
	Quiet bool // disable request logging (tests)
}

func New(db *gorm.DB, store *storage.Storage, cfg config.Config, opts Options) *fiber.App {
	cats := make([]ai.Category, len(Categories))
	for i, c := range Categories {
		cats[i] = ai.Category{Slug: c.Slug, Name: c.Name}
	}
	h := &Handler{db: db, store: store, cfg: cfg, ai: ai.New(cfg.AIModel, cats), visual: newVisualIndex(db, store),
		proxies: newProxyTrust(cfg.TrustedProxies)}
	if !opts.Quiet {
		logVisualStart(h.visual) // background indexing; tests index on demand
	}

	app := fiber.New(fiber.Config{
		AppName: "ModaHouse API",
		// One request may carry a video plus several images.
		BodyLimit: (max(cfg.MaxVideoMB, 1) + 4*max(cfg.MaxUploadMB, 1)) * 1024 * 1024,
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
	}, static.New(store.Dir, static.Config{MaxAge: 86400, ByteRange: true}))

	api := app.Group("/api", h.optionalAuth)
	api.Get("/health", func(c fiber.Ctx) error { return c.JSON(fiber.Map{"status": "ok"}) })
	api.Get("/categories", listCategories)
	api.Get("/business-categories", listBusinessCategories)
	api.Get("/config", h.getConfig)

	// Only credential endpoints are rate limited, per client IP.
	credLimit := func(c fiber.Ctx) error { return c.Next() }
	if !opts.Quiet {
		credLimit = limiter.New(limiter.Config{Max: 20, Expiration: time.Minute, KeyGenerator: h.proxies.clientIP})
	}
	auth := api.Group("/auth")
	auth.Post("/register", credLimit, h.register)
	auth.Post("/login", credLimit, h.login)
	auth.Get("/me", requireAuth, h.getMe)

	me := api.Group("/me", requireAuth)
	me.Get("/", h.getMe)
	me.Put("/", h.updateMe)
	me.Put("/password", h.changePassword)
	me.Post("/avatar", h.uploadAvatar)
	me.Delete("/avatar", h.deleteAvatar)
	me.Get("/boards", h.myBoards)
	me.Get("/likes", h.myLikes)
	me.Get("/blocks", h.myBlocks)
	me.Post("/business", h.openBusiness)
	me.Put("/business", h.updateBusiness)
	me.Delete("/business", h.closeBusiness)

	users := api.Group("/users/:username")
	users.Get("/", h.getUser)
	users.Get("/pins", h.userPins)
	users.Get("/boards", h.userBoards)
	users.Get("/followers", h.followList(true))
	users.Get("/following", h.followList(false))
	users.Get("/stories", h.userStories)
	users.Post("/block", requireAuth, h.blockUser)
	users.Delete("/block", requireAuth, h.unblockUser)
	users.Post("/follow", requireAuth, h.follow)
	users.Delete("/follow", requireAuth, h.unfollow)

	pins := api.Group("/pins")
	pins.Get("/", h.listPins)
	pins.Post("/", requireAuth, h.createPin)
	pins.Get("/:id", h.getPin)
	pins.Put("/:id", requireAuth, h.updatePin)
	pins.Delete("/:id", requireAuth, h.deletePin)
	pins.Get("/:id/similar", h.similarPins)
	pins.Get("/:id/visual", h.visuallySimilar)
	pins.Post("/:id/view", h.viewPin)
	pins.Post("/:id/report", requireAuth, h.reportPin)
	pins.Post("/:id/hide", requireAuth, h.hidePin)
	pins.Delete("/:id/hide", requireAuth, h.unhidePin)
	pins.Get("/:id/reviews", h.listReviews)
	pins.Post("/:id/reviews", requireAuth, h.addReview)
	api.Delete("/reviews/:id", requireAuth, h.deleteReview)
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

	api.Get("/businesses", h.listBusinesses)
	api.Get("/search", h.search)
	api.Post("/search/image", h.searchByImage)
	aiLimit := func(c fiber.Ctx) error { return c.Next() }
	if !opts.Quiet {
		aiLimit = limiter.New(limiter.Config{Max: 10, Expiration: time.Minute, KeyGenerator: func(c fiber.Ctx) string {
			return "ai:" + strconv.FormatUint(uint64(viewerID(c)), 10)
		}})
	}
	api.Get("/ai/status", h.aiStatus)
	api.Post("/ai/suggest", requireAuth, aiLimit, h.aiSuggest)
	api.Get("/top", h.top)
	biz := api.Group("/business", requireAuth)
	biz.Get("/stats", h.businessStats)
	biz.Get("/orders", h.businessOrders)
	biz.Put("/orders/:id", h.updateOrderStatus)

	cart := api.Group("/cart", requireAuth)
	cart.Get("/", h.getCart)
	cart.Get("/count", h.cartCount)
	cart.Post("/", h.addToCart)
	cart.Put("/:id", h.updateCartItem)
	cart.Delete("/:id", h.deleteCartItem)
	cart.Delete("/", h.clearCart)

	orders := api.Group("/orders", requireAuth)
	orders.Post("/", h.createOrders)
	orders.Get("/", h.myOrders)
	orders.Get("/:id", h.getOrder)
	orders.Post("/:id/cancel", h.cancelOrder)

	stories := api.Group("/stories")
	stories.Get("/", h.listStories)
	stories.Post("/", requireAuth, h.createStory)
	stories.Post("/:id/view", requireAuth, h.viewStory)
	stories.Delete("/:id", requireAuth, h.deleteStory)

	notes := api.Group("/notifications", requireAuth)
	notes.Get("/", h.listNotifications)
	notes.Get("/unread-count", h.unreadCount)
	notes.Post("/read-all", h.readAll)

	admin := api.Group("/admin", h.requireAdmin)
	admin.Get("/stats", h.adminStats)
	admin.Get("/settings", h.adminGetSettings)
	admin.Put("/settings", h.adminUpdateSettings)
	admin.Post("/check-url", h.adminCheckURL)
	admin.Get("/users", h.adminListUsers)
	admin.Put("/users/:id", h.adminUpdateUser)
	admin.Get("/reports", h.adminReports)
	admin.Delete("/reports/:pinId", h.adminDismissReports)
	admin.Delete("/pins/:id", h.adminDeletePin)

	api.Use(func(c fiber.Ctx) error { return notFound(c) })
	return app
}
