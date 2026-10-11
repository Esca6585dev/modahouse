package api

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

const (
	maxPinImages   = 8
	maxPrice       = 1_000_000
	newBadgeWindow = 14 * 24 * time.Hour
	hitOrders      = 5
)

var hexColorRe = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func parseColors(raw string) []ColorOption {
	out := []ColorOption{}
	if raw != "" {
		_ = json.Unmarshal([]byte(raw), &out)
	}
	return out
}

func parseSizes(raw string) []string {
	out := []string{}
	for _, s := range strings.Split(raw, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

// isProduct reports whether p is sold: a priced pin whose author is a business.
func isProduct(p models.Pin) bool { return p.Price > 0 && p.User.IsBusiness }

func productDTO(p models.Pin, now time.Time) *ProductDTO {
	if !isProduct(p) {
		return nil
	}
	badge := ""
	switch {
	case p.OldPrice > p.Price:
		badge = "sale"
	case p.OrdersCount >= hitOrders:
		badge = "hit"
	case now.Sub(p.CreatedAt) < newBadgeWindow:
		badge = "new"
	}
	return &ProductDTO{
		Price: p.Price, OldPrice: p.OldPrice, Colors: parseColors(p.Colors), Sizes: parseSizes(p.Sizes),
		Stock: p.Stock, DeliveryDays: p.DeliveryDays, ReturnDays: p.ReturnDays, Material: p.Material, Badge: badge,
	}
}

// productFields carries the optional product part of a pin create/update.
// Stock uses RawMessage so that "absent" (keep) and null (untracked) differ.
type productFields struct {
	Price        *int            `json:"price"`
	OldPrice     *int            `json:"oldPrice"`
	Stock        json.RawMessage `json:"stock"`
	DeliveryDays *int            `json:"deliveryDays"`
	ReturnDays   *int            `json:"returnDays"`
	Material     *string         `json:"material"`
	Colors       *[]ColorOption  `json:"colors"`
	Sizes        *[]string       `json:"sizes"`
}

func (f productFields) touchesProduct() bool {
	return (f.Price != nil && *f.Price > 0) || f.OldPrice != nil || len(f.Stock) > 0 || f.DeliveryDays != nil ||
		f.ReturnDays != nil || f.Material != nil || f.Colors != nil || f.Sizes != nil
}

// apply validates and copies product fields onto p. Returns a user-facing message on error.
func (f productFields) apply(p *models.Pin) string {
	if f.Price != nil {
		if *f.Price < 0 || *f.Price > maxPrice {
			return "Baha nädogry"
		}
		p.Price = *f.Price
	}
	if f.OldPrice != nil {
		if *f.OldPrice < 0 || *f.OldPrice > maxPrice {
			return "Köne baha nädogry"
		}
		p.OldPrice = *f.OldPrice
	}
	if len(f.Stock) > 0 {
		if string(f.Stock) == "null" {
			p.Stock = nil
		} else {
			n, err := strconv.Atoi(strings.Trim(string(f.Stock), `"`))
			if err != nil || n < 0 || n > 100000 {
				return "Galyndy sany nädogry"
			}
			p.Stock = &n
		}
	}
	for _, d := range []struct {
		v   *int
		dst *int
	}{{f.DeliveryDays, &p.DeliveryDays}, {f.ReturnDays, &p.ReturnDays}} {
		if d.v != nil {
			if *d.v < 0 || *d.v > 365 {
				return "Gün sany 0-365 aralygynda bolmaly"
			}
			*d.dst = *d.v
		}
	}
	if f.Material != nil {
		p.Material = clean(*f.Material, 100)
	}
	if f.Colors != nil {
		colors := []ColorOption{}
		seen := map[string]bool{}
		for _, c := range *f.Colors {
			c.Name, c.Hex = clean(c.Name, 40), strings.ToUpper(strings.TrimSpace(c.Hex))
			if c.Name == "" || seen[strings.ToLower(c.Name)] {
				continue
			}
			if !hexColorRe.MatchString(c.Hex) {
				return "Reňk kody #RRGGBB görnüşinde bolmaly"
			}
			seen[strings.ToLower(c.Name)] = true
			colors = append(colors, c)
		}
		if len(colors) > 12 {
			return "Iň köp 12 reňk goşup bolýar"
		}
		raw, _ := json.Marshal(colors)
		p.Colors = string(raw)
	}
	if f.Sizes != nil {
		sizes := []string{}
		seen := map[string]bool{}
		for _, s := range *f.Sizes {
			s = clean(strings.ReplaceAll(s, ",", " "), 20)
			if s != "" && !seen[s] {
				seen[s] = true
				sizes = append(sizes, s)
			}
		}
		if len(sizes) > 30 {
			return "Iň köp 30 ölçeg goşup bolýar"
		}
		p.Sizes = strings.Join(sizes, ",")
	}
	return ""
}

// productFieldsFromForm reads product fields from a multipart create request.
func productFieldsFromForm(c fiber.Ctx) (productFields, string) {
	var f productFields
	intField := func(k string) (*int, string) {
		raw := strings.TrimSpace(c.FormValue(k))
		if raw == "" {
			return nil, ""
		}
		n, err := strconv.Atoi(raw)
		if err != nil {
			return nil, fmt.Sprintf("%s san bolmaly", k)
		}
		return &n, ""
	}
	var msg string
	if f.Price, msg = intField("price"); msg != "" {
		return f, "Baha san bolmaly"
	}
	if f.OldPrice, msg = intField("oldPrice"); msg != "" {
		return f, "Köne baha san bolmaly"
	}
	if f.DeliveryDays, msg = intField("deliveryDays"); msg != "" {
		return f, "Eltip bermek möhleti san bolmaly"
	}
	if f.ReturnDays, msg = intField("returnDays"); msg != "" {
		return f, "Gaýtaryp bermek möhleti san bolmaly"
	}
	if raw := strings.TrimSpace(c.FormValue("stock")); raw != "" {
		f.Stock = json.RawMessage(raw)
	}
	if v := c.FormValue("material"); v != "" {
		f.Material = &v
	}
	if raw := strings.TrimSpace(c.FormValue("colors")); raw != "" {
		var colors []ColorOption
		if err := json.Unmarshal([]byte(raw), &colors); err != nil {
			return f, "Reňkler nädogry görnüşde"
		}
		f.Colors = &colors
	}
	if raw := strings.TrimSpace(c.FormValue("sizes")); raw != "" {
		sizes := parseSizes(raw)
		f.Sizes = &sizes
	}
	return f, ""
}

// formImages returns the uploaded files from "images" (repeated) and "image".
func formImages(c fiber.Ctx) []*multipart.FileHeader {
	form, err := c.MultipartForm()
	if err != nil {
		return nil
	}
	files := append([]*multipart.FileHeader{}, form.File["images"]...)
	files = append(files, form.File["image"]...)
	return files
}

// businessDefaults fills delivery/return days from the business profile when unset.
func (h *Handler) businessDefaults(p *models.Pin) {
	if p.Price <= 0 {
		return
	}
	var b models.Business
	if h.db.First(&b, p.UserID).Error != nil {
		return
	}
	if p.DeliveryDays == 0 {
		p.DeliveryDays = b.DeliveryDays
	}
	if p.ReturnDays == 0 {
		p.ReturnDays = b.ReturnDays
	}
}

// viewPin: POST /pins/:id/view, counted once per viewer per day.
func (h *Handler) viewPin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var p models.Pin
	if err := h.db.Select("id", "user_id", "views_count").First(&p, id).Error; err != nil {
		return notFound(c)
	}
	viewer := ""
	if me := viewerID(c); me != 0 {
		if me == p.UserID {
			return c.JSON(fiber.Map{"viewsCount": p.ViewsCount}) // owners don't inflate their own views
		}
		viewer = "u:" + strconv.FormatUint(uint64(me), 10)
	} else {
		sum := sha256.Sum256([]byte(c.IP() + "|" + h.cfg.JWTSecret))
		viewer = "ip:" + hex.EncodeToString(sum[:12])
	}
	now := time.Now().UTC()
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	res := h.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.PinView{PinID: p.ID, Viewer: viewer, Day: day})
	if res.Error == nil && res.RowsAffected > 0 {
		h.db.Model(&models.Pin{}).Where("id = ?", p.ID).UpdateColumn("views_count", gorm.Expr("views_count + 1"))
		p.ViewsCount++
	}
	return c.JSON(fiber.Map{"viewsCount": p.ViewsCount})
}
