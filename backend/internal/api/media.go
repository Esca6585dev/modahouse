package api

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"image"
	"image/jpeg"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
	"github.com/esca6585dev/modahouse/backend/internal/visual"
	"github.com/esca6585dev/modahouse/backend/internal/watermark"
)

// uploadMarker returns the watermark for a new post's images, or nil when the
// admin switched watermarking off.
func (h *Handler) uploadMarker(userID uint) storage.Marker {
	if !h.appConfig().WatermarkUploads {
		return nil
	}
	var u models.User
	h.db.Select("id", "username").First(&u, userID)
	return func(img image.Image) image.Image {
		out, _ := watermark.Apply(img, u.Username)
		return out
	}
}

// pinMedia lists a pin's media in order (legacy pins have only ImageURL).
func (h *Handler) pinMedia(p models.Pin) []models.PinImage {
	var imgs []models.PinImage
	h.db.Where("pin_id = ?", p.ID).Order("position, id").Find(&imgs)
	if len(imgs) == 0 {
		imgs = []models.PinImage{{Kind: "image", URL: p.ImageURL, Width: p.Width, Height: p.Height}}
	}
	return imgs
}

// svgWidth caps the raster size of SVG seed art: complex SVGs take seconds to rasterise.
const svgWidth = 720

// decodeMedia loads a stored image no wider than about maxW. SVG seed art is
// rasterised once and kept in the storage cache.
func (h *Handler) decodeMedia(url string, maxW int) (image.Image, error) {
	data, err := h.store.Read(url)
	if err != nil {
		return nil, err
	}
	if visual.IsSVG(data) {
		w := min(maxW, svgWidth)
		key := fmt.Sprintf("%x-%d.jpg", sha256.Sum256(data), w)
		if cached, err := h.store.ReadCache(key); err == nil {
			if img, err := jpeg.Decode(bytes.NewReader(cached)); err == nil {
				return img, nil
			}
		}
		img, err := watermark.RasterizeSVG(data, w)
		if err != nil {
			return nil, err
		}
		if enc, err := encodeJPEG(img); err == nil {
			h.store.WriteCache(key, enc)
		}
		return img, nil
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	if img.Bounds().Dx() > maxW*3/2 {
		return watermark.Resize(img, maxW), nil
	}
	return img, nil
}

func encodeJPEG(img image.Image) ([]byte, error) {
	var buf bytes.Buffer
	err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90})
	return buf.Bytes(), err
}

// downloadPin sends one media item as an attachment; images carry the watermark.
func (h *Handler) downloadPin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	media := h.pinMedia(p)
	idx := fiber.Query[int](c, "index", 0)
	if idx < 0 || idx >= len(media) {
		return notFound(c)
	}
	im := media[idx]
	name := fmt.Sprintf("modahouse-%d-%d", p.ID, idx)

	if im.Kind == "video" || im.Watermarked {
		path, ok := h.store.Path(im.URL)
		if !ok {
			return notFound(c)
		}
		return c.Download(path, name+strings.ToLower(filepath.Ext(path)))
	}
	img, err := h.decodeMedia(im.URL, 1080)
	if err != nil {
		return notFound(c)
	}
	marked, _ := watermark.Apply(img, p.User.Username)
	data, err := encodeJPEG(marked)
	if err != nil {
		return err
	}
	c.Set(fiber.HeaderContentType, "image/jpeg")
	c.Set(fiber.HeaderContentDisposition, `attachment; filename="`+name+`.jpg"`)
	c.Set(fiber.HeaderCacheControl, "public, max-age=3600")
	return c.Send(data)
}

// cardCache keeps recently rendered share cards (rendering takes a few hundred ms).
type cardCache struct {
	mu    sync.Mutex
	items map[string]cardEntry
}

type cardEntry struct {
	data []byte
	at   time.Time
}

const (
	cardTTL      = 10 * time.Minute
	cardCacheMax = 200
)

func (cc *cardCache) get(key string) ([]byte, bool) {
	cc.mu.Lock()
	defer cc.mu.Unlock()
	e, ok := cc.items[key]
	if !ok || time.Since(e.at) > cardTTL {
		return nil, false
	}
	return e.data, true
}

func (cc *cardCache) put(key string, data []byte) {
	cc.mu.Lock()
	defer cc.mu.Unlock()
	if cc.items == nil {
		cc.items = map[string]cardEntry{}
	}
	if len(cc.items) >= cardCacheMax {
		for k, e := range cc.items { // drop expired entries, or everything if none expired
			if time.Since(e.at) > cardTTL {
				delete(cc.items, k)
			}
		}
		if len(cc.items) >= cardCacheMax {
			cc.items = map[string]cardEntry{}
		}
	}
	cc.items[key] = cardEntry{data: data, at: time.Now()}
}

