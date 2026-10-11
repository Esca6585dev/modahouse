package api

import (
	"image"
	"io"
	"log"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
	"github.com/esca6585dev/modahouse/backend/internal/visual"
)

// visualIndex keeps every pin's descriptor in memory for fast nearest-neighbour search.
type visualIndex struct {
	db     *gorm.DB
	store  *storage.Storage
	mu     sync.RWMutex
	items  map[uint]*visual.Descriptor
	loaded bool
	work   sync.Mutex // one indexing pass at a time
}

func newVisualIndex(db *gorm.DB, store *storage.Storage) *visualIndex {
	return &visualIndex{db: db, store: store, items: map[uint]*visual.Descriptor{}}
}

func (v *visualIndex) load() {
	v.mu.Lock()
	defer v.mu.Unlock()
	if v.loaded {
		return
	}
	var rows []models.PinFeature
	v.db.Where("version = ?", visual.Version).Find(&rows)
	for _, r := range rows {
		if d, err := visual.Unmarshal(r.Data); err == nil {
			v.items[r.PinID] = d
		}
	}
	v.loaded = true
}

func (v *visualIndex) remove(id uint) {
	v.mu.Lock()
	delete(v.items, id)
	v.mu.Unlock()
}

// indexPending computes descriptors for up to limit pins that have none yet.
func (v *visualIndex) indexPending(limit int) int {
	v.load()
	v.work.Lock()
	defer v.work.Unlock()
	var pins []models.Pin
	v.db.Select("id", "image_url").
		Where("id NOT IN (?)", v.db.Model(&models.PinFeature{}).Select("pin_id").Where("version = ?", visual.Version)).
		Order("id").Limit(limit).Find(&pins)
	done := 0
	for _, p := range pins {
		var row models.PinFeature
		row.PinID, row.Version = p.ID, visual.Version
		data, err := v.store.Read(p.ImageURL)
		var img image.Image
		if err == nil {
			img, err = visual.Decode(data)
		}
		if err != nil {
			// Store an empty row so a broken file isn't retried forever.
			v.db.Clauses(clause.OnConflict{UpdateAll: true}).Create(&row)
			continue
		}
		d := visual.Compute(img, visual.Rect{})
		row.Data = d.Marshal()
		v.db.Clauses(clause.OnConflict{UpdateAll: true}).Create(&row)
		v.mu.Lock()
		v.items[p.ID] = &d
		v.mu.Unlock()
		done++
	}
	return done
}

// run keeps the index fresh in the background.
func (v *visualIndex) run() {
	for {
		for v.indexPending(200) > 0 {
		}
		time.Sleep(20 * time.Second)
	}
}

type scored struct {
	id    uint
	score float64
}

// rank returns pin ids ordered by similarity to q (excluding skip), limited to allowed if set.
func (v *visualIndex) rank(q *visual.Descriptor, skip uint, allowed map[uint]bool, boost map[uint]bool, n int) []scored {
	v.mu.RLock()
	defer v.mu.RUnlock()
	out := make([]scored, 0, len(v.items))
	for id, d := range v.items {
		if id == skip || (allowed != nil && !allowed[id]) {
			continue
		}
		s := visual.Similarity(q, d)
		if boost[id] {
			s += 0.15
		}
		out = append(out, scored{id, s})
	}
	sort.Slice(out, func(a, b int) bool { return out[a].score > out[b].score })
	if len(out) > n {
		out = out[:n]
	}
	return out
}

type VisualResult struct {
	Items    []PinDTO  `json:"items"`
	Scores   []float64 `json:"scores"`   // 0..1, same order as items
	Category string    `json:"category"` // detected by AI, "" when unknown
	Source   string    `json:"source"`   // "local" or "ai+local"
}

