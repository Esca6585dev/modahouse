package api

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

// enrichPins turns pins (with User preloaded) into DTOs with counts and viewer state,
// using a fixed number of queries regardless of page size.
func (h *Handler) enrichPins(pins []models.Pin, viewer uint) []PinDTO {
	out := make([]PinDTO, len(pins))
	if len(pins) == 0 {
		return out
	}
	ids := make([]uint, len(pins))
	for i, p := range pins {
		ids[i] = p.ID
	}

	type count struct {
		PinID uint
		N     int64
	}
	likes, comments := map[uint]int64{}, map[uint]int64{}
	var rows []count
	h.db.Model(&models.Like{}).Select("pin_id, COUNT(*) AS n").Where("pin_id IN ?", ids).Group("pin_id").Scan(&rows)
	for _, r := range rows {
		likes[r.PinID] = r.N
	}
	rows = nil
	h.db.Model(&models.Comment{}).Select("pin_id, COUNT(*) AS n").Where("pin_id IN ?", ids).Group("pin_id").Scan(&rows)
	for _, r := range rows {
		comments[r.PinID] = r.N
	}

	liked := map[uint]bool{}
	saved := map[uint][]uint{}
	if viewer != 0 {
		var likedIDs []uint
		h.db.Model(&models.Like{}).Where("user_id = ? AND pin_id IN ?", viewer, ids).Pluck("pin_id", &likedIDs)
		for _, id := range likedIDs {
			liked[id] = true
		}
		var bp []models.BoardPin
		h.db.Model(&models.BoardPin{}).Select("board_pins.board_id, board_pins.pin_id").
			Joins("JOIN boards ON boards.id = board_pins.board_id").
			Where("boards.user_id = ? AND board_pins.pin_id IN ?", viewer, ids).Scan(&bp)
		for _, r := range bp {
			saved[r.PinID] = append(saved[r.PinID], r.BoardID)
		}
	}

	images := map[uint][]PinImageDTO{}
	var imgRows []models.PinImage
	h.db.Where("pin_id IN ?", ids).Order("pin_id, position, id").Find(&imgRows)
	for _, im := range imgRows {
		kind := im.Kind
		if kind == "" {
			kind = "image"
		}
		images[im.PinID] = append(images[im.PinID], PinImageDTO{Type: kind, PosterURL: im.PosterURL, Duration: im.Duration,
			URL: im.URL, Width: im.Width, Height: im.Height, Color: im.Color})
	}

	type ratingRow struct {
		PinID uint
		Avg   float64
		N     int64
	}
	ratings := map[uint]ratingRow{}
	var rRows []ratingRow
	h.db.Model(&models.Review{}).Select("pin_id, AVG(rating) AS avg, COUNT(*) AS n").Where("pin_id IN ?", ids).Group("pin_id").Scan(&rRows)
	for _, r := range rRows {
		ratings[r.PinID] = r
	}

	now := time.Now()
	for i, p := range pins {
		boards := saved[p.ID]
		if boards == nil {
			boards = []uint{}
		}
		imgs := images[p.ID]
		if len(imgs) == 0 {
			imgs = []PinImageDTO{{Type: "image", URL: p.ImageURL, Width: p.Width, Height: p.Height, Color: p.Color}}
		}
		mediaType := "image"
		if imgs[0].Type == "video" {
			mediaType = "video"
		}
		out[i] = PinDTO{
			ID: p.ID, Title: p.Title, Description: p.Description, Link: p.Link, Category: p.Category,
			Tags: splitTags(p.Tags), ImageURL: p.ImageURL, Width: p.Width, Height: p.Height, Color: p.Color,
			Author: brief(p.User), LikesCount: likes[p.ID], CommentsCount: comments[p.ID],
			Liked: liked[p.ID], SavedBoardIDs: boards, CreatedAt: p.CreatedAt,
			Images: imgs, MediaType: mediaType, Credit: p.Credit, Product: productDTO(p, now), ViewsCount: p.ViewsCount, OrdersCount: p.OrdersCount,
			Rating: round1(ratings[p.ID].Avg), ReviewsCount: ratings[p.ID].N,
		}
	}
	return out
}

