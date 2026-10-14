package api_test

import (
	"fmt"
	"mime/multipart"
	"testing"
)

// webm header bytes are enough for content sniffing.
var fakeWebM = append([]byte{0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0xF7, 0x81, 0x01, 0x42, 0xF2, 0x81, 0x04, 0x42, 0xF3, 0x81, 0x08, 0x42, 0x82, 0x84, 'w', 'e', 'b', 'm'}, make([]byte, 64)...)

func TestListingTypes(t *testing.T) {
	e := newEnv(t, false)
	shop := e.register("atelye")
	buyer := e.register("gyz")
	e.expect(200, "POST", "/api/me/business", shop.Token, map[string]any{"category": "rental", "phone": "+993 62 111111",
		"whatsapp": "+993 62 111111", "telegram": "@atelye", "website": "https://atelye.tm"}, nil)
	e.expect(400, "PUT", "/api/me/business", shop.Token, map[string]any{"website": "atelye.tm"}, nil)

	var rent productResp
	var rentP struct {
		Product *struct {
			ListingType string `json:"listingType"`
			Deposit     int    `json:"deposit"`
			MinDays     int    `json:"minDays"`
			OldPrice    int    `json:"oldPrice"`
		} `json:"product"`
		Tags []string `json:"tags"`
	}
	form := multiImageForm(t, map[string]string{"title": "Ak gelin köýnegi", "category": "gelin", "listingType": "rent",
		"price": "250", "oldPrice": "300", "deposit": "500", "minDays": "2", "description": "Toý üçin #GelinKöýnek #kärende"}, 1)
	e.expect(201, "POST", "/api/pins", shop.Token, form, &rent)
	e.expect(200, "GET", fmt.Sprintf("/api/pins/%d", rent.ID), "", nil, &rentP)
	if rentP.Product == nil || rentP.Product.ListingType != "rent" || rentP.Product.Deposit != 500 || rentP.Product.MinDays != 2 || rentP.Product.OldPrice != 0 {
		t.Fatalf("rent listing: %+v", rentP.Product)
	}
	if len(rentP.Tags) != 2 || rentP.Tags[0] != "gelinköýnek" {
		t.Fatalf("caption hashtags: %v", rentP.Tags)
	}
	// Rentals are not sold through the cart.
	e.expect(400, "POST", "/api/cart", buyer.Token, map[string]any{"pinId": rent.ID}, nil)
	// A priced type needs a price.
	e.expect(400, "POST", "/api/pins", shop.Token, multiImageForm(t, map[string]string{"title": "X", "category": "toy", "listingType": "custom"}, 1), nil)
	e.expect(400, "POST", "/api/pins", shop.Token, multiImageForm(t, map[string]string{"title": "X", "category": "toy", "listingType": "gift", "price": "1"}, 1), nil)
	// Personal accounts can only share posts.
	e.expect(403, "POST", "/api/pins", buyer.Token, multiImageForm(t, map[string]string{"title": "X", "category": "toy", "listingType": "rent", "price": "100"}, 1), nil)
	var post productResp
	e.expect(201, "POST", "/api/pins", buyer.Token, multiImageForm(t, map[string]string{"title": "Meniň örümim", "category": "sac", "listingType": "post"}, 1), &post)
	if post.Product != nil {
		t.Fatal("a post must not be a product")
	}

	var tagged page[productResp]
	e.expect(200, "GET", "/api/pins?tag=%23gelinköýnek", "", nil, &tagged)
	if len(tagged.Items) != 1 {
		t.Fatalf("tag filter: %d", len(tagged.Items))
	}
	var search struct {
		Users []struct{ Username string } `json:"users"`
		Tags  []struct {
			Tag   string `json:"tag"`
			Count int    `json:"count"`
		} `json:"tags"`
	}
	e.expect(200, "GET", "/api/search?q=%23gelin", "", nil, &search)
	if len(search.Tags) == 0 || search.Tags[0].Tag != "gelinköýnek" {
		t.Fatalf("tag search: %+v", search)
	}
	e.expect(200, "GET", "/api/search?q=atel", "", nil, &search)
	if len(search.Users) != 1 {
		t.Fatalf("user search: %+v", search.Users)
	}
	var bcats []struct{ Slug string }
	e.expect(200, "GET", "/api/business-categories", "", nil, &bcats)
	if len(bcats) < 8 {
		t.Fatal("business categories")
	}
}

