package api_test

import (
	"bytes"
	"image"
	"image/jpeg"
	"io"
	"mime/multipart"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/config"
)

func (e *env) raw(method, path, token string, body io.Reader, ct string) (int, map[string]string, []byte) {
	e.t.Helper()
	req := httptest.NewRequest(method, path, body)
	if ct != "" {
		req.Header.Set("Content-Type", ct)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := e.app.Test(req, fiber.TestConfig{Timeout: 60 * time.Second})
	if err != nil {
		e.t.Fatal(err)
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	h := map[string]string{}
	for k := range resp.Header {
		h[k] = resp.Header.Get(k)
	}
	return resp.StatusCode, h, data
}

type mediaPin struct {
	ID       uint   `json:"id"`
	ImageURL string `json:"imageUrl"`
	Images   []struct {
		URL  string `json:"url"`
		Type string `json:"type"`
	} `json:"images"`
}

func TestDownloadAndShareCard(t *testing.T) {
	e := newEnv(t, true)

	var pins page[mediaPin]
	e.expect(200, "GET", "/api/pins?limit=1", "", nil, &pins)
	seedPin := pins.Items[0] // SVG seed art: rasterised and watermarked on download
	status, h, data := e.raw("GET", "/api/pins/"+itoa(seedPin.ID)+"/download", "", nil, "")
	if status != 200 || h["Content-Type"] != "image/jpeg" ||
		!strings.Contains(h["Content-Disposition"], `filename="modahouse-`+itoa(seedPin.ID)+`-0.jpg"`) {
		t.Fatalf("download: %d %v", status, h)
	}
	img, err := jpeg.Decode(bytes.NewReader(data))
	if err != nil || img.Bounds().Dx() != 720 {
		t.Fatalf("download image: %v %v", err, img)
	}
	if s, _, _ := e.raw("GET", "/api/pins/"+itoa(seedPin.ID)+"/download?index=9", "", nil, ""); s != 404 {
		t.Fatalf("bad index: %d", s)
	}
	if s, _, _ := e.raw("GET", "/api/pins/999999/download", "", nil, ""); s != 404 {
		t.Fatalf("missing pin: %d", s)
	}

	// Videos come back unchanged.
	e.expect(200, "GET", "/api/pins?type=videos&limit=1", "", nil, &pins)
	video := pins.Items[0]
	status, h, data = e.raw("GET", "/api/pins/"+itoa(video.ID)+"/download", "", nil, "")
	if status != 200 || !strings.HasSuffix(strings.TrimSuffix(h["Content-Disposition"], `"`), ".webm") || len(data) < 1000 {
		t.Fatalf("video download: %d %v %d bytes", status, h, len(data))
	}

	status, h, data = e.raw("GET", "/api/pins/"+itoa(seedPin.ID)+"/share-card", "", nil, "")
	if status != 200 || h["Content-Type"] != "image/jpeg" {
		t.Fatalf("share card: %d %v", status, h)
	}
	card, err := jpeg.Decode(bytes.NewReader(data))
	if err != nil || card.Bounds() != image.Rect(0, 0, 1080, 1920) {
		t.Fatalf("share card image: %v", err)
	}
	// Cached: identical bytes.
	if _, _, again := e.raw("GET", "/api/pins/"+itoa(seedPin.ID)+"/share-card", "", nil, ""); !bytes.Equal(again, data) {
		t.Fatal("share card not cached")
	}
}

func TestWatermarkOnUpload(t *testing.T) {
	e := newEnvWith(t, false, func(c *config.Config) { c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123" })
	admin := e.login("boss", "boss-pass-123")
	u := e.register("guly")

	var p pinResp
	e.expect(201, "POST", "/api/pins", u.Token, pinForm(t, map[string]string{"title": "Köýnek", "category": "milli"}, testPNG(600, 800)), &p)
	if !strings.HasSuffix(p.ImageURL, ".jpg") {
		t.Fatalf("watermarked upload should be stored as JPEG: %s", p.ImageURL)
	}
	// Already marked: the download is the stored file itself.
	_, _, stored := e.raw("GET", p.ImageURL, "", nil, "")
	_, _, dl := e.raw("GET", "/api/pins/"+itoa(p.ID)+"/download", "", nil, "")
	if !bytes.Equal(stored, dl) {
		t.Fatal("download marked the image twice")
	}

	var cfg appConfig
	e.expect(200, "PUT", "/api/admin/settings", admin.Token, map[string]any{"watermarkUploads": false}, &cfg)
	if cfg.WatermarkUploads {
		t.Fatal("setting not saved")
	}
	e.expect(201, "POST", "/api/pins", u.Token, pinForm(t, map[string]string{"title": "Köýnek 2", "category": "milli"}, testPNG(600, 800)), &p)
	if !strings.HasSuffix(p.ImageURL, ".png") {
		t.Fatalf("unmarked upload should keep its format: %s", p.ImageURL)
	}
}

func bulkForm(t *testing.T, fields map[string]string, files map[string][]byte) *multipartBody {
	t.Helper()
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	for k, v := range fields {
		_ = w.WriteField(k, v)
	}
	for name, data := range files {
		fw, _ := w.CreateFormFile("files", name)
		_, _ = fw.Write(data)
	}
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	return m
}

func TestAdminBulkUpload(t *testing.T) {
	e := newEnvWith(t, true, func(c *config.Config) { c.AdminUsername = "aylar.studio" })
	admin := e.login("aylar.studio", "modahouse123")
	user := e.register("guly")

	files := map[string][]byte{"a.png": testPNG(300, 400), "b.png": testPNG(400, 300), "notes.txt": []byte("salam")}
	var res struct {
		Created []struct {
			ID       uint   `json:"id"`
			Title    string `json:"title"`
			Category string `json:"category"`
			Author   struct {
				Username string `json:"username"`
			} `json:"author"`
		} `json:"created"`
		Failed []struct {
			Name  string `json:"name"`
			Error string `json:"error"`
		} `json:"failed"`
	}
	e.expect(403, "POST", "/api/admin/pins/bulk", user.Token, bulkForm(t, map[string]string{"author": "guly", "category": "milli"}, files), nil)
	e.expect(400, "POST", "/api/admin/pins/bulk", admin.Token, bulkForm(t, map[string]string{"author": "nobody", "category": "milli"}, files), nil)
	e.expect(400, "POST", "/api/admin/pins/bulk", admin.Token, bulkForm(t, map[string]string{"author": "guly", "category": "nope"}, files), nil)
	// Prices need a business author.
	e.expect(403, "POST", "/api/admin/pins/bulk", admin.Token, bulkForm(t, map[string]string{
		"author": "guly", "category": "milli", "listingType": "sale", "price": "500"}, files), nil)

	e.expect(201, "POST", "/api/admin/pins/bulk", admin.Token, bulkForm(t, map[string]string{
		"author": "@Guly", "category": "milli", "tags": "milli,koynek"}, files), &res)
	if len(res.Created) != 2 || len(res.Failed) != 1 || res.Failed[0].Name != "notes.txt" {
		t.Fatalf("bulk result: %+v", res)
	}
	for _, p := range res.Created {
		if p.Title != "Milli köýnekler" || p.Category != "milli" || p.Author.Username != "guly" {
			t.Fatalf("bulk pin: %+v", p)
		}
	}

	// A shop can bulk-upload products.
	var prod struct {
		Created []struct {
			Product *struct {
				Price int `json:"price"`
			} `json:"product"`
		} `json:"created"`
	}
	e.expect(201, "POST", "/api/admin/pins/bulk", admin.Token, bulkForm(t, map[string]string{
		"author": "gyzyl.guyze", "category": "toy", "title": "Toý köýnegi", "listingType": "sale", "price": "750"},
		map[string][]byte{"c.png": testPNG(300, 400)}), &prod)
	if len(prod.Created) != 1 || prod.Created[0].Product == nil || prod.Created[0].Product.Price != 750 {
		t.Fatalf("bulk product: %+v", prod)
	}
}
