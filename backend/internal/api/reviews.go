package api

import (
	"time"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

type ReviewDTO struct {
	ID        uint      `json:"id"`
	Rating    int       `json:"rating"`
	Text      string    `json:"text"`
	Author    UserBrief `json:"author"`
	CanDelete bool      `json:"canDelete"`
	CreatedAt time.Time `json:"createdAt"`
}

type ReviewPage struct {
	Page[ReviewDTO]
	Rating       float64 `json:"rating"`
	ReviewsCount int64   `json:"reviewsCount"`
	CanReview    bool    `json:"canReview"`
}

// canReview: the viewer received (delivered) an order containing this pin.
func (h *Handler) canReview(viewer, pinID uint) bool {
	if viewer == 0 {
		return false
	}
	var n int64
	h.db.Model(&models.OrderItem{}).Joins("JOIN orders ON orders.id = order_items.order_id").
		Where("orders.buyer_id = ? AND orders.status = ? AND order_items.pin_id = ?", viewer, models.OrderDelivered, pinID).Count(&n)
	return n > 0
}

func reviewDTO(r models.Review, viewer uint) ReviewDTO {
	return ReviewDTO{ID: r.ID, Rating: r.Rating, Text: r.Text, Author: brief(r.User), CanDelete: viewer == r.UserID, CreatedAt: r.CreatedAt}
}

func (h *Handler) listReviews(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var n int64
	if h.db.Model(&models.Pin{}).Where("id = ?", id).Count(&n); n == 0 {
		return notFound(c)
	}
	page, limit, offset := paging(c, 20)
	var list []models.Review
	if err := h.db.Preload("User").Where("pin_id = ?", id).Order("created_at DESC, id DESC").Offset(offset).Limit(limit + 1).Find(&list).Error; err != nil {
		return err
	}
	list, more := trimPage(list, limit)
	me := viewerID(c)
	items := make([]ReviewDTO, len(list))
	for i, r := range list {
		items[i] = reviewDTO(r, me)
	}
	var agg struct {
		Avg float64
		N   int64
	}
	h.db.Model(&models.Review{}).Select("COALESCE(AVG(rating), 0) AS avg, COUNT(*) AS n").Where("pin_id = ?", id).Scan(&agg)
	return c.JSON(ReviewPage{
		Page:   Page[ReviewDTO]{Items: items, Page: page, Limit: limit, HasMore: more},
		Rating: round1(agg.Avg), ReviewsCount: agg.N, CanReview: h.canReview(me, id),
	})
}

func (h *Handler) addReview(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var pin models.Pin
	if err := h.db.First(&pin, id).Error; err != nil {
		return notFound(c)
	}
	me := viewerID(c)
	if !h.canReview(me, pin.ID) {
		return fail(c, fiber.StatusForbidden, "Diňe bu harydy alan müşderiler baha berip bilýär")
	}
	var req struct {
		Rating int    `json:"rating"`
		Text   string `json:"text"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if req.Rating < 1 || req.Rating > 5 {
		return badRequest(c, "Bahany 1-den 5-e çenli ýyldyz bilen beriň")
	}
	var r models.Review
	isNew := h.db.Where("pin_id = ? AND user_id = ?", pin.ID, me).First(&r).Error != nil
	r.PinID, r.UserID, r.BusinessID, r.Rating, r.Text = pin.ID, me, pin.UserID, req.Rating, clean(req.Text, 1000)
	if err := h.db.Save(&r).Error; err != nil {
		return err
	}
	if isNew {
		pid := pin.ID
		h.createNotification(models.Notification{UserID: pin.UserID, ActorID: me, Type: models.NotifyReview, PinID: &pid})
	}
	h.db.Preload("User").First(&r, r.ID)
	return c.Status(fiber.StatusCreated).JSON(reviewDTO(r, me))
}

func (h *Handler) deleteReview(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var r models.Review
	if err := h.db.First(&r, id).Error; err != nil {
		return notFound(c)
	}
	if r.UserID != viewerID(c) {
		return forbidden(c)
	}
	h.db.Delete(&models.Review{}, r.ID)
	return c.SendStatus(fiber.StatusNoContent)
}
