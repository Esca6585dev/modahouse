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

var ErrVideo = errors.New("diňe MP4 ýa-da WebM wideolary kabul edilýär")

// IsVideo sniffs the first bytes of an upload.
func IsVideo(fh *multipart.FileHeader) bool {
	f, err := fh.Open()
	if err != nil {
		return false
	}
	defer f.Close()
	head := make([]byte, 512)
	n, _ := io.ReadFull(f, head)
	_, ok := videoExt(head[:n])
	return ok
}

func videoExt(head []byte) (string, bool) {
	if len(head) >= 12 && string(head[4:8]) == "ftyp" {
		return ".mp4", true // MP4 and QuickTime share the ISO box layout
	}
	if http.DetectContentType(head) == "video/webm" {
		return ".webm", true
	}
	return "", false
}

// SaveVideo stores an MP4/WebM upload under sub/ and returns its public URL.
func (s *Storage) SaveVideo(fh *multipart.FileHeader, sub string, maxBytes int64) (string, error) {
	if fh.Size > maxBytes {
		return "", fmt.Errorf("wideo gaty uly (iň köp %d MB)", maxBytes/1024/1024)
	}
	f, err := fh.Open()
	if err != nil {
		return "", err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxBytes+1))
	if err != nil {
		return "", err
	}
	ext, ok := videoExt(data[:min(len(data), 512)])
	if !ok {
		return "", ErrVideo
	}
	name := randomName() + ext
	if err := os.WriteFile(filepath.Join(s.Dir, sub, name), data, 0o644); err != nil {
		return "", err
	}
	return "/uploads/" + sub + "/" + name, nil
}

// VideoPlaceholder writes a poster for a video uploaded without one.
func (s *Storage) VideoPlaceholder(sub string) (string, error) {
	svg := `<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 1080 1920">` +
		`<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3a2f37"/><stop offset="1" stop-color="#7b1e3a"/></linearGradient></defs>` +
		`<rect width="1080" height="1920" fill="url(#g)"/><circle cx="540" cy="960" r="120" fill="#fff" opacity=".9"/>` +
		`<path d="M505 890 L620 960 L505 1030 Z" fill="#7b1e3a"/></svg>`
	return s.WriteFile(sub, randomName()+".svg", []byte(svg))
}

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
	for _, sub := range []string{"pins", "avatars", "seed", "stories"} {
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
