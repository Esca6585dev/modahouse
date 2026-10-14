package api_test

import (
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/esca6585dev/modahouse/backend/internal/config"
)

type appConfig struct {
	APIURL           string `json:"apiUrl"`
	WebURL           string `json:"webUrl"`
	RegistrationOpen bool   `json:"registrationOpen"`
	UpdatedAt        string `json:"updatedAt"`
}

func (e *env) login(login, password string) authResp {
	e.t.Helper()
	var a authResp
	e.expect(200, "POST", "/api/auth/login", "", map[string]string{"login": login, "password": password}, &a)
	return a
}

func TestAppConfigAndSettings(t *testing.T) {
	e := newEnvWith(t, false, func(c *config.Config) {
		c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123"
		c.PublicAPIURL = "https://api.example.tm/"
	})
	admin := e.login("boss", "boss-pass-123")
	user := e.register("guly")

	var cfg appConfig
	e.expect(200, "GET", "/api/config", "", nil, &cfg)
	if cfg.APIURL != "https://api.example.tm" || cfg.WebURL != "" || !cfg.RegistrationOpen || cfg.UpdatedAt != "" {
		t.Fatalf("default config: %+v", cfg)
	}

	var me struct {
		IsAdmin bool `json:"isAdmin"`
	}
	e.expect(200, "GET", "/api/me", admin.Token, nil, &me)
	if !me.IsAdmin {
		t.Fatal("admin flag missing on /me")
	}
	e.expect(200, "GET", "/api/me", user.Token, nil, &me)
	if me.IsAdmin {
		t.Fatal("regular user is admin")
	}

	// Admin endpoints are closed to guests and regular users.
	e.expect(401, "GET", "/api/admin/stats", "", nil, nil)
	e.expect(403, "GET", "/api/admin/stats", user.Token, nil, nil)
	e.expect(403, "PUT", "/api/admin/settings", user.Token, map[string]any{"apiUrl": "https://evil.example"}, nil)

	e.expect(400, "PUT", "/api/admin/settings", admin.Token, map[string]any{"apiUrl": "ftp://x"}, nil)
	e.expect(400, "PUT", "/api/admin/settings", admin.Token, map[string]any{"webUrl": "modahouse.tm"}, nil)
	e.expect(200, "PUT", "/api/admin/settings", admin.Token, map[string]any{
		"apiUrl": " https://new.example.tm/api/ ", "webUrl": "https://modahouse.tm/", "registrationOpen": false,
	}, &cfg)
	if cfg.APIURL != "https://new.example.tm" || cfg.WebURL != "https://modahouse.tm" || cfg.RegistrationOpen || cfg.UpdatedAt == "" {
		t.Fatalf("saved config: %+v", cfg)
	}
	e.expect(200, "GET", "/api/config", "", nil, &cfg)
	if cfg.APIURL != "https://new.example.tm" {
		t.Fatalf("public config not updated: %+v", cfg)
	}

	// Registration closed.
	e.expect(403, "POST", "/api/auth/register", "", map[string]string{
		"username": "late", "name": "Late", "email": "late@example.com", "password": "secret123"}, nil)

	// Partial update keeps the other values; "" clears back to the environment default.
	e.expect(200, "PUT", "/api/admin/settings", admin.Token, map[string]any{"apiUrl": "", "registrationOpen": true}, &cfg)
	if cfg.APIURL != "https://api.example.tm" || cfg.WebURL != "https://modahouse.tm" || !cfg.RegistrationOpen {
		t.Fatalf("partial update: %+v", cfg)
	}
	e.register("early")
}

