package api

import (
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

var BusinessCategories = []Category{
	{"dress", "Köýnek dükany"},
	{"tailor", "Tikinçi"},
	{"boutique", "Butik"},
	{"designer", "Dizaýner"},
	{"accessories", "Aksessuarlar"},
}

var phoneRe = regexp.MustCompile(`^\+?[0-9][0-9 ()\-]{6,18}[0-9]$`)

func validBusinessCategory(s string) bool {
	for _, c := range BusinessCategories {
		if c.Slug == s {
			return true
		}
	}
	return false
}

type businessAgg struct {
	Rating        float64
	ReviewsCount  int64
	OrdersCount   int64
	ProductsCount int64
}

func (h *Handler) businessAgg(userID uint) businessAgg {
	var a businessAgg
	var r struct {
		Avg float64
		N   int64
	}
	h.db.Model(&models.Review{}).Select("COALESCE(AVG(rating), 0) AS avg, COUNT(*) AS n").Where("business_id = ?", userID).Scan(&r)
	a.Rating, a.ReviewsCount = round1(r.Avg), r.N
	h.db.Model(&models.Order{}).Where("business_id = ? AND status <> ?", userID, models.OrderCancelled).Count(&a.OrdersCount)
	h.db.Model(&models.Pin{}).Where("user_id = ? AND price > 0", userID).Count(&a.ProductsCount)
	return a
}

func (h *Handler) businessDTO(u models.User) *BusinessDTO {
	if !u.IsBusiness {
		return nil
	}
	var b models.Business
	h.db.First(&b, u.ID)
	a := h.businessAgg(u.ID)
	return &BusinessDTO{
		Category: b.Category, Phone: b.Phone, Address: b.Address, City: b.City, Instagram: b.Instagram,
		WorkingHours: b.WorkingHours, DeliveryDays: b.DeliveryDays, ReturnDays: b.ReturnDays,
		Rating: a.Rating, ReviewsCount: a.ReviewsCount, OrdersCount: a.OrdersCount, ProductsCount: a.ProductsCount,
	}
}

func (h *Handler) businessCards(users []models.User, viewer uint) []BusinessCard {
	out := make([]BusinessCard, len(users))
	for i, u := range users {
		var b models.Business
		h.db.First(&b, u.ID)
		a := h.businessAgg(u.ID)
		card := BusinessCard{
			UserBrief: brief(u), Category: b.Category, City: b.City, Rating: a.Rating, ReviewsCount: a.ReviewsCount,
			ProductsCount: a.ProductsCount, Covers: []string{},
		}
		h.db.Model(&models.Follow{}).Where("following_id = ?", u.ID).Count(&card.FollowersCount)
		h.db.Model(&models.Pin{}).Where("user_id = ? AND price > 0", u.ID).Order("orders_count DESC, created_at DESC").Limit(4).Pluck("image_url", &card.Covers)
		card.HasStory, _ = h.storyState(u.ID, viewer)
		out[i] = card
	}
	return out
}

type businessReq struct {
	Category     *string `json:"category"`
	Phone        *string `json:"phone"`
	Address      *string `json:"address"`
	City         *string `json:"city"`
	Instagram    *string `json:"instagram"`
	WorkingHours *string `json:"workingHours"`
	DeliveryDays *int    `json:"deliveryDays"`
	ReturnDays   *int    `json:"returnDays"`
}

func (r businessReq) apply(b *models.Business) string {
	if r.Category != nil {
		if !validBusinessCategory(*r.Category) {
			return "Biznes kategoriýasy nädogry"
		}
		b.Category = *r.Category
	}
	if r.Phone != nil {
		b.Phone = strings.TrimSpace(*r.Phone)
	}
	if r.Address != nil {
		b.Address = clean(*r.Address, 200)
	}
	if r.City != nil {
		b.City = clean(*r.City, 60)
	}
	if r.Instagram != nil {
		b.Instagram = clean(strings.TrimPrefix(strings.TrimSpace(*r.Instagram), "@"), 60)
	}
	if r.WorkingHours != nil {
		b.WorkingHours = clean(*r.WorkingHours, 60)
	}
	for _, d := range []struct {
		v   *int
		dst *int
	}{{r.DeliveryDays, &b.DeliveryDays}, {r.ReturnDays, &b.ReturnDays}} {
		if d.v != nil {
			if *d.v < 0 || *d.v > 365 {
				return "Gün sany 0-365 aralygynda bolmaly"
			}
			*d.dst = *d.v
		}
	}
	if b.Category == "" {
		return "Biznes kategoriýasyny saýlaň"
	}
	if !phoneRe.MatchString(b.Phone) {
		return "Telefon belgisi nädogry, mysal: +993 61 234567"
	}
	return ""
}

// openBusiness: POST /me/business switches the account to a business profile.
func (h *Handler) openBusiness(c fiber.Ctx) error { return h.saveBusiness(c, true) }

// updateBusiness: PUT /me/business edits the business profile.
func (h *Handler) updateBusiness(c fiber.Ctx) error { return h.saveBusiness(c, false) }

func (h *Handler) saveBusiness(c fiber.Ctx, opening bool) error {
	var req businessReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	if !opening && !u.IsBusiness {
		return badRequest(c, "Ilki biznes hasabyny açyň")
	}
	b := models.Business{UserID: u.ID, DeliveryDays: 7, ReturnDays: 14}
	h.db.First(&b, u.ID) // keep earlier details when re-opening
	if msg := req.apply(&b); msg != "" {
		return badRequest(c, msg)
	}
	err := h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&b).Error; err != nil {
			return err
		}
		return tx.Model(&u).Update("is_business", true).Error
	})
	if err != nil {
		return err
	}
	u.IsBusiness = true
	return c.JSON(h.me(u))
}

