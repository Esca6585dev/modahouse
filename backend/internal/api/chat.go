package api

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/adaptor"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/chatcrypt"
	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

const (
	maxMessageRunes = 2000
	maxDocBytes     = 20 << 20
	chatFileTTL     = 24 * time.Hour
)

type ChatUser struct {
	ID         uint   `json:"id"`
	Username   string `json:"username"`
	Name       string `json:"name"`
	AvatarURL  string `json:"avatarUrl"`
	IsBusiness bool   `json:"isBusiness"`
	Verified   bool   `json:"verified"`
}

type Attachment struct {
	URL      string `json:"url"`
	Name     string `json:"name"`
	Size     int64  `json:"size"`
	MimeType string `json:"mimeType"`
	Width    int    `json:"width"`
	Height   int    `json:"height"`
}

type PinPreview struct {
	ID          uint   `json:"id"`
	Title       string `json:"title"`
	ImageURL    string `json:"imageUrl"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
	Color       string `json:"color"`
	Price       int    `json:"price"`
	ListingType string `json:"listingType"`
}

type MessageDTO struct {
	ID         uint        `json:"id"`
	ChatID     uint        `json:"chatId"`
	Sender     ChatUser    `json:"sender"`
	Kind       string      `json:"kind"`
	Text       string      `json:"text"`
	Attachment *Attachment `json:"attachment"`
	Pin        *PinPreview `json:"pin"`
	ClientID   string      `json:"clientId"`
	Mine       bool        `json:"mine"`
	Read       bool        `json:"read"`
	Deleted    bool        `json:"deleted"`
	CreatedAt  time.Time   `json:"createdAt"`
}

type ChatDTO struct {
	ID          uint        `json:"id"`
	Other       ChatUser    `json:"other"`
	LastMessage *MessageDTO `json:"lastMessage"`
	UnreadCount int64       `json:"unreadCount"`
	Blocked     bool        `json:"blocked"`
	UpdatedAt   time.Time   `json:"updatedAt"`
}

func chatUser(u models.User) ChatUser {
	return ChatUser{ID: u.ID, Username: u.Username, Name: u.Name, AvatarURL: u.AvatarURL, IsBusiness: u.IsBusiness, Verified: u.Verified}
}

// other returns the other member's id and the read marks (mine, theirs).
func chatSide(ch models.Chat, me uint) (other, myRead, theirRead uint) {
	if ch.UserAID == me {
		return ch.UserBID, ch.ReadA, ch.ReadB
	}
	return ch.UserAID, ch.ReadB, ch.ReadA
}

// --- signed links for private chat files ---

var chatFileRe = regexp.MustCompile(`^[a-f0-9]{24}\.[a-z0-9]{1,5}$`)

func (h *Handler) chatFileKey() []byte {
	sum := sha256.Sum256([]byte("chat-files|" + h.cfg.JWTSecret))
	return sum[:]
}

func (h *Handler) signChatFile(name string, exp int64) string {
	m := hmac.New(sha256.New, h.chatFileKey())
	fmt.Fprintf(m, "%s|%d", name, exp)
	return hex.EncodeToString(m.Sum(nil))[:32]
}

// chatFileURL is valid for 24–25 hours; the expiry is rounded to the hour so
// the same link (and the browser cache) is reused within an hour.
func (h *Handler) chatFileURL(name string) string {
	exp := time.Now().Add(chatFileTTL).Truncate(time.Hour).Add(time.Hour).Unix()
	return fmt.Sprintf("/api/chat-files/%s?exp=%d&sig=%s", name, exp, h.signChatFile(name, exp))
}

func (h *Handler) serveChatFile(c fiber.Ctx) error {
	name := c.Params("name")
	exp, err := strconv.ParseInt(c.Query("exp"), 10, 64)
	if err != nil || !chatFileRe.MatchString(name) || time.Now().Unix() > exp ||
		!hmac.Equal([]byte(c.Query("sig")), []byte(h.signChatFile(name, exp))) {
		return notFound(c)
	}
	path, ok := h.store.PrivatePath(storage.PrivateChat, name)
	if !ok {
		return notFound(c)
	}
	ct := mime.TypeByExtension(filepath.Ext(name))
	if ct == "" {
		ct = "application/octet-stream"
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return notFound(c)
	}
	data, err := chatcrypt.DecryptFile(raw)
	if err != nil {
		log.Printf("chat file %s: %v", name, err)
		return notFound(c)
	}
	c.Set("X-Content-Type-Options", "nosniff")
	c.Set(fiber.HeaderCacheControl, "private, max-age=3600")
	if !strings.HasPrefix(ct, "image/") && !strings.HasPrefix(ct, "video/") && !strings.HasPrefix(ct, "audio/") {
		c.Set(fiber.HeaderContentDisposition, "attachment")
	}
	// ServeContent answers Range requests, so videos can be seeked.
	mod := time.Time{}
	if st, err := os.Stat(path); err == nil {
		mod = st.ModTime()
	}
	return adaptor.HTTPHandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", ct)
		http.ServeContent(w, r, name, mod, bytes.NewReader(data))
	})(c)
}

// --- DTOs ---

func (h *Handler) messageDTOs(ch models.Chat, msgs []models.Message, viewer uint) []MessageDTO {
	_, _, theirRead := chatSide(ch, viewer)
	out := make([]MessageDTO, len(msgs))
	for i, m := range msgs {
		d := MessageDTO{ID: m.ID, ChatID: m.ChatID, Sender: chatUser(m.Sender), Kind: m.Kind, Text: m.Text,
			ClientID: m.ClientID, Mine: m.SenderID == viewer, Deleted: m.Deleted, CreatedAt: m.CreatedAt}
		if d.Mine {
			d.Read = m.ID <= theirRead
		} else {
			d.Read = true
		}
		if !m.Deleted {
			if m.File != "" {
				d.Attachment = &Attachment{URL: h.chatFileURL(m.File), Name: m.FileName, Size: m.FileSize,
					MimeType: m.FileMime, Width: m.Width, Height: m.Height}
			}
			if m.Pin != nil {
				d.Pin = &PinPreview{ID: m.Pin.ID, Title: m.Pin.Title, ImageURL: m.Pin.ImageURL, Width: m.Pin.Width,
					Height: m.Pin.Height, Color: m.Pin.Color, Price: m.Pin.Price, ListingType: m.Pin.ListingType}
			}
		}
		out[i] = d
	}
	return out
}

func (h *Handler) chatDTOs(chats []models.Chat, viewer uint) []ChatDTO {
	out := make([]ChatDTO, len(chats))
	for i, ch := range chats {
		otherID, myRead, _ := chatSide(ch, viewer)
		other := ch.UserA
		if otherID == ch.UserBID {
			other = ch.UserB
		}
		d := ChatDTO{ID: ch.ID, Other: chatUser(other), Blocked: h.isBlockedBetween(viewer, otherID), UpdatedAt: ch.UpdatedAt}
		if ch.LastID != 0 {
			var m models.Message
			if h.db.Preload("Sender").Preload("Pin").First(&m, ch.LastID).Error == nil {
				d.LastMessage = &h.messageDTOs(ch, []models.Message{m}, viewer)[0]
			}
		}
		h.db.Model(&models.Message{}).Where("chat_id = ? AND sender_id <> ? AND id > ? AND deleted = ?",
			ch.ID, viewer, myRead, false).Count(&d.UnreadCount)
		out[i] = d
	}
	return out
}

// loadChat returns a chat the viewer belongs to.
func (h *Handler) loadChat(c fiber.Ctx) (models.Chat, error) {
	id, ok := idParam(c, "id")
	if !ok {
		return models.Chat{}, errNotFound
	}
	var ch models.Chat
	me := viewerID(c)
	if h.db.Preload("UserA").Preload("UserB").Where("id = ? AND (user_a_id = ? OR user_b_id = ?)", id, me, me).
		First(&ch).Error != nil {
		return ch, errNotFound
	}
	return ch, nil
}

// --- handlers ---

func (h *Handler) listChats(c fiber.Ctx) error {
	page, limit, offset := paging(c, 30)
	me := viewerID(c)
	var chats []models.Chat
	if err := h.db.Preload("UserA").Preload("UserB").
		Where("(user_a_id = ? OR user_b_id = ?) AND last_id > 0", me, me).
		Order("updated_at DESC, id DESC").Offset(offset).Limit(limit + 1).Find(&chats).Error; err != nil {
		return err
	}
	chats, more := trimPage(chats, limit)
	return c.JSON(Page[ChatDTO]{Items: h.chatDTOs(chats, me), Page: page, Limit: limit, HasMore: more})
}

func (h *Handler) openChat(c fiber.Ctx) error {
	var req struct {
		Username string `json:"username"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	var other models.User
	username := strings.ToLower(strings.TrimSpace(strings.TrimPrefix(req.Username, "@")))
	if username == "" || h.db.Where("username = ?", username).First(&other).Error != nil {
		return notFound(c)
	}
	if other.ID == me {
		return badRequest(c, "Özüňize ýazyp bilmersiňiz")
	}
	if h.isBlockedBetween(me, other.ID) || other.Suspended {
		return fail(c, fiber.StatusForbidden, "Bu ulanyja ýazyp bolmaýar")
	}
	a, b := min(me, other.ID), max(me, other.ID)
	ch := models.Chat{UserAID: a, UserBID: b}
	res := h.db.Where("user_a_id = ? AND user_b_id = ?", a, b).FirstOrCreate(&ch)
	if res.Error != nil {
		return res.Error
	}
	h.db.Preload("UserA").Preload("UserB").First(&ch, ch.ID)
	status := fiber.StatusOK
	if res.RowsAffected > 0 {
		status = fiber.StatusCreated
	}
	return c.Status(status).JSON(h.chatDTOs([]models.Chat{ch}, me)[0])
}

