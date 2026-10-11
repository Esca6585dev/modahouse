package seed

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// TestFashionArtPreview writes every kind × 8 variants as SVG files into
// $DRESS_PREVIEW for visual review. It is skipped unless the env var is set.
func TestFashionArtPreview(t *testing.T) {
	dir := os.Getenv("DRESS_PREVIEW")
	if dir == "" {
		t.Skip("set DRESS_PREVIEW=<dir> to write preview SVGs")
	}
	kinds := []string{"sac", "makiyaj", "dyrnak", "shay", "keshde", "yaka", "aksessuar", "gundelik"}
	for _, k := range kinds {
		sub := filepath.Join(dir, k)
		if err := os.MkdirAll(sub, 0o755); err != nil {
			t.Fatal(err)
		}
		for v := 0; v < 12; v++ {
			w, h := 300.0, 400.0
			name := fmt.Sprintf("p%02d.svg", v)
			if v >= 8 {
				h = 300
				name = fmt.Sprintf("s%02d.svg", v)
			}
			svg := renderFashionArt(k, v, w, h)
			if len(svg) > 25*1024 {
				t.Logf("%s variant %d is %d bytes", k, v, len(svg))
			}
			if err := os.WriteFile(filepath.Join(sub, name), []byte(svg), 0o644); err != nil {
				t.Fatal(err)
			}
		}
	}
}

func TestFashionArtDeterministic(t *testing.T) {
	for _, k := range []string{"sac", "makiyaj", "dyrnak", "shay", "keshde", "yaka", "aksessuar", "gundelik"} {
		for v := 0; v < 9; v++ {
			a, b := renderFashionArt(k, v, 300, 400), renderFashionArt(k, v, 300, 400)
			if a != b {
				t.Fatalf("%s/%d not deterministic", k, v)
			}
			if len(a) > 30*1024 {
				t.Errorf("%s/%d too large: %d bytes", k, v, len(a))
			}
		}
	}
}
