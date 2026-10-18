package api

import (
	"bufio"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
)

// event is one Server-Sent Event ready to write.
type event struct {
	name string
	data []byte
}

type subscriber struct {
	ch chan event
}

// hub fans events out to every open /events stream of a user (one process;
// run a single API instance, or replace this with Redis pub/sub to scale out).
type hub struct {
	mu     sync.RWMutex
	subs   map[uint]map[*subscriber]struct{}
	closed bool
}

func newHub() *hub { return &hub{subs: map[uint]map[*subscriber]struct{}{}} }

func (h *hub) subscribe(uid uint) *subscriber {
	s := &subscriber{ch: make(chan event, 64)}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		close(s.ch)
		return s
	}
	if h.subs[uid] == nil {
		h.subs[uid] = map[*subscriber]struct{}{}
	}
	h.subs[uid][s] = struct{}{}
	return s
}

func (h *hub) unsubscribe(uid uint, s *subscriber) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if set, ok := h.subs[uid]; ok {
		if _, ok := set[s]; ok {
			delete(set, s)
			close(s.ch)
		}
		if len(set) == 0 {
			delete(h.subs, uid)
		}
	}
}

// publish sends v as JSON to every stream of uid. A stream that is too slow to
// keep up drops the event rather than blocking the sender.
func (h *hub) publish(uid uint, name string, v any) {
	data, err := json.Marshal(v)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for s := range h.subs[uid] {
		select {
		case s.ch <- event{name: name, data: data}:
		default:
		}
	}
}

func (h *hub) online(uid uint) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.subs[uid]) > 0
}

// closeAll ends every stream (server shutdown).
func (h *hub) closeAll() {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.closed = true
	for uid, set := range h.subs {
		for s := range set {
			close(s.ch)
		}
		delete(h.subs, uid)
	}
}

const pingEvery = 25 * time.Second

// events streams real-time events to the signed-in user. Browsers' EventSource
// can't send headers, so the token may also come as ?token=.
func (h *Handler) events(c fiber.Ctx) error {
	uid := viewerID(c)
	if uid == 0 {
		if raw := strings.TrimSpace(c.Query("token")); raw != "" {
			uid = h.userFromToken(raw)
		}
	}
	if uid == 0 {
		return fail(c, fiber.StatusUnauthorized, "Ilki ulgama giriň")
	}
	c.Set(fiber.HeaderContentType, "text/event-stream; charset=utf-8")
	c.Set(fiber.HeaderCacheControl, "no-cache, no-transform")
	c.Set(fiber.HeaderConnection, "keep-alive")
	c.Set("X-Accel-Buffering", "no") // nginx: don't buffer the stream

	sub := h.hub.subscribe(uid)
	return c.SendStreamWriter(func(w *bufio.Writer) {
		defer h.hub.unsubscribe(uid, sub)
		write := func(name string, data []byte) bool {
			if _, err := fmt.Fprintf(w, "event: %s\ndata: %s\n\n", name, data); err != nil {
				return false
			}
			return w.Flush() == nil
		}
		ready, _ := json.Marshal(fiber.Map{"userId": uid})
		// Ask clients to wait 3 s before reconnecting after a drop.
		if _, err := w.WriteString("retry: 3000\n"); err != nil || !write("ready", ready) {
			return
		}
		ticker := time.NewTicker(pingEvery)
		defer ticker.Stop()
		for {
			select {
			case ev, ok := <-sub.ch:
				if !ok {
					return
				}
				if !write(ev.name, ev.data) {
					return
				}
			case <-ticker.C:
				if _, err := w.WriteString(": ping\n\n"); err != nil || w.Flush() != nil {
					return
				}
			}
		}
	})
}
