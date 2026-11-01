package api

import (
	"math"
	"sort"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// How much each action says about a user's taste.
const (
	weightView    = 1.0
	weightComment = 2.0
	weightLike    = 3.0
	weightSave    = 4.0
	weightCart    = 5.0
	weightSearch  = 2.0
	weightPicked  = 12.0 // chosen on the "what do you like?" screen
	weightHide    = -6.0

	interestHalfLife = 30 * 24 * time.Hour
	maxTagsTracked   = 5
)

func decayed(score float64, since time.Duration) float64 {
	if since <= 0 {
		return score
	}
	return score * math.Pow(0.5, float64(since)/float64(interestHalfLife))
}

// bump adds w to one interest after fading the old score.
func (h *Handler) bump(userID uint, kind, key string, w float64) {
	key = strings.ToLower(strings.TrimSpace(key))
	if userID == 0 || key == "" || len(key) > 60 {
		return
	}
	now := time.Now().UTC()
	it := models.Interest{UserID: userID, Kind: kind, Key: key}
	if h.db.Where(&it).First(&it).Error == nil {
		it.Score = decayed(it.Score, now.Sub(it.UpdatedAt))
	}
	it.Score = math.Max(-30, math.Min(500, it.Score+w))
	it.UpdatedAt = now
	h.db.Save(&it)
}

// trackPin records that the user did something with a pin.
func (h *Handler) trackPin(userID, pinID uint, w float64) {
	if userID == 0 {
		return
	}
	var p models.Pin
	if h.db.Select("id", "user_id", "category", "tags").First(&p, pinID).Error != nil || p.UserID == userID {
		return
	}
	h.bump(userID, "category", p.Category, w)
	if w < 0 {
		return // hiding a pin says little about its tags
	}
	for i, t := range splitTags(p.Tags) {
		if i == maxTagsTracked {
			break
		}
		h.bump(userID, "tag", t, w/2)
	}
}

// trackSearch logs a text search and learns from it.
func (h *Handler) trackSearch(userID uint, query string, results int) {
	query = strings.ToLower(clean(query, 100))
	if query == "" {
		return
	}
	entry := models.SearchLog{Query: query, Results: results}
	if userID != 0 {
		entry.UserID = &userID
	}
	h.db.Create(&entry)
	if userID == 0 {
		return
	}
	for _, c := range Categories {
		if strings.Contains(strings.ToLower(c.Name), query) || strings.Contains(query, c.Slug) {
			h.bump(userID, "category", c.Slug, weightSearch)
		}
	}
	for _, w := range strings.Fields(strings.TrimPrefix(query, "#")) {
		if len([]rune(w)) >= 3 {
			h.bump(userID, "tag", strings.TrimPrefix(w, "#"), weightSearch/2)
		}
	}
}

type InterestDTO struct {
	Kind  string  `json:"kind"`
	Key   string  `json:"key"`
	Name  string  `json:"name"` // category name, or the tag itself
	Score float64 `json:"score"`
}

func categoryName(slug string) string {
	for _, c := range Categories {
		if c.Slug == slug {
			return c.Name
		}
	}
	return slug
}

// interests returns a user's current interests, strongest first.
func (h *Handler) interests(userID uint, limit int) []InterestDTO {
	var rows []models.Interest
	h.db.Where("user_id = ?", userID).Find(&rows)
	now := time.Now().UTC()
	out := make([]InterestDTO, 0, len(rows))
	for _, r := range rows {
		s := decayed(r.Score, now.Sub(r.UpdatedAt))
		if s < 0.5 {
			continue
		}
		name := r.Key
		if r.Kind == "category" {
			name = categoryName(r.Key)
		}
		out = append(out, InterestDTO{Kind: r.Kind, Key: r.Key, Name: name, Score: round1(s)})
	}
	sort.Slice(out, func(a, b int) bool { return out[a].Score > out[b].Score })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out
}

// myInterests: GET /me/interests. "picked" tells clients whether to show the
// "what do you like?" screen after sign-up.
func (h *Handler) myInterests(c fiber.Ctx) error {
	items := h.interests(viewerID(c), 30)
	return c.JSON(fiber.Map{"items": items, "picked": len(items) > 0})
}

// pickInterests: PUT /me/interests {"categories": [...]} from the welcome screen.
func (h *Handler) pickInterests(c fiber.Ctx) error {
	var req struct {
		Categories []string `json:"categories"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	n := 0
	for _, slug := range req.Categories {
		if validCategory(slug) && n < len(Categories) {
			h.bump(me, "category", slug, weightPicked)
			n++
		}
	}
	if n == 0 {
		return badRequest(c, "Iň bolmanda bir bölüm saýlaň")
	}
	return h.myInterests(c)
}

// resetInterests: DELETE /me/interests forgets what was learned.
func (h *Handler) resetInterests(c fiber.Ctx) error {
	h.db.Where("user_id = ?", viewerID(c)).Delete(&models.Interest{})
	return c.SendStatus(fiber.StatusNoContent)
}

// --- "for you" feed ---

const forYouCandidates = 800

// forYouFeed orders recent pins by the viewer's interests, keeping some
// freshness and variety. Without interests it is the newest-first feed.
func (h *Handler) forYouFeed(c fiber.Ctx, q *gorm.DB) error {
	me := viewerID(c)
	weights := map[string]float64{}
	var top float64
	for _, it := range h.interests(me, 0) {
		k := it.Kind + ":" + it.Key
		weights[k] = it.Score
		top = math.Max(top, it.Score)
	}
	if me == 0 || top == 0 {
		return h.pagePinsWith(c, q, 24, true)
	}
	promoted := h.promotedFor(c, q)
	var cands []models.Pin
	if err := q.Session(&gorm.Session{}).Select("pins.id", "pins.user_id", "pins.category", "pins.tags", "pins.created_at", "pins.views_count").
		Where("pins.user_id <> ?", me).Limit(forYouCandidates).Find(&cands).Error; err != nil {
		return err
	}
	now := time.Now()
	type scored struct {
		id    uint
		cat   string
		score float64
	}
	list := make([]scored, len(cands))
	for i, p := range cands {
		s := 3 * weights["category:"+p.Category] / top
		tags := 0.0
		for _, t := range splitTags(p.Tags) {
			tags += weights["tag:"+t]
		}
		s += math.Min(2, 2*tags/top)
		s += 1.5 * math.Pow(0.5, now.Sub(p.CreatedAt).Hours()/(24*14)) // fresh posts first
		s += 0.3 * math.Log1p(float64(p.ViewsCount)) / 10
		list[i] = scored{p.ID, p.Category, s}
	}
	sort.SliceStable(list, func(a, b int) bool { return list[a].score > list[b].score })
	// Variety: each further pin of a category within a page counts for a little less.
	ordered := make([]uint, 0, len(list))
	seen := map[string]int{}
	for len(list) > 0 {
		best, bestScore := 0, math.Inf(-1)
		for i := 0; i < len(list) && i < 40; i++ {
			s := list[i].score - 0.35*float64(seen[list[i].cat]%12)
			if s > bestScore {
				best, bestScore = i, s
			}
		}
		ordered = append(ordered, list[best].id)
		seen[list[best].cat]++
		list = append(list[:best], list[best+1:]...)
	}

	page, limit, offset := paging(c, 24)
	if offset >= len(ordered) {
		return c.JSON(Page[PinDTO]{Items: []PinDTO{}, Page: page, Limit: limit})
	}
	ids := ordered[offset:min(len(ordered), offset+limit)]
	var pins []models.Pin
	if err := h.db.Preload("User").Where("id IN ?", ids).Find(&pins).Error; err != nil {
		return err
	}
	pos := map[uint]int{}
	for i, id := range ids {
		pos[id] = i
	}
	sort.Slice(pins, func(a, b int) bool { return pos[pins[a].ID] < pos[pins[b].ID] })
	items := h.withPromoted(c, promoted, h.enrichPins(pins, me))
	if c.Query("withComments") == "1" {
		h.attachComments(items, me)
	}
	return c.JSON(Page[PinDTO]{Items: items, Page: page, Limit: limit, HasMore: offset+limit < len(ordered)})
}
