package api

import (
	"log"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// notify records an event for recipient. Actions on your own content are skipped.
// Like/follow/save are toggles, so an older identical notification is replaced
// instead of piling up when someone toggles repeatedly.
func (h *Handler) notify(recipient, actor uint, kind string, pinID *uint) {
	if recipient == actor {
		return
	}
	h.unnotify(recipient, actor, kind, pinID)
	h.createNotification(models.Notification{UserID: recipient, ActorID: actor, Type: kind, PinID: pinID})
}

func (h *Handler) notifyComment(recipient, actor, pinID, commentID uint) {
	if recipient == actor {
		return
	}
	h.createNotification(models.Notification{UserID: recipient, ActorID: actor, Type: models.NotifyComment, PinID: &pinID, CommentID: &commentID})
}

func (h *Handler) createNotification(n models.Notification) {
	if err := h.db.Create(&n).Error; err != nil {
		log.Printf("notify: %v", err)
	}
}

// unnotify removes the notification for an undone action (unlike, unfollow, unsave).
func (h *Handler) unnotify(recipient, actor uint, kind string, pinID *uint) {
	q := h.db.Where("user_id = ? AND actor_id = ? AND type = ?", recipient, actor, kind)
	if pinID != nil {
		q = q.Where("pin_id = ?", *pinID)
	} else {
		q = q.Where("pin_id IS NULL")
	}
	q.Delete(&models.Notification{})
}

func (h *Handler) listNotifications(c fiber.Ctx) error {
	page, limit, offset := paging(c, 30)
	var list []models.Notification
	if err := h.db.Preload("Actor").Preload("Pin").Where("user_id = ?", viewerID(c)).
		Order("created_at DESC, id DESC").Offset(offset).Limit(limit + 1).Find(&list).Error; err != nil {
		return err
	}
	list, more := trimPage(list, limit)
	items := make([]NotificationDTO, len(list))
	for i, n := range list {
		d := NotificationDTO{ID: n.ID, Type: n.Type, Read: n.Read, Actor: brief(n.Actor), CreatedAt: n.CreatedAt}
		if n.Pin != nil {
			d.Pin = &PinBrief{ID: n.Pin.ID, Title: n.Pin.Title, ImageURL: n.Pin.ImageURL}
		}
		items[i] = d
	}
	return c.JSON(Page[NotificationDTO]{Items: items, Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) unreadCount(c fiber.Ctx) error {
	var n int64
	h.db.Model(&models.Notification{}).Where("user_id = ? AND read = ?", viewerID(c), false).Count(&n)
	return c.JSON(fiber.Map{"count": n})
}

func (h *Handler) readAll(c fiber.Ctx) error {
	h.db.Model(&models.Notification{}).Where("user_id = ? AND read = ?", viewerID(c), false).Update("read", true)
	return c.SendStatus(fiber.StatusNoContent)
}
