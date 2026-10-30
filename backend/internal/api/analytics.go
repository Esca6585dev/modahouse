package api

import (
	"sort"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

type DayStat struct {
	Day         string `json:"day"` // YYYY-MM-DD (UTC)
	NewUsers    int    `json:"newUsers"`
	ActiveUsers int    `json:"activeUsers"` // signed-in users who opened a post
	Views       int    `json:"views"`
	Searches    int    `json:"searches"`
}

type InterestStat struct {
	Key   string  `json:"key"`
	Name  string  `json:"name"`
	Score float64 `json:"score"` // summed, faded interest of all users
	Users int     `json:"users"` // users for whom this is the top interest (categories) or who have it (tags)
}

type SearchStat struct {
	Query   string `json:"query"`
	Count   int64  `json:"count"`
	Results int    `json:"results"` // results of the latest such search
}

type ViewedPin struct {
	ID       uint   `json:"id"`
	Title    string `json:"title"`
	ImageURL string `json:"imageUrl"`
	Category string `json:"category"`
	Views    int64  `json:"views"`
}

type CraftStat struct {
	Slug  string `json:"slug"`
	Name  string `json:"name"`
	Count int64  `json:"count"`
}

type Analytics struct {
	Days           int            `json:"days"`
	ActiveUsers    int            `json:"activeUsers"`
	NewUsers       int            `json:"newUsers"`
	Searches       int            `json:"searches"`
	UsersWithTaste int            `json:"usersWithTaste"` // users the feed can personalise for
	Daily          []DayStat      `json:"daily"`
	Categories     []InterestStat `json:"categories"`
	Tags           []InterestStat `json:"tags"`
	TopSearches    []SearchStat   `json:"topSearches"`
	EmptySearches  []SearchStat   `json:"emptySearches"` // asked for but not found: content to add
	TopPins        []ViewedPin    `json:"topPins"`
	Crafts         []CraftStat    `json:"crafts"`
}

// adminAnalytics: GET /admin/analytics?days=30 — what users are interested in.
func (h *Handler) adminAnalytics(c fiber.Ctx) error {
	days, _ := strconv.Atoi(c.Query("days", "30"))
	days = max(1, min(days, 365))
	now := time.Now().UTC()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	since := today.AddDate(0, 0, -(days - 1))
	a := Analytics{Days: days}

	daily := make([]DayStat, days)
	index := map[string]int{}
	for i := range daily {
		d := since.AddDate(0, 0, i).Format("2006-01-02")
		daily[i].Day, index[d] = d, i
	}
	at := func(t time.Time) *DayStat {
		if i, ok := index[t.UTC().Format("2006-01-02")]; ok {
			return &daily[i]
		}
		return nil
	}

	var joined []time.Time
	h.db.Model(&models.User{}).Where("created_at >= ?", since).Pluck("created_at", &joined)
	for _, t := range joined {
		if d := at(t); d != nil {
			d.NewUsers++
			a.NewUsers++
		}
	}
	var views []models.PinView
	h.db.Select("viewer", "day").Where("day >= ?", since).Find(&views)
	active := map[string]bool{}
	activeDay := map[string]bool{}
	for _, v := range views {
		d := at(v.Day)
		if d == nil {
			continue
		}
		d.Views++
		if len(v.Viewer) > 2 && v.Viewer[:2] == "u:" {
			active[v.Viewer] = true
			if k := d.Day + v.Viewer; !activeDay[k] {
				activeDay[k] = true
				d.ActiveUsers++
			}
		}
	}
	a.ActiveUsers = len(active)
	var searched []time.Time
	h.db.Model(&models.SearchLog{}).Where("created_at >= ?", since).Pluck("created_at", &searched)
	for _, t := range searched {
		if d := at(t); d != nil {
			d.Searches++
			a.Searches++
		}
	}
	a.Daily = daily

	// Interests: summed over users, faded to today.
	var rows []models.Interest
	h.db.Where("score > 0").Find(&rows)
	type agg struct {
		score float64
		users int
	}
	cats, tags := map[string]*agg{}, map[string]*agg{}
	topOf := map[uint]models.Interest{}
	for _, r := range rows {
		s := decayed(r.Score, now.Sub(r.UpdatedAt))
		if s < 0.5 {
			continue
		}
		m := tags
		if r.Kind == "category" {
			m = cats
			if best, ok := topOf[r.UserID]; !ok || s > best.Score {
				r.Score = s
				topOf[r.UserID] = r
			}
		}
		if m[r.Key] == nil {
			m[r.Key] = &agg{}
		}
		m[r.Key].score += s
		if r.Kind == "tag" {
			m[r.Key].users++
		}
	}
	for _, best := range topOf {
		cats[best.Key].users++
	}
	a.UsersWithTaste = len(topOf)
	toList := func(m map[string]*agg, named bool, limit int) []InterestStat {
		out := make([]InterestStat, 0, len(m))
		for k, v := range m {
			name := k
			if named {
				name = categoryName(k)
			}
			out = append(out, InterestStat{Key: k, Name: name, Score: round1(v.score), Users: v.users})
		}
		sort.Slice(out, func(i, j int) bool { return out[i].Score > out[j].Score })
		if len(out) > limit {
			out = out[:limit]
		}
		return out
	}
	a.Categories = toList(cats, true, len(Categories)+10)
	a.Tags = toList(tags, false, 30)

	searches := func(empty bool) []SearchStat {
		out := []SearchStat{}
		q := h.db.Model(&models.SearchLog{}).Select("query, COUNT(*) AS count, MIN(results) AS results").
			Where("created_at >= ?", since).Group("query").Order("count DESC, query").Limit(20)
		if empty {
			q = q.Where("results = 0")
		}
		q.Scan(&out)
		return out
	}
	a.TopSearches, a.EmptySearches = searches(false), searches(true)

	a.TopPins = []ViewedPin{}
	h.db.Table("pin_views").Select("pins.id, pins.title, pins.image_url, pins.category, COUNT(*) AS views").
		Joins("JOIN pins ON pins.id = pin_views.pin_id").Where("pin_views.day >= ?", since).
		Group("pins.id, pins.title, pins.image_url, pins.category").Order("views DESC").Limit(12).Scan(&a.TopPins)

	a.Crafts = []CraftStat{}
	var crafts []struct {
		Category string
		N        int64
	}
	h.db.Model(&models.User{}).Select("category, COUNT(*) AS n").Where("category <> ''").Group("category").Order("n DESC").Scan(&crafts)
	for _, r := range crafts {
		name := r.Category
		for _, pc := range ProfileCategories {
			if pc.Slug == r.Category {
				name = pc.Name
			}
		}
		a.Crafts = append(a.Crafts, CraftStat{r.Category, name, r.N})
	}
	return c.JSON(a)
}

// adminUserInterests: GET /admin/users/:id/interests
func (h *Handler) adminUserInterests(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	return c.JSON(fiber.Map{"items": h.interests(id, 30)})
}
