package api_test

import (
	"testing"
	"time"

	"github.com/esca6585dev/modahouse/backend/internal/config"
)

type coinsResp struct {
	Balance  int `json:"balance"`
	Packages []struct {
		Coins int    `json:"coins"`
		Price string `json:"price"`
	} `json:"packages"`
	History []struct {
		Amount int    `json:"amount"`
		Kind   string `json:"kind"`
	} `json:"history"`
	Requests []struct {
		ID     uint   `json:"id"`
		Status string `json:"status"`
	} `json:"requests"`
}

func adminEnv(t *testing.T) *env {
	return newEnvWith(t, false, func(c *config.Config) { c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123" })
}

func TestCoinsAndBoost(t *testing.T) {
	e := adminEnv(t)
	admin := e.login("boss", "boss-pass-123")
	shop, guly := e.register("aysoltan"), e.register("guly")
	e.expect(200, "PUT", "/api/admin/settings", admin.Token, map[string]any{"coinRate": "0,5", "coinPayment": "Terminal: 12345"}, nil)

	var w coinsResp
	e.expect(200, "GET", "/api/me/coins", shop.Token, nil, &w)
	if w.Balance != 0 || len(w.Packages) == 0 || w.Packages[0].Coins != 50 || w.Packages[0].Price != "25" {
		t.Fatalf("wallet: %+v", w)
	}

	// Buying: the request waits for an admin; approving twice pays once.
	var req struct {
		ID    uint   `json:"id"`
		Price string `json:"price"`
	}
	e.expect(400, "POST", "/api/me/coins/requests", shop.Token, map[string]any{"coins": 5}, nil)
	e.expect(201, "POST", "/api/me/coins/requests", shop.Token, map[string]any{"coins": 100, "note": "tölendi"}, &req)
	if req.Price != "50" {
		t.Fatalf("price: %+v", req)
	}
	e.expect(403, "POST", "/api/admin/coin-requests/"+itoa(req.ID)+"/approve", guly.Token, nil, nil)
	e.expect(200, "POST", "/api/admin/coin-requests/"+itoa(req.ID)+"/approve", admin.Token, nil, nil)
	e.expect(409, "POST", "/api/admin/coin-requests/"+itoa(req.ID)+"/approve", admin.Token, nil, nil)
	e.expect(200, "GET", "/api/me/coins", shop.Token, nil, &w)
	if w.Balance != 100 || w.History[0].Kind != "topup" {
		t.Fatalf("after approve: %+v", w)
	}

	// Boosting spends teňňe and opens the feed with the post.
	old := e.post(shop.Token, "Köne köýnek", "koynekler", "")
	for i := 0; i < 5; i++ {
		e.post(guly.Token, "Täze "+itoa(uint(i)), "koynekler", "")
	}
	e.expect(403, "POST", "/api/pins/"+itoa(old.ID)+"/boost", guly.Token, map[string]int{"days": 1}, nil)
	e.expect(400, "POST", "/api/pins/"+itoa(old.ID)+"/boost", shop.Token, map[string]int{"days": 2}, nil)
	var boosted struct {
		Balance      int       `json:"balance"`
		BoostedUntil time.Time `json:"boostedUntil"`
	}
	e.expect(200, "POST", "/api/pins/"+itoa(old.ID)+"/boost", shop.Token, map[string]int{"days": 3}, &boosted)
	if boosted.Balance != 75 || time.Until(boosted.BoostedUntil) < 71*time.Hour {
		t.Fatalf("boost: %+v", boosted)
	}
	e.expect(200, "POST", "/api/pins/"+itoa(old.ID)+"/boost", shop.Token, map[string]int{"days": 7}, &boosted) // extends
	if boosted.Balance != 25 || time.Until(boosted.BoostedUntil) < 9*24*time.Hour {
		t.Fatalf("extend: %+v", boosted)
	}
	e.expect(402, "POST", "/api/pins/"+itoa(old.ID)+"/boost", shop.Token, map[string]int{"days": 7}, nil)

	var feed struct {
		Items []struct {
			ID       uint `json:"id"`
			Promoted bool `json:"promoted"`
		} `json:"items"`
	}
	e.expect(200, "GET", "/api/pins?limit=3", "", nil, &feed)
	if len(feed.Items) < 1 || feed.Items[0].ID != old.ID || !feed.Items[0].Promoted {
		t.Fatalf("feed should open with the boosted post: %+v", feed.Items)
	}
	feed.Items = nil // promoted is omitted when false: don't decode over old values
	e.expect(200, "GET", "/api/pins?limit=3&page=2", "", nil, &feed)
	for _, it := range feed.Items {
		if it.Promoted {
			t.Fatal("promoted on page 2")
		}
	}
	feed.Items = nil
	e.expect(200, "GET", "/api/pins?author=guly", "", nil, &feed)
	for _, it := range feed.Items {
		if it.ID == old.ID {
			t.Fatal("boosted post leaked into another profile")
		}
	}
	var promoted []struct{ ID uint }
	e.expect(200, "GET", "/api/pins/promoted", "", nil, &promoted)
	if len(promoted) != 1 {
		t.Fatalf("promoted: %+v", promoted)
	}

	// Admin can give and take back teňňe, never below zero.
	e.expect(200, "POST", "/api/admin/users/"+itoa(guly.User.ID)+"/coins", admin.Token, map[string]any{"amount": 30, "note": "sowgat"}, nil)
	e.expect(400, "POST", "/api/admin/users/"+itoa(guly.User.ID)+"/coins", admin.Token, map[string]any{"amount": -31}, nil)
	var me struct {
		Coins int `json:"coins"`
	}
	e.expect(200, "GET", "/api/me", guly.Token, nil, &me)
	if me.Coins != 30 {
		t.Fatalf("me coins: %+v", me)
	}
}

type contestResp struct {
	ID           uint   `json:"id"`
	Status       string `json:"status"`
	EntriesCount int    `json:"entriesCount"`
	VotesCount   int    `json:"votesCount"`
	MyVotePinID  *uint  `json:"myVotePinId"`
	Winner       *struct {
		Pin   struct{ ID uint } `json:"pin"`
		Votes int               `json:"votes"`
	} `json:"winner"`
}

func TestContest(t *testing.T) {
	e := adminEnv(t)
	admin := e.login("boss", "boss-pass-123")
	a, b, v1, v2, fresh := e.register("aysoltan"), e.register("bahar"), e.register("jeren"), e.register("selbi"), e.register("taze")
	// Voters must be older than a day.
	e.db.Exec("UPDATE users SET created_at = ? WHERE username IN ?", time.Now().Add(-48*time.Hour), []string{"jeren", "selbi", "aysoltan", "bahar"})

	now := time.Now()
	var ct contestResp
	e.expect(403, "POST", "/api/admin/contests", a.Token, map[string]any{"title": "x"}, nil)
	e.expect(400, "POST", "/api/admin/contests", admin.Token, map[string]any{"title": "Toý köýnegi", "startsAt": now, "endsAt": now.Add(-time.Hour)}, nil)
	e.expect(201, "POST", "/api/admin/contests", admin.Token, map[string]any{
		"title": "Iň owadan toý köýnegi", "category": "toy", "prize": "Mugt tikin", "prizeCoins": 100,
		"startsAt": now.Add(-time.Minute), "endsAt": now.Add(time.Hour),
	}, &ct)
	if ct.Status != "active" {
		t.Fatalf("contest: %+v", ct)
	}
	path := "/api/contests/" + itoa(ct.ID)

	pa := e.post(a.Token, "Gyzyl toý köýnegi", "toy", "")
	pa2 := e.post(a.Token, "Ikinji", "toy", "")
	pb := e.post(b.Token, "Ak toý köýnegi", "toy", "")
	wrong := e.post(b.Token, "Dyrnak", "dyrnak", "")
	e.expect(400, "POST", path+"/entries", b.Token, map[string]uint{"pinId": wrong.ID}, nil)
	e.expect(403, "POST", path+"/entries", b.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(201, "POST", path+"/entries", a.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(409, "POST", path+"/entries", a.Token, map[string]uint{"pinId": pa2.ID}, nil) // one post per user
	e.expect(201, "POST", path+"/entries", b.Token, map[string]uint{"pinId": pb.ID}, nil)

	// One vote per user per contest; not for yourself; not from a fresh account.
	e.expect(400, "POST", path+"/vote", a.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(403, "POST", path+"/vote", fresh.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(200, "POST", path+"/vote", v1.Token, map[string]uint{"pinId": pa.ID}, &ct)
	if ct.MyVotePinID == nil || *ct.MyVotePinID != pa.ID {
		t.Fatalf("my vote: %+v", ct)
	}
	e.expect(409, "POST", path+"/vote", v1.Token, map[string]uint{"pinId": pb.ID}, nil)
	e.expect(409, "POST", path+"/vote", v1.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(200, "POST", path+"/vote", v2.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(200, "POST", path+"/vote", b.Token, map[string]uint{"pinId": pa.ID}, nil)
	e.expect(200, "POST", path+"/vote", a.Token, map[string]uint{"pinId": pb.ID}, nil)

	var full struct {
		Contest contestResp `json:"contest"`
		Entries []struct {
			Pin   struct{ ID uint } `json:"pin"`
			Votes int               `json:"votes"`
			Rank  int               `json:"rank"`
		} `json:"entries"`
	}
	e.expect(200, "GET", path, "", nil, &full)
	if len(full.Entries) != 2 || full.Entries[0].Pin.ID != pa.ID || full.Entries[0].Votes != 3 || full.Entries[1].Rank != 2 {
		t.Fatalf("standings: %+v", full.Entries)
	}
	// A vote is also a like.
	var liked pinResp
	e.expect(200, "GET", "/api/pins/"+itoa(pa.ID), v1.Token, nil, &liked)
	if !liked.Liked {
		t.Fatal("vote did not like the post")
	}

	// Time is up: the next request finishes it and pays the prize once.
	e.db.Exec("UPDATE contests SET ends_at = ? WHERE id = ?", time.Now().Add(-time.Second), ct.ID)
	e.expect(200, "GET", path, "", nil, &full)
	e.expect(200, "GET", path, "", nil, &full)
	if full.Contest.Status != "finished" || full.Contest.Winner == nil || full.Contest.Winner.Pin.ID != pa.ID {
		t.Fatalf("finished: %+v", full.Contest)
	}
	var w coinsResp
	e.expect(200, "GET", "/api/me/coins", a.Token, nil, &w)
	if w.Balance != 100 || w.History[0].Kind != "prize" {
		t.Fatalf("prize: %+v", w)
	}
	e.expect(400, "POST", path+"/vote", v1.Token, map[string]uint{"pinId": pb.ID}, nil)

	var list []contestResp
	e.expect(200, "GET", "/api/contests", "", nil, &list)
	if len(list) != 1 || list[0].Status != "finished" {
		t.Fatalf("list: %+v", list)
	}
}
