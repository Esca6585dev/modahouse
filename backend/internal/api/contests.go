package api

import (
	"errors"
	"log"
	"sort"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

// Contests: users enter one of their posts, everyone else gets ONE vote per
// contest, and the post with the most votes wins when the contest ends.
// A vote also likes the post. Accounts younger than a day cannot vote, so a
// pile of fresh accounts cannot decide a contest.

const minVoterAge = 24 * time.Hour

type ContestEntryDTO struct {
	Pin   PinDTO `json:"pin"`
	Votes int64  `json:"votes"`
	Rank  int    `json:"rank"`
}

type ContestDTO struct {
	ID           uint             `json:"id"`
	Title        string           `json:"title"`
	Description  string           `json:"description"`
	Category     string           `json:"category"`
	Prize        string           `json:"prize"`
	PrizeCoins   int              `json:"prizeCoins"`
	StartsAt     time.Time        `json:"startsAt"`
	EndsAt       time.Time        `json:"endsAt"`
	Status       string           `json:"status"` // upcoming, active, finished
	EntriesCount int64            `json:"entriesCount"`
	VotesCount   int64            `json:"votesCount"`
	Winner       *ContestEntryDTO `json:"winner"`
	MyVotePinID  *uint            `json:"myVotePinId"`
	MyEntryPinID *uint            `json:"myEntryPinId"`
}

func contestStatus(ct models.Contest, now time.Time) string {
	switch {
	case ct.Finished || !now.Before(ct.EndsAt):
		return "finished"
	case now.Before(ct.StartsAt):
		return "upcoming"
	default:
		return "active"
	}
}

func (h *Handler) contestDTO(ct models.Contest, viewer uint) ContestDTO {
	d := ContestDTO{ID: ct.ID, Title: ct.Title, Description: ct.Description, Category: ct.Category, Prize: ct.Prize,
		PrizeCoins: ct.PrizeCoins, StartsAt: ct.StartsAt, EndsAt: ct.EndsAt, Status: contestStatus(ct, time.Now())}
	h.db.Model(&models.ContestEntry{}).Where("contest_id = ?", ct.ID).Count(&d.EntriesCount)
	h.db.Model(&models.ContestVote{}).Where("contest_id = ?", ct.ID).Count(&d.VotesCount)
	if ct.WinnerPinID != nil {
		if p, err := h.loadPin(*ct.WinnerPinID); err == nil {
			var n int64
			h.db.Model(&models.ContestVote{}).Where("contest_id = ? AND pin_id = ?", ct.ID, p.ID).Count(&n)
			d.Winner = &ContestEntryDTO{Pin: h.enrichPins([]models.Pin{p}, viewer)[0], Votes: n, Rank: 1}
		}
	}
	if viewer != 0 {
		var v models.ContestVote
		if h.db.Where("contest_id = ? AND user_id = ?", ct.ID, viewer).First(&v).Error == nil {
			d.MyVotePinID = &v.PinID
		}
		var e models.ContestEntry
		if h.db.Where("contest_id = ? AND user_id = ?", ct.ID, viewer).First(&e).Error == nil {
			d.MyEntryPinID = &e.PinID
		}
	}
	return d
}

// standings returns entries with their votes, most votes first; ties go to the earlier entry.
func (h *Handler) standings(contestID uint) ([]models.ContestEntry, map[uint]int64) {
	var entries []models.ContestEntry
	h.db.Where("contest_id = ?", contestID).Order("created_at, pin_id").Find(&entries)
	var rows []struct {
		PinID uint
		N     int64
	}
	h.db.Model(&models.ContestVote{}).Select("pin_id, COUNT(*) AS n").Where("contest_id = ?", contestID).Group("pin_id").Scan(&rows)
	votes := map[uint]int64{}
	for _, r := range rows {
		votes[r.PinID] = r.N
	}
	sort.SliceStable(entries, func(a, b int) bool { return votes[entries[a].PinID] > votes[entries[b].PinID] })
	return entries, votes
}

// finishContests closes every contest whose time is up: picks the winner and
// pays the prize. It runs every minute and before contests are shown.
func (h *Handler) finishContests() {
	var due []models.Contest
	h.db.Where("finished = ? AND ends_at <= ?", false, time.Now()).Find(&due)
	for _, ct := range due {
		entries, votes := h.standings(ct.ID)
		err := h.db.Transaction(func(tx *gorm.DB) error {
			upd := map[string]any{"finished": true}
			var win *models.ContestEntry
			if len(entries) > 0 && votes[entries[0].PinID] > 0 {
				win = &entries[0]
				upd["winner_pin_id"], upd["winner_id"] = win.PinID, win.UserID
			}
			// Only the run that flips Finished pays the prize.
			res := tx.Model(&models.Contest{}).Where("id = ? AND finished = ?", ct.ID, false).Updates(upd)
			if res.Error != nil || res.RowsAffected == 0 || win == nil || ct.PrizeCoins <= 0 {
				return res.Error
			}
			return giveCoins(tx, win.UserID, ct.PrizeCoins, "prize", "Ýeňiji: "+ct.Title, &win.PinID)
		})
		if err != nil {
			log.Printf("contest %d: %v", ct.ID, err)
		}
	}
}

func (h *Handler) runContestTimer() {
	go func() {
		for range time.Tick(time.Minute) {
			h.finishContests()
		}
	}()
}

// listContests: GET /contests?status=active|upcoming|finished
func (h *Handler) listContests(c fiber.Ctx) error {
	h.finishContests()
	q := h.db.Order("ends_at DESC").Limit(50)
	now := time.Now()
	switch c.Query("status") {
	case "active":
		q = q.Where("finished = ? AND starts_at <= ? AND ends_at > ?", false, now, now)
	case "upcoming":
		q = q.Where("starts_at > ?", now)
	case "finished":
		q = q.Where("finished = ?", true)
	}
	var rows []models.Contest
	if err := q.Find(&rows).Error; err != nil {
		return err
	}
	out := make([]ContestDTO, len(rows))
	for i, ct := range rows {
		out[i] = h.contestDTO(ct, viewerID(c))
	}
	// Running first, then upcoming, then finished.
	order := map[string]int{"active": 0, "upcoming": 1, "finished": 2}
	sort.SliceStable(out, func(a, b int) bool { return order[out[a].Status] < order[out[b].Status] })
	return c.JSON(out)
}

func (h *Handler) loadContest(c fiber.Ctx) (models.Contest, error) {
	var ct models.Contest
	id, ok := idParam(c, "id")
	if !ok || h.db.First(&ct, id).Error != nil {
		return ct, notFound(c)
	}
	return ct, nil
}

// getContest: GET /contests/:id — the contest and its standings.
func (h *Handler) getContest(c fiber.Ctx) error {
	h.finishContests()
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	entries, votes := h.standings(ct.ID)
	ids := make([]uint, len(entries))
	for i, e := range entries {
		ids[i] = e.PinID
	}
	var pins []models.Pin
	if len(ids) > 0 {
		h.db.Preload("User").Where("id IN ?", ids).Find(&pins)
	}
	byID := map[uint]PinDTO{}
	for _, d := range h.enrichPins(pins, viewerID(c)) {
		byID[d.ID] = d
	}
	list := []ContestEntryDTO{}
	rank, prev := 0, int64(-1)
	for i, e := range entries {
		d, ok := byID[e.PinID]
		if !ok {
			continue
		}
		if votes[e.PinID] != prev {
			rank, prev = i+1, votes[e.PinID]
		}
		list = append(list, ContestEntryDTO{Pin: d, Votes: votes[e.PinID], Rank: rank})
	}
	return c.JSON(fiber.Map{"contest": h.contestDTO(ct, viewerID(c)), "entries": list})
}

// enterContest: POST /contests/:id/entries {pinId} — one own post per contest.
func (h *Handler) enterContest(c fiber.Ctx) error {
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	if contestStatus(ct, time.Now()) == "finished" {
		return badRequest(c, "Bu ýaryş tamamlandy")
	}
	var req struct {
		PinID uint `json:"pinId"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	var p models.Pin
	if h.db.First(&p, req.PinID).Error != nil {
		return badRequest(c, "Post tapylmady")
	}
	if p.UserID != me {
		return forbidden(c)
	}
	if ct.Category != "" && p.Category != ct.Category {
		return badRequest(c, "Bu ýaryşa diňe «"+categoryName(ct.Category)+"» bölüminiň postlary goşulýar")
	}
	var n int64
	h.db.Model(&models.ContestEntry{}).Where("contest_id = ? AND user_id = ?", ct.ID, me).Count(&n)
	if n > 0 {
		return fail(c, fiber.StatusConflict, "Her ulanyjy ýaryşa diňe bir post goşup bilýär")
	}
	if err := h.db.Create(&models.ContestEntry{ContestID: ct.ID, PinID: p.ID, UserID: me}).Error; err != nil {
		return err
	}
	return c.Status(fiber.StatusCreated).JSON(h.contestDTO(ct, me))
}

// leaveContest: DELETE /contests/:id/entries — withdraw before the end; its votes are freed.
func (h *Handler) leaveContest(c fiber.Ctx) error {
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	if contestStatus(ct, time.Now()) == "finished" {
		return badRequest(c, "Bu ýaryş tamamlandy")
	}
	me := viewerID(c)
	var e models.ContestEntry
	if h.db.Where("contest_id = ? AND user_id = ?", ct.ID, me).First(&e).Error != nil {
		return notFound(c)
	}
	err = h.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("contest_id = ? AND pin_id = ?", ct.ID, e.PinID).Delete(&models.ContestVote{}).Error; err != nil {
			return err
		}
		return tx.Where("contest_id = ? AND pin_id = ?", ct.ID, e.PinID).Delete(&models.ContestEntry{}).Error
	})
	if err != nil {
		return err
	}
	return c.JSON(h.contestDTO(ct, me))
}

// voteContest: POST /contests/:id/vote {pinId} — one vote per user per contest, final.
func (h *Handler) voteContest(c fiber.Ctx) error {
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	switch contestStatus(ct, time.Now()) {
	case "upcoming":
		return badRequest(c, "Ses bermek ýaryş başlanda açylýar")
	case "finished":
		return badRequest(c, "Bu ýaryş tamamlandy")
	}
	var req struct {
		PinID uint `json:"pinId"`
	}
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	me := viewerID(c)
	var e models.ContestEntry
	if h.db.Where("contest_id = ? AND pin_id = ?", ct.ID, req.PinID).First(&e).Error != nil {
		return badRequest(c, "Bu post ýaryşa gatnaşmaýar")
	}
	if e.UserID == me {
		return badRequest(c, "Öz postuňyza ses berip bilmersiňiz")
	}
	var u models.User
	if h.db.Select("id", "created_at").First(&u, me).Error != nil {
		return notFound(c)
	}
	if time.Since(u.CreatedAt) < minVoterAge {
		return fail(c, fiber.StatusForbidden, "Täze hasaplar ýaryşda 24 sagatdan soň ses berip bilýär")
	}
	res := h.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.ContestVote{ContestID: ct.ID, UserID: me, PinID: e.PinID})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return fail(c, fiber.StatusConflict, "Siz bu ýaryşda eýýäm ses berdiňiz: her ulanyja 1 ses")
	}
	// The vote is also a like on the post.
	l := models.Like{UserID: me, PinID: e.PinID}
	if r := h.db.Where(&l).FirstOrCreate(&l); r.Error == nil && r.RowsAffected > 0 {
		h.notify(e.UserID, me, models.NotifyLike, &e.PinID)
	}
	return c.JSON(h.contestDTO(ct, me))
}

// --- admin ---

type contestReq struct {
	Title       *string    `json:"title"`
	Description *string    `json:"description"`
	Category    *string    `json:"category"`
	Prize       *string    `json:"prize"`
	PrizeCoins  *int       `json:"prizeCoins"`
	StartsAt    *time.Time `json:"startsAt"`
	EndsAt      *time.Time `json:"endsAt"`
}

func (r contestReq) apply(ct *models.Contest) string {
	if r.Title != nil {
		ct.Title = clean(*r.Title, 100)
	}
	if r.Description != nil {
		ct.Description = clean(*r.Description, 1000)
	}
	if r.Category != nil {
		if *r.Category != "" && !validCategory(*r.Category) {
			return "Kategoriýa nädogry"
		}
		ct.Category = *r.Category
	}
	if r.Prize != nil {
		ct.Prize = clean(*r.Prize, 200)
	}
	if r.PrizeCoins != nil {
		if *r.PrizeCoins < 0 || *r.PrizeCoins > 100000 {
			return "Baýrak teňňesi 0-100000 aralygynda bolmaly"
		}
		ct.PrizeCoins = *r.PrizeCoins
	}
	if r.StartsAt != nil {
		ct.StartsAt = r.StartsAt.UTC()
	}
	if r.EndsAt != nil {
		ct.EndsAt = r.EndsAt.UTC()
	}
	switch {
	case ct.Title == "":
		return "Ýaryşyň adyny ýazyň"
	case ct.StartsAt.IsZero() || ct.EndsAt.IsZero():
		return "Başlaýan we gutarýan wagtyny saýlaň"
	case !ct.EndsAt.After(ct.StartsAt):
		return "Gutarýan wagty başlaýan wagtyndan soň bolmaly"
	}
	return ""
}

// adminCreateContest: POST /admin/contests
func (h *Handler) adminCreateContest(c fiber.Ctx) error {
	var req contestReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	var ct models.Contest
	if msg := req.apply(&ct); msg != "" {
		return badRequest(c, msg)
	}
	if !ct.EndsAt.After(time.Now()) {
		return badRequest(c, "Gutarýan wagty geljekde bolmaly")
	}
	if err := h.db.Create(&ct).Error; err != nil {
		return err
	}
	return c.Status(fiber.StatusCreated).JSON(h.contestDTO(ct, viewerID(c)))
}

// adminUpdateContest: PUT /admin/contests/:id (not after it finished)
func (h *Handler) adminUpdateContest(c fiber.Ctx) error {
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	if ct.Finished {
		return badRequest(c, "Tamamlanan ýaryşy üýtgedip bolmaýar")
	}
	var req contestReq
	if err := c.Bind().Body(&req); err != nil {
		return badRequest(c, "Nädogry maglumat")
	}
	if msg := req.apply(&ct); msg != "" {
		return badRequest(c, msg)
	}
	if err := h.db.Save(&ct).Error; err != nil {
		return err
	}
	return c.JSON(h.contestDTO(ct, viewerID(c)))
}

// adminDeleteContest: DELETE /admin/contests/:id
func (h *Handler) adminDeleteContest(c fiber.Ctx) error {
	ct, err := h.loadContest(c)
	if err != nil {
		return err
	}
	if err := h.db.Delete(&ct).Error; err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}