// closeBusiness: DELETE /me/business switches back to a personal account.
// Open orders must be finished first so no buyer is left without a seller.
func (h *Handler) closeBusiness(c fiber.Ctx) error {
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	var open int64
	h.db.Model(&models.Order{}).Where("business_id = ? AND status IN ?", u.ID,
		[]string{models.OrderNew, models.OrderConfirmed, models.OrderShipped}).Count(&open)
	if open > 0 {
		return badRequest(c, "Ilki açyk sargytlary tamamlaň ýa-da ýatyryň")
	}
	h.db.Model(&u).Update("is_business", false)
	u.IsBusiness = false
	return c.JSON(h.me(u))
}

func periodStart(period string) (time.Time, bool) {
	now := time.Now().UTC()
	switch period {
	case "week":
		return now.AddDate(0, 0, -7), true
	case "month":
		return now.AddDate(0, -1, 0), true
	default:
		return time.Time{}, false
	}
}

type periodMetrics struct {
	views, likes, orders map[uint]int64
}

// metrics returns per-business views, likes and orders within the period.
func (h *Handler) metrics(since time.Time, bounded bool, ids []uint) periodMetrics {
	m := periodMetrics{views: map[uint]int64{}, likes: map[uint]int64{}, orders: map[uint]int64{}}
	if len(ids) == 0 {
		return m
	}
	type row struct {
		ID uint
		N  int64
	}
	var rows []row
	if bounded {
		h.db.Table("pin_views").Select("pins.user_id AS id, COUNT(*) AS n").Joins("JOIN pins ON pins.id = pin_views.pin_id").
			Where("pins.user_id IN ? AND pin_views.day >= ?", ids, since.Truncate(24*time.Hour)).Group("pins.user_id").Scan(&rows)
	} else {
		h.db.Table("pins").Select("user_id AS id, COALESCE(SUM(views_count), 0) AS n").Where("user_id IN ?", ids).Group("user_id").Scan(&rows)
	}
	for _, r := range rows {
		m.views[r.ID] = r.N
	}
	rows = nil
	q := h.db.Table("likes").Select("pins.user_id AS id, COUNT(*) AS n").Joins("JOIN pins ON pins.id = likes.pin_id").Where("pins.user_id IN ?", ids)
	if bounded {
		q = q.Where("likes.created_at >= ?", since)
	}
	q.Group("pins.user_id").Scan(&rows)
	for _, r := range rows {
		m.likes[r.ID] = r.N
	}
	rows = nil
	q = h.db.Table("orders").Select("business_id AS id, COUNT(*) AS n").Where("business_id IN ? AND status <> ?", ids, models.OrderCancelled)
	if bounded {
		q = q.Where("created_at >= ?", since)
	}
	q.Group("business_id").Scan(&rows)
	for _, r := range rows {
		m.orders[r.ID] = r.N
	}
	return m
}

