package api

import (
	"errors"
	"fmt"
	"math/rand/v2"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// Teňňe are bought through an admin (who confirms the payment) and spent on
// boosts that show a post above the others for a few days.

// CoinPackages are the amounts offered on the "buy teňňe" screen.
var CoinPackages = []int{50, 100, 250, 500, 1000}

type BoostOption struct {
	Days  int `json:"days"`
	Coins int `json:"coins"`
}

var BoostOptions = []BoostOption{{1, 10}, {3, 25}, {7, 50}, {30, 180}}

var errNoCoins = errors.New("not enough coins")

// spendCoins takes amount from the user's balance or fails without touching it.
func spendCoins(tx *gorm.DB, userID uint, amount int, kind, note string, pinID *uint) error {
	res := tx.Model(&models.User{}).Where("id = ? AND coins >= ?", userID, amount).
		UpdateColumn("coins", gorm.Expr("coins - ?", amount))
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errNoCoins
	}
	return tx.Create(&models.CoinTx{UserID: userID, Amount: -amount, Kind: kind, Note: note, PinID: pinID}).Error
}

func giveCoins(tx *gorm.DB, userID uint, amount int, kind, note string, pinID *uint) error {
	if err := tx.Model(&models.User{}).Where("id = ?", userID).UpdateColumn("coins", gorm.Expr("coins + ?", amount)).Error; err != nil {
		return err
	}
	return tx.Create(&models.CoinTx{UserID: userID, Amount: amount, Kind: kind, Note: note, PinID: pinID}).Error
}

func (h *Handler) coinPrice(coins int) string {
	rate, err := strconv.ParseFloat(h.appConfig().CoinRate, 64)
	if err != nil || rate <= 0 {
		rate = 1
	}
	return strconv.FormatFloat(float64(coins)*rate, 'f', -1, 64)
}

type CoinTxDTO struct {
	ID        uint      `json:"id"`
	Amount    int       `json:"amount"`
	Kind      string    `json:"kind"`
	Note      string    `json:"note"`
	PinID     *uint     `json:"pinId"`
	CreatedAt time.Time `json:"createdAt"`
}

type CoinRequestDTO struct {
	ID        uint       `json:"id"`
	User      UserBrief  `json:"user"`
	Coins     int        `json:"coins"`
	Price     string     `json:"price"`
	Note      string     `json:"note"`
	Status    string     `json:"status"`
	CreatedAt time.Time  `json:"createdAt"`
	DecidedAt *time.Time `json:"decidedAt"`
}

func coinRequestDTO(r models.CoinRequest) CoinRequestDTO {
	return CoinRequestDTO{ID: r.ID, User: brief(r.User), Coins: r.Coins, Price: r.Price, Note: r.Note, Status: r.Status,
		CreatedAt: r.CreatedAt, DecidedAt: r.DecidedAt}
}

type CoinPackage struct {
	Coins int    `json:"coins"`
	Price string `json:"price"` // manat
}

// myCoins: GET /me/coins — balance, offers and history.
func (h *Handler) myCoins(c fiber.Ctx) error {
	me := viewerID(c)
	var u models.User
	if err := h.db.Select("id", "coins").First(&u, me).Error; err != nil {
		return notFound(c)
	}
	packages := make([]CoinPackage, len(CoinPackages))
	for i, n := range CoinPackages {
		packages[i] = CoinPackage{n, h.coinPrice(n)}
	}
	var txs []models.CoinTx
	h.db.Where("user_id = ?", me).Order("id DESC").Limit(50).Find(&txs)
	history := make([]CoinTxDTO, len(txs))
	for i, t := range txs {
		history[i] = CoinTxDTO{t.ID, t.Amount, t.Kind, t.Note, t.PinID, t.CreatedAt}
	}
	var reqs []models.CoinRequest
	h.db.Preload("User").Where("user_id = ?", me).Order("id DESC").Limit(10).Find(&reqs)
	requests := make([]CoinRequestDTO, len(reqs))
	for i, r := range reqs {
		requests[i] = coinRequestDTO(r)
	}
	cfg := h.appConfig()
	return c.JSON(fiber.Map{"balance": u.Coins, "rate": cfg.CoinRate, "paymentInfo": cfg.CoinPayment,
		"packages": packages, "boostOptions": BoostOptions, "history": history, "requests": requests})
}