func round1(v float64) float64 { return float64(int(v*10+0.5)) / 10 }

// productScope limits q to pins that are for sale.
func (h *Handler) productScope(q *gorm.DB) *gorm.DB {
	return q.Where("pins.price > 0 AND pins.user_id IN (?)", h.db.Model(&models.User{}).Select("id").Where("is_business = ?", true))
}

// pagePins runs q (already filtered/ordered) for the requested page.
func (h *Handler) pagePins(c fiber.Ctx, q *gorm.DB, defLimit int) error {
	page, limit, offset := paging(c, defLimit)
	var pins []models.Pin
	if err := q.Preload("User").Offset(offset).Limit(limit + 1).Find(&pins).Error; err != nil {
		return err
	}
	pins, more := trimPage(pins, limit)
	items := h.enrichPins(pins, viewerID(c))
	if c.Query("withComments") == "1" {
		h.attachComments(items, viewerID(c))
	}
	return c.JSON(Page[PinDTO]{Items: items, Page: page, Limit: limit, HasMore: more})
}

func searchText(p *models.Pin) string {
	return strings.ToLower(strings.Join([]string{p.Title, p.Description, p.Tags}, " "))
}

func escapeLike(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// listPins: GET /pins?q=&category=&feed=following
func (h *Handler) listPins(c fiber.Ctx) error {
	q := h.db.Model(&models.Pin{}).Order("pins.created_at DESC, pins.id DESC")
	if cat := c.Query("category"); cat != "" {
		q = q.Where("pins.category = ?", cat)
	}
	if term := strings.ToLower(strings.TrimSpace(c.Query("q"))); term != "" {
		for _, w := range strings.Fields(term) {
			q = q.Where(`pins.search_text LIKE ? ESCAPE '\'`, "%"+escapeLike(w)+"%")
		}
	}
	switch c.Query("type") {
	case "products":
		q = h.productScope(q)
	case "videos":
		q = q.Where("pins.has_video = ?", true)
	case "ideas":
		q = q.Where("NOT (pins.price > 0 AND pins.user_id IN (?))", h.db.Model(&models.User{}).Select("id").Where("is_business = ?", true))
	}
	if author := strings.ToLower(c.Query("author")); author != "" {
		q = q.Where("pins.user_id IN (?)", h.db.Model(&models.User{}).Select("id").Where("username = ?", author))
	}
	if tag := strings.ToLower(strings.TrimPrefix(strings.TrimSpace(c.Query("tag")), "#")); tag != "" {
		q = q.Where(`(',' || pins.tags || ',') LIKE ? ESCAPE '\'`, "%,"+escapeLike(tag)+",%")
	}
	q = h.viewerFilter(q, viewerID(c))
	if c.Query("feed") == "following" {
		me := viewerID(c)
		if me == 0 {
			return fail(c, fiber.StatusUnauthorized, "Ilki ulgama giriň")
		}
		q = q.Where("pins.user_id IN (?)", h.db.Model(&models.Follow{}).Select("following_id").Where("follower_id = ?", me))
	}
	return h.pagePins(c, q, 24)
}

func (h *Handler) loadPin(id uint) (models.Pin, error) {
	var p models.Pin
	err := h.db.Preload("User").First(&p, id).Error
	return p, err
}

func (h *Handler) getPin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	return c.JSON(h.enrichPins([]models.Pin{p}, viewerID(c))[0])
}

