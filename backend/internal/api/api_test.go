package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/api"
	"github.com/esca6585dev/modahouse/backend/internal/config"
	"github.com/esca6585dev/modahouse/backend/internal/database"
	"github.com/esca6585dev/modahouse/backend/internal/seed"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

type env struct {
	t   *testing.T
	app *fiber.App
	dir string // upload dir
}

func newEnv(t *testing.T, withSeed bool) *env {
	t.Helper()
	// Tests use a fresh SQLite file by default. Set TEST_POSTGRES_URL to run them
	// against PostgreSQL instead (the public schema is wiped before each test).
	driver, dsn := "sqlite", filepath.Join(t.TempDir(), "test.db")
	if pg := os.Getenv("TEST_POSTGRES_URL"); pg != "" {
		driver, dsn = "postgres", pg
		raw, err := database.Open("postgres", pg)
		if err != nil {
			t.Fatal(err)
		}
		raw.Exec("DROP SCHEMA public CASCADE")
		raw.Exec("CREATE SCHEMA public")
		if sqlDB, err := raw.DB(); err == nil {
			sqlDB.Close()
		}
	}
	db, err := database.Open(driver, dsn)
	if err != nil {
		t.Fatal(err)
	}
	if sqlDB, err := db.DB(); err == nil {
		t.Cleanup(func() { sqlDB.Close() })
	}
	store, err := storage.New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if withSeed {
		if err := seed.Run(db, store); err != nil {
			t.Fatal(err)
		}
	}
	cfg := config.Config{JWTSecret: "test", UploadDir: store.Dir, CORSOrigins: []string{"*"}, MaxUploadMB: 5, TokenTTLDays: 1}
	return &env{t: t, app: api.New(db, store, cfg, api.Options{Quiet: true}), dir: store.Dir}
}

// do sends a request and decodes the JSON response into out (if non-nil). It returns the status code.
func (e *env) do(method, path, token string, body any, out any) int {
	e.t.Helper()
	var r io.Reader
	ct := ""
	switch b := body.(type) {
	case nil:
	case *multipartBody:
		r, ct = &b.buf, b.contentType
	default:
		raw, _ := json.Marshal(b)
		r, ct = bytes.NewReader(raw), "application/json"
	}
	req := httptest.NewRequest(method, path, r)
	if ct != "" {
		req.Header.Set("Content-Type", ct)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := e.app.Test(req)
	if err != nil {
		e.t.Fatal(err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if out != nil && len(data) > 0 {
		if err := json.Unmarshal(data, out); err != nil {
			e.t.Fatalf("%s %s: decode %q: %v", method, path, data, err)
		}
	}
	return resp.StatusCode
}

func (e *env) expect(want int, method, path, token string, body, out any) {
	e.t.Helper()
	if got := e.do(method, path, token, body, out); got != want {
		e.t.Fatalf("%s %s: status %d, want %d", method, path, got, want)
	}
}

type multipartBody struct {
	buf         bytes.Buffer
	contentType string
}

func pinForm(t *testing.T, fields map[string]string, img []byte) *multipartBody {
	t.Helper()
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	for k, v := range fields {
		_ = w.WriteField(k, v)
	}
	if img != nil {
		fw, _ := w.CreateFormFile("image", "photo.png")
		_, _ = fw.Write(img)
	}
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	return m
}

func testPNG(w, h int) []byte {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{200, 50, 100, 255})
		}
	}
	var b bytes.Buffer
	_ = png.Encode(&b, img)
	return b.Bytes()
}