func (h *Handler) getChat(c fiber.Ctx) error {
	ch, err := h.loadChat(c)
	if err != nil {
		return err
	}
	return c.JSON(h.chatDTOs([]models.Chat{ch}, viewerID(c))[0])
}

func (h *Handler) chatMessages(c fiber.Ctx) error {
	ch, err := h.loadChat(c)
	if err != nil {
		return err
	}
	limit := fiber.Query[int](c, "limit", 30)
	if limit < 1 || limit > 50 {
		limit = 30
	}
	q := h.db.Preload("Sender").Preload("Pin").Where("chat_id = ?", ch.ID)
	if before := fiber.Query[int](c, "before", 0); before > 0 {
		q = q.Where("id < ?", before)
	}
	var msgs []models.Message
	if err := q.Order("id DESC").Limit(limit + 1).Find(&msgs).Error; err != nil {
		return err
	}
	msgs, more := trimPage(msgs, limit)
	for i, j := 0, len(msgs)-1; i < j; i, j = i+1, j-1 { // oldest first
		msgs[i], msgs[j] = msgs[j], msgs[i]
	}
	return c.JSON(fiber.Map{"items": h.messageDTOs(ch, msgs, viewerID(c)), "hasMore": more})
}

// chatFile checks an uploaded chat file and returns its kind ("image" or "file"),
// extension, MIME type and image size.
func (h *Handler) chatFile(name string, data []byte) (kind, ext, mimeType string, w, hgt int, msg string) {
	sniff := http.DetectContentType(data)
	switch sniff {
	case "image/jpeg", "image/png", "image/gif", "image/webp":
		if len(data) > h.cfg.MaxUploadMB<<20 {
			return "", "", "", 0, 0, fmt.Sprintf("Surat gaty uly (iň köp %d MB)", h.cfg.MaxUploadMB)
		}
		cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
		if err != nil || cfg.Width*cfg.Height > 40_000_000 {
			return "", "", "", 0, 0, "Surat açylmady"
		}
		ext := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/gif": ".gif", "image/webp": ".webp"}[sniff]
		return "image", ext, sniff, cfg.Width, cfg.Height, ""
	}
	ext = strings.ToLower(filepath.Ext(name))
	type rule struct {
		mime  string
		check func([]byte) bool
		limit int
	}
	isZip := func(b []byte) bool { return bytes.HasPrefix(b, []byte("PK\x03\x04")) }
	isOLE := func(b []byte) bool { return bytes.HasPrefix(b, []byte{0xD0, 0xCF, 0x11, 0xE0}) }
	video := h.cfg.MaxVideoMB << 20
	rules := map[string]rule{
		".pdf":  {"application/pdf", func(b []byte) bool { return bytes.HasPrefix(b, []byte("%PDF")) }, maxDocBytes},
		".docx": {"application/vnd.openxmlformats-officedocument.wordprocessingml.document", isZip, maxDocBytes},
		".xlsx": {"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", isZip, maxDocBytes},
		".pptx": {"application/vnd.openxmlformats-officedocument.presentationml.presentation", isZip, maxDocBytes},
		".doc":  {"application/msword", isOLE, maxDocBytes},
		".xls":  {"application/vnd.ms-excel", isOLE, maxDocBytes},
		".ppt":  {"application/vnd.ms-powerpoint", isOLE, maxDocBytes},
		".zip":  {"application/zip", isZip, maxDocBytes},
		".txt":  {"text/plain", func(b []byte) bool { return strings.HasPrefix(http.DetectContentType(b), "text/plain") }, maxDocBytes},
		".mp3": {"audio/mpeg", func(b []byte) bool {
			return bytes.HasPrefix(b, []byte("ID3")) || (len(b) > 1 && b[0] == 0xFF && b[1]&0xE0 == 0xE0)
		}, maxDocBytes},
		".m4a":  {"audio/mp4", func(b []byte) bool { return len(b) > 8 && string(b[4:8]) == "ftyp" }, maxDocBytes},
		".ogg":  {"audio/ogg", func(b []byte) bool { return bytes.HasPrefix(b, []byte("OggS")) }, maxDocBytes},
		".mp4":  {"video/mp4", func(b []byte) bool { return len(b) > 8 && string(b[4:8]) == "ftyp" }, video},
		".mov":  {"video/mp4", func(b []byte) bool { return len(b) > 8 && string(b[4:8]) == "ftyp" }, video},
		".webm": {"video/webm", func(b []byte) bool { return bytes.HasPrefix(b, []byte{0x1A, 0x45, 0xDF, 0xA3}) }, video},
	}
	r, ok := rules[ext]
	if !ok || !r.check(data) {
		return "", "", "", 0, 0, "Bu faýl görnüşini ugradyp bolmaýar"
	}
	if len(data) > r.limit {
		return "", "", "", 0, 0, fmt.Sprintf("Faýl gaty uly (iň köp %d MB)", r.limit>>20)
	}
	if ext == ".mov" {
		ext = ".mp4"
	}
	return "file", ext, r.mime, 0, 0, ""
}

