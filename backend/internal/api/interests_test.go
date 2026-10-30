package api_test

import (
	"testing"

	"github.com/esca6585dev/modahouse/backend/internal/config"
)

type interestsResp struct {
	Items []struct {
		Kind  string  `json:"kind"`
		Key   string  `json:"key"`
		Score float64 `json:"score"`
	} `json:"items"`
	Picked bool `json:"picked"`
}

func (e *env) post(token, title, category, tags string) pinResp {
	e.t.Helper()
	var p pinResp
	e.expect(201, "POST", "/api/pins", token, pinForm(e.t, map[string]string{"title": title, "category": category, "tags": tags}, testPNG(30, 40)), &p)
	return p
}

func TestProfileCraft(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("nurana")
	var me struct {
		Category string `json:"category"`
	}
	e.expect(200, "PUT", "/api/me", a.Token, map[string]string{"category": "lashes"}, &me)
	if me.Category != "lashes" {
		t.Fatalf("craft not saved: %+v", me)
	}
	e.expect(400, "PUT", "/api/me", a.Token, map[string]string{"category": "astronaut"}, nil)
	var masters struct {
		Items []struct {
			Username string `json:"username"`
			Category string `json:"category"`
		} `json:"items"`
	}
	e.expect(200, "GET", "/api/masters?category=lashes", "", nil, &masters)
	if len(masters.Items) != 1 || masters.Items[0].Username != "nurana" {
		t.Fatalf("masters: %+v", masters.Items)
	}
	// Opening a business keeps the craft; changing it later updates both.
	e.expect(200, "POST", "/api/me/business", a.Token, map[string]string{"phone": "+993 61 234567"}, nil)
	var biz struct {
		Business struct {
			Category string `json:"category"`
		} `json:"business"`
	}
	e.expect(200, "GET", "/api/users/nurana", "", nil, &biz)
	if biz.Business.Category != "lashes" {
		t.Fatalf("business category: %+v", biz)
	}
	e.expect(200, "PUT", "/api/me", a.Token, map[string]string{"category": "nails"}, nil)
	e.expect(200, "GET", "/api/users/nurana", "", nil, &biz)
	if biz.Business.Category != "nails" {
		t.Fatalf("business category not synced: %+v", biz)
	}
	e.expect(400, "PUT", "/api/me", a.Token, map[string]string{"category": ""}, nil)
}

