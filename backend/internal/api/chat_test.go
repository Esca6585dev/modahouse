package api_test

import (
	"bufio"
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
)

type chatResp struct {
	ID    uint `json:"id"`
	Other struct {
		Username string `json:"username"`
	} `json:"other"`
	LastMessage *msgResp `json:"lastMessage"`
	UnreadCount int      `json:"unreadCount"`
	Blocked     bool     `json:"blocked"`
}

type msgResp struct {
	ID         uint   `json:"id"`
	Kind       string `json:"kind"`
	Text       string `json:"text"`
	ClientID   string `json:"clientId"`
	Mine       bool   `json:"mine"`
	Read       bool   `json:"read"`
	Deleted    bool   `json:"deleted"`
	Attachment *struct {
		URL      string `json:"url"`
		Name     string `json:"name"`
		MimeType string `json:"mimeType"`
		Width    int    `json:"width"`
	} `json:"attachment"`
	Pin *struct {
		ID uint `json:"id"`
	} `json:"pin"`
}

func fileForm(t *testing.T, name string, data []byte, text string) *multipartBody {
	t.Helper()
	m := &multipartBody{}
	w := multipart.NewWriter(&m.buf)
	if text != "" {
		_ = w.WriteField("text", text)
	}
	_ = w.WriteField("clientId", "c-"+name)
	fw, _ := w.CreateFormFile("file", name)
	_, _ = fw.Write(data)
	_ = w.Close()
	m.contentType = w.FormDataContentType()
	return m
}

func TestChatFlow(t *testing.T) {
	e := newEnv(t, false)
	a, b, c := e.register("aygul"), e.register("bahar"), e.register("jeren")

	e.expect(400, "POST", "/api/chats", a.Token, map[string]string{"username": "aygul"}, nil)
	e.expect(404, "POST", "/api/chats", a.Token, map[string]string{"username": "nobody"}, nil)
	e.expect(401, "POST", "/api/chats", "", map[string]string{"username": "bahar"}, nil)

	var ch chatResp
	e.expect(201, "POST", "/api/chats", a.Token, map[string]string{"username": "@Bahar"}, &ch)
	var again chatResp
	e.expect(200, "POST", "/api/chats", b.Token, map[string]string{"username": "aygul"}, &again)
	if again.ID != ch.ID || ch.Other.Username != "bahar" || again.Other.Username != "aygul" {
		t.Fatalf("one chat per pair: %+v %+v", ch, again)
	}
	path := "/api/chats/" + itoa(ch.ID)
	e.expect(404, "GET", path, c.Token, nil, nil) // not a member

	// Empty chats are not listed.
	var list page[chatResp]
	e.expect(200, "GET", "/api/chats", a.Token, nil, &list)
	if len(list.Items) != 0 {
		t.Fatalf("empty chat listed: %+v", list.Items)
	}

	var m1, m2 msgResp
	e.expect(400, "POST", path+"/messages", a.Token, map[string]string{"text": "   "}, nil)
	e.expect(201, "POST", path+"/messages", a.Token, map[string]string{"text": " Salam! ", "clientId": "x1"}, &m1)
	if m1.Text != "Salam!" || !m1.Mine || m1.Read || m1.ClientID != "x1" || m1.Kind != "text" {
		t.Fatalf("message: %+v", m1)
	}
	e.expect(404, "POST", path+"/messages", c.Token, map[string]string{"text": "hi"}, nil) // not a member
	e.expect(400, "POST", path+"/messages", a.Token, map[string]string{"text": strings.Repeat("a", 2001)}, nil)

	var unread struct{ Count int }
	e.expect(200, "GET", "/api/chats/unread-count", b.Token, nil, &unread)
	if unread.Count != 1 {
		t.Fatalf("unread for b: %d", unread.Count)
	}
	e.expect(200, "GET", "/api/chats", b.Token, nil, &list)
	if len(list.Items) != 1 || list.Items[0].UnreadCount != 1 || list.Items[0].LastMessage.Text != "Salam!" || list.Items[0].LastMessage.Mine {
		t.Fatalf("b's chats: %+v", list.Items)
	}

	// b reads; a sees the tick.
	e.expect(204, "POST", path+"/read", b.Token, map[string]uint{"messageId": m1.ID}, nil)
	e.expect(200, "GET", "/api/chats/unread-count", b.Token, nil, &unread)
	if unread.Count != 0 {
		t.Fatalf("still unread: %d", unread.Count)
	}
	var msgs struct {
		Items   []msgResp `json:"items"`
		HasMore bool      `json:"hasMore"`
	}
	e.expect(200, "GET", path+"/messages", a.Token, nil, &msgs)
	if len(msgs.Items) != 1 || !msgs.Items[0].Read {
		t.Fatalf("read tick: %+v", msgs.Items)
	}

	// Share a post.
	var p pinResp
	e.expect(201, "POST", "/api/pins", b.Token, pinForm(t, map[string]string{"title": "Köýnek", "category": "milli"}, testPNG(300, 400)), &p)
	e.expect(201, "POST", path+"/messages", b.Token, map[string]any{"pinId": p.ID, "text": "Görüň"}, &m2)
	if m2.Kind != "pin" || m2.Pin == nil || m2.Pin.ID != p.ID {
		t.Fatalf("pin message: %+v", m2)
	}

	// Paging: oldest first, before= goes back.
	for i := 0; i < 5; i++ {
		e.expect(201, "POST", path+"/messages", a.Token, map[string]string{"text": "msg " + itoa(uint(i))}, nil)
	}
	e.expect(200, "GET", path+"/messages?limit=3", a.Token, nil, &msgs)
	if len(msgs.Items) != 3 || !msgs.HasMore || msgs.Items[2].Text != "msg 4" {
		t.Fatalf("page 1: %+v", msgs)
	}
	e.expect(200, "GET", path+"/messages?limit=3&before="+itoa(msgs.Items[0].ID), a.Token, nil, &msgs)
	if len(msgs.Items) != 3 || msgs.Items[0].Kind != "pin" || !msgs.HasMore {
		t.Fatalf("page 2: %+v", msgs)
	}

	// Delete: only own, text cleared.
	e.expect(403, "DELETE", "/api/messages/"+itoa(m1.ID), b.Token, nil, nil)
	e.expect(204, "DELETE", "/api/messages/"+itoa(m1.ID), a.Token, nil, nil)
	e.expect(200, "GET", path+"/messages?limit=50", b.Token, nil, &msgs)
	if !msgs.Items[0].Deleted || msgs.Items[0].Text != "" {
		t.Fatalf("deleted: %+v", msgs.Items[0])
	}

	e.expect(204, "POST", path+"/typing", a.Token, nil, nil)

	// Blocking stops sending both ways.
	e.expect(200, "POST", "/api/users/bahar/block", a.Token, nil, nil)
	e.expect(403, "POST", path+"/messages", b.Token, map[string]string{"text": "?"}, nil)
	e.expect(403, "POST", path+"/messages", a.Token, map[string]string{"text": "?"}, nil)
	e.expect(200, "GET", path, b.Token, nil, &ch)
	if !ch.Blocked {
		t.Fatal("blocked flag")
	}
	e.expect(201, "POST", "/api/chats", c.Token, map[string]string{"username": "aygul"}, nil) // others still can
}