// top: GET /top?period=week|month|all&category=&limit=10
func (h *Handler) top(c fiber.Ctx) error {
	limit := fiber.Query[int](c, "limit", 10)
	if limit < 1 || limit > 10 {
		limit = 10
	}
	since, bounded := periodStart(c.Query("period", "week"))

	q := h.db.Model(&models.User{}).Where("is_business = ?", true).
		Where("id IN (?)", h.db.Model(&models.Pin{}).Select("user_id").Where("price > 0"))
	if cat := c.Query("category"); cat != "" {
		q = q.Where("id IN (?)", h.db.Model(&models.Business{}).Select("user_id").Where("category = ?", cat))
	}
	var users []models.User
	if err := q.Find(&users).Error; err != nil {
		return err
	}
	ids := make([]uint, len(users))
	for i, u := range users {
		ids[i] = u.ID
	}
	m := h.metrics(since, bounded, ids)
	maxOf := func(mm map[uint]int64) float64 {
		var mx int64
		for _, v := range mm {
			mx = max(mx, v)
		}
		return float64(max(mx, 1))
	}
	vMax, lMax, oMax := maxOf(m.views), maxOf(m.likes), maxOf(m.orders)

	type scored struct {
		user  models.User
		score int
	}
	list := make([]scored, len(users))
	ratings := map[uint]float64{}
	for i, u := range users {
		ratings[u.ID] = h.businessAgg(u.ID).Rating
		s := 25*float64(m.views[u.ID])/vMax + 25*float64(m.likes[u.ID])/lMax + 35*float64(m.orders[u.ID])/oMax + 15*ratings[u.ID]/5
		list[i] = scored{u, int(s + 0.5)}
	}
	sort.SliceStable(list, func(a, b int) bool {
		x, y := list[a], list[b]
		if x.score != y.score {
			return x.score > y.score
		}
		if m.orders[x.user.ID] != m.orders[y.user.ID] {
			return m.orders[x.user.ID] > m.orders[y.user.ID]
		}
		return m.views[x.user.ID] > m.views[y.user.ID]
	})
	if len(list) > limit {
		list = list[:limit]
	}
	top := make([]models.User, len(list))
	for i, s := range list {
		top[i] = s.user
	}
	cards := h.businessCards(top, viewerID(c))
	out := make([]TopEntry, len(list))
	for i, s := range list {
		id := s.user.ID
		out[i] = TopEntry{
			Rank: i + 1, Business: cards[i], Score: s.score, Views: m.views[id], Likes: m.likes[id], Orders: m.orders[id],
			MoreCount: max(cards[i].ProductsCount-int64(len(cards[i].Covers)), 0),
		}
	}
	return c.JSON(out)
}

// listBusinesses: GET /businesses?q=&category=
func (h *Handler) listBusinesses(c fiber.Ctx) error {
	page, limit, offset := paging(c, 20)
	q := h.db.Model(&models.User{}).Where("is_business = ?", true)
	if cat := c.Query("category"); cat != "" {
		q = q.Where("id IN (?)", h.db.Model(&models.Business{}).Select("user_id").Where("category = ?", cat))
	}
	if term := strings.ToLower(strings.TrimSpace(c.Query("q"))); term != "" {
		like := "%" + escapeLike(term) + "%"
		q = q.Where(`(username LIKE ? ESCAPE '\' OR LOWER(name) LIKE ? ESCAPE '\')`, like, like)
	}
	var users []models.User
	if err := q.Order("verified DESC, id ASC").Offset(offset).Limit(limit + 1).Find(&users).Error; err != nil {
		return err
	}
	users, more := trimPage(users, limit)
	return c.JSON(Page[BusinessCard]{Items: h.businessCards(users, viewerID(c)), Page: page, Limit: limit, HasMore: more})
}

// businessStats: GET /business/stats?period=
func (h *Handler) businessStats(c fiber.Ctx) error {
	me := viewerID(c)
	if !h.isBusiness(me) {
		return fail(c, fiber.StatusForbidden, "Bu bölüm diňe biznes hasaplary üçin")
	}
	since, bounded := periodStart(c.Query("period", "month"))
	m := h.metrics(since, bounded, []uint{me})
	a := h.businessAgg(me)
	var revenue struct{ N int64 }
	q := h.db.Model(&models.Order{}).Select("COALESCE(SUM(total), 0) AS n").Where("business_id = ? AND status <> ?", me, models.OrderCancelled)
	if bounded {
		q = q.Where("created_at >= ?", since)
	}
	q.Scan(&revenue)
	var pending, followers int64
	h.db.Model(&models.Order{}).Where("business_id = ? AND status = ?", me, models.OrderNew).Count(&pending)
	h.db.Model(&models.Follow{}).Where("following_id = ?", me).Count(&followers)
	return c.JSON(fiber.Map{
		"views": m.views[me], "likes": m.likes[me], "orders": m.orders[me], "revenue": revenue.N,
		"pendingOrders": pending, "rating": a.Rating, "reviewsCount": a.ReviewsCount,
		"productsCount": a.ProductsCount, "followersCount": followers,
	})
}