// shareCard renders the 1080×1920 branded collage for sharing to stories and chats.
func (h *Handler) shareCard(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	key := fmt.Sprintf("%d:%d", p.ID, p.UpdatedAt.UnixNano())
	data, ok := h.cards.get(key)
	if !ok {
		urls := []string{p.ImageURL}
		for _, im := range h.pinMedia(p)[1:] {
			if len(urls) < 2 {
				urls = append(urls, coverImage(im))
			}
		}
		var similar []models.Pin
		h.db.Select("id", "image_url").Where("id <> ? AND category = ?", p.ID, p.Category).
			Clauses(clause.OrderBy{Expression: clause.Expr{
				SQL:                "(SELECT COUNT(*) FROM likes WHERE likes.pin_id = pins.id) DESC, pins.id DESC",
				WithoutParentheses: true,
			}}).Limit(4 - len(urls)).Find(&similar)
		for _, s := range similar {
			urls = append(urls, s.ImageURL)
		}
		var imgs []image.Image
		for _, u := range urls {
			if img, err := h.decodeMedia(u, svgWidth); err == nil {
				imgs = append(imgs, img)
			}
		}
		card := watermark.Card(watermark.CardInput{Images: imgs, Title: p.Title, Handle: p.User.Username})
		if data, err = encodeJPEG(card); err != nil {
			return err
		}
		h.cards.put(key, data)
	}
	c.Set(fiber.HeaderContentType, "image/jpeg")
	c.Set(fiber.HeaderCacheControl, "public, max-age=600")
	return c.Send(data)
}

const maxBulkFiles = 30

type bulkFailure struct {
	Name  string `json:"name"`
	Error string `json:"error"`
}

// adminBulkPins creates one post per uploaded image for the given author.
func (h *Handler) adminBulkPins(c fiber.Ctx) error {
	form, err := c.MultipartForm()
	if err != nil {
		return badRequest(c, "Suratlary saýlaň")
	}
	files := append(form.File["files"], form.File["files[]"]...)
	if len(files) == 0 {
		return badRequest(c, "Suratlary saýlaň")
	}
	if len(files) > maxBulkFiles {
		return badRequest(c, fmt.Sprintf("Bir gezekde iň köp %d surat ýükläp bolýar", maxBulkFiles))
	}
	var author models.User
	username := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(c.FormValue("author"), "@")))
	if username == "" || h.db.Where("username = ?", username).First(&author).Error != nil {
		return badRequest(c, "Awtor tapylmady")
	}

	category := c.FormValue("category")
	title := strings.TrimSpace(c.FormValue("title"))
	if title == "" {
		for _, cat := range Categories {
			if cat.Slug == category {
				title = cat.Name
			}
		}
	}
	str := func(v string) *string { return &v }
	fields := pinFields{Title: str(title), Description: str(c.FormValue("description")), Category: str(category), Tags: str(c.FormValue("tags"))}
	prod, msg := productFieldsFromForm(c)
	if msg != "" {
		return badRequest(c, msg)
	}
	if prod.touchesProduct() && !author.IsBusiness {
		return fail(c, fiber.StatusForbidden, "Harydyň bahasyny diňe biznes hasaplary goýup bilýär")
	}
	// Validate the shared fields once before touching any file.
	probe := models.Pin{UserID: author.ID}
	if msg := fields.apply(&probe); msg != "" {
		return badRequest(c, msg)
	}
	if msg := prod.apply(&probe); msg != "" {
		return badRequest(c, msg)
	}
	if msg := finishListing(&probe); msg != "" {
		return badRequest(c, msg)
	}

	mark := h.uploadMarker(author.ID)
	created := []models.Pin{}
	failed := []bulkFailure{}
	for _, fh := range files {
		if storage.IsVideo(fh) {
			failed = append(failed, bulkFailure{fh.Filename, "Diňe suratlar ýüklenýär"})
			continue
		}
		if fh.Size > int64(h.cfg.MaxUploadMB)*1024*1024 {
			failed = append(failed, bulkFailure{fh.Filename, fmt.Sprintf("Surat gaty uly (iň köp %d MB)", h.cfg.MaxUploadMB)})
			continue
		}
		saved, err := h.store.SaveImageMarked(fh, "pins", mark)
		if err != nil {
			failed = append(failed, bulkFailure{fh.Filename, err.Error()})
			continue
		}
		pin := models.Pin{UserID: author.ID}
		fields.apply(&pin)
		prod.apply(&pin)
		finishListing(&pin)
		h.businessDefaults(&pin)
		pin.ImageURL, pin.Width, pin.Height, pin.Color = saved.URL, saved.Width, saved.Height, saved.Color
		err = h.db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Create(&pin).Error; err != nil {
				return err
			}
			return tx.Create(&models.PinImage{PinID: pin.ID, Kind: "image", URL: saved.URL, Width: saved.Width,
				Height: saved.Height, Color: saved.Color, Watermarked: saved.Watermarked}).Error
		})
		if err != nil {
			h.store.Remove(saved.URL)
			failed = append(failed, bulkFailure{fh.Filename, "Serwerde ýalňyşlyk ýüze çykdy"})
			continue
		}
		p, _ := h.loadPin(pin.ID)
		created = append(created, p)
	}
	out := []PinDTO{}
	if len(created) > 0 {
		out = h.enrichPins(created, viewerID(c))
	}
	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"created": out,
		"failed":  failed,
	})
}