func TestChatFiles(t *testing.T) {
	e := newEnv(t, false)
	a, b, c := e.register("aygul"), e.register("bahar"), e.register("jeren")
	var ch chatResp
	e.expect(201, "POST", "/api/chats", a.Token, map[string]string{"username": "bahar"}, &ch)
	path := "/api/chats/" + itoa(ch.ID) + "/messages"

	var img, pdf msgResp
	e.expect(201, "POST", path, a.Token, fileForm(t, "photo.png", testPNG(320, 240), "Seret"), &img)
	if img.Kind != "image" || img.Attachment == nil || img.Attachment.Width != 320 || img.Text != "Seret" || img.ClientID != "c-photo.png" {
		t.Fatalf("image message: %+v", img)
	}
	e.expect(201, "POST", path, a.Token, fileForm(t, "../../ölçeg.pdf", []byte("%PDF-1.4 test"), ""), &pdf)
	if pdf.Kind != "file" || pdf.Attachment.Name != "ölçeg.pdf" || pdf.Attachment.MimeType != "application/pdf" {
		t.Fatalf("pdf message: %+v", pdf.Attachment)
	}
	e.expect(400, "POST", path, a.Token, fileForm(t, "virus.exe", []byte("MZ\x90\x00"), ""), nil)
	e.expect(400, "POST", path, a.Token, fileForm(t, "fake.pdf", []byte("not a pdf"), ""), nil)
	e.expect(400, "POST", path, a.Token, fileForm(t, "page.html", []byte("<html><script>x</script>"), ""), nil)

	// Signed links work for anyone holding them, tampered or expired ones don't.
	u := img.Attachment.URL
	if s, h, data := e.raw("GET", u, "", nil, ""); s != 200 || h["Content-Type"] != "image/png" || len(data) == 0 {
		t.Fatalf("signed image: %d %v", s, h)
	}
	if s, h, _ := e.raw("GET", pdf.Attachment.URL, "", nil, ""); s != 200 || h["Content-Disposition"] != "attachment" {
		t.Fatalf("pdf should download: %d %v", s, h)
	}
	tampered := u[:len(u)-1] + "0"
	if strings.HasSuffix(u, "0") {
		tampered = u[:len(u)-1] + "1"
	}
	if s, _, _ := e.raw("GET", tampered, "", nil, ""); s != 404 {
		t.Fatalf("tampered signature: %d", s)
	}
	name := u[len("/api/chat-files/"):strings.Index(u, "?")]
	if s, _, _ := e.raw("GET", "/api/chat-files/"+name+"?exp=1&sig=x", "", nil, ""); s != 404 {
		t.Fatalf("expired link: %d", s)
	}
	if s, _, _ := e.raw("GET", "/uploads/.private/chat/"+name, "", nil, ""); s != 404 {
		t.Fatalf("private file served publicly: %d", s)
	}
	_ = b
	_ = c

	// Deleting removes the file.
	e.expect(204, "DELETE", "/api/messages/"+itoa(img.ID), a.Token, nil, nil)
	if s, _, _ := e.raw("GET", u, "", nil, ""); s != 404 {
		t.Fatalf("deleted file still served: %d", s)
	}
}

