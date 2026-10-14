package api_test

import (
	"fmt"
	"mime/multipart"
	"strings"
	"testing"
)

type productResp struct {
	ID       uint `json:"id"`
	ImageURL string
	Images   []struct {
		URL string `json:"url"`
	} `json:"images"`
	Product *struct {
		Price    int    `json:"price"`
		OldPrice int    `json:"oldPrice"`
		Stock    *int   `json:"stock"`
		Badge    string `json:"badge"`
		Colors   []struct{ Name, Hex string }
		Sizes    []string `json:"sizes"`
	} `json:"product"`
	ViewsCount   int     `json:"viewsCount"`
	OrdersCount  int     `json:"ordersCount"`
	Rating       float64 `json:"rating"`
	ReviewsCount int     `json:"reviewsCount"`
}

func multiImageForm(t *testing.T, fields map[string]string, n int) *multipartBody {
	t.Helper()
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	for k, v := range fields {
		_ = w.WriteField(k, v)
	}
	for i := 0; i < n; i++ {
		fw, _ := w.CreateFormFile("images", fmt.Sprintf("p%d.png", i))
		_, _ = fw.Write(testPNG(30+i, 40))
	}
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	return m
}

type orderResp struct {
	ID           uint     `json:"id"`
	Status       string   `json:"status"`
	Total        int      `json:"total"`
	CanCancel    bool     `json:"canCancel"`
	NextStatuses []string `json:"nextStatuses"`
	Items        []struct {
		PinID *uint  `json:"pinId"`
		Title string `json:"title"`
	} `json:"items"`
}

