// Package ai writes Turkmen post copy (title, caption, hashtags, price line)
// with Claude, falling back to templates when no API credentials are configured.
package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/shared/constant"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

type Category struct{ Slug, Name string }

type Request struct {
	ListingType string // post, sale, rent, custom
	Category    string
	Title       string
	Notes       string
	Image       []byte // optional; JPEG/PNG/GIF/WEBP
}

type Suggestion struct {
	Title       string   `json:"title"`
	Description string   `json:"description"`
	Hashtags    []string `json:"hashtags"`
	Category    string   `json:"category"`
	PriceLine   string   `json:"priceLine"`
	Details     []string `json:"details"`
	Source      string   `json:"source"` // "ai" or "template"
}

type Service struct {
	client     *anthropic.Client
	model      string
	categories []Category
}

// New enables Claude when credentials are configured (ANTHROPIC_API_KEY,
// ANTHROPIC_AUTH_TOKEN, or AI_ENABLED=true for the SDK's other credential sources).
func New(model string, categories []Category) *Service {
	s := &Service{model: model, categories: categories}
	if os.Getenv("ANTHROPIC_API_KEY") != "" || os.Getenv("ANTHROPIC_AUTH_TOKEN") != "" || os.Getenv("AI_ENABLED") == "true" {
		c := anthropic.NewClient()
		s.client = &c
	}
	return s
}

func (s *Service) Enabled() bool { return s.client != nil }

// NewWithClient is used by tests to point the service at a fake API server.
func NewWithClient(c anthropic.Client, model string, categories []Category) *Service {
	return &Service{client: &c, model: model, categories: categories}
}

// Suggest returns Claude's suggestion, or a template one if Claude is unavailable or fails.
func (s *Service) Suggest(ctx context.Context, r Request) Suggestion {
	if s.client != nil {
		out, err := s.claude(ctx, r)
		if err == nil {
			out.Source = "ai"
			return s.tidy(out, r)
		}
		log.Printf("ai: falling back to templates: %v", err)
	}
	return s.tidy(s.template(r), r)
}

const systemPrompt = `You are the copywriter of ModaHouse ("Modalar öýi"), a fashion app where Turkmen women and girls share and shop dresses, collar styles, hand embroidery, wedding wear, hair, make-up, nails and jewellery. Shops and ateliers post items for sale, for rent and for made-to-order tailoring.

Write everything in Turkmen (Latin script with the letters ä, ç, ž, ň, ö, ş, ü, ý), warm, elegant and concise, the way a good Instagram boutique writes.

Never invent facts. Prices, phone numbers, sizes, fabrics, delivery times, rent terms and addresses may only come from the author's notes or be clearly visible in the image. When the listing type needs a value that is missing, write "…" as a placeholder the author will fill in.

Fields:
- title: at most 60 characters, no hashtags, no leading emoji.
- description: 2 to 5 short lines; at most 3 tasteful emoji; no hashtags; describe what is visible (cut, collar, sleeves, embroidery, colour, fabric look) and end with a call to action that fits the listing type: post = invite to save/share; sale = order; rent = book the dates; custom = order your size.
- hashtags: 5 to 10, lowercase, without "#" and without spaces (for example toýköýnek, milliköýnek, elkeşde, ýakafason, gelinlik, türkmenmoda).
- category: exactly one slug from the provided list.
- priceLine: empty for "post". sale: "Bahasy: X TMT". rent: "Günlük kärende: X TMT" and, if given, " · Girew: Y TMT" and " · Iň az Z gün". custom: "Bahasy: X TMT-dan başlap" and, if given, " · N günde taýýar".
- details: 0 to 5 short facts buyers ask about for this listing type (sizes, fabric, rent terms, fitting, delivery), only from the notes or the image.`

var listingNames = map[string]string{
	"post": "Diňe paýlaşmak (no price)", "sale": "Satlyk (for sale)", "rent": "Kärende (daily rental)", "custom": "Sargyt bilen tikmek (made to order)",
}

