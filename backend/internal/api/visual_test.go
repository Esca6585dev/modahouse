package api_test

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"mime/multipart"
	"testing"
)

// twoTone draws a centred block of fg on bg (like a product photo).
func twoTone(bg, fg color.RGBA) []byte {
	img := image.NewRGBA(image.Rect(0, 0, 60, 80))
	for y := 0; y < 80; y++ {
		for x := 0; x < 60; x++ {
			c := bg
			if x > 15 && x < 45 && y > 15 && y < 65 {
				c = fg
			}
			img.Set(x, y, c)
		}
	}
	var b bytes.Buffer
	_ = png.Encode(&b, img)
	return b.Bytes()
}

func imageQuery(t *testing.T, img []byte, fields map[string]string) *multipartBody {
	t.Helper()
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	for k, v := range fields {
		_ = w.WriteField(k, v)
	}
	fw, _ := w.CreateFormFile("image", "q.png")
	_, _ = fw.Write(img)
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	return m
}

func TestVisualSearch(t *testing.T) {
	e := newEnv(t, false)
	u := e.register("suratgyz")
	cream := color.RGBA{240, 232, 220, 255}
	red := color.RGBA{180, 20, 40, 255}
	green := color.RGBA{30, 110, 90, 255}
	blue := color.RGBA{90, 140, 210, 255}
	ids := map[string]uint{}
	for name, c := range map[string]color.RGBA{"red": red, "green": green, "blue": blue} {
		var p struct{ ID uint }
		e.expect(201, "POST", "/api/pins", u.Token, pinForm(t, map[string]string{"title": name, "category": "toy"}, twoTone(cream, c)), &p)
		ids[name] = p.ID
	}

	type result struct {
		Items  []struct{ ID uint } `json:"items"`
		Scores []float64           `json:"scores"`
		Source string              `json:"source"`
	}
	var r result
	// A slightly different red dress photo finds the red one first.
	e.expect(200, "POST", "/api/search/image", "", imageQuery(t, twoTone(color.RGBA{235, 228, 215, 255}, color.RGBA{170, 30, 45, 255}), nil), &r)
	if len(r.Items) != 3 || r.Items[0].ID != ids["red"] || r.Scores[0] < r.Scores[1] || r.Source != "local" {
		t.Fatalf("search: %+v", r)
	}
	// Cropping to the coloured part of a mostly-green photo finds green.
	e.expect(200, "POST", "/api/search/image", "", imageQuery(t, twoTone(green, blue), map[string]string{"x": "0.3", "y": "0.25", "w": "0.4", "h": "0.5"}), &r)
	if r.Items[0].ID != ids["blue"] {
		t.Fatalf("crop: %+v", r)
	}
	// Find similar for a pin excludes the pin itself.
	e.expect(200, "GET", fmt.Sprintf("/api/pins/%d/visual", ids["red"]), "", nil, &r)
	if len(r.Items) != 2 || r.Items[0].ID == ids["red"] {
		t.Fatalf("similar: %+v", r)
	}
	// Products-only finds nothing here; SVG queries are refused.
	e.expect(200, "POST", "/api/search/image", "", imageQuery(t, twoTone(cream, red), map[string]string{"type": "products"}), &r)
	if len(r.Items) != 0 {
		t.Fatalf("products filter: %+v", r)
	}
	e.expect(400, "POST", "/api/search/image", "", imageQuery(t, []byte(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>`), nil), nil)
	e.expect(400, "POST", "/api/search/image", "", nil, nil)

	// Deleted pins disappear from results.
	e.expect(204, "DELETE", fmt.Sprintf("/api/pins/%d", ids["red"]), u.Token, nil, nil)
	e.expect(200, "POST", "/api/search/image", "", imageQuery(t, twoTone(cream, red), nil), &r)
	for _, it := range r.Items {
		if it.ID == ids["red"] {
			t.Fatal("deleted pin still returned")
		}
	}
}
