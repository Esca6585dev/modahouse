package api

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html"
	"io"
	"log"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/seed"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

// Wikimedia asks API clients to identify themselves.
const commonsUserAgent = "ModaHouse/1.0 (photo import by a site administrator)"

// OfficialUsername owns imported photos unless another author is chosen.
const OfficialUsername = "modahouse"

var commonsClient = &http.Client{Timeout: 30 * time.Second}

func (h *Handler) commonsGet(ctx context.Context, params url.Values, out any) error {
	params.Set("format", "json")
	params.Set("formatversion", "2")
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, h.cfg.CommonsAPIURL+"?"+params.Encode(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", commonsUserAgent)
	resp, err := commonsClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("commons: HTTP %d", resp.StatusCode)
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 8<<20)).Decode(out)
}

func commonsUnreachable(c fiber.Ctx, err error) error {
	log.Printf("commons: %v", err)
	return fail(c, fiber.StatusBadGateway, "Wikimedia Commons bilen baglanyşyk ýok: serweriň internete çykyşyny barlaň")
}

// adminCommonsSearch finds Commons categories for a query, with their file counts.
func (h *Handler) adminCommonsSearch(c fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	if q == "" {
		return badRequest(c, "Gözleg sözüni ýazyň")
	}
	var found struct {
		Query struct {
			Search []struct {
				Title string `json:"title"`
			} `json:"search"`
		} `json:"query"`
	}
	ctx := c.Context()
	if err := h.commonsGet(ctx, url.Values{"action": {"query"}, "list": {"search"}, "srsearch": {q},
		"srnamespace": {"14"}, "srlimit": {"20"}}, &found); err != nil {
		return commonsUnreachable(c, err)
	}
	type category struct {
		Title string `json:"title"`
		Files int    `json:"files"`
	}
	cats := []category{}
	var titles []string
	for _, s := range found.Query.Search {
		titles = append(titles, s.Title)
	}
	counts := map[string]int{}
	if len(titles) > 0 {
		var info struct {
			Query struct {
				Pages []struct {
					Title        string `json:"title"`
					CategoryInfo struct {
						Files int `json:"files"`
					} `json:"categoryinfo"`
				} `json:"pages"`
			} `json:"query"`
		}
		if err := h.commonsGet(ctx, url.Values{"action": {"query"}, "prop": {"categoryinfo"},
			"titles": {strings.Join(titles, "|")}}, &info); err == nil {
			for _, p := range info.Query.Pages {
				counts[p.Title] = p.CategoryInfo.Files
			}
		}
	}
	for _, t := range titles {
		cats = append(cats, category{Title: t, Files: counts[t]})
	}
	sort.SliceStable(cats, func(i, j int) bool { return cats[i].Files > cats[j].Files })
	return c.JSON(fiber.Map{"categories": cats})
}

type commonsFile struct {
	Title     string
	ThumbURL  string
	SourceURL string // file page
	Mime      string
	License   string
	Artist    string
	Desc      string
	Object    string
	Tags      string // added to the post, comma separated
}

var tagRe = regexp.MustCompile(`<[^>]*>`)

func stripHTML(s string) string {
	s = tagRe.ReplaceAllString(s, " ")
	return strings.Join(strings.Fields(html.UnescapeString(s)), " ")
}

