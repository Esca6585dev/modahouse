package api

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// Setting keys stored in the settings table.
const (
	settingAPIURL       = "api_url"
	settingWebURL       = "web_url"
	settingRegistration = "registration_open"
	settingWatermark    = "watermark_uploads"
)

// AppConfig is the public client configuration (GET /api/config).
type AppConfig struct {
	APIURL           string `json:"apiUrl"`
	WebURL           string `json:"webUrl"`
	RegistrationOpen bool   `json:"registrationOpen"`
	WatermarkUploads bool   `json:"watermarkUploads"`
	UpdatedAt        string `json:"updatedAt"`
}

// normalizeOrigin validates an absolute http(s) address and returns it without a
// trailing slash or a trailing /api. ok is false for anything else.
func normalizeOrigin(raw string) (string, bool) {
	s := strings.TrimSpace(raw)
	s = strings.TrimRight(s, "/")
	s = strings.TrimSuffix(s, "/api")
	s = strings.TrimRight(s, "/")
	u, err := url.Parse(s)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" ||
		u.User != nil || u.RawQuery != "" || u.Fragment != "" || len(s) > 255 {
		return "", false
	}
	return s, true
}

func (h *Handler) appConfig() AppConfig {
	cfg := AppConfig{RegistrationOpen: true, WatermarkUploads: true}
	cfg.APIURL, _ = normalizeOrigin(h.cfg.PublicAPIURL)
	cfg.WebURL, _ = normalizeOrigin(h.cfg.PublicWebURL)
	var rows []models.Setting
	h.db.Find(&rows)
	var latest time.Time
	for _, r := range rows {
		switch r.Key {
		case settingAPIURL:
			cfg.APIURL = r.Value
		case settingWebURL:
			cfg.WebURL = r.Value
		case settingRegistration:
			cfg.RegistrationOpen = r.Value != "false"
		case settingWatermark:
			cfg.WatermarkUploads = r.Value != "false"
		}
		if r.UpdatedAt.After(latest) {
			latest = r.UpdatedAt
		}
	}
	if !latest.IsZero() {
		cfg.UpdatedAt = latest.UTC().Format(time.RFC3339)
	}
	return cfg
}

func (h *Handler) getConfig(c fiber.Ctx) error {
	c.Set(fiber.HeaderCacheControl, "no-store")
	return c.JSON(h.appConfig())
}

// requireAdmin lets only signed-in administrators through.
func (h *Handler) requireAdmin(c fiber.Ctx) error {
	id := viewerID(c)
	if id == 0 {
		return fail(c, fiber.StatusUnauthorized, "Ilki ulgama giriň")
	}
	var u models.User
	if h.db.Select("id", "is_admin").First(&u, id).Error != nil || !u.IsAdmin {
		return fail(c, fiber.StatusForbidden, "Bu bölüm diňe administratorlar üçin")
	}
	return c.Next()
}

func (h *Handler) adminGetSettings(c fiber.Ctx) error {
	return c.JSON(h.appConfig())
}

type settingsReq struct {
	APIURL           *string `json:"apiUrl"`
	WebURL           *string `json:"webUrl"`
	RegistrationOpen *bool   `json:"registrationOpen"`
	WatermarkUploads *bool   `json:"watermarkUploads"`
}

