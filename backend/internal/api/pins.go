package api

import (
	"net/url"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// enrichPins turns pins (with User preloaded) into DTOs with counts and viewer state,
// using a fixed number of queries regardless of page size.
func (h *Handler) enrichPins(pins []models.Pin, viewer uint) []PinDTO {
	out := make([]PinDTO, len(pins))
	if len(pins) == 0 {
		return out
	}
	ids := make([]uint, len(pins))
	for i, p := range pins {
		ids[i] = p.ID
	}

	type count struct {
		PinID uint
		N     int64
	}
	likes, comments := map[uint]int64{}, map[uint]int64{}
	var rows []count
	h.db.Model(&models.Like{}).Select("pin_id, COUNT(*) AS n").Where("pin_id IN ?", ids).Group("pin_id").Scan(&rows)
	for _, r := range rows {
		likes[r.PinID] = r.N
	}
	rows = nil
	h.db.Model(&models.Comment{}).Select("pin_id, COUNT(*) AS n").Where("pin_id IN ?", ids).Group("pin_id").Scan(&rows)
	for _, r := range rows {
		comments[r.PinID] = r.N
	}

	liked := map[uint]bool{}
	saved := map[uint][]uint{}
	if viewer != 0 {
		var likedIDs []uint
		h.db.Model(&models.Like{}).Where("user_id = ? AND pin_id IN ?", viewer, ids).Pluck("pin_id", &likedIDs)
		for _, id := range likedIDs {
			liked[id] = true
		}
		var bp []models.BoardPin
		h.db.Model(&models.BoardPin{}).Select("board_pins.board_id, board_pins.pin_id").
			Joins("JOIN boards ON boards.id = board_pins.board_id").
			Where("boards.user_id = ? AND board_pins.pin_id IN ?", viewer, ids).Scan(&bp)
		for _, r := range bp {
			saved[r.PinID] = append(saved[r.PinID], r.BoardID)
		}
	}

	for i, p := range pins {
		boards := saved[p.ID]
		if boards == nil {
			boards = []uint{}
		}
		out[i] = PinDTO{
			ID: p.ID, Title: p.Title, Description: p.Description, Link: p.Link, Category: p.Category,
			Tags: splitTags(p.Tags), ImageURL: p.ImageURL, Width: p.Width, Height: p.Height, Color: p.Color,
			Author: brief(p.User), LikesCount: likes[p.ID], CommentsCount: comments[p.ID],
			Liked: liked[p.ID], SavedBoardIDs: boards, CreatedAt: p.CreatedAt,
		}
	}
	return out
}

// pagePins runs q (already filtered/ordered) for the requested page.
func (h *Handler) pagePins(c fiber.Ctx, q *gorm.DB, defLimit int) error {
	page, limit, offset := paging(c, defLimit)
	var pins []models.Pin
	if err := q.Preload("User").Offset(offset).Limit(limit + 1).Find(&pins).Error; err != nil {
		return err
	}
	pins, more := trimPage(pins, limit)
	return c.JSON(Page[PinDTO]{Items: h.enrichPins(pins, viewerID(c)), Page: page, Limit: limit, HasMore: more})
}

func searchText(p *models.Pin) string {
	return strings.ToLower(strings.Join([]string{p.Title, p.Description, p.Tags}, " "))
}

func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// listPins: GET /pins?q=&category=&feed=following
func (h *Handler) listPins(c fiber.Ctx) error {
	q := h.db.Model(&models.Pin{}).Order("pins.created_at DESC, pins.id DESC")
	if cat := c.Query("category"); cat != "" {
		q = q.Where("pins.category = ?", cat)
	}
	if term := strings.ToLower(strings.TrimSpace(c.Query("q"))); term != "" {
		for _, w := range strings.Fields(term) {
			q = q.Where(`pins.search_text LIKE ? ESCAPE '\'`, "%"+escapeLike(w)+"%")
		}
	}
	if c.Query("feed") == "following" {
		me := viewerID(c)
		if me == 0 {
			return fail(c, fiber.StatusUnauthorized, "Ilki ulgama giriň")
		}
		q = q.Where("pins.user_id IN (?)", h.db.Model(&models.Follow{}).Select("following_id").Where("follower_id = ?", me))
	}
	return h.pagePins(c, q, 24)
}

func (h *Handler) loadPin(id uint) (models.Pin, error) {
	var p models.Pin
	err := h.db.Preload("User").First(&p, id).Error
	return p, err
}

func (h *Handler) getPin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	return c.JSON(h.enrichPins([]models.Pin{p}, viewerID(c))[0])
}

// similarPins: same category first, then everything else, newest first.
func (h *Handler) similarPins(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	q := h.db.Model(&models.Pin{}).Where("pins.id <> ?", p.ID).Clauses(clause.OrderBy{Expression: clause.Expr{
		SQL:                "CASE WHEN pins.category = ? THEN 0 ELSE 1 END, pins.created_at DESC, pins.id DESC",
		Vars:               []any{p.Category},
		WithoutParentheses: true,
	}})
	return h.pagePins(c, q, 20)
}

func (h *Handler) userPins(c fiber.Ctx) error {
	u, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	return h.pagePins(c, h.db.Model(&models.Pin{}).Where("pins.user_id = ?", u.ID).Order("pins.created_at DESC, pins.id DESC"), 24)
}