func TestInterestsAndForYou(t *testing.T) {
	e := newEnvWith(t, false, func(c *config.Config) { c.AdminUsername, c.AdminPassword = "boss", "boss-pass-123" })
	author, guly := e.register("aysoltan"), e.register("guly")
	var nails, dresses []pinResp
	for i := 0; i < 6; i++ {
		dresses = append(dresses, e.post(author.Token, "Toý köýnegi "+itoa(uint(i)), "toy", "köýnek,atlas"))
	}
	for i := 0; i < 3; i++ {
		nails = append(nails, e.post(author.Token, "Dyrnak "+itoa(uint(i)), "dyrnak", "dyrnak,manikýur"))
	}
	// Newest first without interests: nails were posted last.
	var feed struct {
		Items []pinResp `json:"items"`
	}
	var mine interestsResp
	e.expect(200, "GET", "/api/me/interests", guly.Token, nil, &mine)
	if mine.Picked {
		t.Fatal("fresh user has interests")
	}

	// Picking on the welcome screen, then liking and saving a dress.
	e.expect(400, "PUT", "/api/me/interests", guly.Token, map[string]any{"categories": []string{"nope"}}, nil)
	e.expect(200, "PUT", "/api/me/interests", guly.Token, map[string]any{"categories": []string{"toy"}}, &mine)
	e.expect(200, "POST", "/api/pins/"+itoa(dresses[0].ID)+"/like", guly.Token, nil, nil)
	e.expect(200, "POST", "/api/pins/"+itoa(dresses[1].ID)+"/view", guly.Token, nil, nil)
	e.expect(200, "GET", "/api/pins?q=atlas", guly.Token, nil, nil)
	e.expect(200, "GET", "/api/pins?q=zerbap", guly.Token, nil, nil)
	e.expect(200, "GET", "/api/me/interests", guly.Token, nil, &mine)
	if !mine.Picked || mine.Items[0].Key != "toy" || mine.Items[0].Kind != "category" {
		t.Fatalf("interests: %+v", mine)
	}

	e.expect(200, "GET", "/api/pins?feed=foryou&limit=4", guly.Token, nil, &feed)
	if len(feed.Items) != 4 {
		t.Fatalf("for you page: %d", len(feed.Items))
	}
	if feed.Items[0].Title[:3] != "Toý"[:3] {
		t.Fatalf("for you should start with dresses, got %q", feed.Items[0].Title)
	}
	// Every pin appears exactly once across pages.
	seen := map[uint]bool{}
	for page := 1; page <= 3; page++ {
		e.expect(200, "GET", "/api/pins?feed=foryou&limit=4&page="+itoa(uint(page)), guly.Token, nil, &feed)
		for _, p := range feed.Items {
			if seen[p.ID] {
				t.Fatalf("pin %d repeated", p.ID)
			}
			seen[p.ID] = true
		}
	}
	if len(seen) != 9 {
		t.Fatalf("for you covered %d of 9 pins", len(seen))
	}

	// Hiding nails pushes the category down; resetting forgets everything.
	e.expect(204, "POST", "/api/pins/"+itoa(nails[0].ID)+"/hide", guly.Token, nil, nil)
	e.expect(204, "DELETE", "/api/me/interests", guly.Token, nil, nil)
	e.expect(200, "GET", "/api/me/interests", guly.Token, nil, &mine)
	if mine.Picked {
		t.Fatalf("reset kept: %+v", mine)
	}

	// Admin analytics.
	admin := e.login("boss", "boss-pass-123")
	e.expect(200, "PUT", "/api/me/interests", guly.Token, map[string]any{"categories": []string{"toy", "gelin"}}, nil)
	e.expect(403, "GET", "/api/admin/analytics", guly.Token, nil, nil)
	var a struct {
		Days        int                    `json:"days"`
		ActiveUsers int                    `json:"activeUsers"`
		Searches    int                    `json:"searches"`
		Daily       []struct{ Day string } `json:"daily"`
		Categories  []struct {
			Key   string `json:"key"`
			Users int    `json:"users"`
		} `json:"categories"`
		TopSearches   []struct{ Query string } `json:"topSearches"`
		EmptySearches []struct{ Query string } `json:"emptySearches"`
		TopPins       []struct{ ID uint }      `json:"topPins"`
	}
	e.expect(200, "GET", "/api/admin/analytics?days=7", admin.Token, nil, &a)
	if a.Days != 7 || len(a.Daily) != 7 || a.ActiveUsers != 1 || a.Searches != 2 {
		t.Fatalf("analytics totals: %+v", a)
	}
	top := 0
	for _, c := range a.Categories {
		top += c.Users
	}
	if len(a.Categories) != 2 || top != 1 { // each user counts once, under their top category
		t.Fatalf("analytics categories: %+v", a.Categories)
	}
	if len(a.EmptySearches) != 1 || a.EmptySearches[0].Query != "zerbap" || len(a.TopSearches) != 2 {
		t.Fatalf("searches: %+v / %+v", a.TopSearches, a.EmptySearches)
	}
	if len(a.TopPins) != 1 || a.TopPins[0].ID != dresses[1].ID {
		t.Fatalf("top pins: %+v", a.TopPins)
	}
	var ui interestsResp
	e.expect(200, "GET", "/api/admin/users/"+itoa(guly.User.ID)+"/interests", admin.Token, nil, &ui)
	if len(ui.Items) < 2 {
		t.Fatalf("user interests: %+v", ui)
	}
}
