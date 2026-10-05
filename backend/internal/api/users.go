package api

import (
	"strings"

	"github.com/gofiber/fiber/v3"
	"golang.org/x/crypto/bcrypt"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

func (h *Handler) profile(u models.User, viewer uint) Profile {
	p := Profile{UserBrief: brief(u), Bio: u.Bio, IsMe: viewer == u.ID, CreatedAt: u.CreatedAt}
	h.db.Model(&models.Follow{}).Where("following_id = ?", u.ID).Count(&p.FollowersCount)
	h.db.Model(&models.Follow{}).Where("follower_id = ?", u.ID).Count(&p.FollowingCount)
	h.db.Model(&models.Pin{}).Where("user_id = ?", u.ID).Count(&p.PinsCount)
	if viewer != 0 && viewer != u.ID {
		var n int64
		h.db.Model(&models.Follow{}).Where("follower_id = ? AND following_id = ?", viewer, u.ID).Count(&n)
		p.IsFollowing = n > 0
	}
	return p
}

func (h *Handler) findUser(c fiber.Ctx) (models.User, bool) {
	var u models.User
	err := h.db.Where("username = ?", strings.ToLower(c.Params("username"))).First(&u).Error
	return u, err == nil
}

func (h *Handler) getUser(c fiber.Ctx) error {
	u, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	return c.JSON(h.profile(u, viewerID(c)))
}

type updateMeReq struct {
	Name     *string `json:"name"`
	Bio      *string `json:"bio"`
	Username *string `json:"username"`
}

func (h *Handler) updateMe(c fiber.Ctx) error {
	var req updateMeReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	if req.Name != nil {
		if u.Name = clean(*req.Name, 60); u.Name == "" {
			return badRequest(c, "Adyňyzy ýazyň")
		}
	}
	if req.Bio != nil {
		u.Bio = clean(*req.Bio, 300)
	}
	if req.Username != nil {
		name := strings.ToLower(strings.TrimSpace(*req.Username))
		if !usernameRe.MatchString(name) {
			return badRequest(c, "Ulanyjy ady 3-30 simwol bolmaly: kiçi harplar, sanlar, nokat we aşaky çyzyk")
		}
		var taken int64
		h.db.Model(&models.User{}).Where("username = ? AND id <> ?", name, u.ID).Count(&taken)
		if taken > 0 {
			return fail(c, fiber.StatusConflict, "Bu ulanyjy ady eýýäm alnan")
		}
		u.Username = name
	}
	if err := h.db.Save(&u).Error; err != nil {
		return err
	}
	return c.JSON(h.me(u))
}

func (h *Handler) uploadAvatar(c fiber.Ctx) error {
	fh, err := c.FormFile("avatar")
	if err != nil {
		return badRequest(c, "Surat saýlaň")
	}
	saved, err := h.store.SaveImage(fh, "avatars")
	if err != nil {
		return badRequest(c, err.Error())
	}
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		h.store.Remove(saved.URL)
		return notFound(c)
	}
	old := u.AvatarURL
	u.AvatarURL = saved.URL
	if err := h.db.Save(&u).Error; err != nil {
		return err
	}
	h.store.Remove(old)
	return c.JSON(h.me(u))
}

func (h *Handler) deleteAvatar(c fiber.Ctx) error {
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	h.store.Remove(u.AvatarURL)
	u.AvatarURL = ""
	h.db.Save(&u)
	return c.JSON(h.me(u))
}

type passwordReq struct {
	CurrentPassword string `json:"currentPassword"`
	NewPassword     string `json:"newPassword"`
}

func (h *Handler) changePassword(c fiber.Ctx) error {
	var req passwordReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	var u models.User
	if err := h.db.First(&u, viewerID(c)).Error; err != nil {
		return notFound(c)
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.CurrentPassword)) != nil {
		return badRequest(c, "Häzirki parol nädogry")
	}
	if msg := validPassword(req.NewPassword); msg != "" {
		return badRequest(c, msg)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	h.db.Model(&u).Update("password_hash", string(hash))
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *Handler) follow(c fiber.Ctx) error {
	target, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	if target.ID == me {
		return badRequest(c, "Özüňizi yzarlap bilmersiňiz")
	}
	f := models.Follow{FollowerID: me, FollowingID: target.ID}
	res := h.db.Where(&f).FirstOrCreate(&f)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		h.notify(target.ID, me, models.NotifyFollow, nil)
	}
	return c.JSON(h.profile(target, me))
}

func (h *Handler) unfollow(c fiber.Ctx) error {
	target, ok := h.findUser(c)
	if !ok {
		return notFound(c)
	}
	me := viewerID(c)
	h.db.Where("follower_id = ? AND following_id = ?", me, target.ID).Delete(&models.Follow{})
	return c.JSON(h.profile(target, me))
}

// followList serves /users/:username/followers and /following.
func (h *Handler) followList(followers bool) fiber.Handler {
	return func(c fiber.Ctx) error {
		target, ok := h.findUser(c)
		if !ok {
			return notFound(c)
		}
		page, limit, offset := paging(c, 30)
		q := h.db.Model(&models.User{}).Order("follows.created_at DESC").Offset(offset).Limit(limit + 1)
		if followers {
			q = q.Joins("JOIN follows ON follows.follower_id = users.id").Where("follows.following_id = ?", target.ID)
		} else {
			q = q.Joins("JOIN follows ON follows.following_id = users.id").Where("follows.follower_id = ?", target.ID)
		}
		var users []models.User
		if err := q.Find(&users).Error; err != nil {
			return err
		}
		users, more := trimPage(users, limit)
		items := make([]UserBrief, len(users))
		for i, u := range users {
			items[i] = brief(u)
		}
		return c.JSON(Page[UserBrief]{Items: items, Page: page, Limit: limit, HasMore: more})
	}
}