func (h *Handler) adminUpdateSettings(c fiber.Ctx) error {
	var req settingsReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	// nil value = delete the row (fall back to the environment default).
	updates := map[string]*string{}
	for key, raw := range map[string]*string{settingAPIURL: req.APIURL, settingWebURL: req.WebURL} {
		if raw == nil {
			continue
		}
		if strings.TrimSpace(*raw) == "" {
			updates[key] = nil
			continue
		}
		v, ok := normalizeOrigin(*raw)
		if !ok {
			return badRequest(c, "Salga nädogry: http:// ýa-da https:// bilen başlamaly, meselem https://api.modahouse.tm")
		}
		updates[key] = &v
	}
	for key, b := range map[string]*bool{settingRegistration: req.RegistrationOpen, settingWatermark: req.WatermarkUploads} {
		if b != nil {
			v := fmt.Sprint(*b)
			updates[key] = &v
		}
	}
	err := h.db.Transaction(func(tx *gorm.DB) error {
		for key, v := range updates {
			if v == nil {
				if err := tx.Delete(&models.Setting{}, "key = ?", key).Error; err != nil {
					return err
				}
				continue
			}
			row := models.Setting{Key: key, Value: *v, UpdatedAt: time.Now()}
			if err := tx.Clauses(clause.OnConflict{
				Columns:   []clause.Column{{Name: "key"}},
				DoUpdates: clause.AssignmentColumns([]string{"value", "updated_at"}),
			}).Create(&row).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	return c.JSON(h.appConfig())
}

// adminCheckURL tells whether {url}/api/health answers like a ModaHouse server.
func (h *Handler) adminCheckURL(c fiber.Ctx) error {
	var req struct {
		URL string `json:"url"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	base, ok := normalizeOrigin(req.URL)
	if !ok {
		return badRequest(c, "Salga nädogry: http:// ýa-da https:// bilen başlamaly, meselem https://api.modahouse.tm")
	}
	client := &http.Client{
		Timeout:       5 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	resp, err := client.Get(base + "/api/health")
	if err != nil {
		return c.JSON(fiber.Map{"ok": false, "status": 0, "error": "Serwere birigip bolmady"})
	}
	defer resp.Body.Close()
	var body struct {
		Status string `json:"status"`
	}
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode == http.StatusOK && json.Unmarshal(data, &body) == nil && body.Status == "ok" {
		return c.JSON(fiber.Map{"ok": true, "status": resp.StatusCode, "error": ""})
	}
	return c.JSON(fiber.Map{"ok": false, "status": resp.StatusCode,
		"error": fmt.Sprintf("Bu salgy ModaHouse serweri ýaly jogap bermedi (HTTP %d)", resp.StatusCode)})
}

type AdminStats struct {
	Users       int64 `json:"users"`
	Businesses  int64 `json:"businesses"`
	Admins      int64 `json:"admins"`
	Suspended   int64 `json:"suspended"`
	Pins        int64 `json:"pins"`
	Products    int64 `json:"products"`
	Videos      int64 `json:"videos"`
	Comments    int64 `json:"comments"`
	Orders      int64 `json:"orders"`
	OpenReports int64 `json:"openReports"`
	NewUsers7d  int64 `json:"newUsers7d"`
	NewPins7d   int64 `json:"newPins7d"`
}

func (h *Handler) adminStats(c fiber.Ctx) error {
	var s AdminStats
	week := time.Now().Add(-7 * 24 * time.Hour)
	users := func() *gorm.DB { return h.db.Model(&models.User{}) }
	pins := func() *gorm.DB { return h.db.Model(&models.Pin{}) }
	users().Count(&s.Users)
	users().Where("is_business = ?", true).Count(&s.Businesses)
	users().Where("is_admin = ?", true).Count(&s.Admins)
	users().Where("suspended = ?", true).Count(&s.Suspended)
	users().Where("created_at >= ?", week).Count(&s.NewUsers7d)
	pins().Count(&s.Pins)
	pins().Where("listing_type IN ? OR (listing_type = '' AND price > 0)", []string{"sale", "rent", "custom"}).Count(&s.Products)
	pins().Where("has_video = ?", true).Count(&s.Videos)
	pins().Where("created_at >= ?", week).Count(&s.NewPins7d)
	h.db.Model(&models.Comment{}).Count(&s.Comments)
	h.db.Model(&models.Order{}).Count(&s.Orders)
	h.db.Model(&models.Report{}).Distinct("pin_id").Count(&s.OpenReports)
	return c.JSON(s)
}

type AdminUser struct {
	ID         uint      `json:"id"`
	Username   string    `json:"username"`
	Name       string    `json:"name"`
	Email      string    `json:"email"`
	AvatarURL  string    `json:"avatarUrl"`
	IsAdmin    bool      `json:"isAdmin"`
	IsBusiness bool      `json:"isBusiness"`
	Verified   bool      `json:"verified"`
	Suspended  bool      `json:"suspended"`
	PinsCount  int64     `json:"pinsCount"`
	CreatedAt  time.Time `json:"createdAt"`
}

func (h *Handler) adminUsers(rows []models.User) []AdminUser {
	ids := make([]uint, len(rows))
	for i, u := range rows {
		ids[i] = u.ID
	}
	counts := map[uint]int64{}
	if len(ids) > 0 {
		var cs []struct {
			UserID uint
			N      int64
		}
		h.db.Model(&models.Pin{}).Select("user_id, COUNT(*) AS n").Where("user_id IN ?", ids).Group("user_id").Scan(&cs)
		for _, x := range cs {
			counts[x.UserID] = x.N
		}
	}
	out := make([]AdminUser, len(rows))
	for i, u := range rows {
		out[i] = AdminUser{ID: u.ID, Username: u.Username, Name: u.Name, Email: u.Email, AvatarURL: u.AvatarURL,
			IsAdmin: u.IsAdmin, IsBusiness: u.IsBusiness, Verified: u.Verified, Suspended: u.Suspended,
			PinsCount: counts[u.ID], CreatedAt: u.CreatedAt}
	}
	return out
}

func (h *Handler) adminListUsers(c fiber.Ctx) error {
	page, limit, offset := paging(c, 20)
	q := h.db.Model(&models.User{})
	if s := strings.ToLower(strings.TrimSpace(c.Query("q"))); s != "" {
		like := "%" + strings.NewReplacer("%", "", "_", "").Replace(s) + "%"
		q = q.Where("LOWER(username) LIKE ? OR LOWER(name) LIKE ? OR LOWER(email) LIKE ?", like, like, like)
	}
	switch c.Query("filter") {
	case "admin":
		q = q.Where("is_admin = ?", true)
	case "business":
		q = q.Where("is_business = ?", true)
	case "suspended":
		q = q.Where("suspended = ?", true)
	}
	var rows []models.User
	if err := q.Order("id DESC").Limit(limit + 1).Offset(offset).Find(&rows).Error; err != nil {
		return err
	}
	rows, more := trimPage(rows, limit)
	return c.JSON(Page[AdminUser]{Items: h.adminUsers(rows), Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) adminUpdateUser(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var req struct {
		IsAdmin   *bool `json:"isAdmin"`
		Verified  *bool `json:"verified"`
		Suspended *bool `json:"suspended"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if id == viewerID(c) && ((req.IsAdmin != nil && !*req.IsAdmin) || (req.Suspended != nil && *req.Suspended)) {
		return badRequest(c, "Özüňizden admin hukugyny aýryp ýa-da özüňizi petikläp bilmersiňiz")
	}
	var u models.User
	if err := h.db.First(&u, id).Error; err != nil {
		return notFound(c)
	}
	changes := map[string]any{}
	if req.IsAdmin != nil {
		changes["is_admin"] = *req.IsAdmin
	}
	if req.Verified != nil {
		changes["verified"] = *req.Verified
	}
	if req.Suspended != nil {
		changes["suspended"] = *req.Suspended
		if *req.Suspended && !u.Suspended {
			changes["tokens_valid_after"] = time.Now() // end every session
		}
	}
	if len(changes) > 0 {
		if err := h.db.Model(&u).Updates(changes).Error; err != nil {
			return err
		}
		h.db.First(&u, id)
	}
	return c.JSON(h.adminUsers([]models.User{u})[0])
}

type AdminReport struct {
	Pin struct {
		ID       uint      `json:"id"`
		Title    string    `json:"title"`
		ImageURL string    `json:"imageUrl"`
		Author   UserBrief `json:"author"`
	} `json:"pin"`
	Count          int64     `json:"count"`
	Reasons        []string  `json:"reasons"`
	LastNote       string    `json:"lastNote"`
	LastReportedAt time.Time `json:"lastReportedAt"`
}

func (h *Handler) adminReports(c fiber.Ctx) error {
	page, limit, offset := paging(c, 20)
	var groups []struct {
		PinID  uint
		N      int64
		LastID uint
	}
	if err := h.db.Model(&models.Report{}).Select("pin_id, COUNT(*) AS n, MAX(id) AS last_id").
		Group("pin_id").Order("last_id DESC").Limit(limit + 1).Offset(offset).Scan(&groups).Error; err != nil {
		return err
	}
	groups, more := trimPage(groups, limit)
	ids := make([]uint, len(groups))
	for i, g := range groups {
		ids[i] = g.PinID
	}
	pins := map[uint]models.Pin{}
	byPin := map[uint][]models.Report{}
	if len(ids) > 0 {
		var ps []models.Pin
		h.db.Preload("User").Where("id IN ?", ids).Find(&ps)
		for _, p := range ps {
			pins[p.ID] = p
		}
		var rs []models.Report
		h.db.Where("pin_id IN ?", ids).Order("id DESC").Find(&rs)
		for _, r := range rs {
			byPin[r.PinID] = append(byPin[r.PinID], r)
		}
	}
	items := make([]AdminReport, 0, len(groups))
	for _, g := range groups {
		p, ok := pins[g.PinID]
		if !ok {
			continue
		}
		var it AdminReport
		it.Pin.ID, it.Pin.Title, it.Pin.ImageURL, it.Pin.Author = p.ID, p.Title, p.ImageURL, brief(p.User)
		it.Count = g.N
		it.Reasons = []string{}
		seen := map[string]bool{}
		for i, r := range byPin[g.PinID] { // newest first
			if i == 0 {
				it.LastReportedAt = r.CreatedAt
			}
			if !seen[r.Reason] {
				seen[r.Reason] = true
				it.Reasons = append(it.Reasons, r.Reason)
			}
			if it.LastNote == "" && r.Note != "" {
				it.LastNote = r.Note
			}
		}
		items = append(items, it)
	}
	return c.JSON(Page[AdminReport]{Items: items, Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) adminDismissReports(c fiber.Ctx) error {
	id, ok := idParam(c, "pinId")
	if !ok {
		return notFound(c)
	}
	if err := h.db.Where("pin_id = ?", id).Delete(&models.Report{}).Error; err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) adminDeletePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var p models.Pin
	if err := h.db.First(&p, id).Error; err != nil {
		return notFound(c)
	}
	if err := h.removePin(p); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// EnsureAdmin makes cfg.AdminUsername an administrator. The user is created when
// missing and cfg.AdminPassword is set; an existing password is never changed.
func EnsureAdmin(db *gorm.DB, cfg config.Config) error {
	name := cfg.AdminUsername
	if name == "" {
		return nil
	}
	if !usernameRe.MatchString(name) {
		return fmt.Errorf("ADMIN_USERNAME %q is not a valid username", name)
	}
	var u models.User
	err := db.Where("username = ?", name).First(&u).Error
	if err == nil {
		return db.Model(&u).Updates(map[string]any{"is_admin": true, "suspended": false}).Error
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	if len(cfg.AdminPassword) < 8 || len(cfg.AdminPassword) > 72 {
		log.Printf("WARNING: admin %q does not exist; set ADMIN_PASSWORD (8-72 characters) to create it", name)
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(cfg.AdminPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	u = models.User{Username: name, Name: "Administrator", Email: name + "@modahouse.local",
		PasswordHash: string(hash), IsAdmin: true}
	if err := db.Create(&u).Error; err != nil {
		return err
	}
	log.Printf("created admin user %q", name)
	return db.Create(&models.Board{UserID: u.ID, Name: DefaultBoardName}).Error
}
