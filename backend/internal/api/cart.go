package api

import (
	"slices"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

type CartPin struct {
	ID       uint      `json:"id"`
	Title    string    `json:"title"`
	ImageURL string    `json:"imageUrl"`
	Color    string    `json:"color"`
	Price    int       `json:"price"`
	OldPrice int       `json:"oldPrice"`
	Stock    *int      `json:"stock"`
	Author   UserBrief `json:"author"`
}

type CartItemDTO struct {
	ID        uint    `json:"id"`
	Quantity  int     `json:"quantity"`
	Color     string  `json:"color"`
	Size      string  `json:"size"`
	Pin       CartPin `json:"pin"`
	LineTotal int     `json:"lineTotal"`
	Available bool    `json:"available"`
}

type CartDTO struct {
	Items []CartItemDTO `json:"items"`
	Total int           `json:"total"`
	Count int           `json:"count"`
}

func available(p models.Pin, qty int) bool {
	return isForSale(p) && (p.Stock == nil || *p.Stock >= qty)
}

func (h *Handler) cartItems(userID uint) []models.CartItem {
	var items []models.CartItem
	h.db.Preload("Pin").Preload("Pin.User").Where("user_id = ?", userID).Order("created_at ASC, id ASC").Find(&items)
	return items
}

func (h *Handler) cartDTO(userID uint) CartDTO {
	out := CartDTO{Items: []CartItemDTO{}}
	for _, it := range h.cartItems(userID) {
		p := it.Pin
		d := CartItemDTO{
			ID: it.ID, Quantity: it.Quantity, Color: it.Color, Size: it.Size,
			Pin:       CartPin{ID: p.ID, Title: p.Title, ImageURL: p.ImageURL, Color: p.Color, Price: p.Price, OldPrice: p.OldPrice, Stock: p.Stock, Author: brief(p.User)},
			Available: available(p, it.Quantity),
		}
		if d.Available {
			d.LineTotal = p.Price * it.Quantity
			out.Total += d.LineTotal
		}
		out.Count += it.Quantity
		out.Items = append(out.Items, d)
	}
	return out
}

func (h *Handler) getCart(c fiber.Ctx) error { return c.JSON(h.cartDTO(viewerID(c))) }

func (h *Handler) cartCount(c fiber.Ctx) error {
	var n struct{ N int64 }
	h.db.Model(&models.CartItem{}).Select("COALESCE(SUM(quantity), 0) AS n").Where("user_id = ?", viewerID(c)).Scan(&n)
	return c.JSON(fiber.Map{"count": n.N})
}

type lineReq struct {
	PinID    uint   `json:"pinId"`
	Color    string `json:"color"`
	Size     string `json:"size"`
	Quantity int    `json:"quantity"`
}

// validateLine checks a product line against the product's options and stock.
// It returns the loaded pin, or a user-facing message.
func (h *Handler) validateLine(buyer uint, r *lineReq, extraQty int) (models.Pin, string) {
	var p models.Pin
	if err := h.db.Preload("User").First(&p, r.PinID).Error; err != nil {
		return p, "Haryt tapylmady"
	}
	if !isProduct(p) {
		return p, "Bu pin satylmaýar"
	}
	if !isForSale(p) {
		return p, "Bu haryt kärende ýa-da sargyt üçin: satyjy bilen habarlaşyň"
	}
	if p.UserID == buyer {
		return p, "Öz harydyňyzy satyn alyp bilmersiňiz"
	}
	if r.Quantity == 0 {
		r.Quantity = 1
	}
	if r.Quantity < 1 || r.Quantity > 99 {
		return p, "Sany 1-99 aralygynda bolmaly"
	}
	colors := parseColors(p.Colors)
	if len(colors) > 0 {
		ok := slices.ContainsFunc(colors, func(c ColorOption) bool { return c.Name == r.Color })
		if !ok {
			return p, "Reňkini saýlaň"
		}
	} else {
		r.Color = ""
	}
	sizes := parseSizes(p.Sizes)
	if len(sizes) > 0 {
		if !slices.Contains(sizes, r.Size) {
			return p, "Ölçegini saýlaň"
		}
	} else {
		r.Size = ""
	}
	if p.Stock != nil && *p.Stock < r.Quantity+extraQty {
		if *p.Stock == 0 {
			return p, "Bu haryt gutardy"
		}
		return p, "Ýeterlik haryt ýok"
	}
	return p, ""
}

func (h *Handler) addToCart(c fiber.Ctx) error {
	var r lineReq
	if err := c.Bind().Body(&r); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	var existing models.CartItem
	found := h.db.Where("user_id = ? AND pin_id = ? AND color = ? AND size = ?", me, r.PinID, r.Color, r.Size).First(&existing).Error == nil
	extra := 0
	if found {
		extra = existing.Quantity
	}
	if _, msg := h.validateLine(me, &r, extra); msg != "" {
		return badRequest(c, msg)
	}
	if found {
		existing.Quantity = min(existing.Quantity+r.Quantity, 99)
		h.db.Save(&existing)
	} else {
		h.db.Create(&models.CartItem{UserID: me, PinID: r.PinID, Color: r.Color, Size: r.Size, Quantity: r.Quantity})
	}
	return c.JSON(h.cartDTO(me))
}

func (h *Handler) updateCartItem(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	var it models.CartItem
	if err := h.db.Preload("Pin").Where("id = ? AND user_id = ?", id, me).First(&it).Error; err != nil {
		return notFound(c)
	}
	var req struct {
		Quantity int `json:"quantity"`
	}
	if err := c.Bind().Body(&req); err != nil || req.Quantity < 1 || req.Quantity > 99 {
		return badRequest(c, "Sany 1-99 aralygynda bolmaly")
	}
	if it.Pin.Stock != nil && *it.Pin.Stock < req.Quantity {
		return badRequest(c, "Ýeterlik haryt ýok")
	}
	h.db.Model(&it).Update("quantity", req.Quantity)
	return c.JSON(h.cartDTO(me))
}

func (h *Handler) deleteCartItem(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	h.db.Where("id = ? AND user_id = ?", id, me).Delete(&models.CartItem{})
	return c.JSON(h.cartDTO(me))
}

func (h *Handler) clearCart(c fiber.Ctx) error {
	me := viewerID(c)
	h.db.Where("user_id = ?", me).Delete(&models.CartItem{})
	return c.JSON(h.cartDTO(me))
}

// reserveStock takes qty from a tracked stock, failing if not enough is left.
func reserveStock(tx *gorm.DB, pinID uint, qty int) (bool, error) {
	res := tx.Model(&models.Pin{}).Where("id = ? AND (stock IS NULL OR stock >= ?)", pinID, qty).
		Updates(map[string]any{
			"stock":        gorm.Expr("CASE WHEN stock IS NULL THEN NULL ELSE stock - ? END", qty),
			"orders_count": gorm.Expr("orders_count + 1"),
		})
	return res.RowsAffected > 0, res.Error
}

// releaseStock returns stock for a cancelled order line.
func releaseStock(tx *gorm.DB, pinID uint, qty int) error {
	return tx.Model(&models.Pin{}).Where("id = ?", pinID).Updates(map[string]any{
		"stock":        gorm.Expr("CASE WHEN stock IS NULL THEN NULL ELSE stock + ? END", qty),
		"orders_count": gorm.Expr("CASE WHEN orders_count > 0 THEN orders_count - 1 ELSE 0 END"),
	}).Error
}