func (s *Service) schema() map[string]any {
	slugs := make([]any, len(s.categories))
	for i, c := range s.categories {
		slugs[i] = c.Slug
	}
	str := map[string]any{"type": "string"}
	list := map[string]any{"type": "array", "items": str}
	return map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"required":             []any{"title", "description", "hashtags", "category", "priceLine", "details"},
		"properties": map[string]any{
			"title": str, "description": str, "hashtags": list, "priceLine": str, "details": list,
			"category": map[string]any{"type": "string", "enum": slugs},
		},
	}
}

func (s *Service) claude(ctx context.Context, r Request) (Suggestion, error) {
	var cats []string
	for _, c := range s.categories {
		cats = append(cats, c.Slug+" = "+c.Name)
	}
	prompt := fmt.Sprintf("Listing type: %s\nCategories: %s\nCurrent category: %s\nTitle so far: %s\nAuthor's notes: %s",
		listingNames[r.ListingType], strings.Join(cats, "; "), orDash(r.Category), orDash(r.Title), orDash(r.Notes))

	var blocks []anthropic.BetaContentBlockParamUnion
	if img, mt, ok := prepareImage(r.Image); ok {
		blocks = append(blocks, anthropic.NewBetaImageBlock(anthropic.BetaBase64ImageSourceParam{
			Data: base64.StdEncoding.EncodeToString(img), MediaType: anthropic.BetaBase64ImageSourceMediaType(mt),
		}))
	}
	blocks = append(blocks, anthropic.NewBetaTextBlock(prompt))

	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	resp, err := s.client.Beta.Messages.New(ctx, anthropic.BetaMessageNewParams{
		Model:     anthropic.Model(s.model),
		MaxTokens: 4096,
		System:    []anthropic.BetaTextBlockParam{{Text: systemPrompt}},
		Messages:  []anthropic.BetaMessageParam{anthropic.NewBetaUserMessage(blocks...)},
		OutputConfig: anthropic.BetaOutputConfigParam{
			Effort: "low", // short copywriting; keeps latency and cost down
			Format: anthropic.BetaJSONOutputFormatParam{Schema: s.schema()},
		},
		// Re-serve policy declines on a fallback model inside the same call.
		Fallbacks: anthropic.BetaFallbacksParamUnion{OfDefault: constant.ValueOf[constant.Default]()},
		Betas:     []anthropic.AnthropicBeta{anthropic.AnthropicBetaServerSideFallback2026_07_01},
	})
	if err != nil {
		return Suggestion{}, err
	}
	if resp.StopReason == anthropic.BetaStopReasonRefusal {
		return Suggestion{}, errors.New("request declined")
	}
	for _, block := range resp.Content {
		if t, ok := block.AsAny().(anthropic.BetaTextBlock); ok {
			var out Suggestion
			if err := json.Unmarshal([]byte(t.Text), &out); err != nil {
				return Suggestion{}, fmt.Errorf("decode: %w", err)
			}
			return out, nil
		}
	}
	return Suggestion{}, errors.New("empty response")
}

func orDash(s string) string {
	if strings.TrimSpace(s) == "" {
		return "—"
	}
	return s
}

// prepareImage keeps images under the API limits: at most 1568 px on the long side, JPEG.
func prepareImage(data []byte) ([]byte, string, bool) {
	if len(data) == 0 {
		return nil, "", false
	}
	mt := http.DetectContentType(data)
	switch mt {
	case "image/jpeg", "image/png", "image/gif", "image/webp":
	default:
		return nil, "", false
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, "", false
	}
	const maxSide = 1568
	if len(data) < 3_500_000 && cfg.Width <= maxSide && cfg.Height <= maxSide && mt != "image/webp" {
		return data, mt, true
	}
	src, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, "", false
	}
	w, h := cfg.Width, cfg.Height
	if w > h && w > maxSide {
		w, h = maxSide, h*maxSide/w
	} else if h > maxSide {
		w, h = w*maxSide/h, maxSide
	}
	dst := image.NewRGBA(image.Rect(0, 0, max(w, 1), max(h, 1)))
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, src.Bounds(), draw.Over, nil)
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, dst, &jpeg.Options{Quality: 85}); err != nil {
		return nil, "", false
	}
	return buf.Bytes(), "image/jpeg", true
}

