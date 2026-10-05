package api

import (
	"regexp"
	"strings"

	"github.com/gofiber/fiber/v3"
	"golang.org/x/crypto/bcrypt"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

var usernameRe = regexp.MustCompile(`^[a-z0-9._]{3,30}$`)

const DefaultBoardName = "Saklananlar"

type registerReq struct {
	Username string `json:"username"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type authResp struct {
	Token string `json:"token"`
	User  Me     `json:"user"`
}

func validEmail(e string) bool {
	at := strings.Index(e, "@")
	return at > 0 && strings.Contains(e[at:], ".") && !strings.ContainsAny(e, " \t") && len(e) <= 120
}

func validPassword(p string) string {
	if len(p) < 6 {
		return "Parol azyndan 6 simwol bolmaly"
	}
	if len(p) > 72 {
		return "Parol 72 simwoldan uzyn bolmaly däl"
	}
	return ""
}

func (h *Handler) register(c fiber.Ctx) error {
	var req registerReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	req.Username = strings.ToLower(strings.TrimSpace(req.Username))
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	req.Name = clean(req.Name, 60)

	switch {
	case !usernameRe.MatchString(req.Username):
		return badRequest(c, "Ulanyjy ady 3-30 simwol bolmaly: kiçi harplar, sanlar, nokat we aşaky çyzyk")
	case req.Name == "":
		return badRequest(c, "Adyňyzy ýazyň")
	case !validEmail(req.Email):
		return badRequest(c, "E-poçta nädogry")
	}
	if msg := validPassword(req.Password); msg != "" {
		return badRequest(c, msg)
	}

	var taken int64
	h.db.Model(&models.User{}).Where("username = ? OR email = ?", req.Username, req.Email).Count(&taken)
	if taken > 0 {
		return fail(c, fiber.StatusConflict, "Bu ulanyjy ady ýa-da e-poçta eýýäm hasaba alnan")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user := models.User{Username: req.Username, Name: req.Name, Email: req.Email, PasswordHash: string(hash)}
	if err := h.db.Create(&user).Error; err != nil {
		return fail(c, fiber.StatusConflict, "Bu ulanyjy ady ýa-da e-poçta eýýäm hasaba alnan")
	}
	h.db.Create(&models.Board{UserID: user.ID, Name: DefaultBoardName})
	return h.respondAuth(c, fiber.StatusCreated, user)
}

type loginReq struct {
	Login    string `json:"login"` // username or email
	Password string `json:"password"`
}

func (h *Handler) login(c fiber.Ctx) error {
	var req loginReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	login := strings.ToLower(strings.TrimSpace(req.Login))
	var user models.User
	err := h.db.Where("username = ? OR email = ?", login, login).First(&user).Error
	if err != nil || bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		return fail(c, fiber.StatusUnauthorized, "Login ýa-da parol nädogry")
	}
	return h.respondAuth(c, fiber.StatusOK, user)
}

func (h *Handler) respondAuth(c fiber.Ctx, status int, user models.User) error {
	token, err := h.issueToken(user.ID)
	if err != nil {
		return err
	}
	return c.Status(status).JSON(authResp{Token: token, User: h.me(user)})
}

func (h *Handler) getMe(c fiber.Ctx) error {
	var user models.User
	if err := h.db.First(&user, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	return c.JSON(h.me(user))
}

func (h *Handler) me(u models.User) Me {
	return Me{Profile: h.profile(u, u.ID), Email: u.Email}
}
