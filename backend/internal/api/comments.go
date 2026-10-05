package api

import (
	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

func commentDTO(cm models.Comment, viewer, pinOwner uint) CommentDTO {
	return CommentDTO{
		ID: cm.ID, Text: cm.Text, Author: brief(cm.User), CreatedAt: cm.CreatedAt,
		CanDelete: viewer != 0 && (viewer == cm.UserID || viewer == pinOwner),
	}
}

// listComments returns oldest first so threads read top to bottom.
func (h *Handler) listComments(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var pin models.Pin
	if err := h.db.First(&pin, id).Error; err != nil {
		return notFound(c)
	}
	page, limit, offset := paging(c, 30)
	var list []models.Comment
	if err := h.db.Preload("User").Where("pin_id = ?", id).Order("created_at ASC, id ASC").
		Offset(offset).Limit(limit + 1).Find(&list).Error; err != nil {
		return err
	}
	list, more := trimPage(list, limit)
	items := make([]CommentDTO, len(list))
	for i, cm := range list {
		items[i] = commentDTO(cm, viewerID(c), pin.UserID)
	}
	return c.JSON(Page[CommentDTO]{Items: items, Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) addComment(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var pin models.Pin
	if err := h.db.First(&pin, id).Error; err != nil {
		return notFound(c)
	}
	var req struct {
		Text string `json:"text"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	text := clean(req.Text, 500)
	if text == "" {
		return badRequest(c, "Teswir boş bolmaly däl")
	}
	me := viewerID(c)
	cm := models.Comment{PinID: pin.ID, UserID: me, Text: text}
	if err := h.db.Create(&cm).Error; err != nil {
		return err
	}
	h.notify(pin.UserID, me, models.NotifyComment, &pin.ID)
	h.db.Preload("User").First(&cm, cm.ID)
	return c.Status(fiber.StatusCreated).JSON(commentDTO(cm, me, pin.UserID))
}

// deleteComment: the comment author or the pin owner may delete.
func (h *Handler) deleteComment(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var cm models.Comment
	if err := h.db.Preload("Pin").First(&cm, id).Error; err != nil {
		return notFound(c)
	}
	me := viewerID(c)
	if cm.UserID != me && cm.Pin.UserID != me {
		return forbidden(c)
	}
	h.db.Delete(&models.Comment{}, cm.ID)
	return c.SendStatus(fiber.StatusNoContent)
}