// similarPins: same category first, then everything else, newest first.
func (h *Handler) similarPins(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	q := h.db.Model(&models.Pin{}).Where("pins.id <> ?", p.ID).Clauses(clause.OrderBy{Expression: clause.Expr{
		SQL:                "CASE WHEN pins.category = ? THEN 0 ELSE 1 END, pins.created_at DESC, pins.id DESC",
		Vars:               []any{p.Category},
		WithoutParentheses: true,
	}})
	q = h.viewerFilter(q, viewerID(c))
	return h.pagePins(c, q, 20)
}

func (h *Handler) userPins(c fiber.Ctx) error {
	u, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	return h.pagePins(c, h.db.Model(&models.Pin{}).Where("pins.user_id = ?", u.ID).Order("pins.created_at DESC, pins.id DESC"), 24)
}

type pinFields struct {
	Title       *string `json:"title" form:"title"`
	Description *string `json:"description" form:"description"`
	Link        *string `json:"link" form:"link"`
	Category    *string `json:"category" form:"category"`
	Tags        *string `json:"tags" form:"tags"`
}

// apply validates and copies the provided fields onto p. It returns a user-facing error message.
func (f pinFields) apply(p *models.Pin) string {
	if f.Title != nil {
		p.Title = clean(*f.Title, 100)
	}
	if f.Description != nil {
		p.Description = clean(*f.Description, 1000)
	}
	if f.Link != nil {
		link := clean(*f.Link, 500)
		if link != "" {
			u, err := url.Parse(link)
			if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
				return "Baglanyşyk http:// ýa-da https:// bilen başlamaly"
			}
		}
		p.Link = link
	}
	if f.Category != nil {
		if !validCategory(*f.Category) {
			return "Kategoriýa nädogry"
		}
		p.Category = *f.Category
	}
	if f.Tags != nil || f.Description != nil {
		tags := splitTags(p.Tags)
		if f.Tags != nil {
			tags = splitTags(*f.Tags)
		}
		p.Tags = strings.Join(splitTags(strings.Join(append(tags, captionTags(p.Description)...), ",")), ",")
	}
	if p.Title == "" {
		return "Pine at beriň"
	}
	if p.Category == "" {
		return "Kategoriýa saýlaň"
	}
	p.SearchText = searchText(p)
	return ""
}