type pinFields struct {
	Title       *string `json:"title" form:"title"`
	Description *string `json:"description" form:"description"`
	Link        *string `json:"link" form:"link"`
	Category    *string `json:"category" form:"category"`
	Tags        *string `json:"tags" form:"tags"`
}

// apply validates and copies the provided fields onto p. It returns a user-facing error message.
func (f pinFields) apply(p *models.Pin) string {
	if f.Title != nil {
		p.Title = clean(*f.Title, 100)
	}
	if f.Description != nil {
		p.Description = clean(*f.Description, 1000)
	}
	if f.Link != nil {
		link := clean(*f.Link, 500)
		if link != "" {
			u, err := url.Parse(link)
			if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
				return "Baglanyşyk http:// ýa-da https:// bilen başlamaly"
			}
		}
		p.Link = link
	}
	if f.Category != nil {
		if !validCategory(*f.Category) {
			return "Kategoriýa nädogry"
		}
		p.Category = *f.Category
	}
	if f.Tags != nil {
		p.Tags = strings.Join(splitTags(*f.Tags), ",")
	}
	if p.Title == "" {
		return "Pine at beriň"
	}
	if p.Category == "" {
		return "Kategoriýa saýlaň"
	}
	p.SearchText = searchText(p)
	return ""
}

// createPin: multipart form with "image" file, pin fields and optional boardId.
func (h *Handler) createPin(c fiber.Ctx) error {
	fh, err := c.FormFile("image")
	if err != nil {
		return badRequest(c, "Surat saýlaň")
	}
	str := func(k string) *string { v := c.FormValue(k); return &v }
	fields := pinFields{Title: str("title"), Description: str("description"), Link: str("link"), Category: str("category"), Tags: str("tags")}
	pin := models.Pin{UserID: viewerID(c)}
	if msg := fields.apply(&pin); msg != "" {
		return badRequest(c, msg)
	}

	var board *models.Board
	if raw := c.FormValue("boardId"); raw != "" {
		bid, _ := strconv.ParseUint(raw, 10, 64)
		var b models.Board
		if err := h.db.Where("id = ? AND user_id = ?", bid, pin.UserID).First(&b).Error; err != nil {
			return badRequest(c, "Tagta tapylmady")
		}
		board = &b
	}

	saved, err := h.store.SaveImage(fh, "pins")
	if err != nil {
		return badRequest(c, err.Error())
	}
	pin.ImageURL, pin.Width, pin.Height, pin.Color = saved.URL, saved.Width, saved.Height, saved.Color

	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&pin).Error; err != nil {
			return err
		}
		if board != nil {
			return tx.Create(&models.BoardPin{BoardID: board.ID, PinID: pin.ID}).Error
		}
		return nil
	})
	if err != nil {
		h.store.Remove(saved.URL)
		return err
	}
	p, _ := h.loadPin(pin.ID)
	return c.Status(fiber.StatusCreated).JSON(h.enrichPins([]models.Pin{p}, pin.UserID)[0])
}

func (h *Handler) ownPin(c fiber.Ctx) (models.Pin, error) {
	id, ok := idParam(c, "id")
	if !ok {
		return models.Pin{}, errNotFound
	}
	p, err := h.loadPin(id)
	if err != nil {
		return p, errNotFound
	}
	if p.UserID != viewerID(c) {
		return p, errForbidden
	}
	return p, nil
}

func (h *Handler) updatePin(c fiber.Ctx) error {
	p, err := h.ownPin(c)
	if err != nil {
		return err
	}
	var f pinFields
	if err := c.Bind().Body(&f); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if msg := f.apply(&p); msg != "" {
		return badRequest(c, msg)
	}
	if err := h.db.Omit("User").Save(&p).Error; err != nil {
		return err
	}
	return c.JSON(h.enrichPins([]models.Pin{p}, p.UserID)[0])
}

func (h *Handler) deletePin(c fiber.Ctx) error {
	p, err := h.ownPin(c)
	if err != nil {
		return err
	}
	err = h.db.Transaction(func(tx *gorm.DB) error {
		// Explicit cleanup keeps SQLite and Postgres consistent even without FK cascades.
		for _, m := range []any{&models.BoardPin{}, &models.Like{}, &models.Comment{}, &models.Notification{}} {
			if err := tx.Where("pin_id = ?", p.ID).Delete(m).Error; err != nil {
				return err
			}
		}
		return tx.Delete(&models.Pin{}, p.ID).Error
	})
	if err != nil {
		return err
	}
	h.store.Remove(p.ImageURL)
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) likeState(c fiber.Ctx, pinID uint) error {
	var n int64
	h.db.Model(&models.Like{}).Where("pin_id = ?", pinID).Count(&n)
	var mine int64
	h.db.Model(&models.Like{}).Where("pin_id = ? AND user_id = ?", pinID, viewerID(c)).Count(&mine)
	return c.JSON(fiber.Map{"liked": mine > 0, "likesCount": n})
}

func (h *Handler) likePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	me := viewerID(c)
	l := models.Like{UserID: me, PinID: p.ID}
	res := h.db.Where(&l).FirstOrCreate(&l)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		h.notify(p.UserID, me, models.NotifyLike, &p.ID)
	}
	return h.likeState(c, p.ID)
}

func (h *Handler) unlikePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	h.db.Where("user_id = ? AND pin_id = ?", viewerID(c), id).Delete(&models.Like{})
	return h.likeState(c, id)
}
