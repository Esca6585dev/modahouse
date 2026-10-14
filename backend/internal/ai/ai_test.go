package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"image"
	"image/png"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

var cats = []Category{{"toy", "Toý köýnekleri"}, {"milli", "Milli köýnekler"}}

func TestClaudeRequestAndParse(t *testing.T) {
	var body map[string]any
	var betaHeader string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		betaHeader = r.Header.Get("anthropic-beta")
		answer, _ := json.Marshal(map[string]any{
			"title": "Gyzyl toý köýnegi", "description": "Owadan köýnek ✨", "hashtags": []string{"#ToýKöýnek", "toý köýnek", "toýköýnek"},
			"category": "toy", "priceLine": "Günlük kärende: 250 TMT", "details": []string{"Ölçegi: 44"},
		})
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"id": "msg_1", "type": "message", "role": "assistant", "model": "claude-opus-5-5",
			"content": []any{
				map[string]any{"type": "thinking", "thinking": "", "signature": "x"},
				map[string]any{"type": "text", "text": string(answer)},
			},
			"stop_reason": "end_turn", "usage": map[string]any{"input_tokens": 10, "output_tokens": 10},
		})
	}))
	defer srv.Close()

	client := anthropic.NewClient(option.WithAPIKey("test"), option.WithBaseURL(srv.URL), option.WithMaxRetries(0))
	s := NewWithClient(client, "claude-opus-5-5", cats)

	img := image.NewRGBA(image.Rect(0, 0, 20, 30))
	var buf bytes.Buffer
	_ = png.Encode(&buf, img)
	out := s.Suggest(context.Background(), Request{ListingType: "rent", Category: "toy", Notes: "250 manat günlük", Image: buf.Bytes()})

	if out.Source != "ai" || out.Title != "Gyzyl toý köýnegi" || out.PriceLine == "" {
		t.Fatalf("unexpected suggestion: %+v", out)
	}
	if strings.Join(out.Hashtags, ",") != "toýköýnek" {
		t.Fatalf("hashtags not normalized: %v", out.Hashtags)
	}
	if body["model"] != "claude-opus-5-5" {
		t.Fatalf("model: %v", body["model"])
	}
	oc, _ := body["output_config"].(map[string]any)
	format, _ := oc["format"].(map[string]any)
	if format["type"] != "json_schema" || oc["effort"] != "low" {
		t.Fatalf("output_config: %v", oc)
	}
	if body["fallbacks"] != "default" || !strings.Contains(betaHeader, "server-side-fallback-2026-07-01") {
		t.Fatalf("fallbacks: %v / %q", body["fallbacks"], betaHeader)
	}
	msgs, _ := body["messages"].([]any)
	content := msgs[0].(map[string]any)["content"].([]any)
	if content[0].(map[string]any)["type"] != "image" || content[1].(map[string]any)["type"] != "text" {
		t.Fatalf("content blocks: %v", content)
	}
}

func TestClaudeFailureFallsBackToTemplate(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, `{"type":"error","error":{"type":"api_error","message":"boom"}}`, 500)
	}))
	defer srv.Close()
	client := anthropic.NewClient(option.WithAPIKey("test"), option.WithBaseURL(srv.URL), option.WithMaxRetries(0))
	out := NewWithClient(client, "claude-opus-5-5", cats).Suggest(context.Background(), Request{ListingType: "sale", Category: "milli", Title: "Keşdeli köýnek", Notes: "450"})
	if out.Source != "template" || out.PriceLine != "Bahasy: 450 TMT" || out.Category != "milli" {
		t.Fatalf("fallback: %+v", out)
	}
}

func TestTemplates(t *testing.T) {
	s := New("claude-opus-5-5", cats) // no credentials in tests → templates
	if s.Enabled() {
		t.Skip("credentials present in the environment")
	}
	for _, lt := range []string{"post", "sale", "rent", "custom"} {
		out := s.Suggest(context.Background(), Request{ListingType: lt, Category: "nope", Notes: "300 600"})
		if out.Source != "template" || out.Description == "" || len(out.Hashtags) < 5 || out.Category != "toy" {
			t.Fatalf("%s: %+v", lt, out)
		}
		if (lt == "post") != (out.PriceLine == "") {
			t.Fatalf("%s price line: %q", lt, out.PriceLine)
		}
	}
	rent := s.Suggest(context.Background(), Request{ListingType: "rent", Category: "toy", Notes: "Günlük 300, girew 600"})
	if rent.PriceLine != "Günlük kärende: 300 TMT · Girew: 600 TMT" {
		t.Fatalf("rent price line: %q", rent.PriceLine)
	}
}
