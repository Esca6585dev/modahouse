package api

import (
	"sort"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

const storyTTL = 24 * time.Hour

type StoryDTO struct {
	ID         uint      `json:"id"`
	ImageURL   string    `json:"imageUrl"`
	Width      int       `json:"width"`
	Height     int       `json:"height"`
	Color      string    `json:"color"`
	Caption    string    `json:"caption"`
	PinID      *uint     `json:"pinId"`
	Seen       bool      `json:"seen"`
	ViewsCount int64     `json:"viewsCount"`
	CreatedAt  time.Time `json:"createdAt"`
	ExpiresAt  time.Time `json:"expiresAt"`
}

type StoryGroup struct {
	User    UserBrief  `json:"user"`
	Stories []StoryDTO `json:"stories"`
	AllSeen bool       `json:"allSeen"`
}

// storyState reports whether userID has an active story and whether viewer saw all of them.
func (h *Handler) storyState(userID, viewer uint) (has, seen bool) {
	var ids []uint
	h.db.Model(&models.Story{}).Where("user_id = ? AND expires_at > ?", userID, time.Now()).Pluck("id", &ids)
	if len(ids) == 0 {
		return false, false
	}
	if viewer == 0 {
		return true, false
	}
	if viewer == userID {
		return true, true
	}
	var n int64
	h.db.Model(&models.StoryView{}).Where("user_id = ? AND story_id IN ?", viewer, ids).Count(&n)
	return true, n >= int64(len(ids))
}

// storyGroups loads active stories of the given users (in that order) for viewer.
func (h *Handler) storyGroups(userIDs []uint, viewer uint) []StoryGroup {
	if len(userIDs) == 0 {
		return []StoryGroup{}
	}
	var stories []models.Story
	h.db.Preload("User").Where("user_id IN ? AND expires_at > ?", userIDs, time.Now()).Order("created_at ASC, id ASC").Find(&stories)
	seen := map[uint]bool{}
	views := map[uint]int64{}
	if len(stories) > 0 {
		ids := make([]uint, len(stories))
		for i, s := range stories {
			ids[i] = s.ID
		}
		if viewer != 0 {
			var seenIDs []uint
			h.db.Model(&models.StoryView{}).Where("user_id = ? AND story_id IN ?", viewer, ids).Pluck("story_id", &seenIDs)
			for _, id := range seenIDs {
				seen[id] = true
			}
		}
		type row struct {
			StoryID uint
			N       int64
		}
		var rows []row
		h.db.Model(&models.StoryView{}).Select("story_id, COUNT(*) AS n").Where("story_id IN ?", ids).Group("story_id").Scan(&rows)
		for _, r := range rows {
			views[r.StoryID] = r.N
		}
	}
	byUser := map[uint]*StoryGroup{}
	for _, s := range stories {
		g := byUser[s.UserID]
		if g == nil {
			g = &StoryGroup{User: brief(s.User), AllSeen: true}
			byUser[s.UserID] = g
		}
		d := StoryDTO{ID: s.ID, ImageURL: s.ImageURL, Width: s.Width, Height: s.Height, Color: s.Color, Caption: s.Caption,
			PinID: s.PinID, Seen: seen[s.ID] || s.UserID == viewer, CreatedAt: s.CreatedAt, ExpiresAt: s.ExpiresAt}
		if s.UserID == viewer {
			d.ViewsCount = views[s.ID]
		}
		g.AllSeen = g.AllSeen && d.Seen
		g.Stories = append(g.Stories, d)
	}
	out := []StoryGroup{}
	for _, id := range userIDs {
		if g := byUser[id]; g != nil {
			out = append(out, *g)
		}
	}
	return out
}

// listStories: own first, then followed users, then other businesses; unseen before seen.
func (h *Handler) listStories(c fiber.Ctx) error {
	me := viewerID(c)
	var active []uint
	h.db.Model(&models.Story{}).Distinct("user_id").Where("expires_at > ?", time.Now()).Pluck("user_id", &active)
	following := map[uint]bool{}
	if me != 0 {
		var ids []uint
		h.db.Model(&models.Follow{}).Where("follower_id = ?", me).Pluck("following_id", &ids)
		for _, id := range ids {
			following[id] = true
		}
	}
	business := map[uint]bool{}
	if len(active) > 0 {
		var ids []uint
		h.db.Model(&models.User{}).Where("id IN ? AND is_business = ?", active, true).Pluck("id", &ids)
		for _, id := range ids {
			business[id] = true
		}
	}
	rank := func(id uint) int {
		switch {
		case id == me:
			return 0
		case following[id]:
			return 1
		case business[id]:
			return 2
		default:
			return 3
		}
	}
	var ids []uint
	for _, id := range active {
		if rank(id) < 3 {
			ids = append(ids, id)
		}
	}
	groups := h.storyGroups(ids, me)
	sort.SliceStable(groups, func(a, b int) bool {
		ga, gb := groups[a], groups[b]
		if (ga.User.ID == me) != (gb.User.ID == me) {
			return ga.User.ID == me
		}
		if ga.AllSeen != gb.AllSeen {
			return !ga.AllSeen
		}
		return rank(ga.User.ID) < rank(gb.User.ID)
	})
	return c.JSON(groups)
}

func (h *Handler) userStories(c fiber.Ctx) error {
	u, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	groups := h.storyGroups([]uint{u.ID}, viewerID(c))
	if len(groups) == 0 {
		return notFound(c)
	}
	return c.JSON(groups[0])
}

func (h *Handler) createStory(c fiber.Ctx) error {
	fh, err := c.FormFile("image")
	if err != nil {
		return badRequest(c, "Surat saýlaň")
	}
	me := viewerID(c)
	story := models.Story{UserID: me, Caption: clean(c.FormValue("caption"), 200)}
	if raw := c.FormValue("pinId"); raw != "" {
		id, _ := strconv.ParseUint(raw, 10, 64)
		var n int64
		h.db.Model(&models.Pin{}).Where("id = ?", id).Count(&n)
		if n == 0 {
			return badRequest(c, "Pin tapylmady")
		}
		pid := uint(id)
		story.PinID = &pid
	}
	saved, err := h.store.SaveImage(fh, "stories")
	if err != nil {
		return badRequest(c, err.Error())
	}
	now := time.Now()
	story.ImageURL, story.Width, story.Height, story.Color = saved.URL, saved.Width, saved.Height, saved.Color
	story.CreatedAt, story.ExpiresAt = now, now.Add(storyTTL)
	if err := h.db.Create(&story).Error; err != nil {
		h.store.Remove(saved.URL)
		return err
	}
	return c.Status(fiber.StatusCreated).JSON(StoryDTO{ID: story.ID, ImageURL: story.ImageURL, Width: story.Width, Height: story.Height,
		Color: story.Color, Caption: story.Caption, PinID: story.PinID, Seen: true, CreatedAt: story.CreatedAt, ExpiresAt: story.ExpiresAt})
}

func (h *Handler) viewStory(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var s models.Story
	if err := h.db.Where("id = ? AND expires_at > ?", id, time.Now()).First(&s).Error; err != nil {
		return notFound(c)
	}
	if me := viewerID(c); me != s.UserID {
		h.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.StoryView{StoryID: s.ID, UserID: me})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) deleteStory(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var s models.Story
	if err := h.db.First(&s, id).Error; err != nil {
		return notFound(c)
	}
	if s.UserID != viewerID(c) {
		return forbidden(c)
	}
	h.db.Where("story_id = ?", s.ID).Delete(&models.StoryView{})
	h.db.Delete(&models.Story{}, s.ID)
	h.store.Remove(s.ImageURL)
	return c.SendStatus(fiber.StatusNoContent)
}
