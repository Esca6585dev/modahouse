package api_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/esca6585dev/modahouse/backend/internal/config"
)

// fakeCommons imitates the parts of the MediaWiki API the importer uses.
func fakeCommons(t *testing.T) *httptest.Server {
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/thumb/") {
			if r.Header.Get("User-Agent") == "" {
				http.Error(w, "no UA", 403)
				return
			}
			w.Header().Set("Content-Type", "image/png")
			_, _ = w.Write(testPNG(400, 600))
			return
		}
		q := r.URL.Query()
		meta := func(license, artist, object string) map[string]any {
			return map[string]any{
				"LicenseShortName": map[string]any{"value": license},
				"Artist":           map[string]any{"value": artist},
				"ObjectName":       map[string]any{"value": object},
				"ImageDescription": map[string]any{"value": "<p>Milli <b>köýnek</b></p>"},
			}
		}
		file := func(title, mime, license, artist, object string) map[string]any {
			slug := strings.ReplaceAll(strings.TrimPrefix(title, "File:"), " ", "_")
			return map[string]any{"title": title, "imageinfo": []any{map[string]any{
				"url": srv.URL + "/orig/" + slug, "thumburl": srv.URL + "/thumb/" + slug,
				"descriptionurl": "https://commons.example/wiki/" + slug, "mime": mime,
				"extmetadata": meta(license, artist, object),
			}}}
		}
		var out any
		switch {
		case q.Get("list") == "search":
			out = map[string]any{"query": map[string]any{"search": []any{
				map[string]any{"title": "Category:Turkmen dresses"}, map[string]any{"title": "Category:Turkmen jewellery"}}}}
		case q.Get("prop") == "categoryinfo":
			out = map[string]any{"query": map[string]any{"pages": []any{
				map[string]any{"title": "Category:Turkmen dresses", "categoryinfo": map[string]any{"files": 12}},
				map[string]any{"title": "Category:Turkmen jewellery", "categoryinfo": map[string]any{"files": 40}}}}}
		case q.Get("generator") == "search":
			// Three good photos per search page and one too small to use.
			base := strings.Fields(q.Get("gsrsearch"))[0] + "_" + q.Get("gsroffset")
			pages := []any{}
			for i, w := range []int{1200, 1600, 900, 200} {
				f := file("File:"+base+"_"+string(rune('a'+i))+".jpg", "image/jpeg", "CC BY 4.0", "Fotograf", "")
				f["imageinfo"].([]any)[0].(map[string]any)["width"] = w
				pages = append(pages, f)
			}
			out = map[string]any{"query": map[string]any{"pages": pages}}
		case q.Get("generator") == "categorymembers":
			if q.Get("gcmtitle") != "Category:Turkmen dresses" {
				out = map[string]any{"batchcomplete": true}
				break
			}
			out = map[string]any{"query": map[string]any{"pages": []any{
				file("File:Turkmen_dress_red.jpg", "image/jpeg", "CC BY-SA 4.0", `<a href="x">Aýna Ç.</a>`, ""),
				file("File:Keshde 2.jpg", "image/jpeg", "CC0", "Museum", "Keşde nagşy"),
				file("File:Shop poster.jpg", "image/jpeg", "CC BY-NC-SA 4.0", "X", ""),
				file("File:Map.svg", "image/svg+xml", "CC0", "X", ""),
			}}}
		default:
			http.Error(w, "bad request", 400)
			return
		}
		_ = json.NewEncoder(w).Encode(out)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestCommonsImport(t *testing.T) {
	commons := fakeCommons(t)
	e := newEnvWith(t, false, func(c *config.Config) {
		c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123"
		c.CommonsAPIURL = commons.URL + "/w/api.php"
	})
	admin := e.login("boss", "boss-pass-123")
	user := e.register("guly")

	var cats struct {
		Categories []struct {
			Title string `json:"title"`
			Files int    `json:"files"`
		} `json:"categories"`
	}
	e.expect(403, "GET", "/api/admin/import/commons/search?q=turkmen", user.Token, nil, nil)
	e.expect(200, "GET", "/api/admin/import/commons/search?q=turkmen", admin.Token, nil, &cats)
	if len(cats.Categories) != 2 || cats.Categories[0].Title != "Category:Turkmen jewellery" || cats.Categories[0].Files != 40 {
		t.Fatalf("search: %+v", cats)
	}

	type created struct {
		ID       uint   `json:"id"`
		Title    string `json:"title"`
		Credit   string `json:"credit"`
		Link     string `json:"link"`
		Category string `json:"category"`
		ImageURL string `json:"imageUrl"`
		Author   struct {
			Username string `json:"username"`
			Verified bool   `json:"verified"`
		} `json:"author"`
	}
	var res struct {
		Created []created `json:"created"`
		Skipped []struct {
			Title  string `json:"title"`
			Reason string `json:"reason"`
		} `json:"skipped"`
	}
	e.expect(400, "POST", "/api/admin/import/commons", admin.Token, map[string]any{"category": "Turkmen dresses", "appCategory": "nope"}, nil)
	e.expect(200, "POST", "/api/admin/import/commons", admin.Token, map[string]any{"category": "Turkmen dresses", "appCategory": "milli"}, &res)
	if len(res.Created) != 2 || len(res.Skipped) != 2 {
		t.Fatalf("import: %+v", res)
	}
	byTitle := map[string]created{}
	for _, p := range res.Created {
		byTitle[p.Title] = p
	}
	red, ok := byTitle["Turkmen dress red"]
	if !ok || red.Credit != "Surat: Aýna Ç. · CC BY-SA 4.0 · Wikimedia Commons" ||
		red.Link != "https://commons.example/wiki/Turkmen_dress_red.jpg" || red.Category != "milli" ||
		red.Author.Username != "modahouse" || !red.Author.Verified || !strings.HasSuffix(red.ImageURL, ".png") {
		t.Fatalf("imported post: %+v", res.Created)
	}
	if _, ok := byTitle["Keşde nagşy"]; !ok {
		t.Fatalf("object name as title: %+v", res.Created)
	}

	// Licensed photos download unchanged (no watermark).
	_, _, stored := e.raw("GET", red.ImageURL, "", nil, "")
	_, _, dl := e.raw("GET", "/api/pins/"+itoa(red.ID)+"/download", "", nil, "")
	if len(stored) == 0 || string(stored) != string(dl) {
		t.Fatal("credited photo was modified on download")
	}

	// Importing again skips everything already imported.
	e.expect(200, "POST", "/api/admin/import/commons", admin.Token, map[string]any{"category": "Category:Turkmen dresses", "appCategory": "milli"}, &res)
	if len(res.Created) != 0 {
		t.Fatalf("duplicates imported: %+v", res.Created)
	}

	// Nobody can log in as the official account.
	e.expect(401, "POST", "/api/auth/login", "", map[string]string{"login": "modahouse", "password": ""}, nil)

	// Unreachable Commons: a clear 502.
	bad := newEnvWith(t, false, func(c *config.Config) {
		c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123"
		c.CommonsAPIURL = "http://127.0.0.1:1/w/api.php"
	})
	tok := bad.login("boss", "boss-pass-123").Token
	bad.expect(502, "GET", "/api/admin/import/commons/search?q=x", tok, nil, nil)
}