var numberRe = regexp.MustCompile(`\d[\d ]{0,8}`)

// numbers pulls integers out of the author's notes, in order.
func numbers(s string) []string {
	var out []string
	for _, m := range numberRe.FindAllString(s, -1) {
		out = append(out, strings.ReplaceAll(strings.TrimSpace(m), " ", ""))
	}
	return out
}

func (s *Service) categoryName(slug string) string {
	for _, c := range s.categories {
		if c.Slug == slug {
			return c.Name
		}
	}
	return ""
}

var categoryTags = map[string][]string{
	"toy": {"toýköýnek", "toý", "agşamköýnek"}, "gelin": {"gelinlik", "gelinlibasy", "toý"}, "milli": {"milliköýnek", "türkmenlibasy", "milli"},
	"koynekler": {"köýnek", "moda", "stil"}, "yaka": {"ýakafason", "ýakakeşde", "fason"}, "keshde": {"elkeşde", "keşde", "elişi"},
	"gundelik": {"gündelikmoda", "stil", "obraz"}, "sac": {"saçdüzüm", "örüm", "saç"}, "makiyaj": {"makiýaž", "gözellik", "makeup"},
	"dyrnak": {"dyrnak", "dyrnakdizaýny", "manikýur"}, "shay": {"şaýsep", "kümüş", "türkmenşaý"}, "aksessuar": {"aksessuar", "sumka", "stil"},
}

