package api

import (
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// Status transitions the seller may make.
var nextStatuses = map[string][]string{
	models.OrderNew:       {models.OrderConfirmed, models.OrderCancelled},
	models.OrderConfirmed: {models.OrderShipped, models.OrderCancelled},
	models.OrderShipped:   {models.OrderDelivered},
}

type OrderItemDTO struct {
	PinID    *uint  `json:"pinId"`
	Title    string `json:"title"`
	ImageURL string `json:"imageUrl"`
	Price    int    `json:"price"`
	Color    string `json:"color"`
	Size     string `json:"size"`
	Quantity int    `json:"quantity"`
}

type OrderDTO struct {
	ID           uint           `json:"id"`
	Status       string         `json:"status"`
	Total        int            `json:"total"`
	Buyer        UserBrief      `json:"buyer"`
	Business     UserBrief      `json:"business"`
	FullName     string         `json:"fullName"`
	Phone        string         `json:"phone"`
	Address      string         `json:"address"`
	Note         string         `json:"note"`
	Items        []OrderItemDTO `json:"items"`
	CanCancel    bool           `json:"canCancel"`
	NextStatuses []string       `json:"nextStatuses"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
}

func orderDTO(o models.Order, viewer uint) OrderDTO {
	d := OrderDTO{
		ID: o.ID, Status: o.Status, Total: o.Total, Buyer: brief(o.Buyer), Business: brief(o.Business),
		FullName: o.FullName, Phone: o.Phone, Address: o.Address, Note: o.Note, Items: []OrderItemDTO{},
		CanCancel: viewer == o.BuyerID && o.Status == models.OrderNew, NextStatuses: []string{},
		CreatedAt: o.CreatedAt, UpdatedAt: o.UpdatedAt,
	}
	for _, it := range o.Items {
		d.Items = append(d.Items, OrderItemDTO{PinID: it.PinID, Title: it.Title, ImageURL: it.ImageURL, Price: it.Price, Color: it.Color, Size: it.Size, Quantity: it.Quantity})
	}
	if viewer == o.BusinessID && nextStatuses[o.Status] != nil {
		d.NextStatuses = nextStatuses[o.Status]
	}
	return d
}

func (h *Handler) loadOrder(id uint) (models.Order, error) {
	var o models.Order
	err := h.db.Preload("Buyer").Preload("Business").Preload("Items", func(db *gorm.DB) *gorm.DB { return db.Order("id") }).First(&o, id).Error
	return o, err
}

type orderReq struct {
	FullName    string   `json:"fullName"`
	Phone       string   `json:"phone"`
	Address     string   `json:"address"`
	Note        string   `json:"note"`
	CartItemIDs []uint   `json:"cartItemIds"`
	BuyNow      *lineReq `json:"buyNow"`
}

type orderLine struct {
	pin    models.Pin
	color  string
	size   string
	qty    int
	cartID uint // 0 for buy-now
}

var errStock = errors.New("stock")

// createOrders: POST /orders. One order per seller.
func (h *Handler) createOrders(c fiber.Ctx) error {
	var req orderReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	req.FullName, req.Address, req.Note = clean(req.FullName, 80), clean(req.Address, 300), clean(req.Note, 500)
	req.Phone = strings.TrimSpace(req.Phone)
	switch {
	case req.FullName == "":
		return badRequest(c, "Adyňyzy ýazyň")
	case !phoneRe.MatchString(req.Phone):
		return badRequest(c, "Telefon belgisi nädogry, mysal: +993 61 234567")
	case len([]rune(req.Address)) < 5:
		return badRequest(c, "Eltip bermek üçin salgyňyzy doly ýazyň")
	}
	me := viewerID(c)

	var lines []orderLine
	if req.BuyNow != nil {
		p, msg := h.validateLine(me, req.BuyNow, 0)
		if msg != "" {
			return badRequest(c, msg)
		}
		lines = append(lines, orderLine{pin: p, color: req.BuyNow.Color, size: req.BuyNow.Size, qty: req.BuyNow.Quantity})
	} else {
		for _, it := range h.cartItems(me) {
			if len(req.CartItemIDs) > 0 && !slices.Contains(req.CartItemIDs, it.ID) {
				continue
			}
			if available(it.Pin, it.Quantity) {
				lines = append(lines, orderLine{pin: it.Pin, color: it.Color, size: it.Size, qty: it.Quantity, cartID: it.ID})
			}
		}
		if len(lines) == 0 {
			return badRequest(c, "Sebetde sargyt üçin elýeterli haryt ýok")
		}
	}

	groups := map[uint][]orderLine{}
	var sellers []uint
	for _, l := range lines {
		if groups[l.pin.UserID] == nil {
			sellers = append(sellers, l.pin.UserID)
		}
		groups[l.pin.UserID] = append(groups[l.pin.UserID], l)
	}

	var created []uint
	var short string
	err := h.db.Transaction(func(tx *gorm.DB) error {
		for _, seller := range sellers {
			o := models.Order{BuyerID: me, BusinessID: seller, Status: models.OrderNew, FullName: req.FullName, Phone: req.Phone, Address: req.Address, Note: req.Note}
			for _, l := range groups[seller] {
				ok, err := reserveStock(tx, l.pin.ID, l.qty)
				if err != nil {
					return err
				}
				if !ok {
					short = l.pin.Title
					return errStock
				}
				pid := l.pin.ID
				o.Items = append(o.Items, models.OrderItem{PinID: &pid, Title: l.pin.Title, ImageURL: l.pin.ImageURL, Price: l.pin.Price, Color: l.color, Size: l.size, Quantity: l.qty})
				o.Total += l.pin.Price * l.qty
			}
			if err := tx.Create(&o).Error; err != nil {
				return err
			}
			created = append(created, o.ID)
		}
		for _, l := range lines {
			if l.cartID != 0 {
				if err := tx.Delete(&models.CartItem{}, l.cartID).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
	if errors.Is(err, errStock) {
		return badRequest(c, fmt.Sprintf("«%s» harydyndan ýeterlik ýok", short))
	}
	if err != nil {
		return err
	}

	out := []OrderDTO{}
	for _, id := range created {
		o, _ := h.loadOrder(id)
		h.notifyOrder(o.BusinessID, me, models.NotifyOrder, o)
		out = append(out, orderDTO(o, me))
	}
	return c.Status(fiber.StatusCreated).JSON(out)
}

func (h *Handler) pageOrders(c fiber.Ctx, q *gorm.DB) error {
	page, limit, offset := paging(c, 20)
	if st := c.Query("status"); st != "" {
		q = q.Where("status = ?", st)
	}
	var list []models.Order
	if err := q.Preload("Buyer").Preload("Business").Preload("Items", func(db *gorm.DB) *gorm.DB { return db.Order("id") }).
		Order("created_at DESC, id DESC").Offset(offset).Limit(limit + 1).Find(&list).Error; err != nil {
		return err
	}
	list, more := trimPage(list, limit)
	items := make([]OrderDTO, len(list))
	for i, o := range list {
		items[i] = orderDTO(o, viewerID(c))
	}
	return c.JSON(Page[OrderDTO]{Items: items, Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) myOrders(c fiber.Ctx) error {
	return h.pageOrders(c, h.db.Model(&models.Order{}).Where("buyer_id = ?", viewerID(c)))
}

func (h *Handler) businessOrders(c fiber.Ctx) error {
	me := viewerID(c)
	if !h.isBusiness(me) {
		return fail(c, fiber.StatusForbidden, "Bu bölüm diňe biznes hasaplary üçin")
	}
	return h.pageOrders(c, h.db.Model(&models.Order{}).Where("business_id = ?", me))
}

func (h *Handler) getOrder(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	o, err := h.loadOrder(id)
	me := viewerID(c)
	if err != nil || (o.BuyerID != me && o.BusinessID != me) {
		return notFound(c)
	}
	return c.JSON(orderDTO(o, me))
}

// setStatus moves an order to status, giving stock back on cancellation.
func (h *Handler) setStatus(o *models.Order, status string) error {
	return h.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&models.Order{}).Where("id = ? AND status = ?", o.ID, o.Status).Updates(map[string]any{"status": status, "updated_at": time.Now()})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return errNotFound // changed concurrently
		}
		if status == models.OrderCancelled {
			for _, it := range o.Items {
				if it.PinID != nil {
					if err := releaseStock(tx, *it.PinID, it.Quantity); err != nil {
						return err
					}
				}
			}
		}
		return nil
	})
}

func (h *Handler) cancelOrder(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	o, err := h.loadOrder(id)
	if err != nil || o.BuyerID != me {
		return notFound(c)
	}
	if o.Status != models.OrderNew {
		return badRequest(c, "Diňe täze sargydy ýatyryp bolýar")
	}
	if err := h.setStatus(&o, models.OrderCancelled); err != nil {
		return err
	}
	o, _ = h.loadOrder(id)
	h.notifyOrder(o.BusinessID, me, models.NotifyOrderStatus, o)
	return c.JSON(orderDTO(o, me))
}

func (h *Handler) updateOrderStatus(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	o, err := h.loadOrder(id)
	if err != nil || o.BusinessID != me {
		return notFound(c)
	}
	var req struct {
		Status string `json:"status"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if !slices.Contains(nextStatuses[o.Status], req.Status) {
		return badRequest(c, "Sargydyň ýagdaýyny beýle üýtgedip bolmaýar")
	}
	if err := h.setStatus(&o, req.Status); err != nil {
		return err
	}
	o, _ = h.loadOrder(id)
	h.notifyOrder(o.BuyerID, me, models.NotifyOrderStatus, o)
	return c.JSON(orderDTO(o, me))
}