func cleanFileName(name string) string {
	name = filepath.Base(strings.ReplaceAll(name, `\`, "/"))
	name = strings.Map(func(r rune) rune {
		if r < 32 || r == '"' {
			return -1
		}
		return r
	}, name)
	if name == "" || name == "." || name == "/" {
		name = "faýl"
	}
	return clean(name, 200)
}

func (h *Handler) sendMessage(c fiber.Ctx) error {
	ch, err := h.loadChat(c)
	if err != nil {
		return err
	}
	me := viewerID(c)
	otherID, _, _ := chatSide(ch, me)
	if h.isBlockedBetween(me, otherID) {
		return fail(c, fiber.StatusForbidden, "Bu ulanyja ýazyp bolmaýar")
	}

	msg := models.Message{ChatID: ch.ID, SenderID: me, Kind: "text"}
	var fileData []byte
	var fileName string
	if strings.HasPrefix(c.Get(fiber.HeaderContentType), fiber.MIMEMultipartForm) {
		msg.Text = c.FormValue("text")
		msg.ClientID = c.FormValue("clientId")
		fh, err := c.FormFile("file")
		if err != nil {
			return badRequest(c, "Faýl saýlaň")
		}
		f, err := fh.Open()
		if err != nil {
			return err
		}
		fileData, err = io.ReadAll(io.LimitReader(f, int64(max(h.cfg.MaxVideoMB, 20)+1)<<20))
		f.Close()
		if err != nil {
			return err
		}
		fileName = fh.Filename
	} else {
		var req struct {
			Text     string `json:"text"`
			PinID    uint   `json:"pinId"`
			ClientID string `json:"clientId"`
		}
		if err := c.Bind().Body(&req); err != nil {
			return badRequest(c, "Nädogry maglumat")
		}
		msg.Text, msg.ClientID = req.Text, req.ClientID
		if req.PinID != 0 {
			var p models.Pin
			if h.db.Select("id").First(&p, req.PinID).Error != nil {
				return badRequest(c, "Post tapylmady")
			}
			msg.Kind, msg.PinID = "pin", &p.ID
		}
	}
	msg.Text = strings.TrimSpace(strings.ToValidUTF8(msg.Text, ""))
	if utf8.RuneCountInString(msg.Text) > maxMessageRunes {
		return badRequest(c, fmt.Sprintf("Habar %d simwoldan uzyn bolmaly däl", maxMessageRunes))
	}
	msg.ClientID = clean(msg.ClientID, 64)

	if fileData != nil {
		kind, ext, mimeType, w, hgt, problem := h.chatFile(fileName, fileData)
		if problem != "" {
			return badRequest(c, problem)
		}
		name, err := h.store.SavePrivate(storage.PrivateChat, chatcrypt.EncryptFile(fileData), ext)
		if err != nil {
			return err
		}
		msg.Kind, msg.File, msg.FileMime, msg.FileSize, msg.Width, msg.Height = kind, name, mimeType, int64(len(fileData)), w, hgt
		msg.FileName = cleanFileName(fileName)
	}
	if msg.Kind == "text" && msg.Text == "" {
		return badRequest(c, "Habar ýazyň")
	}

	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&msg).Error; err != nil {
			return err
		}
		read := "read_a"
		if ch.UserBID == me {
			read = "read_b"
		}
		// Sending also means the sender has read everything before it.
		return tx.Model(&models.Chat{}).Where("id = ?", ch.ID).
			Updates(map[string]any{"last_id": msg.ID, "updated_at": msg.CreatedAt, read: msg.ID}).Error
	})
	if err != nil {
		if msg.File != "" {
			h.store.RemovePrivate(storage.PrivateChat, msg.File)
		}
		return err
	}
	h.db.Preload("Sender").Preload("Pin").First(&msg, msg.ID)
	h.db.First(&ch, ch.ID)
	for _, uid := range []uint{ch.UserAID, ch.UserBID} {
		h.hub.publish(uid, "message", fiber.Map{"chatId": ch.ID, "message": h.messageDTOs(ch, []models.Message{msg}, uid)[0]})
	}
	return c.Status(fiber.StatusCreated).JSON(h.messageDTOs(ch, []models.Message{msg}, me)[0])
}

func (h *Handler) readChat(c fiber.Ctx) error {
	ch, err := h.loadChat(c)
	if err != nil {
		return err
	}
	var req struct {
		MessageID uint `json:"messageId"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	upTo := min(req.MessageID, ch.LastID)
	if req.MessageID == 0 {
		upTo = ch.LastID
	}
	col := "read_a"
	if ch.UserBID == me {
		col = "read_b"
	}
	// Read marks only move forward.
	res := h.db.Model(&models.Chat{}).Where("id = ? AND "+col+" < ?", ch.ID, upTo).Update(col, upTo)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		ev := fiber.Map{"chatId": ch.ID, "userId": me, "messageId": upTo}
		h.hub.publish(ch.UserAID, "read", ev)
		h.hub.publish(ch.UserBID, "read", ev)
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) typing(c fiber.Ctx) error {
	ch, err := h.loadChat(c)
	if err != nil {
		return err
	}
	me := viewerID(c)
	other, _, _ := chatSide(ch, me)
	if !h.isBlockedBetween(me, other) {
		h.hub.publish(other, "typing", fiber.Map{"chatId": ch.ID, "userId": me})
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) deleteMessage(c fiber.Ctx) error {
	id, ok := idParam(c, "id")
	if !ok {
		return notFound(c)
	}
	var m models.Message
	if h.db.First(&m, id).Error != nil {
		return notFound(c)
	}
	if m.SenderID != viewerID(c) {
		return forbidden(c)
	}
	if !m.Deleted {
		if m.File != "" {
			h.store.RemovePrivate(storage.PrivateChat, m.File)
		}
		if err := h.db.Model(&m).Updates(map[string]any{"deleted": true, "text": "", "file": "", "file_name": "",
			"file_mime": "", "file_size": 0, "width": 0, "height": 0, "pin_id": nil}).Error; err != nil {
			return err
		}
		var ch models.Chat
		if h.db.First(&ch, m.ChatID).Error == nil {
			ev := fiber.Map{"chatId": ch.ID, "messageId": m.ID}
			h.hub.publish(ch.UserAID, "message_deleted", ev)
			h.hub.publish(ch.UserBID, "message_deleted", ev)
		}
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) chatUnreadCount(c fiber.Ctx) error {
	me := viewerID(c)
	var n int64
	h.db.Model(&models.Message{}).
		Joins("JOIN chats ON chats.id = messages.chat_id").
		Where("messages.sender_id <> ? AND messages.deleted = ?", me, false).
		Where("(chats.user_a_id = ? AND messages.id > chats.read_a) OR (chats.user_b_id = ? AND messages.id > chats.read_b)", me, me).
		Count(&n)
	return c.JSON(fiber.Map{"count": n})
}