// allowedLicense accepts licences that permit commercial reuse with attribution.
func allowedLicense(l string) bool {
	s := strings.ToLower(strings.TrimSpace(l))
	for _, tok := range strings.FieldsFunc(s, func(r rune) bool { return !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9') }) {
		if tok == "nc" || tok == "nd" { // non-commercial or no-derivatives
			return false
		}
	}
	return strings.HasPrefix(s, "cc0") || strings.HasPrefix(s, "public domain") || strings.HasPrefix(s, "pd") ||
		strings.HasPrefix(s, "cc by") || strings.HasPrefix(s, "cc-by")
}

func commonsTitle(f commonsFile) string {
	if t := stripHTML(f.Object); t != "" {
		return clean(t, 100)
	}
	name := strings.TrimPrefix(f.Title, "File:")
	name = strings.TrimSuffix(name, path.Ext(name))
	name = strings.NewReplacer("_", " ", "-", " ").Replace(name)
	return clean(strings.Join(strings.Fields(name), " "), 100)
}

// adminCommonsImport imports openly licensed photos of a Commons category as posts.
func (h *Handler) adminCommonsImport(c fiber.Ctx) error {
	var req struct {
		Category    string `json:"category"`
		Limit       int    `json:"limit"`
		AppCategory string `json:"appCategory"`
		Author      string `json:"author"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	cat := strings.TrimSpace(req.Category)
	if cat == "" {
		return badRequest(c, "Kategoriýany saýlaň")
	}
	if !strings.HasPrefix(cat, "Category:") {
		cat = "Category:" + cat
	}
	if !validCategory(req.AppCategory) {
		return badRequest(c, "Kategoriýa nädogry")
	}
	if req.Limit <= 0 {
		req.Limit = 20
	}
	req.Limit = min(req.Limit, 50)

	author, err := h.importAuthor(req.Author)
	if err != nil {
		return badRequest(c, err.Error())
	}

	created, skipped, err := h.importCommons(c.Context(), url.Values{"generator": {"categorymembers"},
		"gcmtitle": {cat}, "gcmtype": {"file"}, "gcmlimit": {fmt.Sprint(min(req.Limit*3, 200))}},
		req.Limit, author, req.AppCategory, "")
	if err != nil {
		return commonsUnreachable(c, err)
	}
	out := []PinDTO{}
	if len(created) > 0 {
		out = h.enrichPins(created, viewerID(c))
	}
	return c.JSON(fiber.Map{"created": out, "skipped": skipped})
}

type commonsSkip struct {
	Title  string `json:"title"`
	Reason string `json:"reason"`
}

// importCommons lists files with the given generator parameters and imports up
// to limit openly licensed photos as posts of author in category.
func (h *Handler) importCommons(ctx context.Context, gen url.Values, limit int, author models.User, category, tags string) ([]models.Pin, []commonsSkip, error) {
	var res struct {
		Query struct {
			Pages []struct {
				Title     string `json:"title"`
				ImageInfo []struct {
					URL            string `json:"url"`
					ThumbURL       string `json:"thumburl"`
					DescriptionURL string `json:"descriptionurl"`
					Mime           string `json:"mime"`
					Width          int    `json:"width"`
					ExtMetadata    map[string]struct {
						Value any `json:"value"`
					} `json:"extmetadata"`
				} `json:"imageinfo"`
			} `json:"pages"`
		} `json:"query"`
	}
	params := url.Values{"action": {"query"}, "prop": {"imageinfo"}, "iiprop": {"url|mime|size|extmetadata"}, "iiurlwidth": {"1080"}}
	for k, v := range gen {
		params[k] = v
	}
	if err := h.commonsGet(ctx, params, &res); err != nil {
		return nil, nil, err
	}

	skipped := []commonsSkip{}
	var files []commonsFile
	meta := func(m map[string]struct {
		Value any `json:"value"`
	}, k string) string {
		if v, ok := m[k]; ok {
			if s, ok := v.Value.(string); ok {
				return s
			}
		}
		return ""
	}
	for _, p := range res.Query.Pages {
		if len(p.ImageInfo) == 0 {
			continue
		}
		ii := p.ImageInfo[0]
		f := commonsFile{Title: p.Title, ThumbURL: ii.ThumbURL, SourceURL: ii.DescriptionURL, Mime: ii.Mime,
			License: stripHTML(meta(ii.ExtMetadata, "LicenseShortName")), Artist: stripHTML(meta(ii.ExtMetadata, "Artist")),
			Desc: stripHTML(meta(ii.ExtMetadata, "ImageDescription")), Object: meta(ii.ExtMetadata, "ObjectName"), Tags: tags}
		if f.ThumbURL == "" {
			f.ThumbURL = ii.URL
		}
		switch {
		case !strings.HasPrefix(f.Mime, "image/") || f.Mime == "image/svg+xml" || f.Mime == "image/gif":
			skipped = append(skipped, commonsSkip{p.Title, "Surat däl"})
		case ii.Width > 0 && ii.Width < 500:
			skipped = append(skipped, commonsSkip{p.Title, "Hili pes (kiçi surat)"})
		case !allowedLicense(f.License):
			skipped = append(skipped, commonsSkip{p.Title, "Ygtyýarnamasy laýyk däl: " + f.License})
		default:
			var n int64
			h.db.Model(&models.Pin{}).Where("link = ?", f.SourceURL).Count(&n)
			if n > 0 {
				skipped = append(skipped, commonsSkip{p.Title, "Eýýäm import edilen"})
			} else if len(files) < limit {
				files = append(files, f)
			}
		}
	}

	// Download up to four thumbnails at a time.
	type result struct {
		pin  *models.Pin
		skip *commonsSkip
	}
	results := make([]result, len(files))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 4)
	for i, f := range files {
		wg.Add(1)
		go func(i int, f commonsFile) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			p, reason := h.importCommonsFile(ctx, f, author, category)
			if reason != "" {
				results[i] = result{skip: &commonsSkip{f.Title, reason}}
			} else {
				results[i] = result{pin: p}
			}
		}(i, f)
	}
	wg.Wait()

	created := []models.Pin{}
	for _, r := range results {
		if r.skip != nil {
			skipped = append(skipped, *r.skip)
		} else if r.pin != nil {
			if p, err := h.loadPin(r.pin.ID); err == nil {
				created = append(created, p)
			}
		}
	}
	return created, skipped, nil
}

func (h *Handler) importCommonsFile(ctx context.Context, f commonsFile, author models.User, category string) (*models.Pin, string) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.ThumbURL, nil)
	if err != nil {
		return nil, "Salgy nädogry"
	}
	req.Header.Set("User-Agent", commonsUserAgent)
	resp, err := commonsClient.Do(req)
	if err != nil {
		return nil, "Ýüklenmedi"
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Sprintf("Ýüklenmedi (HTTP %d)", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, int64(h.cfg.MaxUploadMB)<<20+1))
	if err != nil || len(data) > h.cfg.MaxUploadMB<<20 {
		return nil, "Surat gaty uly"
	}
	saved, err := h.store.SaveImageData(data, "pins", nil) // licensed photos are kept unmodified
	if err != nil {
		return nil, err.Error()
	}
	artist := f.Artist
	if artist == "" {
		artist = "näbelli awtor"
	}
	credit := clean(fmt.Sprintf("Surat: %s · %s · Wikimedia Commons", artist, f.License), 300)
	str := func(v string) *string { return &v }
	fields := pinFields{Title: str(commonsTitle(f)), Description: str(clean(f.Desc, 600)), Link: str(f.SourceURL), Category: str(category)}
	if f.Tags != "" {
		fields.Tags = &f.Tags
	}
	pin := models.Pin{UserID: author.ID, Credit: credit}
	if msg := fields.apply(&pin); msg != "" {
		h.store.Remove(saved.URL)
		return nil, msg
	}
	finishListing(&pin)
	pin.ImageURL, pin.Width, pin.Height, pin.Color = saved.URL, saved.Width, saved.Height, saved.Color
	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&pin).Error; err != nil {
			return err
		}
		return tx.Create(&models.PinImage{PinID: pin.ID, Kind: "image", URL: saved.URL, Width: saved.Width,
			Height: saved.Height, Color: saved.Color}).Error
	})
	if err != nil {
		h.store.Remove(saved.URL)
		return nil, "Serwerde ýalňyşlyk ýüze çykdy"
	}
	return &pin, ""
}

// importAuthor returns the chosen author or the official account (created on first use).
func (h *Handler) importAuthor(username string) (models.User, error) {
	var u models.User
	username = strings.ToLower(strings.TrimSpace(strings.TrimPrefix(username, "@")))
	if username != "" && username != OfficialUsername {
		if h.db.Where("username = ?", username).First(&u).Error != nil {
			return u, fmt.Errorf("Awtor tapylmady")
		}
		return u, nil
	}
	if h.db.Where("username = ?", OfficialUsername).First(&u).Error == nil {
		h.officialAvatar(&u)
		return u, nil
	}
	// No usable password: nobody can log in as the official account.
	secret := make([]byte, 32)
	_, _ = rand.Read(secret)
	hash, err := bcrypt.GenerateFromPassword([]byte(hex.EncodeToString(secret)[:64]), bcrypt.DefaultCost)
	if err != nil {
		return u, err
	}
	u = models.User{Username: OfficialUsername, Name: "ModaHouse", Email: "official@modahouse.local",
		Bio:          "Türkmen modasynyň resmi sahypasy: köýnekler, ýaka fasonlary, el keşdeleri we şaý-sepler.",
		PasswordHash: string(hash), Verified: true}
	if err := h.db.Create(&u).Error; err != nil {
		return u, err
	}
	h.db.Create(&models.Board{UserID: u.ID, Name: DefaultBoardName})
	h.officialAvatar(&u)
	return u, nil
}

//go:embed official-avatar.svg
var officialAvatarSVG []byte

// officialAvatar gives the official account the ModaHouse badge as its photo.
func (h *Handler) officialAvatar(u *models.User) {
	if u.AvatarURL != "" {
		return
	}
	if url, err := h.store.WriteFile("avatars", "modahouse-official.svg", officialAvatarSVG); err == nil {
		u.AvatarURL = url
		h.db.Model(u).UpdateColumn("avatar_url", url)
	}
}

// --- demo content ---

func (h *Handler) demoUserIDs() []uint {
	var ids []uint
	h.db.Model(&models.User{}).Where("username IN ? AND email LIKE ?", seed.DemoUsernames(), "%@modahouse.tm").Pluck("id", &ids)
	return ids
}

func (h *Handler) adminDemoCounts(c fiber.Ctx) error {
	ids := h.demoUserIDs()
	var pins int64
	if len(ids) > 0 {
		h.db.Model(&models.Pin{}).Where("user_id IN ?", ids).Count(&pins)
	}
	return c.JSON(fiber.Map{"users": len(ids), "pins": pins})
}

// adminRemoveDemo deletes the seed accounts with everything they made and turns the seeder off for good.
func (h *Handler) adminRemoveDemo(c fiber.Ctx) error {
	ids := h.demoUserIDs()
	for _, id := range ids {
		if id == viewerID(c) {
			return badRequest(c, "Siz özüňiz demo hasabyndan girdiňiz: ilki başga admin hasabyndan giriň")
		}
	}
	var pins []models.Pin
	if len(ids) > 0 {
		h.db.Where("user_id IN ?", ids).Find(&pins)
	}
	for _, p := range pins {
		if err := h.removePin(p); err != nil {
			return err
		}
	}
	if len(ids) > 0 {
		var stories []models.Story
		h.db.Where("user_id IN ?", ids).Find(&stories)
		var avatars []string
		h.db.Model(&models.User{}).Where("id IN ?", ids).Pluck("avatar_url", &avatars)
		err := h.db.Transaction(func(tx *gorm.DB) error {
			// Explicit cleanup keeps SQLite and Postgres consistent even without FK cascades.
			var chatIDs []uint
			tx.Model(&models.Chat{}).Where("user_a_id IN ? OR user_b_id IN ?", ids, ids).Pluck("id", &chatIDs)
			if len(chatIDs) > 0 {
				var files []string
				tx.Model(&models.Message{}).Where("chat_id IN ? AND file <> ''", chatIDs).Pluck("file", &files)
				for _, f := range files {
					h.store.RemovePrivate(storage.PrivateChat, f)
				}
				if err := tx.Where("chat_id IN ?", chatIDs).Delete(&models.Message{}).Error; err != nil {
					return err
				}
			}
			var storyIDs []uint
			tx.Model(&models.Story{}).Where("user_id IN ?", ids).Pluck("id", &storyIDs)
			if len(storyIDs) > 0 {
				if err := tx.Where("story_id IN ?", storyIDs).Delete(&models.StoryView{}).Error; err != nil {
					return err
				}
			}
			for _, q := range []struct {
				model any
				where string
			}{
				{&models.Message{}, "sender_id IN ?"},
				{&models.Chat{}, "user_a_id IN ? OR user_b_id IN ?"},
				{&models.Notification{}, "user_id IN ? OR actor_id IN ?"},
				{&models.Follow{}, "follower_id IN ? OR following_id IN ?"},
				{&models.Like{}, "user_id IN ?"},
				{&models.Comment{}, "user_id IN ?"},
				{&models.Review{}, "user_id IN ? OR business_id IN ?"},
				{&models.CartItem{}, "user_id IN ?"},
				{&models.StoryView{}, "user_id IN ?"},
				{&models.Story{}, "user_id IN ?"},
				{&models.Report{}, "user_id IN ?"},
				{&models.HiddenPin{}, "user_id IN ?"},
				{&models.Block{}, "blocker_id IN ? OR blocked_id IN ?"},
				{&models.Business{}, "user_id IN ?"},
			} {
				args := []any{ids}
				if strings.Count(q.where, "?") == 2 {
					args = append(args, ids)
				}
				if err := tx.Where(q.where, args...).Delete(q.model).Error; err != nil {
					return err
				}
			}
			var orderIDs []uint
			tx.Model(&models.Order{}).Where("buyer_id IN ? OR business_id IN ?", ids, ids).Pluck("id", &orderIDs)
			if len(orderIDs) > 0 {
				if err := tx.Where("order_id IN ?", orderIDs).Delete(&models.OrderItem{}).Error; err != nil {
					return err
				}
				if err := tx.Delete(&models.Order{}, orderIDs).Error; err != nil {
					return err
				}
			}
			var boardIDs []uint
			tx.Model(&models.Board{}).Where("user_id IN ?", ids).Pluck("id", &boardIDs)
			if len(boardIDs) > 0 {
				if err := tx.Where("board_id IN ?", boardIDs).Delete(&models.BoardPin{}).Error; err != nil {
					return err
				}
				if err := tx.Delete(&models.Board{}, boardIDs).Error; err != nil {
					return err
				}
			}
			return tx.Delete(&models.User{}, ids).Error
		})
		if err != nil {
			return err
		}
		for _, s := range stories {
			h.store.Remove(s.ImageURL)
			h.store.Remove(s.VideoURL)
		}
		for _, a := range avatars {
			h.store.Remove(a)
		}
	}
	h.db.Save(&models.Setting{Key: seed.DemoRemovedKey, Value: "true", UpdatedAt: time.Now()})
	return c.JSON(fiber.Map{"users": len(ids), "pins": len(pins)})
}
