// Package storage saves uploaded images on local disk.
package storage

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	_ "golang.org/x/image/webp"
)

var ErrUnsupported = errors.New("diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär")

var ErrTooLarge = errors.New("suratyň ölçegi gaty uly (iň köp 40 megapiksel)")

const maxPixels = 40_000_000

var extByType = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/gif":  ".gif",
	"image/webp": ".webp",
}

type Storage struct {
	Dir string // root directory, served at /uploads
}

type Saved struct {
	URL    string
	Width  int
	Height int
	Color  string
}

func New(dir string) (*Storage, error) {
	for _, sub := range []string{"pins", "avatars", "seed"} {
		if err := os.MkdirAll(filepath.Join(dir, sub), 0o755); err != nil {
			return nil, err
		}
	}
	return &Storage{Dir: dir}, nil
}

// SaveImage validates the file by its content (not its name), stores it under
// sub/ and returns its public URL and dimensions.
func (s *Storage) SaveImage(fh *multipart.FileHeader, sub string) (*Saved, error) {
	f, err := fh.Open()
	if err != nil {
		return nil, err
	}
	defer f.Close()
	data, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}
	ext, ok := extByType[http.DetectContentType(data)]
	if !ok {
		return nil, ErrUnsupported
	}
	// Check dimensions before a full decode so a tiny file can't claim a huge canvas.
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, ErrUnsupported
	}
	if cfg.Width*cfg.Height > maxPixels {
		return nil, ErrTooLarge
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, ErrUnsupported
	}
	b := img.Bounds()

	name := randomName() + ext
	if err := os.WriteFile(filepath.Join(s.Dir, sub, name), data, 0o644); err != nil {
		return nil, err
	}
	return &Saved{URL: "/uploads/" + sub + "/" + name, Width: b.Dx(), Height: b.Dy(), Color: averageColor(img)}, nil
}

// WriteFile stores raw bytes (used by the seeder for generated SVGs).
func (s *Storage) WriteFile(sub, name string, data []byte) (string, error) {
	if err := os.WriteFile(filepath.Join(s.Dir, sub, name), data, 0o644); err != nil {
		return "", err
	}
	return "/uploads/" + sub + "/" + name, nil
}

// Remove deletes a file previously returned as a /uploads/ URL. Unknown URLs are ignored.
func (s *Storage) Remove(url string) {
	rel, ok := strings.CutPrefix(url, "/uploads/")
	if !ok || strings.Contains(rel, "..") {
		return
	}
	_ = os.Remove(filepath.Join(s.Dir, filepath.FromSlash(rel)))
}

func randomName() string {
	b := make([]byte, 12)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// averageColor samples a grid of pixels to get a placeholder color for the UI.
func averageColor(img image.Image) string {
	b := img.Bounds()
	var r, g, bl, n uint64
	stepX, stepY := max(b.Dx()/20, 1), max(b.Dy()/20, 1)
	for y := b.Min.Y; y < b.Max.Y; y += stepY {
		for x := b.Min.X; x < b.Max.X; x += stepX {
			cr, cg, cb, _ := img.At(x, y).RGBA()
			r, g, bl, n = r+uint64(cr>>8), g+uint64(cg>>8), bl+uint64(cb>>8), n+1
		}
	}
	if n == 0 {
		return "#e9e9e9"
	}
	return fmt.Sprintf("#%02x%02x%02x", r/n, g/n, bl/n)
}