// sseClient reads events from a live server.
type sseEvent struct {
	Name string
	Data map[string]any
}

func readEvents(t *testing.T, resp *http.Response, out chan<- sseEvent) {
	sc := bufio.NewScanner(resp.Body)
	var name string
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "event: "):
			name = strings.TrimPrefix(line, "event: ")
		case strings.HasPrefix(line, "data: "):
			var d map[string]any
			_ = json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &d)
			out <- sseEvent{name, d}
		}
	}
	close(out)
}

func waitEvent(t *testing.T, ch <-chan sseEvent, name string) sseEvent {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case ev, ok := <-ch:
			if !ok {
				t.Fatalf("stream closed waiting for %s", name)
			}
			if ev.Name == name {
				return ev
			}
		case <-timeout:
			t.Fatalf("no %s event", name)
		}
	}
}

func TestRealtimeEvents(t *testing.T) {
	e := newEnv(t, false)
	a, b := e.register("aygul"), e.register("bahar")

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = e.app.Listener(ln, fiber.ListenConfig{DisableStartupMessage: true}) }()
	t.Cleanup(func() { _ = e.app.Shutdown() })
	base := "http://" + ln.Addr().String()

	if resp, err := http.Get(base + "/api/events"); err != nil || resp.StatusCode != 401 {
		t.Fatalf("events without token: %v %v", err, resp)
	}
	resp, err := http.Get(base + "/api/events?token=" + b.Token)
	if err != nil || resp.StatusCode != 200 || !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") ||
		resp.Header.Get("X-Accel-Buffering") != "no" {
		t.Fatalf("events: %v %v", err, resp)
	}
	defer resp.Body.Close()
	events := make(chan sseEvent, 32)
	go readEvents(t, resp, events)
	if ev := waitEvent(t, events, "ready"); ev.Data["userId"] != float64(b.User.ID) {
		t.Fatalf("ready: %+v", ev)
	}

	post := func(path, token string, body any) *http.Response {
		data, _ := json.Marshal(body)
		req, _ := http.NewRequest("POST", base+path, bytes.NewReader(data))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		r, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		r.Body.Close()
		return r
	}
	var ch chatResp
	e.expect(201, "POST", "/api/chats", a.Token, map[string]string{"username": "bahar"}, &ch)
	cp := "/api/chats/" + itoa(ch.ID)

	post(cp+"/typing", a.Token, nil)
	if ev := waitEvent(t, events, "typing"); ev.Data["userId"] != float64(a.User.ID) {
		t.Fatalf("typing: %+v", ev)
	}
	post(cp+"/messages", a.Token, map[string]string{"text": "Salam", "clientId": "k1"})
	ev := waitEvent(t, events, "message")
	msg := ev.Data["message"].(map[string]any)
	if msg["text"] != "Salam" || msg["mine"] != false || msg["clientId"] != "k1" {
		t.Fatalf("message event: %+v", ev)
	}

	// b's read reaches a's stream too; b gets its own copy.
	post(cp+"/read", b.Token, map[string]any{"messageId": msg["id"]})
	if ev := waitEvent(t, events, "read"); ev.Data["userId"] != float64(b.User.ID) {
		t.Fatalf("read: %+v", ev)
	}

	// Notifications are pushed live.
	var p pinResp
	e.expect(201, "POST", "/api/pins", b.Token, pinForm(t, map[string]string{"title": "Köýnek", "category": "milli"}, testPNG(300, 400)), &p)
	post("/api/pins/"+itoa(p.ID)+"/like", a.Token, nil)
	ev = waitEvent(t, events, "notification")
	if ev.Data["unreadCount"] != float64(1) || ev.Data["notification"].(map[string]any)["type"] != "like" {
		t.Fatalf("notification: %+v", ev)
	}
}