func TestShopFlow(t *testing.T) {
	e := newEnv(t, false)
	seller := e.register("seller")
	buyer := e.register("buyer")
	productFields := map[string]string{
		"title": "Gyzyl köýnek", "category": "koynekler", "price": "300", "oldPrice": "350", "stock": "3",
		"colors": `[{"name":"Gyzyl","hex":"#c62828"},{"name":"Gara","hex":"#111111"}]`, "sizes": "S, M",
	}

	// Personal accounts cannot sell.
	e.expect(403, "POST", "/api/pins", seller.Token, multiImageForm(t, productFields, 1), nil)
	e.expect(400, "POST", "/api/me/business", seller.Token, map[string]any{"category": "dress", "phone": "abc"}, nil)
	e.expect(400, "POST", "/api/me/business", seller.Token, map[string]any{"category": "nope", "phone": "+993 65 112233"}, nil)
	var me struct {
		IsBusiness bool `json:"isBusiness"`
		Business   *struct {
			Category     string `json:"category"`
			DeliveryDays int    `json:"deliveryDays"`
		} `json:"business"`
	}
	e.expect(200, "POST", "/api/me/business", seller.Token, map[string]any{"category": "dress", "phone": "+993 65 112233", "city": "Aşgabat", "deliveryDays": 5}, &me)
	if !me.IsBusiness || me.Business == nil || me.Business.Category != "dress" {
		t.Fatalf("business not opened: %+v", me)
	}

	e.expect(400, "POST", "/api/pins", seller.Token, multiImageForm(t, productFields, 11), nil) // too many images
	var pin productResp
	e.expect(201, "POST", "/api/pins", seller.Token, multiImageForm(t, productFields, 2), &pin)
	if pin.Product == nil || pin.Product.Price != 300 || pin.Product.Badge != "sale" || *pin.Product.Stock != 3 ||
		len(pin.Images) != 2 || len(pin.Product.Colors) != 2 || pin.Product.Colors[0].Hex != "#C62828" || len(pin.Product.Sizes) != 2 {
		t.Fatalf("bad product: %+v %+v", pin, pin.Product)
	}
	pinPath := fmt.Sprintf("/api/pins/%d", pin.ID)

	// Filters.
	var list page[productResp]
	e.expect(200, "GET", "/api/pins?type=products", "", nil, &list)
	if len(list.Items) != 1 {
		t.Fatalf("products filter: %d", len(list.Items))
	}
	e.expect(200, "GET", "/api/pins?type=ideas", "", nil, &list)
	if len(list.Items) != 0 {
		t.Fatalf("ideas filter: %d", len(list.Items))
	}

	// Views: once per viewer per day, owners don't count.
	var v struct {
		ViewsCount int `json:"viewsCount"`
	}
	e.expect(200, "POST", pinPath+"/view", buyer.Token, nil, &v)
	e.expect(200, "POST", pinPath+"/view", buyer.Token, nil, &v)
	e.expect(200, "POST", pinPath+"/view", seller.Token, nil, &v)
	if v.ViewsCount != 1 {
		t.Fatalf("views: %d", v.ViewsCount)
	}

	// Cart validation.
	var cart struct {
		Items []struct{ ID uint } `json:"items"`
		Total int                 `json:"total"`
		Count int                 `json:"count"`
	}
	e.expect(400, "POST", "/api/cart", buyer.Token, map[string]any{"pinId": pin.ID, "size": "S"}, nil)
	e.expect(400, "POST", "/api/cart", buyer.Token, map[string]any{"pinId": pin.ID, "color": "Gyzyl", "size": "XXL"}, nil)
	e.expect(400, "POST", "/api/cart", seller.Token, map[string]any{"pinId": pin.ID, "color": "Gyzyl", "size": "S"}, nil)
	e.expect(200, "POST", "/api/cart", buyer.Token, map[string]any{"pinId": pin.ID, "color": "Gyzyl", "size": "S", "quantity": 2}, &cart)
	if cart.Total != 600 || cart.Count != 2 {
		t.Fatalf("cart: %+v", cart)
	}
	e.expect(400, "POST", "/api/cart", buyer.Token, map[string]any{"pinId": pin.ID, "color": "Gyzyl", "size": "S", "quantity": 2}, nil) // stock 3

	// Checkout from the cart.
	addr := map[string]any{"fullName": "Aýna", "phone": "+993 61 234567", "address": "Aşgabat, Bitarap Türkmenistan şaýoly 1"}
	e.expect(400, "POST", "/api/orders", buyer.Token, map[string]any{"fullName": "Aýna", "phone": "12", "address": "Aşgabat, 1"}, nil)
	var orders []orderResp
	e.expect(201, "POST", "/api/orders", buyer.Token, addr, &orders)
	if len(orders) != 1 || orders[0].Total != 600 || orders[0].Status != "new" || !orders[0].CanCancel {
		t.Fatalf("order: %+v", orders)
	}
	order := orders[0]
	e.expect(200, "GET", "/api/cart", buyer.Token, nil, &cart)
	if len(cart.Items) != 0 {
		t.Fatal("cart not cleared")
	}
	var fresh productResp
	e.expect(200, "GET", pinPath, "", nil, &fresh)
	if *fresh.Product.Stock != 1 || fresh.OrdersCount != 1 {
		t.Fatalf("stock not reserved: %+v", fresh.Product)
	}
	var unread struct{ Count int }
	e.expect(200, "GET", "/api/notifications/unread-count", seller.Token, nil, &unread)
	if unread.Count != 1 {
		t.Fatalf("seller should get an order notification, got %d", unread.Count)
	}

	// Seller workflow.
	var incoming page[orderResp]
	e.expect(200, "GET", "/api/business/orders", seller.Token, nil, &incoming)
	if len(incoming.Items) != 1 || len(incoming.Items[0].NextStatuses) != 2 {
		t.Fatalf("incoming: %+v", incoming.Items)
	}
	e.expect(403, "GET", "/api/business/orders", buyer.Token, nil, nil)
	opath := fmt.Sprintf("/api/business/orders/%d", order.ID)
	e.expect(404, "PUT", opath, buyer.Token, map[string]any{"status": "confirmed"}, nil)
	e.expect(400, "PUT", opath, seller.Token, map[string]any{"status": "shipped"}, nil)
	e.expect(403, "POST", pinPath+"/reviews", buyer.Token, map[string]any{"rating": 5}, nil) // not delivered yet
	for _, st := range []string{"confirmed", "shipped", "delivered"} {
		e.expect(200, "PUT", opath, seller.Token, map[string]any{"status": st}, nil)
	}
	e.expect(400, "POST", fmt.Sprintf("/api/orders/%d/cancel", order.ID), buyer.Token, nil, nil)
	var notes page[struct {
		Type  string `json:"type"`
		Order *struct {
			Status        string `json:"status"`
			CurrentStatus string `json:"currentStatus"`
			Role          string `json:"role"`
		} `json:"order"`
	}]
	e.expect(200, "GET", "/api/notifications", buyer.Token, nil, &notes)
	var steps []string
	for _, n := range notes.Items {
		if n.Type == "order_status" {
			steps = append(steps, n.Order.Status)
			if n.Order.CurrentStatus != "delivered" || n.Order.Role != "buyer" {
				t.Fatalf("notification order: %+v", n.Order)
			}
		}
	}
	if strings.Join(steps, ",") != "delivered,shipped,confirmed" {
		t.Fatalf("status per notification: %v", steps)
	}

	// Reviews.
	e.expect(400, "POST", pinPath+"/reviews", buyer.Token, map[string]any{"rating": 6}, nil)
	e.expect(201, "POST", pinPath+"/reviews", buyer.Token, map[string]any{"rating": 4, "text": "Gowy"}, nil)
	e.expect(201, "POST", pinPath+"/reviews", buyer.Token, map[string]any{"rating": 5, "text": "Örän gowy"}, nil) // updates
	var reviews struct {
		Items        []struct{ Rating int } `json:"items"`
		Rating       float64                `json:"rating"`
		ReviewsCount int                    `json:"reviewsCount"`
		CanReview    bool                   `json:"canReview"`
	}
	e.expect(200, "GET", pinPath+"/reviews", buyer.Token, nil, &reviews)
	if reviews.ReviewsCount != 1 || reviews.Rating != 5 || !reviews.CanReview {
		t.Fatalf("reviews: %+v", reviews)
	}

	// Buy now, out of stock, cancel gives stock back.
	buyNow := func(qty int) map[string]any {
		return map[string]any{"fullName": "Aýna", "phone": "+993 61 234567", "address": "Aşgabat, 1-nji köçe",
			"buyNow": map[string]any{"pinId": pin.ID, "color": "Gara", "size": "M", "quantity": qty}}
	}
	e.expect(201, "POST", "/api/orders", buyer.Token, buyNow(1), &orders)
	e.expect(400, "POST", "/api/orders", buyer.Token, buyNow(1), nil)
	e.expect(200, "POST", fmt.Sprintf("/api/orders/%d/cancel", orders[0].ID), buyer.Token, nil, nil)
	e.expect(200, "GET", pinPath, "", nil, &fresh)
	if *fresh.Product.Stock != 1 {
		t.Fatalf("cancel should release stock: %d", *fresh.Product.Stock)
	}

	// Ranking and stats count the delivered order, not the cancelled one.
	var top []struct {
		Rank     int `json:"rank"`
		Score    int `json:"score"`
		Orders   int `json:"orders"`
		Business struct {
			Username string  `json:"username"`
			Rating   float64 `json:"rating"`
		} `json:"business"`
	}
	e.expect(200, "GET", "/api/top?period=week", "", nil, &top)
	if len(top) != 1 || top[0].Business.Username != "seller" || top[0].Orders != 1 || top[0].Score == 0 || top[0].Business.Rating != 5 {
		t.Fatalf("top: %+v", top)
	}
	var stats struct {
		Orders  int `json:"orders"`
		Revenue int `json:"revenue"`
		Views   int `json:"views"`
	}
	e.expect(200, "GET", "/api/business/stats?period=week", seller.Token, nil, &stats)
	if stats.Orders != 1 || stats.Revenue != 600 || stats.Views != 1 {
		t.Fatalf("stats: %+v", stats)
	}

	// Editing product fields.
	e.expect(400, "PUT", pinPath, seller.Token, map[string]any{"colors": []map[string]string{{"name": "X", "hex": "red"}}}, nil)
	e.expect(200, "PUT", pinPath, seller.Token, map[string]any{"stock": nil, "price": 280}, &fresh)
	if fresh.Product.Stock != nil || fresh.Product.Price != 280 {
		t.Fatalf("update: %+v", fresh.Product)
	}

	// Deleting the product keeps the order snapshot.
	e.expect(204, "DELETE", pinPath, seller.Token, nil, nil)
	var mine page[orderResp]
	e.expect(200, "GET", "/api/orders", buyer.Token, nil, &mine)
	if len(mine.Items) != 2 || mine.Items[1].Items[0].PinID != nil || mine.Items[1].Items[0].Title != "Gyzyl köýnek" {
		t.Fatalf("snapshot: %+v", mine.Items)
	}

	// Switching back to personal.
	e.expect(200, "DELETE", "/api/me/business", seller.Token, nil, &me)
	if me.IsBusiness || me.Business != nil {
		t.Fatalf("still business: %+v", me)
	}
}

