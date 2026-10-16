package watermark

import (
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"
)

// half-busy image: left half noisy stripes, right half calm.
func testImage(w, h int, calm color.RGBA) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	draw.Draw(img, img.Bounds(), image.NewUniform(calm), image.Point{}, draw.Src)
	for y := 0; y < h; y++ {
		for x := 0; x < w/2; x++ {
			if (x/3+y/5)%2 == 0 {
				img.Set(x, y, color.Black)
			} else {
				img.Set(x, y, color.White)
			}
		}
	}
	return img
}

func TestApplyPicksCalmCornerAndContrast(t *testing.T) {
	out, res := Apply(testImage(800, 1000, color.RGBA{240, 236, 230, 255}), "aylar.studio")
	if res.Corner != BottomRight || res.Light {
		t.Fatalf("light calm right half: got %+v", res)
	}
	if out.Bounds().Dx() != 800 || out.Bounds().Dy() != 1000 {
		t.Fatalf("size changed: %v", out.Bounds())
	}

	// Mirror: calm area on the left, dark.
	img := testImage(800, 1000, color.RGBA{20, 20, 30, 255})
	flipped := image.NewRGBA(img.Bounds())
	for y := 0; y < 1000; y++ {
		for x := 0; x < 800; x++ {
			flipped.Set(799-x, y, img.At(x, y))
		}
	}
	_, res = Apply(flipped, "x")
	if res.Corner != BottomLeft || !res.Light {
		t.Fatalf("dark calm left half: got %+v", res)
	}

	// The mark actually changed pixels in the chosen corner only.
	plain := testImage(800, 1000, color.RGBA{240, 236, 230, 255})
	out, _ = Apply(plain, "aylar.studio")
	changed := func(r image.Rectangle) int {
		n := 0
		for y := r.Min.Y; y < r.Max.Y; y++ {
			for x := r.Min.X; x < r.Max.X; x++ {
				if out.RGBAAt(x, y) != plain.RGBAAt(x, y) {
					n++
				}
			}
		}
		return n
	}
	if changed(image.Rect(400, 700, 800, 1000)) < 1000 || changed(image.Rect(400, 0, 800, 300)) != 0 {
		t.Fatal("watermark not where expected")
	}
}

func TestTinyImagesAreLeftAlone(t *testing.T) {
	img := testImage(80, 80, color.RGBA{255, 255, 255, 255})
	out, res := Apply(img, "a")
	if res.Corner != "" || out.RGBAAt(70, 70) != img.RGBAAt(70, 70) {
		t.Fatal("tiny image was marked")
	}
}

func TestCard(t *testing.T) {
	card := Card(CardInput{Images: []image.Image{testImage(600, 900, color.RGBA{200, 30, 60, 255})},
		Title: "Gyzyl toý köýnegi 💃 — ýaka fasony", Handle: "gyzyl.guyze"})
	if card.Bounds().Dx() != CardW || card.Bounds().Dy() != CardH {
		t.Fatalf("card size %v", card.Bounds())
	}
	// Logo pill is brand red somewhere on the left column.
	found := false
	for y := 800; y < 1100 && !found; y++ {
		found = card.RGBAAt(80, y) == Red
	}
	if !found {
		t.Fatal("logo pill not drawn")
	}
	if Card(CardInput{}).Bounds().Dx() != CardW {
		t.Fatal("empty card")
	}
}

// WATERMARK_DUMP=dir go test ./internal/watermark -run Dump writes samples for a visual check.
func TestDump(t *testing.T) {
	dir := os.Getenv("WATERMARK_DUMP")
	if dir == "" {
		t.Skip("set WATERMARK_DUMP")
	}
	var imgs []image.Image
	for _, p := range filepath.SplitList(os.Getenv("WATERMARK_INPUTS")) {
		f, err := os.Open(p)
		if err != nil {
			t.Fatal(err)
		}
		img, _, err := image.Decode(f)
		f.Close()
		if err != nil {
			t.Fatal(err)
		}
		imgs = append(imgs, img)
		out, res := Apply(img, "aylar.studio")
		t.Logf("%s: %+v", p, res)
		save(t, filepath.Join(dir, "wm-"+filepath.Base(p)), out)
	}
	save(t, filepath.Join(dir, "card.jpg"), Card(CardInput{Images: imgs, Title: "Milli köýnek — täze ýaka fasony", Handle: "aylar.studio"}))
	logo := image.NewRGBA(image.Rect(0, 0, 640, 360))
	draw.Draw(logo, logo.Bounds(), image.White, image.Point{}, draw.Src)
	l := Logo(600, Ink, Red)
	draw.Draw(logo, l.Bounds().Add(image.Pt(20, 20)), l, image.Point{}, draw.Over)
	save(t, filepath.Join(dir, "logo.jpg"), logo)
}

func save(t *testing.T, path string, img image.Image) {
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := jpeg.Encode(f, img, &jpeg.Options{Quality: 88}); err != nil {
		t.Fatal(err)
	}
}