// requestCoins: POST /me/coins/requests {coins, note} — "I paid, add my teňňe".
func (h *Handler) requestCoins(c fiber.Ctx) error {
	var req struct {
		Coins int    `json:"coins"`
		Note  string `json:"note"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if req.Coins < 10 || req.Coins > 100000 {
		return badRequest(c, "Teňňe sany 10-100000 aralygynda bolmaly")
	}
	me := viewerID(c)
	var pending int64
	h.db.Model(&models.CoinRequest{}).Where("user_id = ? AND status = ?", me, models.CoinRequestPending).Count(&pending)
	if pending >= 3 {
		return badRequest(c, "Öňki haýyşlaryňyz barlanýança garaşyň")
	}
	r := models.CoinRequest{UserID: me, Coins: req.Coins, Price: h.coinPrice(req.Coins), Note: clean(req.Note, 300), Status: models.CoinRequestPending}
	if err := h.db.Create(&r).Error; err != nil {
		return err
	}
	h.db.Preload("User").First(&r, r.ID)
	return c.Status(fiber.StatusCreated).JSON(coinRequestDTO(r))
}

// adminCoinRequests: GET /admin/coin-requests?status=pending
func (h *Handler) adminCoinRequests(c fiber.Ctx) error {
	page, limit, offset := paging(c, 30)
	q := h.db.Preload("User").Order("id DESC").Offset(offset).Limit(limit + 1)
	if s := c.Query("status", models.CoinRequestPending); s != "all" {
		q = q.Where("status = ?", s)
	}
	var rows []models.CoinRequest
	if err := q.Find(&rows).Error; err != nil {
		return err
	}
	rows, more := trimPage(rows, limit)
	items := make([]CoinRequestDTO, len(rows))
	for i, r := range rows {
		items[i] = coinRequestDTO(r)
	}
	return c.JSON(Page[CoinRequestDTO]{Items: items, Page: page, Limit: limit, HasMore: more})
}

// adminDecideCoinRequest: POST /admin/coin-requests/:id/approve|reject
func (h *Handler) adminDecideCoinRequest(approve bool) fiber.Handler {
	return func(c fiber.Ctx) error {
		id, ok := idParam(c, "id")
		if !ok {
			return notFound(c)
		}
		var r models.CoinRequest
		err := h.db.Transaction(func(tx *gorm.DB) error {
			if err := tx.First(&r, id).Error; err != nil {
				return err
			}
			if r.Status != models.CoinRequestPending {
				return errAlreadyDecided
			}
			now := time.Now()
			status := models.CoinRequestRejected
			if approve {
				status = models.CoinRequestApproved
			}
			// The status check in WHERE stops a double click from paying twice.
			res := tx.Model(&models.CoinRequest{}).Where("id = ? AND status = ?", r.ID, models.CoinRequestPending).
				Updates(map[string]any{"status": status, "decided_at": now})
			if res.Error != nil || res.RowsAffected == 0 {
				return errAlreadyDecided
			}
			if approve {
				return giveCoins(tx, r.UserID, r.Coins, "topup", fmt.Sprintf("%s manat", r.Price), nil)
			}
			return nil
		})
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return notFound(c)
		}
		if errors.Is(err, errAlreadyDecided) {
			return fail(c, fiber.StatusConflict, "Bu haýyş eýýäm çözüldi")
		}
		if err != nil {
			return err
		}
		h.db.Preload("User").First(&r, r.ID)
		return c.JSON(coinRequestDTO(r))
	}
}

var errAlreadyDecided = errors.New("already decided")

// adminGiveCoins: POST /admin/users/:id/coins {amount, note}; a negative amount takes teňňe back.
func (h *Handler) adminGiveCoins(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var req struct {
		Amount int    `json:"amount"`
		Note   string `json:"note"`
	}
	if err := c.Bind().Body(&req); err != nil || req.Amount == 0 || req.Amount > 100000 || req.Amount < -100000 {
		return badRequest(c, "Teňňe sanyny ýazyň")
	}
	var u models.User
	if h.db.First(&u, id).Error != nil {
		return notFound(c)
	}
	err := h.db.Transaction(func(tx *gorm.DB) error {
		if req.Amount < 0 {
			return spendCoins(tx, u.ID, -req.Amount, "admin", clean(req.Note, 200), nil)
		}
		return giveCoins(tx, u.ID, req.Amount, "admin", clean(req.Note, 200), nil)
	})
	if errors.Is(err, errNoCoins) {
		return badRequest(c, "Ulanyjynyň balansynda ýeterlik teňňe ýok")
	}
	if err != nil {
		return err
	}
	h.db.Select("id", "coins").First(&u, u.ID)
	return c.JSON(fiber.Map{"balance": u.Coins})
}

// --- boosts ---

// boostPin: POST /pins/:id/boost {days} spends teňňe to show the post above others.
func (h *Handler) boostPin(c fiber.Ctx) error {
	p, err := h.ownPin(c)
	if err != nil {
		return err
	}
	var req struct {
		Days int `json:"days"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	var opt *BoostOption
	for i := range BoostOptions {
		if BoostOptions[i].Days == req.Days {
			opt = &BoostOptions[i]
		}
	}
	if opt == nil {
		return badRequest(c, "Möhleti saýlaň")
	}
	me := viewerID(c)
	now := time.Now().UTC()
	var b models.Boost
	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := spendCoins(tx, me, opt.Coins, "boost", fmt.Sprintf("%d gün öňe çykarmak", opt.Days), &p.ID); err != nil {
			return err
		}
		// A running boost is extended instead of overlapping.
		start := now
		var last models.Boost
		if tx.Where("pin_id = ? AND ends_at > ?", p.ID, now).Order("ends_at DESC").First(&last).Error == nil {
			start = last.EndsAt
		}
		b = models.Boost{PinID: p.ID, UserID: me, Coins: opt.Coins, StartsAt: start, EndsAt: start.Add(time.Duration(opt.Days) * 24 * time.Hour)}
		return tx.Create(&b).Error
	})
	if errors.Is(err, errNoCoins) {
		return fail(c, fiber.StatusPaymentRequired, "Teňňe ýeterlik däl: ilki teňňe satyn alyň")
	}
	if err != nil {
		return err
	}
	var u models.User
	h.db.Select("id", "coins").First(&u, me)
	return c.JSON(fiber.Map{"boostedUntil": h.boostedUntil(p.ID), "balance": u.Coins})
}