// results loads the ranked pins, applying the viewer's hide/block filters.
func (h *Handler) visualResults(c fiber.Ctx, ranked []scored, limit int) ([]PinDTO, []float64) {
	ids := make([]uint, len(ranked))
	for i, r := range ranked {
		ids[i] = r.id
	}
	var pins []models.Pin
	if len(ids) > 0 {
		h.viewerFilter(h.db.Model(&models.Pin{}), viewerID(c)).Preload("User").Where("pins.id IN ?", ids).Find(&pins)
	}
	byID := map[uint]models.Pin{}
	for _, p := range pins {
		byID[p.ID] = p
	}
	var ordered []models.Pin
	var scores []float64
	for _, r := range ranked {
		if p, ok := byID[r.id]; ok && len(ordered) < limit {
			ordered = append(ordered, p)
			scores = append(scores, round2(min(r.score, 1)))
		}
	}
	return h.enrichPins(ordered, viewerID(c)), scores
}

func round2(v float64) float64 { return float64(int(v*100+0.5)) / 100 }

// allowedSet restricts results to products when ?type=products.
func (h *Handler) allowedSet(c fiber.Ctx) map[uint]bool {
	if c.Query("type") != "products" && c.FormValue("type") != "products" {
		return nil
	}
	var ids []uint
	h.productScope(h.db.Model(&models.Pin{})).Pluck("pins.id", &ids)
	set := map[uint]bool{}
	for _, id := range ids {
		set[id] = true
	}
	return set
}

func floatField(c fiber.Ctx, k string) float64 {
	f, _ := strconv.ParseFloat(c.FormValue(k), 64)
	return f
}

// searchByImage: POST /search/image (multipart: image, optional crop x,y,w,h in 0..1, type, limit).
func (h *Handler) searchByImage(c fiber.Ctx) error {
	fh, err := c.FormFile("image")
	if err != nil {
		return badRequest(c, "Surat saýlaň")
	}
	if fh.Size > int64(h.cfg.MaxUploadMB)*1024*1024 {
		return badRequest(c, "Surat gaty uly")
	}
	f, err := fh.Open()
	if err != nil {
		return err
	}
	data, err := io.ReadAll(f)
	f.Close()
	if err != nil {
		return err
	}
	if visual.IsSVG(data) {
		return badRequest(c, "Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär")
	}
	img, err := visual.Decode(data)
	if err != nil {
		return badRequest(c, "Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär")
	}
	crop := visual.Rect{X: floatField(c, "x"), Y: floatField(c, "y"), W: floatField(c, "w"), H: floatField(c, "h")}
	q := visual.Compute(img, crop)

	h.visual.indexPending(500) // make sure fresh posts are searchable
	limit := 30
	if n, err := strconv.Atoi(c.FormValue("limit")); err == nil && n > 0 && n <= 60 {
		limit = n
	}

	res := VisualResult{Source: "local", Items: []PinDTO{}, Scores: []float64{}}
	var boost map[uint]bool
	if h.ai.Enabled() {
		if cat := h.ai.Classify(c.Context(), data); cat != "" {
			res.Category, res.Source = cat, "ai+local"
			var ids []uint
			h.db.Model(&models.Pin{}).Where("category = ?", cat).Pluck("id", &ids)
			boost = map[uint]bool{}
			for _, id := range ids {
				boost[id] = true
			}
		}
	}
	ranked := h.visual.rank(&q, 0, h.allowedSet(c), boost, limit*2)
	res.Items, res.Scores = h.visualResults(c, ranked, limit)
	return c.JSON(res)
}

// visuallySimilar: GET /pins/:id/visual — "Meňzeşini tap".
func (h *Handler) visuallySimilar(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var n int64
	if h.db.Model(&models.Pin{}).Where("id = ?", id).Count(&n); n == 0 {
		return notFound(c)
	}
	h.visual.indexPending(500)
	h.visual.mu.RLock()
	q := h.visual.items[id]
	h.visual.mu.RUnlock()
	res := VisualResult{Source: "local", Items: []PinDTO{}, Scores: []float64{}}
	if q == nil {
		return c.JSON(res)
	}
	limit := fiber.Query[int](c, "limit", 30)
	if limit < 1 || limit > 60 {
		limit = 30
	}
	ranked := h.visual.rank(q, id, h.allowedSet(c), nil, limit*2)
	res.Items, res.Scores = h.visualResults(c, ranked, limit)
	return c.JSON(res)
}

func logVisualStart(v *visualIndex) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("visual index stopped: %v", r)
			}
		}()
		v.run()
	}()
}