func TestAdminCheckURL(t *testing.T) {
	e := newEnvWith(t, false, func(c *config.Config) { c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123" })
	admin := e.login("boss", "boss-pass-123")

	good := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/health" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	}))
	defer good.Close()
	bad := httptest.NewServer(http.NotFoundHandler())
	defer bad.Close()

	var res struct {
		OK     bool   `json:"ok"`
		Status int    `json:"status"`
		Error  string `json:"error"`
	}
	e.expect(200, "POST", "/api/admin/check-url", admin.Token, map[string]string{"url": good.URL + "/api"}, &res)
	if !res.OK || res.Status != 200 {
		t.Fatalf("good server: %+v", res)
	}
	e.expect(200, "POST", "/api/admin/check-url", admin.Token, map[string]string{"url": bad.URL}, &res)
	if res.OK || res.Status != 404 || res.Error == "" {
		t.Fatalf("bad server: %+v", res)
	}
	e.expect(400, "POST", "/api/admin/check-url", admin.Token, map[string]string{"url": "not a url"}, nil)
}

func TestAdminUsersAndModeration(t *testing.T) {
	e := newEnvWith(t, true, func(c *config.Config) { c.AdminUsername = "aylar.studio" }) // seeded user becomes admin
	admin := e.login("aylar.studio", "modahouse123")
	user := e.register("guly")
	other := e.register("jeren")

	var stats struct {
		Users, Admins, Pins, OpenReports int64
	}
	e.expect(200, "GET", "/api/admin/stats", admin.Token, nil, &stats)
	if stats.Users < 20 || stats.Admins != 1 || stats.Pins < 150 || stats.OpenReports != 0 {
		t.Fatalf("stats: %+v", stats)
	}

	type adminUser struct {
		ID        uint   `json:"id"`
		Username  string `json:"username"`
		IsAdmin   bool   `json:"isAdmin"`
		Verified  bool   `json:"verified"`
		Suspended bool   `json:"suspended"`
		PinsCount int64  `json:"pinsCount"`
	}
	var users page[adminUser]
	e.expect(200, "GET", "/api/admin/users?q=GUL", admin.Token, nil, &users)
	found := false
	for _, u := range users.Items {
		found = found || u.Username == "guly"
	}
	if !found {
		t.Fatalf("search: %+v", users.Items)
	}
	e.expect(200, "GET", "/api/admin/users?filter=admin", admin.Token, nil, &users)
	if len(users.Items) != 1 || users.Items[0].Username != "aylar.studio" || users.Items[0].PinsCount == 0 {
		t.Fatalf("admin filter: %+v", users.Items)
	}

	// An admin cannot demote or suspend themselves.
	e.expect(400, "PUT", "/api/admin/users/"+itoa(admin.User.ID), admin.Token, map[string]bool{"isAdmin": false}, nil)
	e.expect(400, "PUT", "/api/admin/users/"+itoa(admin.User.ID), admin.Token, map[string]bool{"suspended": true}, nil)

	// Promote, verify and suspend.
	var u adminUser
	e.expect(200, "PUT", "/api/admin/users/"+itoa(other.User.ID), admin.Token, map[string]bool{"isAdmin": true, "verified": true}, &u)
	if !u.IsAdmin || !u.Verified {
		t.Fatalf("promote: %+v", u)
	}
	e.expect(200, "GET", "/api/admin/stats", other.Token, nil, nil)

	e.expect(200, "PUT", "/api/admin/users/"+itoa(user.User.ID), admin.Token, map[string]bool{"suspended": true}, &u)
	if !u.Suspended {
		t.Fatalf("suspend: %+v", u)
	}
	e.expect(401, "GET", "/api/me", user.Token, nil, nil)
	e.expect(403, "POST", "/api/auth/login", "", map[string]string{"login": "guly", "password": "secret123"}, nil)
	e.expect(200, "PUT", "/api/admin/users/"+itoa(user.User.ID), admin.Token, map[string]bool{"suspended": false}, nil)
	user = e.login("guly", "secret123")

	// Reports: two users report the same pin, the admin sees one grouped row.
	var pins page[pinResp]
	e.expect(200, "GET", "/api/pins?limit=2", "", nil, &pins)
	target, spare := pins.Items[0], pins.Items[1]
	e.expect(204, "POST", "/api/pins/"+itoa(target.ID)+"/report", user.Token, map[string]string{"reason": "spam"}, nil)
	e.expect(204, "POST", "/api/pins/"+itoa(target.ID)+"/report", other.Token, map[string]string{"reason": "fake", "note": "Galp"}, nil)
	e.expect(204, "POST", "/api/pins/"+itoa(spare.ID)+"/report", user.Token, map[string]string{"reason": "other"}, nil)

	var reports page[struct {
		Pin struct {
			ID uint `json:"id"`
		} `json:"pin"`
		Count    int      `json:"count"`
		Reasons  []string `json:"reasons"`
		LastNote string   `json:"lastNote"`
	}]
	e.expect(200, "GET", "/api/admin/reports", admin.Token, nil, &reports)
	if len(reports.Items) != 2 || reports.Items[0].Pin.ID != spare.ID {
		t.Fatalf("reports order: %+v", reports.Items)
	}
	r := reports.Items[1]
	if r.Pin.ID != target.ID || r.Count != 2 || len(r.Reasons) != 2 || r.LastNote != "Galp" {
		t.Fatalf("grouped report: %+v", r)
	}

	e.expect(204, "DELETE", "/api/admin/reports/"+itoa(spare.ID), admin.Token, nil, nil)
	e.expect(204, "DELETE", "/api/admin/pins/"+itoa(target.ID), admin.Token, nil, nil)
	e.expect(404, "GET", "/api/pins/"+itoa(target.ID), "", nil, nil)
	e.expect(200, "GET", "/api/pins/"+itoa(spare.ID), "", nil, nil)
	e.expect(200, "GET", "/api/admin/reports", admin.Token, nil, &reports)
	if len(reports.Items) != 0 {
		t.Fatalf("reports left: %+v", reports.Items)
	}
	e.expect(404, "DELETE", "/api/admin/pins/"+itoa(target.ID), admin.Token, nil, nil)
}

func itoa(id uint) string { return strconv.FormatUint(uint64(id), 10) }