// boostedUntil is the end of the post's last boost, or nil when it is not boosted.
func (h *Handler) boostedUntil(pinID uint) *time.Time {
	var b models.Boost
	if h.db.Where("pin_id = ? AND ends_at > ?", pinID, time.Now().UTC()).Order("ends_at DESC").First(&b).Error != nil {
		return nil
	}
	return &b.EndsAt
}

// boostedIDs returns the posts boosted right now, in random order so each gets its turn.
func (h *Handler) boostedIDs(q *gorm.DB, limit int) []uint {
	now := time.Now().UTC()
	var ids []uint
	q.Session(&gorm.Session{}).Where("pins.id IN (?)", h.db.Model(&models.Boost{}).Select("pin_id").
		Where("starts_at <= ? AND ends_at > ?", now, now)).Limit(200).Pluck("pins.id", &ids)
	rand.Shuffle(len(ids), func(i, j int) { ids[i], ids[j] = ids[j], ids[i] })
	if len(ids) > limit {
		ids = ids[:limit]
	}
	return ids
}

// promotedFor picks up to two boosted posts matching the feed's filters for
// its first page. Call it before running q: running a query changes it.
func (h *Handler) promotedFor(c fiber.Ctx, q *gorm.DB) []uint {
	if c.Query("page", "1") != "1" {
		return nil
	}
	return h.boostedIDs(q, 2)
}

// withPromoted puts the boosted posts ids at the top, marked as promoted.
func (h *Handler) withPromoted(c fiber.Ctx, ids []uint, items []PinDTO) []PinDTO {
	if len(ids) == 0 {
		return items
	}
	var pins []models.Pin
	h.db.Preload("User").Where("id IN ?", ids).Find(&pins)
	promoted := h.enrichPins(pins, viewerID(c))
	seen := map[uint]bool{}
	for i := range promoted {
		promoted[i].Promoted = true
		seen[promoted[i].ID] = true
	}
	out := promoted
	for _, it := range items {
		if !seen[it.ID] {
			out = append(out, it)
		}
	}
	return out
}

// promotedPins: GET /pins/promoted — every post boosted right now.
func (h *Handler) promotedPins(c fiber.Ctx) error {
	q := h.viewerFilter(h.db.Model(&models.Pin{}), viewerID(c))
	ids := h.boostedIDs(q, 20)
	items := []PinDTO{}
	if len(ids) > 0 {
		var pins []models.Pin
		h.db.Preload("User").Where("id IN ?", ids).Find(&pins)
		items = h.enrichPins(pins, viewerID(c))
		for i := range items {
			items[i].Promoted = true
		}
	}
	return c.JSON(items)
}