// createPin: multipart form with "images" (repeatable) or "image", pin fields,
// optional product fields (business accounts) and optional boardId.
func (h *Handler) createPin(c fiber.Ctx) error {
	files := formImages(c)
	if len(files) == 0 {
		return badRequest(c, "Surat saýlaň")
	}
	if len(files) > maxPinImages {
		return badRequest(c, fmt.Sprintf("Iň köp %d surat ýükläp bolýar", maxPinImages))
	}
	str := func(k string) *string { v := c.FormValue(k); return &v }
	fields := pinFields{Title: str("title"), Description: str("description"), Link: str("link"), Category: str("category"), Tags: str("tags")}
	pin := models.Pin{UserID: viewerID(c)}
	if msg := fields.apply(&pin); msg != "" {
		return badRequest(c, msg)
	}
	prod, msg := productFieldsFromForm(c)
	if msg != "" {
		return badRequest(c, msg)
	}
	if prod.touchesProduct() && !h.isBusiness(pin.UserID) {
		return fail(c, fiber.StatusForbidden, "Harydyň bahasyny diňe biznes hasaplary goýup bilýär")
	}
	if msg := prod.apply(&pin); msg != "" {
		return badRequest(c, msg)
	}
	if msg := finishListing(&pin); msg != "" {
		return badRequest(c, msg)
	}
	h.businessDefaults(&pin)

	var board *models.Board
	if raw := c.FormValue("boardId"); raw != "" {
		bid, _ := strconv.ParseUint(raw, 10, 64)
		var b models.Board
		if err := h.db.Where("id = ? AND user_id = ?", bid, pin.UserID).First(&b).Error; err != nil {
			return badRequest(c, "Tagta tapylmady")
		}
		board = &b
	}

	var images []models.PinImage
	removeAll := func() {
		for _, im := range images {
			h.store.Remove(im.URL)
			h.store.Remove(im.PosterURL)
		}
	}
	posters := formFiles(c, "posters")
	durations := c.Request().PostArgs().PeekMulti("durations")
	if form, err := c.MultipartForm(); err == nil {
		durations = nil
		for _, d := range form.Value["durations"] {
			durations = append(durations, []byte(d))
		}
	}
	videoIdx := 0
	mark := h.uploadMarker(pin.UserID)
	for i, fh := range files {
		if storage.IsVideo(fh) {
			im, msg := h.saveVideoMedia(fh, posters, durations, videoIdx, "pins")
			videoIdx++
			if msg != "" {
				removeAll()
				return badRequest(c, msg)
			}
			im.Position = i
			images = append(images, im)
			pin.HasVideo = true
			continue
		}
		if fh.Size > int64(h.cfg.MaxUploadMB)*1024*1024 {
			removeAll()
			return badRequest(c, fmt.Sprintf("Surat gaty uly (iň köp %d MB)", h.cfg.MaxUploadMB))
		}
		saved, err := h.store.SaveImageMarked(fh, "pins", mark)
		if err != nil {
			removeAll()
			return badRequest(c, err.Error())
		}
		images = append(images, models.PinImage{Kind: "image", URL: saved.URL, Width: saved.Width, Height: saved.Height,
			Color: saved.Color, Position: i, Watermarked: saved.Watermarked})
	}
	cover := images[0]
	pin.ImageURL, pin.Width, pin.Height, pin.Color = coverImage(cover), cover.Width, cover.Height, cover.Color

	err := h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&pin).Error; err != nil {
			return err
		}
		for i := range images {
			images[i].PinID = pin.ID
		}
		if err := tx.Create(&images).Error; err != nil {
			return err
		}
		if board != nil {
			return tx.Create(&models.BoardPin{BoardID: board.ID, PinID: pin.ID}).Error
		}
		return nil
	})
	if err != nil {
		removeAll()
		return err
	}
	p, _ := h.loadPin(pin.ID)
	return c.Status(fiber.StatusCreated).JSON(h.enrichPins([]models.Pin{p}, pin.UserID)[0])
}

func (h *Handler) ownPin(c fiber.Ctx) (models.Pin, error) {
	id, ok := idParam(c, "id")
	if !ok {
		return models.Pin{}, errNotFound
	}
	p, err := h.loadPin(id)
	if err != nil {
		return p, errNotFound
	}
	if p.UserID != viewerID(c) {
		return p, errForbidden
	}
	return p, nil
}

func (h *Handler) updatePin(c fiber.Ctx) error {
	p, err := h.ownPin(c)
	if err != nil {
		return err
	}
	var f struct {
		pinFields
		productFields
	}
	if err := c.Bind().Body(&f); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if msg := f.pinFields.apply(&p); msg != "" {
		return badRequest(c, msg)
	}
	if f.productFields.touchesProduct() && !p.User.IsBusiness {
		return fail(c, fiber.StatusForbidden, "Harydyň bahasyny diňe biznes hasaplary goýup bilýär")
	}
	if msg := f.productFields.apply(&p); msg != "" {
		return badRequest(c, msg)
	}
	if msg := finishListing(&p); msg != "" {
		return badRequest(c, msg)
	}
	if err := h.db.Omit("User").Save(&p).Error; err != nil {
		return err
	}
	return c.JSON(h.enrichPins([]models.Pin{p}, p.UserID)[0])
}

