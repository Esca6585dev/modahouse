package api

import (
	"io"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/ai"
)

// aiSuggest: POST /ai/suggest (multipart or JSON) — Turkmen copy for a new post.
func (h *Handler) aiSuggest(c fiber.Ctx) error {
	req := ai.Request{
		ListingType: c.FormValue("listingType"), Category: c.FormValue("category"),
		Title: clean(c.FormValue("title"), 100), Notes: clean(c.FormValue("notes"), 500),
	}
	if len(c.Body()) > 0 && c.Get(fiber.HeaderContentType) == fiber.MIMEApplicationJSON {
		var body struct {
			ListingType, Category, Title, Notes string
		}
		if err := c.Bind().Body(&body); err != nil {
			return badRequest(c, "Nädogry maglumat")
		}
		req = ai.Request{ListingType: body.ListingType, Category: body.Category, Title: clean(body.Title, 100), Notes: clean(body.Notes, 500)}
	}
	switch req.ListingType {
	case "", ListingPost, ListingSale, ListingRent, ListingCustom:
	default:
		return badRequest(c, "Post görnüşi nädogry")
	}
	if fh, err := c.FormFile("image"); err == nil {
		if fh.Size > int64(h.cfg.MaxUploadMB)*1024*1024 {
			return badRequest(c, "Surat gaty uly")
		}
		if f, err := fh.Open(); err == nil {
			req.Image, _ = io.ReadAll(f)
			f.Close()
		}
	}
	return c.JSON(h.ai.Suggest(c.Context(), req))
}

func (h *Handler) aiStatus(c fiber.Ctx) error {
	return c.JSON(fiber.Map{"enabled": h.ai.Enabled()})
}
