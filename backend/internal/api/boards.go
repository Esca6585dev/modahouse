package api

import (
	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

func (h *Handler) boardDTOs(boards []models.Board) []BoardDTO {
	out := make([]BoardDTO, len(boards))
	for i, b := range boards {
		d := BoardDTO{ID: b.ID, Name: b.Name, Description: b.Description, IsPrivate: b.IsPrivate, Owner: brief(b.User), CreatedAt: b.CreatedAt, Covers: []string{}}
		h.db.Model(&models.BoardPin{}).Where("board_id = ?", b.ID).Count(&d.PinsCount)
		h.db.Model(&models.Pin{}).Joins("JOIN board_pins ON board_pins.pin_id = pins.id").
			Where("board_pins.board_id = ?", b.ID).Order("board_pins.created_at DESC").Limit(3).Pluck("pins.image_url", &d.Covers)
		out[i] = d
	}
	return out
}

// listBoards returns a user's boards; private boards only for their owner.
func (h *Handler) listBoards(c fiber.Ctx, ownerID uint) error {
	q := h.db.Preload("User").Where("user_id = ?", ownerID).Order("created_at ASC, id ASC")
	if viewerID(c) != ownerID {
		q = q.Where("is_private = ?", false)
	}
	var boards []models.Board
	if err := q.Find(&boards).Error; err != nil {
		return err
	}
	return c.JSON(h.boardDTOs(boards))
}

func (h *Handler) userBoards(c fiber.Ctx) error {
	u, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	return h.listBoards(c, u.ID)
}

func (h *Handler) myBoards(c fiber.Ctx) error { return h.listBoards(c, viewerID(c)) }

// visibleBoard loads a board the viewer may see (public, or their own private one).
func (h *Handler) visibleBoard(c fiber.Ctx) (models.Board, bool) {
	id, ok := idParam(c, "id")
	if !ok {
		return models.Board{}, false
	}
	var b models.Board
	if err := h.db.Preload("User").First(&b, id).Error; err != nil {
		return b, false
	}
	if b.IsPrivate && b.UserID != viewerID(c) {
		return b, false
	}
	return b, true
}

func (h *Handler) getBoard(c fiber.Ctx) error {
	b, ok := h.visibleBoard(c)
	if !ok {
		return notFound(c)
	}
	return c.JSON(h.boardDTOs([]models.Board{b})[0])
}

func (h *Handler) boardPins(c fiber.Ctx) error {
	b, ok := h.visibleBoard(c)
	if !ok {
		return notFound(c)
	}
	q := h.db.Model(&models.Pin{}).Joins("JOIN board_pins ON board_pins.pin_id = pins.id").
		Where("board_pins.board_id = ?", b.ID).Order("board_pins.created_at DESC, pins.id DESC")
	return h.pagePins(c, q, 24)
}

type boardReq struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	IsPrivate   *bool   `json:"isPrivate"`
}

func (r boardReq) apply(b *models.Board) string {
	if r.Name != nil {
		b.Name = clean(*r.Name, 50)
	}
	if r.Description != nil {
		b.Description = clean(*r.Description, 300)
	}
	if r.IsPrivate != nil {
		b.IsPrivate = *r.IsPrivate
	}
	if b.Name == "" {
		return "Tagta at beriň"
	}
	return ""
}

func (h *Handler) createBoard(c fiber.Ctx) error {
	var req boardReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	b := models.Board{UserID: viewerID(c)}
	if msg := req.apply(&b); msg != "" {
		return badRequest(c, msg)
	}
	if err := h.db.Create(&b).Error; err != nil {
		return err
	}
	h.db.Preload("User").First(&b, b.ID)
	return c.Status(fiber.StatusCreated).JSON(h.boardDTOs([]models.Board{b})[0])
}

func (h *Handler) ownBoard(c fiber.Ctx, param string) (models.Board, error) {
	id, ok := idParam(c, param)
	if !ok {
		return models.Board{}, errNotFound
	}
	var b models.Board
	if err := h.db.Preload("User").First(&b, id).Error; err != nil {
		return b, errNotFound
	}
	if b.UserID != viewerID(c) {
		return b, errForbidden
	}
	return b, nil
}

func (h *Handler) updateBoard(c fiber.Ctx) error {
	b, err := h.ownBoard(c, "id")
	if err != nil {
		return err
	}
	var req boardReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if msg := req.apply(&b); msg != "" {
		return badRequest(c, msg)
	}
	if err := h.db.Omit("User").Save(&b).Error; err != nil {
		return err
	}
	return c.JSON(h.boardDTOs([]models.Board{b})[0])
}

func (h *Handler) deleteBoard(c fiber.Ctx) error {
	b, err := h.ownBoard(c, "id")
	if err != nil {
		return err
	}
	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("board_id = ?", b.ID).Delete(&models.BoardPin{}).Error; err != nil {
			return err
		}
		return tx.Delete(&models.Board{}, b.ID).Error
	})
	if err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// savePin: POST /boards/:id/pins/:pinId
func (h *Handler) savePin(c fiber.Ctx) error {
	b, err := h.ownBoard(c, "id")
	if err != nil {
		return err
	}
	pinID, ok := idParam(c, "pinId")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(pinID)
	if err != nil {
		return notFound(c)
	}
	bp := models.BoardPin{BoardID: b.ID, PinID: p.ID}
	res := h.db.Where(&bp).FirstOrCreate(&bp)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 && !b.IsPrivate {
		h.notify(p.UserID, b.UserID, models.NotifySave, &p.ID)
	}
	p, _ = h.loadPin(p.ID)
	return c.JSON(h.enrichPins([]models.Pin{p}, b.UserID)[0])
}

// unsavePin: DELETE /boards/:id/pins/:pinId
func (h *Handler) unsavePin(c fiber.Ctx) error {
	b, err := h.ownBoard(c, "id")
	if err != nil {
		return err
	}
	pinID, ok := idParam(c, "pinId")
	if !ok {
		return notFound(c)
	}
	h.db.Where("board_id = ? AND pin_id = ?", b.ID, pinID).Delete(&models.BoardPin{})
	p, err := h.loadPin(pinID)
	if err != nil {
		return c.SendStatus(fiber.StatusNoContent)
	}
	// Drop the "saved" notification once the pin is in none of this user's boards.
	if len(h.enrichPins([]models.Pin{p}, b.UserID)[0].SavedBoardIDs) == 0 {
		h.unnotify(p.UserID, b.UserID, models.NotifySave, &p.ID)
	}
	return c.JSON(h.enrichPins([]models.Pin{p}, b.UserID)[0])
}
