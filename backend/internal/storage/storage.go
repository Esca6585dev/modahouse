// Package storage saves uploaded images on local disk.
package storage

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"image"
	"image/draw"
	_ "image/gif"
	"image/jpeg"
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
	Watermarked bool
	URL         string
	Width       int
	Height      int
	Color       string
}

func New(dir string) (*Storage, error) {
	for _, sub := range []string{"pins", "avatars", "seed", "stories", PrivateChat} {
		if err := os.MkdirAll(filepath.Join(dir, sub), 0o755); err != nil {
			return nil, err
		}
	}
	return &Storage{Dir: dir}, nil
}

// SaveImage validates the file by its content (not its name), stores it under
// sub/ and returns its public URL and dimensions.
func (s *Storage) SaveImage(fh *multipart.FileHeader, sub string) (*Saved, error) {
	return s.SaveImageMarked(fh, sub, nil)
}

// Marker draws onto an uploaded image (e.g. the ModaHouse watermark).
type Marker func(image.Image) image.Image

// SaveImageMarked is SaveImage with an optional marker. A marked image is stored
// as JPEG (transparency flattened onto white); animated GIFs are kept as they are.
func (s *Storage) SaveImageMarked(fh *multipart.FileHeader, sub string, mark Marker) (*Saved, error) {
	f, err := fh.Open()
	if err != nil {
		return nil, err
	}
	defer f.Close()
	data, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}
	return s.SaveImageData(data, sub, mark)
}

// SaveImageData stores image bytes (see SaveImageMarked).
func (s *Storage) SaveImageData(data []byte, sub string, mark Marker) (*Saved, error) {
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
	avg := averageColor(img) // of the original, so the placeholder matches the photo

	marked := false
	if mark != nil && ext != ".gif" {
		flat := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
		draw.Draw(flat, flat.Bounds(), image.White, image.Point{}, draw.Src)
		draw.Draw(flat, flat.Bounds(), img, b.Min, draw.Over)
		var buf bytes.Buffer
		if err := jpeg.Encode(&buf, mark(flat), &jpeg.Options{Quality: 90}); err != nil {
			return nil, err
		}
		data, ext, marked = buf.Bytes(), ".jpg", true
	}

	name := randomName() + ext
	if err := os.WriteFile(filepath.Join(s.Dir, sub, name), data, 0o644); err != nil {
		return nil, err
	}
	return &Saved{URL: "/uploads/" + sub + "/" + name, Width: b.Dx(), Height: b.Dy(), Color: avg, Watermarked: marked}, nil
}

// WriteFile stores raw bytes (used by the seeder for generated SVGs).
func (s *Storage) WriteFile(sub, name string, data []byte) (string, error) {
	if err := os.WriteFile(filepath.Join(s.Dir, sub, name), data, 0o644); err != nil {
		return "", err
	}
	return "/uploads/" + sub + "/" + name, nil
}

// Read returns the bytes of a file previously returned as a /uploads/ URL.
func (s *Storage) Read(url string) ([]byte, error) {
	rel, ok := strings.CutPrefix(url, "/uploads/")
	if !ok || strings.Contains(rel, "..") {
		return nil, os.ErrNotExist
	}
	return os.ReadFile(filepath.Join(s.Dir, filepath.FromSlash(rel)))
}

// Remove deletes a file previously returned as a /uploads/ URL. Unknown URLs are ignored.
// cacheDir holds derived files (rasterised seed art) inside the uploads volume,
// so it is writable wherever uploads are.
func (s *Storage) cacheDir() string { return filepath.Join(s.Dir, ".cache") }

// ReadCache returns a cached derived file by key (a plain file name).
func (s *Storage) ReadCache(key string) ([]byte, error) {
	if strings.ContainsAny(key, `/\`) {
		return nil, os.ErrNotExist
	}
	return os.ReadFile(filepath.Join(s.cacheDir(), key))
}

// WriteCache stores a derived file; errors are ignored (the cache is best effort).
func (s *Storage) WriteCache(key string, data []byte) {
	if strings.ContainsAny(key, `/\`) {
		return
	}
	dir := s.cacheDir()
	if os.MkdirAll(dir, 0o755) != nil {
		return
	}
	tmp := filepath.Join(dir, key+".tmp"+randomName())
	if os.WriteFile(tmp, data, 0o644) == nil {
		_ = os.Rename(tmp, filepath.Join(dir, key))
	}
}

// Path maps an /uploads/... URL to its file path.
func (s *Storage) Path(url string) (string, bool) {
	rel, ok := strings.CutPrefix(url, "/uploads/")
	if !ok || rel == "" || strings.Contains(rel, "..") {
		return "", false
	}
	path := filepath.Join(s.Dir, filepath.FromSlash(rel))
	if _, err := os.Stat(path); err != nil {
		return "", false
	}
	return path, true
}

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

// PrivateChat holds chat attachments. Directories starting with "." are never
// served by the /uploads route; these files go out through signed links only.
const PrivateChat = ".private/chat"

// SavePrivate stores data under sub with a random name and the given extension.
func (s *Storage) SavePrivate(sub string, data []byte, ext string) (string, error) {
	name := randomName() + ext
	if err := os.WriteFile(filepath.Join(s.Dir, filepath.FromSlash(sub), name), data, 0o600); err != nil {
		return "", err
	}
	return name, nil
}

// PrivatePath returns the path of a private file; name must be a plain file name.
func (s *Storage) PrivatePath(sub, name string) (string, bool) {
	if name == "" || strings.ContainsAny(name, `/\`) || strings.HasPrefix(name, ".") {
		return "", false
	}
	path := filepath.Join(s.Dir, filepath.FromSlash(sub), name)
	if _, err := os.Stat(path); err != nil {
		return "", false
	}
	return path, true
}

// RemovePrivate deletes a private file (best effort).
func (s *Storage) RemovePrivate(sub, name string) {
	if path, ok := s.PrivatePath(sub, name); ok {
		_ = os.Remove(path)
	}
}