func TestVideoPosts(t *testing.T) {
	e := newEnv(t, false)
	u := e.register("reelgyz")
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	_ = w.WriteField("title", "Örüm sapagy")
	_ = w.WriteField("category", "sac")
	_ = w.WriteField("durations", "12.5")
	fw, _ := w.CreateFormFile("images", "reel.webm")
	_, _ = fw.Write(fakeWebM)
	pw, _ := w.CreateFormFile("posters", "poster.png")
	_, _ = pw.Write(testPNG(9, 16))
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	var pin struct {
		ID        uint   `json:"id"`
		MediaType string `json:"mediaType"`
		ImageURL  string `json:"imageUrl"`
		Images    []struct {
			Type      string  `json:"type"`
			URL       string  `json:"url"`
			PosterURL string  `json:"posterUrl"`
			Duration  float64 `json:"duration"`
			Width     int     `json:"width"`
		} `json:"images"`
	}
	e.expect(201, "POST", "/api/pins", u.Token, m, &pin)
	if pin.MediaType != "video" || pin.Images[0].Type != "video" || pin.Images[0].Duration != 12.5 ||
		pin.ImageURL != pin.Images[0].PosterURL || pin.Images[0].Width != 9 {
		t.Fatalf("video pin: %+v", pin)
	}
	e.expect(200, "GET", pin.Images[0].URL, "", nil, nil)
	var reels page[struct{ ID uint }]
	e.expect(200, "GET", "/api/pins?type=videos", "", nil, &reels)
	if len(reels.Items) != 1 {
		t.Fatalf("reels: %d", len(reels.Items))
	}

	// A video story without a poster gets a placeholder.
	m = &multipartBody{}
	w = multipart.NewWriter(&m.buf)
	fw, _ = w.CreateFormFile("video", "s.webm")
	_, _ = fw.Write(fakeWebM)
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	var story struct {
		MediaType string `json:"mediaType"`
		VideoURL  string `json:"videoUrl"`
		ImageURL  string `json:"imageUrl"`
	}
	e.expect(201, "POST", "/api/stories", u.Token, m, &story)
	if story.MediaType != "video" || story.VideoURL == "" || story.ImageURL == "" {
		t.Fatalf("video story: %+v", story)
	}
}

func TestModerationAndLikes(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("aylyk")
	b := e.register("bahar")
	var pin productResp
	e.expect(201, "POST", "/api/pins", a.Token, pinForm(t, map[string]string{"title": "Keşde", "category": "keshde"}, testPNG(5, 5)), &pin)
	path := fmt.Sprintf("/api/pins/%d", pin.ID)
	count := func(token string) int {
		var p page[productResp]
		e.expect(200, "GET", "/api/pins", token, nil, &p)
		return len(p.Items)
	}

	e.expect(400, "POST", path+"/report", b.Token, map[string]any{"reason": "nope"}, nil)
	e.expect(204, "POST", path+"/report", b.Token, map[string]any{"reason": "spam"}, nil)

	e.expect(204, "POST", path+"/hide", b.Token, nil, nil)
	if count(b.Token) != 0 || count(a.Token) != 1 {
		t.Fatal("hide should only affect the viewer")
	}
	e.expect(204, "DELETE", path+"/hide", b.Token, nil, nil)
	if count(b.Token) != 1 {
		t.Fatal("unhide")
	}

	e.expect(200, "POST", "/api/users/aylyk/follow", b.Token, nil, nil)
	e.expect(200, "POST", "/api/users/aylyk/block", b.Token, nil, nil)
	if count(b.Token) != 0 || count(a.Token) != 0+1 {
		t.Fatal("block should hide the blocked user's pins for the blocker")
	}
	var prof struct{ FollowersCount int }
	e.expect(200, "GET", "/api/users/aylyk", "", nil, &prof)
	if prof.FollowersCount != 0 {
		t.Fatal("block should remove follows")
	}
	var blocks []struct{ Username string }
	e.expect(200, "GET", "/api/me/blocks", b.Token, nil, &blocks)
	if len(blocks) != 1 {
		t.Fatal("blocks list")
	}
	e.expect(200, "DELETE", "/api/users/aylyk/block", b.Token, nil, nil)

	e.expect(200, "POST", path+"/like", b.Token, nil, nil)
	var likes page[productResp]
	e.expect(200, "GET", "/api/me/likes", b.Token, nil, &likes)
	if len(likes.Items) != 1 {
		t.Fatal("liked list")
	}
	e.expect(201, "POST", path+"/comments", b.Token, map[string]any{"text": "Ajaýyp!"}, nil)
	var feed page[struct {
		LatestComments []struct{ Text string } `json:"latestComments"`
	}]
	e.expect(200, "GET", "/api/pins?withComments=1", "", nil, &feed)
	if len(feed.Items) != 1 || len(feed.Items[0].LatestComments) != 1 {
		t.Fatalf("latest comments: %+v", feed.Items)
	}

	var sug struct {
		Source    string   `json:"source"`
		Title     string   `json:"title"`
		Hashtags  []string `json:"hashtags"`
		PriceLine string   `json:"priceLine"`
	}
	e.expect(401, "POST", "/api/ai/suggest", "", map[string]any{"listingType": "sale"}, nil)
	e.expect(400, "POST", "/api/ai/suggest", a.Token, map[string]any{"listingType": "gift"}, nil)
	e.expect(200, "POST", "/api/ai/suggest", a.Token, map[string]any{"listingType": "sale", "category": "milli", "title": "Keşdeli köýnek", "notes": "550"}, &sug)
	if sug.Title == "" || len(sug.Hashtags) == 0 || sug.PriceLine == "" {
		t.Fatalf("ai suggest: %+v", sug)
	}
}
