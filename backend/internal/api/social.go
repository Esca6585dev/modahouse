package api

import (
	"regexp"
	"sort"
	"strings"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

var hashtagRe = regexp.MustCompile(`#([\p{L}\p{N}_]{2,40})`)

// captionTags extracts #hashtags from a caption, lower-cased.
func captionTags(text string) []string {
	var out []string
	for _, m := range hashtagRe.FindAllStringSubmatch(text, -1) {
		out = append(out, strings.ToLower(m[1]))
	}
	return out
}

// viewerFilter hides pins the viewer marked "not interested" and pins of blocked
// users (in both directions).
func (h *Handler) viewerFilter(q *gorm.DB, viewer uint) *gorm.DB {
	if viewer == 0 {
		return q
	}
	return q.Where("pins.id NOT IN (?)", h.db.Model(&models.HiddenPin{}).Select("pin_id").Where("user_id = ?", viewer)).
		Where("pins.user_id NOT IN (?)", h.db.Model(&models.Block{}).Select("blocked_id").Where("blocker_id = ?", viewer)).
		Where("pins.user_id NOT IN (?)", h.db.Model(&models.Block{}).Select("blocker_id").Where("blocked_id = ?", viewer))
}

// isBlockedBetween reports a block in either direction.
func (h *Handler) isBlockedBetween(a, b uint) bool {
	if a == 0 || b == 0 {
		return false
	}
	var n int64
	h.db.Model(&models.Block{}).Where("(blocker_id = ? AND blocked_id = ?) OR (blocker_id = ? AND blocked_id = ?)", a, b, b, a).Count(&n)
	return n > 0
}

var reportReasons = map[string]bool{"spam": true, "inappropriate": true, "copyright": true, "fake": true, "other": true}

func (h *Handler) reportPin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var n int64
	if h.db.Model(&models.Pin{}).Where("id = ?", id).Count(&n); n == 0 {
		return notFound(c)
	}
	var req struct {
		Reason string `json:"reason"`
		Note   string `json:"note"`
	}
	if err := c.Bind().Body(&req); err != nil || !reportReasons[req.Reason] {
		return badRequest(c, "Şikaýatyň sebäbini saýlaň")
	}
	h.db.Create(&models.Report{PinID: id, UserID: viewerID(c), Reason: req.Reason, Note: clean(req.Note, 300)})
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) hidePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var n int64
	if h.db.Model(&models.Pin{}).Where("id = ?", id).Count(&n); n == 0 {
		return notFound(c)
	}
	h.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.HiddenPin{UserID: viewerID(c), PinID: id})
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) unhidePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	h.db.Where("user_id = ? AND pin_id = ?", viewerID(c), id).Delete(&models.HiddenPin{})
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) blockUser(c fiber.Ctx) error {
	target, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	if target.ID == me {
		return badRequest(c, "Özüňizi petikläp bilmersiňiz")
	}
	h.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Block{BlockerID: me, BlockedID: target.ID})
	h.db.Where("(follower_id = ? AND following_id = ?) OR (follower_id = ? AND following_id = ?)", me, target.ID, target.ID, me).Delete(&models.Follow{})
	return c.JSON(fiber.Map{"blocked": true})
}

func (h *Handler) unblockUser(c fiber.Ctx) error {
	target, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	h.db.Where("blocker_id = ? AND blocked_id = ?", viewerID(c), target.ID).Delete(&models.Block{})
	return c.JSON(fiber.Map{"blocked": false})
}

func (h *Handler) myBlocks(c fiber.Ctx) error {
	var users []models.User
	h.db.Joins("JOIN blocks ON blocks.blocked_id = users.id").Where("blocks.blocker_id = ?", viewerID(c)).Order("blocks.created_at DESC").Find(&users)
	out := make([]UserBrief, len(users))
	for i, u := range users {
		out[i] = brief(u)
	}
	return c.JSON(out)
}

// myLikes: GET /me/likes — posts the viewer liked, newest like first.
func (h *Handler) myLikes(c fiber.Ctx) error {
	q := h.db.Model(&models.Pin{}).Joins("JOIN likes ON likes.pin_id = pins.id").
		Where("likes.user_id = ?", viewerID(c)).Order("likes.created_at DESC, pins.id DESC")
	return h.pagePins(c, q, 24)
}

type TagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// search: GET /search?q= — people, shops and hashtags for the search box.
func (h *Handler) search(c fiber.Ctx) error {
	term := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(c.Query("q")), "#")))
	out := fiber.Map{"users": []UserBrief{}, "tags": []TagCount{}}
	if term == "" {
		return c.JSON(out)
	}
	like := "%" + escapeLike(term) + "%"
	var users []models.User
	h.db.Where(`username LIKE ? ESCAPE '\' OR LOWER(name) LIKE ? ESCAPE '\'`, like, like).
		Order("is_business DESC, verified DESC, id").Limit(10).Find(&users)
	briefs := make([]UserBrief, len(users))
	for i, u := range users {
		briefs[i] = brief(u)
	}
	out["users"] = briefs

	var rows []string
	h.db.Model(&models.Pin{}).Where(`tags LIKE ? ESCAPE '\'`, like).Limit(500).Pluck("tags", &rows)
	counts := map[string]int{}
	for _, r := range rows {
		for _, t := range strings.Split(r, ",") {
			if strings.Contains(t, term) {
				counts[t]++
			}
		}
	}
	tags := make([]TagCount, 0, len(counts))
	for t, n := range counts {
		tags = append(tags, TagCount{t, n})
	}
	sort.Slice(tags, func(a, b int) bool {
		if tags[a].Count != tags[b].Count {
			return tags[a].Count > tags[b].Count
		}
		return tags[a].Tag < tags[b].Tag
	})
	if len(tags) > 10 {
		tags = tags[:10]
	}
	out["tags"] = tags
	return c.JSON(out)
}