func TestStories(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("storyteller")
	b := e.register("watcher")

	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	_ = w.WriteField("caption", "Täze kolleksiýa")
	fw, _ := w.CreateFormFile("image", "s.png")
	_, _ = fw.Write(testPNG(9, 16))
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	var story struct{ ID uint }
	e.expect(201, "POST", "/api/stories", a.Token, m, &story)

	type group struct {
		User    struct{ Username string } `json:"user"`
		AllSeen bool                      `json:"allSeen"`
		Stories []struct {
			Seen       bool `json:"seen"`
			ViewsCount int  `json:"viewsCount"`
		} `json:"stories"`
	}
	var groups []group
	e.expect(200, "POST", "/api/users/storyteller/follow", b.Token, nil, nil)
	e.expect(200, "GET", "/api/stories", b.Token, nil, &groups)
	if len(groups) != 1 || groups[0].AllSeen {
		t.Fatalf("stories: %+v", groups)
	}
	e.expect(204, "POST", fmt.Sprintf("/api/stories/%d/view", story.ID), b.Token, nil, nil)
	e.expect(200, "GET", "/api/stories", b.Token, nil, &groups)
	if !groups[0].AllSeen {
		t.Fatal("story should be seen")
	}
	var g group
	e.expect(200, "GET", "/api/users/storyteller/stories", a.Token, nil, &g)
	if g.Stories[0].ViewsCount != 1 {
		t.Fatalf("owner should see view count: %+v", g)
	}
	var prof struct {
		HasStory  bool `json:"hasStory"`
		StorySeen bool `json:"storySeen"`
	}
	e.expect(200, "GET", "/api/users/storyteller", b.Token, nil, &prof)
	if !prof.HasStory || !prof.StorySeen {
		t.Fatalf("profile story state: %+v", prof)
	}
	e.expect(403, "DELETE", fmt.Sprintf("/api/stories/%d", story.ID), b.Token, nil, nil)
	e.expect(204, "DELETE", fmt.Sprintf("/api/stories/%d", story.ID), a.Token, nil, nil)
	e.expect(404, "GET", "/api/users/storyteller/stories", "", nil, nil)
}

func TestShopSeed(t *testing.T) {
	e := newEnv(t, true)
	var top []struct {
		Rank      int `json:"rank"`
		MoreCount int `json:"moreCount"`
		Business  struct {
			Covers []string `json:"covers"`
		} `json:"business"`
	}
	e.expect(200, "GET", "/api/top?period=month", "", nil, &top)
	if len(top) < 5 || len(top[0].Business.Covers) == 0 {
		t.Fatalf("seed top: %+v", top)
	}
	var cards page[struct{ Username string }]
	e.expect(200, "GET", "/api/businesses?category=tailor", "", nil, &cards)
	if len(cards.Items) == 0 {
		t.Fatal("no tailors")
	}
	var groups []struct{ User struct{ Username string } }
	e.expect(200, "GET", "/api/stories", "", nil, &groups)
	if len(groups) == 0 {
		t.Fatal("no stories for guests")
	}
}