func TestRemoveDemo(t *testing.T) {
	e := newEnvWith(t, true, func(c *config.Config) { c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123" })
	admin := e.login("boss", "boss-pass-123")
	real := e.register("guly")

	// A real user interacts with demo content.
	var pins page[pinResp]
	e.expect(200, "GET", "/api/pins?limit=1", "", nil, &pins)
	e.expect(200, "POST", "/api/pins/"+itoa(pins.Items[0].ID)+"/like", real.Token, nil, nil)
	var ch chatResp
	e.expect(201, "POST", "/api/chats", real.Token, map[string]string{"username": "gyzyl.guyze"}, &ch)
	e.expect(201, "POST", "/api/chats/"+itoa(ch.ID)+"/messages", real.Token, map[string]string{"text": "Salam"}, nil)
	var own pinResp
	e.expect(201, "POST", "/api/pins", real.Token, pinForm(t, map[string]string{"title": "Meniňki", "category": "milli"}, testPNG(300, 400)), &own)

	var counts struct{ Users, Pins int }
	e.expect(403, "GET", "/api/admin/demo", real.Token, nil, nil)
	e.expect(200, "GET", "/api/admin/demo", admin.Token, nil, &counts)
	if counts.Users < 30 || counts.Pins < 150 {
		t.Fatalf("demo counts: %+v", counts)
	}
	e.expect(200, "DELETE", "/api/admin/demo", admin.Token, nil, &counts)
	if counts.Users < 30 {
		t.Fatalf("removed: %+v", counts)
	}
	e.expect(200, "GET", "/api/admin/demo", admin.Token, nil, &counts)
	if counts.Users != 0 || counts.Pins != 0 {
		t.Fatalf("left over: %+v", counts)
	}
	e.expect(200, "GET", "/api/pins?limit=50", "", nil, &pins)
	if len(pins.Items) != 1 || pins.Items[0].ID != own.ID {
		t.Fatalf("only the real post should remain: %+v", pins.Items)
	}
	e.expect(404, "GET", "/api/users/gyzyl.guyze", "", nil, nil)
	var chats page[chatResp]
	e.expect(200, "GET", "/api/chats", real.Token, nil, &chats)
	if len(chats.Items) != 0 {
		t.Fatalf("chat with a removed account: %+v", chats.Items)
	}
	e.expect(200, "GET", "/api/me", real.Token, nil, nil)
}

func TestStarterPack(t *testing.T) {
	commons := fakeCommons(t)
	e := newEnvWith(t, false, func(c *config.Config) {
		c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123"
		c.CommonsAPIURL = commons.URL + "/w/api.php"
	})
	admin := e.login("boss", "boss-pass-123")
	user := e.register("guly")
	e.expect(403, "POST", "/api/admin/import/starter", user.Token, map[string]int{"total": 10}, nil)

	type status struct {
		Running bool   `json:"running"`
		Target  int    `json:"target"`
		Created int    `json:"created"`
		Skipped int    `json:"skipped"`
		Error   string `json:"error"`
	}
	var st status
	e.expect(202, "POST", "/api/admin/import/starter", admin.Token, map[string]int{"total": 10}, &st)
	if !st.Running || st.Target != 10 {
		t.Fatalf("start: %+v", st)
	}
	deadline := time.Now().Add(20 * time.Second)
	for st.Running && time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
		e.expect(200, "GET", "/api/admin/import/starter", admin.Token, nil, &st)
	}
	if st.Running || st.Created != 10 || st.Error != "" {
		t.Fatalf("finished: %+v", st)
	}
	var feed struct {
		Items []struct {
			Credit string   `json:"credit"`
			Tags   []string `json:"tags"`
		} `json:"items"`
	}
	e.expect(200, "GET", "/api/pins?author=modahouse&limit=50", "", nil, &feed)
	if len(feed.Items) != 10 || !strings.Contains(feed.Items[0].Credit, "CC BY 4.0") || len(feed.Items[0].Tags) == 0 {
		t.Fatalf("imported: %+v", feed.Items)
	}
}