// template builds a sensible suggestion without the model.
func (s *Service) template(r Request) Suggestion {
	cat := r.Category
	if s.categoryName(cat) == "" && len(s.categories) > 0 {
		cat = s.categories[0].Slug
	}
	name := s.categoryName(cat)
	title := strings.TrimSpace(r.Title)
	if title == "" {
		title = name
	}
	nums := numbers(r.Notes)
	num := func(i int) string {
		if i < len(nums) {
			return nums[i]
		}
		return "…"
	}
	out := Suggestion{Title: title, Category: cat, Details: []string{}, Source: "template"}
	notes := strings.TrimSpace(r.Notes)
	switch r.ListingType {
	case "sale":
		out.Description = fmt.Sprintf("✨ %s\n%s\nÖlçegiňizi we reňkini saýlap, şu gün sargyt ediň! 🛍️", title, firstNonEmpty(notes, "Ýokary hilli mata, owadan tikin."))
		out.PriceLine = "Bahasy: " + num(0) + " TMT"
		out.Details = []string{"Ölçegleri: …", "Matasy: …", "Eltip bermek: … gün"}
	case "rent":
		out.Description = fmt.Sprintf("👗 %s kärendä berilýär!\n%s\nToýuňyzyň senesini öňünden bellediň — günler tiz eýelenýär. 📅", title, firstNonEmpty(notes, "Arassa, täze ýaly ýagdaýda."))
		out.PriceLine = "Günlük kärende: " + num(0) + " TMT · Girew: " + num(1) + " TMT"
		out.Details = []string{"Ölçegleri: …", "Iň az kärende möhleti: … gün", "Synap görmek mümkin"}
	case "custom":
		out.Description = fmt.Sprintf("✂️ %s — ölçegiňize görä tikýäris.\n%s\nIsleýän fasonyňyzy we reňkiňizi ýazyň, bilelikde saýlalyň! 💬", title, firstNonEmpty(notes, "Mata we keşde saýlamaga kömek ederis."))
		out.PriceLine = "Bahasy: " + num(0) + " TMT-dan başlap · " + num(1) + " günde taýýar"
		out.Details = []string{"Ölçeg almak: salonda ýa-da öýde", "Matany saýlap bolýar", "Taýýar bolmak möhleti: … gün"}
	default:
		out.Description = fmt.Sprintf("🌸 %s\n%s\nHalasaňyz, tagtaňyza saklaň we dostlaryňyz bilen paýlaşyň! 💕", title, firstNonEmpty(notes, "Täze ideýa — sizem synap görüň."))
	}
	out.Hashtags = append([]string{}, categoryTags[cat]...)
	out.Hashtags = append(out.Hashtags, "modahouse", "türkmenmoda")
	switch r.ListingType {
	case "rent":
		out.Hashtags = append(out.Hashtags, "kärende")
	case "custom":
		out.Hashtags = append(out.Hashtags, "tikinçi")
	case "sale":
		out.Hashtags = append(out.Hashtags, "satlyk")
	}
	return out
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// tidy normalizes either source: valid category, clean hashtags, no price line for posts.
func (s *Service) tidy(out Suggestion, r Request) Suggestion {
	if s.categoryName(out.Category) == "" {
		out.Category = r.Category
		if s.categoryName(out.Category) == "" && len(s.categories) > 0 {
			out.Category = s.categories[0].Slug
		}
	}
	seen := map[string]bool{}
	tags := []string{}
	for _, t := range out.Hashtags {
		t = strings.ToLower(strings.ReplaceAll(strings.TrimPrefix(strings.TrimSpace(t), "#"), " ", ""))
		if t != "" && !seen[t] && len(tags) < 10 {
			seen[t] = true
			tags = append(tags, t)
		}
	}
	out.Hashtags = tags
	if out.Details == nil {
		out.Details = []string{}
	}
	if r.ListingType == "post" || r.ListingType == "" {
		out.PriceLine = ""
	}
	if len([]rune(out.Title)) > 80 {
		out.Title = string([]rune(out.Title)[:80])
	}
	return out
}

// Classify returns the category slug of a fashion photo, or "" when the model is
// unavailable or unsure. Used to boost visual search results.
func (s *Service) Classify(ctx context.Context, img []byte) string {
	if s.client == nil {
		return ""
	}
	data, mt, ok := prepareImage(img)
	if !ok {
		return ""
	}
	slugs := []any{"none"}
	var names []string
	for _, c := range s.categories {
		slugs = append(slugs, c.Slug)
		names = append(names, c.Slug+" = "+c.Name)
	}
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	resp, err := s.client.Beta.Messages.New(ctx, anthropic.BetaMessageNewParams{
		Model:     anthropic.Model(s.model),
		MaxTokens: 1024,
		Messages: []anthropic.BetaMessageParam{anthropic.NewBetaUserMessage(
			anthropic.NewBetaImageBlock(anthropic.BetaBase64ImageSourceParam{Data: base64.StdEncoding.EncodeToString(data), MediaType: anthropic.BetaBase64ImageSourceMediaType(mt)}),
			anthropic.NewBetaTextBlock("Which category of this fashion app best matches the main item in the photo? Categories: "+strings.Join(names, "; ")+". Answer \"none\" if nothing fits."),
		)},
		OutputConfig: anthropic.BetaOutputConfigParam{
			Effort: "low",
			Format: anthropic.BetaJSONOutputFormatParam{Schema: map[string]any{
				"type": "object", "additionalProperties": false, "required": []any{"category"},
				"properties": map[string]any{"category": map[string]any{"type": "string", "enum": slugs}},
			}},
		},
		Fallbacks: anthropic.BetaFallbacksParamUnion{OfDefault: constant.ValueOf[constant.Default]()},
		Betas:     []anthropic.AnthropicBeta{anthropic.AnthropicBetaServerSideFallback2026_07_01},
	})
	if err != nil || resp.StopReason == anthropic.BetaStopReasonRefusal {
		return ""
	}
	for _, block := range resp.Content {
		if t, ok := block.AsAny().(anthropic.BetaTextBlock); ok {
			var out struct{ Category string }
			if json.Unmarshal([]byte(t.Text), &out) == nil && s.categoryName(out.Category) != "" {
				return out.Category
			}
		}
	}
	return ""
}