func (h *Handler) deletePin(c fiber.Ctx) error {
	p, err := h.ownPin(c)
	if err != nil {
		return err
	}
	if err := h.removePin(p); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

// removePin deletes a pin with everything attached to it and its media files.
func (h *Handler) removePin(p models.Pin) error {
	var imgs []models.PinImage
	h.db.Where("pin_id = ?", p.ID).Find(&imgs)
	err := h.db.Transaction(func(tx *gorm.DB) error {
		// Explicit cleanup keeps SQLite and Postgres consistent even without FK cascades.
		for _, m := range []any{&models.BoardPin{}, &models.Like{}, &models.Comment{}, &models.Notification{},
			&models.PinImage{}, &models.PinView{}, &models.CartItem{}, &models.Review{},
			&models.PinFeature{}, &models.HiddenPin{}, &models.Report{}} {
			if err := tx.Where("pin_id = ?", p.ID).Delete(m).Error; err != nil {
				return err
			}
		}
		// Orders keep their snapshot; only the link to the pin goes away.
		if err := tx.Model(&models.OrderItem{}).Where("pin_id = ?", p.ID).Update("pin_id", nil).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.Story{}).Where("pin_id = ?", p.ID).Update("pin_id", nil).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.Message{}).Where("pin_id = ?", p.ID).Update("pin_id", nil).Error; err != nil {
			return err
		}
		return tx.Delete(&models.Pin{}, p.ID).Error
	})
	if err != nil {
		return err
	}
	removed := map[string]bool{}
	for _, im := range imgs {
		if !removed[im.URL] && !h.urlInOrders(im.URL) {
			removed[im.URL] = true
			h.store.Remove(im.URL)
		}
		if im.PosterURL != "" && !removed[im.PosterURL] && !h.urlInOrders(im.PosterURL) {
			removed[im.PosterURL] = true
			h.store.Remove(im.PosterURL)
		}
	}
	if !removed[p.ImageURL] && !h.urlInOrders(p.ImageURL) {
		h.store.Remove(p.ImageURL)
	}
	h.visual.remove(p.ID)
	return nil
}

func (h *Handler) likeState(c fiber.Ctx, pinID uint) error {
	var n int64
	h.db.Model(&models.Like{}).Where("pin_id = ?", pinID).Count(&n)
	var mine int64
	h.db.Model(&models.Like{}).Where("pin_id = ? AND user_id = ?", pinID, viewerID(c)).Count(&mine)
	return c.JSON(fiber.Map{"liked": mine > 0, "likesCount": n})
}

func (h *Handler) likePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	p, err := h.loadPin(id)
	if err != nil {
		return notFound(c)
	}
	me := viewerID(c)
	l := models.Like{UserID: me, PinID: p.ID}
	res := h.db.Where(&l).FirstOrCreate(&l)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		h.notify(p.UserID, me, models.NotifyLike, &p.ID)
	}
	return h.likeState(c, p.ID)
}

func (h *Handler) unlikePin(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	if res := h.db.Where("user_id = ? AND pin_id = ?", viewerID(c), id).Delete(&models.Like{}); res.RowsAffected > 0 {
		var owner uint
		h.db.Model(&models.Pin{}).Where("id = ?", id).Pluck("user_id", &owner)
		h.unnotify(owner, viewerID(c), models.NotifyLike, &id)
	}
	return h.likeState(c, id)
}

func (h *Handler) isBusiness(userID uint) bool {
	var n int64
	h.db.Model(&models.User{}).Where("id = ? AND is_business = ?", userID, true).Count(&n)
	return n > 0
}

// urlInOrders keeps images that past orders still show.
func (h *Handler) urlInOrders(url string) bool {
	var n int64
	h.db.Model(&models.OrderItem{}).Where("image_url = ?", url).Count(&n)
	return n > 0
}

// attachComments adds the two newest comments to each pin (Instagram feed view).
func (h *Handler) attachComments(items []PinDTO, viewer uint) {
	for i := range items {
		var list []models.Comment
		h.db.Preload("User").Where("pin_id = ?", items[i].ID).Order("created_at DESC, id DESC").Limit(2).Find(&list)
		items[i].LatestComments = make([]CommentDTO, len(list))
		for j := range list {
			// oldest of the two first, like Instagram
			items[i].LatestComments[len(list)-1-j] = commentDTO(list[j], viewer, items[i].Author.ID)
		}
	}
}