type authResp struct {
	Token string `json:"token"`
	User  struct {
		ID       uint   `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
}

type pinResp struct {
	ID            uint   `json:"id"`
	Title         string `json:"title"`
	ImageURL      string `json:"imageUrl"`
	Width         int    `json:"width"`
	Height        int    `json:"height"`
	Liked         bool   `json:"liked"`
	LikesCount    int    `json:"likesCount"`
	SavedBoardIDs []uint `json:"savedBoardIds"`
	Category      string `json:"category"`
}

type page[T any] struct {
	Items   []T  `json:"items"`
	HasMore bool `json:"hasMore"`
}

func (e *env) register(username string) authResp {
	e.t.Helper()
	var a authResp
	e.expect(201, "POST", "/api/auth/register", "", map[string]string{
		"username": username, "name": "Test " + username, "email": username + "@example.com", "password": "secret123",
	}, &a)
	return a
}

func TestAuthFlow(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("merdan")
	if a.Token == "" || a.User.Username != "merdan" {
		t.Fatalf("bad auth response %+v", a)
	}

	e.expect(409, "POST", "/api/auth/register", "", map[string]string{"username": "merdan", "name": "X", "email": "other@example.com", "password": "secret123"}, nil)
	e.expect(400, "POST", "/api/auth/register", "", map[string]string{"username": "Bad Name!", "name": "X", "email": "x@example.com", "password": "secret123"}, nil)
	e.expect(400, "POST", "/api/auth/register", "", map[string]string{"username": "short", "name": "X", "email": "x@example.com", "password": "123"}, nil)

	var login authResp
	e.expect(200, "POST", "/api/auth/login", "", map[string]string{"login": "MERDAN@example.com", "password": "secret123"}, &login)
	e.expect(401, "POST", "/api/auth/login", "", map[string]string{"login": "merdan", "password": "wrong"}, nil)

	e.expect(200, "GET", "/api/auth/me", login.Token, nil, nil)
	e.expect(401, "GET", "/api/auth/me", "", nil, nil)
	e.expect(401, "GET", "/api/auth/me", "not-a-token", nil, nil)

	var boards []struct{ Name string }
	e.expect(200, "GET", "/api/me/boards", login.Token, nil, &boards)
	if len(boards) != 1 || boards[0].Name != api.DefaultBoardName {
		t.Fatalf("expected default board, got %+v", boards)
	}

	e.expect(400, "PUT", "/api/me/password", login.Token, map[string]string{"currentPassword": "nope", "newPassword": "newsecret"}, nil)
	e.expect(204, "PUT", "/api/me/password", login.Token, map[string]string{"currentPassword": "secret123", "newPassword": "newsecret"}, nil)
	e.expect(200, "POST", "/api/auth/login", "", map[string]string{"login": "merdan", "password": "newsecret"}, nil)
}

func TestPinLifecycle(t *testing.T) {
	e := newEnv(t, false)
	owner := e.register("owner")
	other := e.register("other")

	// Validation: missing image, missing title, bad category, non-image file.
	e.expect(400, "POST", "/api/pins", owner.Token, pinForm(t, map[string]string{"title": "A", "category": "moda"}, nil), nil)
	e.expect(400, "POST", "/api/pins", owner.Token, pinForm(t, map[string]string{"category": "moda"}, testPNG(4, 4)), nil)
	e.expect(400, "POST", "/api/pins", owner.Token, pinForm(t, map[string]string{"title": "A", "category": "nope"}, testPNG(4, 4)), nil)
	e.expect(400, "POST", "/api/pins", owner.Token, pinForm(t, map[string]string{"title": "A", "category": "moda"}, []byte("<svg onload=alert(1)>")), nil)
	e.expect(401, "POST", "/api/pins", "", pinForm(t, map[string]string{"title": "A", "category": "moda"}, testPNG(4, 4)), nil)

	var pin pinResp
	e.expect(201, "POST", "/api/pins", owner.Token, pinForm(t, map[string]string{
		"title": "Täze köýnek", "category": "moda", "description": "Gyzyl", "tags": "#Ýaz, köýnek, ýaz", "link": "https://example.com",
	}, testPNG(40, 60)), &pin)
	if pin.Width != 40 || pin.Height != 60 || pin.ImageURL == "" {
		t.Fatalf("bad pin %+v", pin)
	}
	e.expect(200, "GET", pin.ImageURL, "", nil, nil)

	// Search is case-insensitive for Turkmen letters.
	var res page[pinResp]
	e.expect(200, "GET", "/api/pins?q=K%C3%96%C3%9DNEK", "", nil, &res)
	if len(res.Items) != 1 || res.Items[0].ID != pin.ID {
		t.Fatalf("search failed: %+v", res.Items)
	}
	e.expect(200, "GET", "/api/pins?category=tagamlar", "", nil, &res)
	if len(res.Items) != 0 {
		t.Fatalf("category filter failed: %+v", res.Items)
	}

	// Only the owner can edit or delete.
	e.expect(403, "PUT", fmt.Sprintf("/api/pins/%d", pin.ID), other.Token, map[string]string{"title": "hack"}, nil)
	e.expect(403, "DELETE", fmt.Sprintf("/api/pins/%d", pin.ID), other.Token, nil, nil)
	var updated pinResp
	e.expect(200, "PUT", fmt.Sprintf("/api/pins/%d", pin.ID), owner.Token, map[string]string{"title": "Gyzyl köýnek", "category": "moda"}, &updated)
	if updated.Title != "Gyzyl köýnek" {
		t.Fatalf("update failed: %+v", updated)
	}
	e.expect(400, "PUT", fmt.Sprintf("/api/pins/%d", pin.ID), owner.Token, map[string]string{"link": "javascript:alert(1)"}, nil)

	// Like, comment, save from another account; owner gets notifications.
	var like struct {
		Liked      bool `json:"liked"`
		LikesCount int  `json:"likesCount"`
	}
	e.expect(200, "POST", fmt.Sprintf("/api/pins/%d/like", pin.ID), other.Token, nil, &like)
	e.expect(200, "POST", fmt.Sprintf("/api/pins/%d/like", pin.ID), other.Token, nil, &like) // idempotent
	if !like.Liked || like.LikesCount != 1 {
		t.Fatalf("like failed: %+v", like)
	}

	var cm struct {
		ID        uint `json:"id"`
		CanDelete bool `json:"canDelete"`
	}
	e.expect(400, "POST", fmt.Sprintf("/api/pins/%d/comments", pin.ID), other.Token, map[string]string{"text": "   "}, nil)
	e.expect(201, "POST", fmt.Sprintf("/api/pins/%d/comments", pin.ID), other.Token, map[string]string{"text": "Gowy!"}, &cm)
	if !cm.CanDelete {
		t.Fatal("comment author should be able to delete")
	}

	var boards []struct {
		ID uint `json:"id"`
	}
	e.expect(200, "GET", "/api/me/boards", other.Token, nil, &boards)
	var saved pinResp
	e.expect(200, "POST", fmt.Sprintf("/api/boards/%d/pins/%d", boards[0].ID, pin.ID), other.Token, nil, &saved)
	if len(saved.SavedBoardIDs) != 1 {
		t.Fatalf("save failed: %+v", saved)
	}
	// Owner can't save into someone else's board.
	e.expect(403, "POST", fmt.Sprintf("/api/boards/%d/pins/%d", boards[0].ID, pin.ID), owner.Token, nil, nil)

	var unread struct{ Count int }
	e.expect(200, "GET", "/api/notifications/unread-count", owner.Token, nil, &unread)
	if unread.Count != 3 { // like + comment + save
		t.Fatalf("want 3 notifications, got %d", unread.Count)
	}
	e.expect(204, "POST", "/api/notifications/read-all", owner.Token, nil, nil)
	e.expect(200, "GET", "/api/notifications/unread-count", owner.Token, nil, &unread)
	if unread.Count != 0 {
		t.Fatalf("read-all failed: %d", unread.Count)
	}

	// Viewer-specific fields.
	var view pinResp
	e.expect(200, "GET", fmt.Sprintf("/api/pins/%d", pin.ID), other.Token, nil, &view)
	if !view.Liked || view.LikesCount != 1 || len(view.SavedBoardIDs) != 1 {
		t.Fatalf("viewer state wrong: %+v", view)
	}
	e.expect(200, "GET", fmt.Sprintf("/api/pins/%d", pin.ID), "", nil, &view)
	if view.Liked || len(view.SavedBoardIDs) != 0 {
		t.Fatalf("guest should see no viewer state: %+v", view)
	}

	// Pin owner may delete the comment; then delete the pin and everything attached.
	e.expect(204, "DELETE", fmt.Sprintf("/api/comments/%d", cm.ID), owner.Token, nil, nil)
	e.expect(204, "DELETE", fmt.Sprintf("/api/pins/%d", pin.ID), owner.Token, nil, nil)
	e.expect(404, "GET", fmt.Sprintf("/api/pins/%d", pin.ID), "", nil, nil)
	if _, err := os.Stat(filepath.Join(e.dir, strings.TrimPrefix(pin.ImageURL, "/uploads/"))); !os.IsNotExist(err) {
		t.Fatalf("image file not removed: %v", err)
	}
	var bp page[pinResp]
	e.expect(200, "GET", fmt.Sprintf("/api/boards/%d/pins", boards[0].ID), other.Token, nil, &bp)
	if len(bp.Items) != 0 {
		t.Fatal("deleted pin still on board")
	}
}

func TestBoardsAndPrivacy(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("alpha")
	b := e.register("beta")

	var board struct {
		ID        uint `json:"id"`
		IsPrivate bool `json:"isPrivate"`
	}
	e.expect(400, "POST", "/api/boards", a.Token, map[string]any{"name": " "}, nil)
	e.expect(201, "POST", "/api/boards", a.Token, map[string]any{"name": "Gizlin", "isPrivate": true}, &board)

	e.expect(404, "GET", fmt.Sprintf("/api/boards/%d", board.ID), b.Token, nil, nil)
	e.expect(404, "GET", fmt.Sprintf("/api/boards/%d", board.ID), "", nil, nil)
	e.expect(200, "GET", fmt.Sprintf("/api/boards/%d", board.ID), a.Token, nil, nil)

	var list []struct{ ID uint }
	e.expect(200, "GET", "/api/users/alpha/boards", b.Token, nil, &list)
	if len(list) != 1 { // only the public default board
		t.Fatalf("private board leaked: %+v", list)
	}
	e.expect(200, "GET", "/api/users/alpha/boards", a.Token, nil, &list)
	if len(list) != 2 {
		t.Fatalf("owner should see both boards: %+v", list)
	}

	e.expect(403, "PUT", fmt.Sprintf("/api/boards/%d", board.ID), b.Token, map[string]any{"name": "x"}, nil)
	e.expect(200, "PUT", fmt.Sprintf("/api/boards/%d", board.ID), a.Token, map[string]any{"isPrivate": false}, &board)
	if board.IsPrivate {
		t.Fatal("board should be public now")
	}
	e.expect(403, "DELETE", fmt.Sprintf("/api/boards/%d", board.ID), b.Token, nil, nil)
	e.expect(204, "DELETE", fmt.Sprintf("/api/boards/%d", board.ID), a.Token, nil, nil)
	e.expect(404, "GET", fmt.Sprintf("/api/boards/%d", board.ID), a.Token, nil, nil)
}

func TestFollowAndFeed(t *testing.T) {
	e := newEnv(t, true)
	me := e.register("newbie")

	var prof struct {
		IsFollowing    bool `json:"isFollowing"`
		FollowersCount int  `json:"followersCount"`
	}
	e.expect(400, "POST", "/api/users/newbie/follow", me.Token, nil, nil)
	e.expect(404, "POST", "/api/users/nobody/follow", me.Token, nil, nil)
	e.expect(200, "POST", "/api/users/gezelenc/follow", me.Token, nil, &prof)
	if !prof.IsFollowing {
		t.Fatal("follow failed")
	}

	e.expect(401, "GET", "/api/pins?feed=following", "", nil, nil)
	var feed page[pinResp]
	e.expect(200, "GET", "/api/pins?feed=following&limit=50", me.Token, nil, &feed)
	if len(feed.Items) == 0 {
		t.Fatal("following feed empty")
	}
	for _, p := range feed.Items {
		if p.Category != "syyahat" {
			t.Fatalf("unexpected pin in following feed: %+v", p)
		}
	}

	var followers page[struct{ Username string }]
	e.expect(200, "GET", "/api/users/gezelenc/followers", "", nil, &followers)
	found := false
	for _, u := range followers.Items {
		found = found || u.Username == "newbie"
	}
	if !found {
		t.Fatal("follower list missing newbie")
	}

	e.expect(200, "DELETE", "/api/users/gezelenc/follow", me.Token, nil, &prof)
	if prof.IsFollowing {
		t.Fatal("unfollow failed")
	}
}

func TestSeedAndPaging(t *testing.T) {
	e := newEnv(t, true)
	var p1, p2 page[pinResp]
	e.expect(200, "GET", "/api/pins?limit=20", "", nil, &p1)
	e.expect(200, "GET", "/api/pins?limit=20&page=2", "", nil, &p2)
	if len(p1.Items) != 20 || !p1.HasMore || len(p2.Items) != 10 || p2.HasMore {
		t.Fatalf("paging wrong: %d/%v %d/%v", len(p1.Items), p1.HasMore, len(p2.Items), p2.HasMore)
	}
	seen := map[uint]bool{}
	for _, p := range append(p1.Items, p2.Items...) {
		if seen[p.ID] {
			t.Fatalf("duplicate pin %d across pages", p.ID)
		}
		seen[p.ID] = true
	}

	var sim page[pinResp]
	e.expect(200, "GET", fmt.Sprintf("/api/pins/%d/similar?limit=3", p1.Items[0].ID), "", nil, &sim)
	if len(sim.Items) != 3 || sim.Items[0].Category != p1.Items[0].Category {
		t.Fatalf("similar wrong: %+v", sim.Items)
	}

	e.expect(200, "GET", "/api/categories", "", nil, nil)
	e.expect(200, "GET", "/api/users/aylar.studio", "", nil, nil)
	e.expect(404, "GET", "/api/users/nobody", "", nil, nil)
	e.expect(404, "GET", "/api/does-not-exist", "", nil, nil)
}

func TestAvatarUpload(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("avatar")
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	fw, _ := w.CreateFormFile("avatar", "me.png")
	_, _ = fw.Write(testPNG(10, 10))
	_ = w.Close()
	m.contentType = w.FormDataContentType()

	var me struct {
		AvatarURL string `json:"avatarUrl"`
	}
	e.expect(200, "POST", "/api/me/avatar", a.Token, m, &me)
	if me.AvatarURL == "" {
		t.Fatal("avatar not set")
	}
	if code := e.do("GET", me.AvatarURL, "", nil, nil); code != http.StatusOK {
		t.Fatalf("avatar not served: %d", code)
	}
	e.expect(200, "DELETE", "/api/me/avatar", a.Token, nil, &me)
	if me.AvatarURL != "" {
		t.Fatal("avatar not removed")
	}
}
