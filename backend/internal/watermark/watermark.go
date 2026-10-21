// Package watermark draws the ModaHouse logo onto images (downloads, uploads)
// and renders branded share cards.
package watermark

import (
	"bytes"
	"image"
	"image/color"
	"image/draw"
	"math"
	"strings"
	"sync"
	"unicode"

	"github.com/srwiley/oksvg"
	"github.com/srwiley/rasterx"
	xdraw "golang.org/x/image/draw"
	"golang.org/x/image/font"
	"golang.org/x/image/font/gofont/gobold"
	"golang.org/x/image/font/opentype"
	"golang.org/x/image/math/fixed"
)

// Brand colours (brand/README.md).
var (
	Red   = color.RGBA{0xD7, 0x26, 0x3D, 0xff}
	Ink   = color.RGBA{0x26, 0x2B, 0x2F, 0xff}
	White = color.RGBA{0xff, 0xff, 0xff, 0xff}
	Muted = color.RGBA{0x76, 0x76, 0x76, 0xff}
)

// The "moda" letters and the roof of brand/logo-wordmark.svg (300×160 view box).
// "HOUSE" is a <text> element there, so it is drawn with a font instead.
const lettersSVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 160">
<g fill="none" stroke="{INK}" stroke-width="7.5" stroke-linecap="round" stroke-linejoin="round">
<path d="M14 110 V76 A16 16 0 0 1 46 76 V110 M46 76 A16 16 0 0 1 78 76 V110"/>
<circle cx="114" cy="85" r="24"/><circle cx="176" cy="85" r="24"/><path d="M200 110 V38"/>
<circle cx="238" cy="85" r="24"/><path d="M262 62 V110"/></g>
<path d="M184 30 L200 15 L216 30" fill="none" stroke="{ROOF}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>`

var (
	fontOnce sync.Once
	boldFont *opentype.Font
)

func bold() *opentype.Font {
	fontOnce.Do(func() {
		f, err := opentype.Parse(gobold.TTF)
		if err != nil {
			panic(err)
		}
		boldFont = f
	})
	return boldFont
}

func face(size float64) font.Face {
	f, err := opentype.NewFace(bold(), &opentype.FaceOptions{Size: size, DPI: 72, Hinting: font.HintingFull})
	if err != nil {
		panic(err)
	}
	return f
}

func hex(c color.RGBA) string {
	const digits = "0123456789ABCDEF"
	b := []byte{'#', 0, 0, 0, 0, 0, 0}
	for i, v := range []uint8{c.R, c.G, c.B} {
		b[1+2*i], b[2+2*i] = digits[v>>4], digits[v&15]
	}
	return string(b)
}

// Logo renders the wordmark on a transparent canvas of the given width
// (height = width × 160/300). ink colours the letters, accent the roof and "HOUSE".
func Logo(width int, ink, accent color.RGBA) *image.RGBA {
	if width < 30 {
		width = 30
	}
	scale := float64(width) / 300
	height := int(math.Round(160 * scale))
	dst := image.NewRGBA(image.Rect(0, 0, width, height))

	svg := strings.NewReplacer("{INK}", hex(ink), "{ROOF}", hex(accent)).Replace(lettersSVG)
	icon, err := oksvg.ReadIconStream(strings.NewReader(svg), oksvg.IgnoreErrorMode)
	if err == nil {
		icon.SetTarget(0, 0, float64(width), float64(height))
		scanner := rasterx.NewScannerGV(width, height, dst, dst.Bounds())
		icon.Draw(rasterx.NewDasher(width, height, scanner), 1)
	}
	// HOUSE: right-aligned at x=264, baseline y=147, size 30, letter spacing 2.5.
	f := face(30 * scale)
	defer f.Close()
	spacing := 2.5 * scale
	w := textWidth(f, "HOUSE", spacing)
	drawText(dst, f, "HOUSE", 264*scale-w, 147*scale, spacing, accent)
	return dst
}

func textWidth(f font.Face, s string, spacing float64) float64 {
	var w float64
	n := 0
	for _, r := range s {
		if adv, ok := f.GlyphAdvance(r); ok {
			w += float64(adv) / 64
			n++
		}
	}
	if n > 1 {
		w += spacing * float64(n-1)
	}
	return w
}

// drawText draws s with its baseline at (x, y), skipping runes the font lacks (emoji).
func drawText(dst draw.Image, f font.Face, s string, x, y, spacing float64, c color.Color) {
	d := &font.Drawer{Dst: dst, Src: image.NewUniform(c), Face: f}
	pos := x
	for _, r := range s {
		adv, ok := f.GlyphAdvance(r)
		if !ok {
			continue
		}
		d.Dot = fixed.Point26_6{X: fixed.Int26_6(pos * 64), Y: fixed.Int26_6(y * 64)}
		d.DrawString(string(r))
		pos += float64(adv)/64 + spacing
	}
}

// renderable drops characters the font can't draw and collapses spaces.
func renderable(f font.Face, s string) string {
	var b strings.Builder
	for _, r := range s {
		if _, ok := f.GlyphAdvance(r); ok && (unicode.IsPrint(r) || r == ' ') {
			b.WriteRune(r)
		}
	}
	return strings.Join(strings.Fields(b.String()), " ")
}

// fit shortens s with "…" until it is at most max pixels wide.
func fit(f font.Face, s string, max float64) string {
	if textWidth(f, s, 0) <= max {
		return s
	}
	r := []rune(s)
	for len(r) > 1 {
		r = r[:len(r)-1]
		if t := strings.TrimSpace(string(r)) + "…"; textWidth(f, t, 0) <= max {
			return t
		}
	}
	return "…"
}

// Corner names the place the mark was drawn.
type Corner string

const (
	BottomRight Corner = "bottom-right"
	BottomLeft  Corner = "bottom-left"
	TopRight    Corner = "top-right"
	TopLeft     Corner = "top-left"
)

// Result reports where and how the mark was placed (useful for tests).
type Result struct {
	Corner Corner
	Light  bool // white mark on a dark area
}

// Apply returns a copy of img with the ModaHouse logo and "@handle" in the
// calmest corner (bottom preferred), white on dark areas and ink on light ones.
func Apply(img image.Image, handle string) (*image.RGBA, Result) {
	b := img.Bounds()
	dst := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(dst, dst.Bounds(), img, b.Min, draw.Src)
	W, H := dst.Bounds().Dx(), dst.Bounds().Dy()
	if W < 120 || H < 120 {
		return dst, Result{}
	}

	logoW := int(math.Round(0.22 * float64(W)))
	logoW = max(110, min(logoW, 520))
	if logoW > W/2 {
		logoW = W / 2
	}
	logoH := logoW * 160 / 300
	handle = strings.TrimSpace(strings.TrimPrefix(handle, "@"))
	textSize := float64(logoW) * 0.12
	textH := 0
	if handle != "" {
		textH = int(math.Ceil(textSize * 1.25))
	}
	markW, markH := logoW, logoH+textH
	margin := int(math.Round(0.035 * float64(min(W, H))))
	margin = max(margin, 8)

	rects := map[Corner]image.Rectangle{
		BottomRight: image.Rect(W-margin-markW, H-margin-markH, W-margin, H-margin),
		BottomLeft:  image.Rect(margin, H-margin-markH, margin+markW, H-margin),
		TopRight:    image.Rect(W-margin-markW, margin, W-margin, margin+markH),
		TopLeft:     image.Rect(margin, margin, margin+markW, margin+markH),
	}
	gray := grayscale(dst)
	best, bestScore := BottomRight, math.Inf(1)
	for _, c := range []Corner{BottomRight, BottomLeft, TopRight, TopLeft} {
		score := busyness(gray, W, rects[c])
		if c == TopRight || c == TopLeft {
			score = score*1.25 + 2 // the bottom is the expected place
		}
		if score < bestScore {
			best, bestScore = c, score
		}
	}
	area := rects[best]
	light := meanLuma(gray, W, area) < 150

	ink, accent := Ink, Red
	if light {
		ink, accent = White, color.RGBA{0xFF, 0x5A, 0x6E, 0xff}
	}
	mark := image.NewRGBA(image.Rect(0, 0, markW, markH))
	logo := Logo(logoW, ink, accent)
	draw.Draw(mark, logo.Bounds(), logo, image.Point{}, draw.Over)
	if handle != "" {
		f := face(textSize)
		label := fit(f, "@"+renderable(f, handle), float64(markW))
		tw := textWidth(f, label, 0)
		x := float64(markW) - tw // right aligned under "HOUSE"
		if best == BottomLeft || best == TopLeft {
			x = float64(logoW) * 14 / 300 // left aligned with the "m"
		}
		drawText(mark, f, label, x, float64(logoH)+textSize, 0, ink)
		f.Close()
	}

	// A soft shadow (light marks) or glow (dark marks) keeps the mark readable on any texture.
	halo := color.RGBA{0, 0, 0, 0}
	if light {
		halo = color.RGBA{0, 0, 0, 120}
	} else {
		halo = color.RGBA{255, 255, 255, 140}
	}
	pad := max(4, logoW/30)
	shadow := blurredMask(mark, pad, halo)
	off := image.Point{}
	if light {
		off = image.Pt(1+logoW/180, 1+logoW/180)
	}
	draw.Draw(dst, shadow.Bounds().Add(area.Min).Sub(image.Pt(pad, pad)).Add(off), shadow, image.Point{}, draw.Over)
	opaque := image.NewUniform(color.Alpha{230})
	draw.DrawMask(dst, area, mark, image.Point{}, opaque, image.Point{}, draw.Over)
	return dst, Result{Corner: best, Light: light}
}

func grayscale(img *image.RGBA) []uint8 {
	W, H := img.Bounds().Dx(), img.Bounds().Dy()
	g := make([]uint8, W*H)
	for y := 0; y < H; y++ {
		row := img.Pix[y*img.Stride:]
		for x := 0; x < W; x++ {
			r, gg, b := row[4*x], row[4*x+1], row[4*x+2]
			g[y*W+x] = uint8((299*uint32(r) + 587*uint32(gg) + 114*uint32(b)) / 1000)
		}
	}
	return g
}

// busyness is the mean gradient magnitude plus the luminance spread inside r:
// detailed or contrasty areas (faces, embroidery) score high.
func busyness(g []uint8, W int, r image.Rectangle) float64 {
	step := max(1, min(r.Dx(), r.Dy())/60)
	var grad, sum, sum2, n float64
	for y := r.Min.Y; y < r.Max.Y-step; y += step {
		for x := r.Min.X; x < r.Max.X-step; x += step {
			v := float64(g[y*W+x])
			dx := math.Abs(v - float64(g[y*W+x+step]))
			dy := math.Abs(v - float64(g[(y+step)*W+x]))
			grad += dx + dy
			sum += v
			sum2 += v * v
			n++
		}
	}
	if n == 0 {
		return math.Inf(1)
	}
	mean := sum / n
	std := math.Sqrt(math.Max(0, sum2/n-mean*mean))
	return grad/n + 0.35*std
}

func meanLuma(g []uint8, W int, r image.Rectangle) float64 {
	var sum, n float64
	for y := r.Min.Y; y < r.Max.Y; y += 2 {
		for x := r.Min.X; x < r.Max.X; x += 2 {
			sum += float64(g[y*W+x])
			n++
		}
	}
	if n == 0 {
		return 255
	}
	return sum / n
}

// blurredMask returns src's alpha, grown by pad pixels, box-blurred and tinted with c.
func blurredMask(src *image.RGBA, pad int, c color.RGBA) *image.RGBA {
	w, h := src.Bounds().Dx()+2*pad, src.Bounds().Dy()+2*pad
	a := make([]float64, w*h)
	for y := 0; y < src.Bounds().Dy(); y++ {
		for x := 0; x < src.Bounds().Dx(); x++ {
			a[(y+pad)*w+x+pad] = float64(src.Pix[y*src.Stride+4*x+3]) / 255
		}
	}
	r := max(1, pad/2)
	for pass := 0; pass < 2; pass++ {
		a = boxBlur(a, w, h, r)
	}
	out := image.NewRGBA(image.Rect(0, 0, w, h))
	for i, v := range a {
		al := math.Min(1, v*1.6) * float64(c.A) / 255
		out.Pix[4*i] = uint8(float64(c.R) * al)
		out.Pix[4*i+1] = uint8(float64(c.G) * al)
		out.Pix[4*i+2] = uint8(float64(c.B) * al)
		out.Pix[4*i+3] = uint8(255 * al)
	}
	return out
}

func boxBlur(a []float64, w, h, r int) []float64 {
	tmp := make([]float64, len(a))
	out := make([]float64, len(a))
	for y := 0; y < h; y++ {
		var acc float64
		for x := -r; x < w+r; x++ {
			if x+r < w && x+r >= 0 {
				acc += a[y*w+x+r]
			}
			if x-r-1 >= 0 && x-r-1 < w {
				acc -= a[y*w+x-r-1]
			}
			if x >= 0 && x < w {
				tmp[y*w+x] = acc / float64(2*r+1)
			}
		}
	}
	for x := 0; x < w; x++ {
		var acc float64
		for y := -r; y < h+r; y++ {
			if y+r < h && y+r >= 0 {
				acc += tmp[(y+r)*w+x]
			}
			if y-r-1 >= 0 && y-r-1 < h {
				acc -= tmp[(y-r-1)*w+x]
			}
			if y >= 0 && y < h {
				out[y*w+x] = acc / float64(2*r+1)
			}
		}
	}
	return out
}

// Resize scales img to the given width, keeping its aspect ratio.
func Resize(img image.Image, width int) *image.RGBA {
	b := img.Bounds()
	if width <= 0 || b.Dx() == 0 {
		width = b.Dx()
	}
	height := max(1, int(math.Round(float64(b.Dy())*float64(width)/float64(b.Dx()))))
	dst := image.NewRGBA(image.Rect(0, 0, width, height))
	xdraw.CatmullRom.Scale(dst, dst.Bounds(), img, b, xdraw.Src, nil)
	return dst
}

// RasterizeSVG renders an SVG at the given width on a white background.
func RasterizeSVG(data []byte, width int) (*image.RGBA, error) {
	icon, err := oksvg.ReadIconStream(bytes.NewReader(data), oksvg.IgnoreErrorMode)
	if err != nil {
		return nil, err
	}
	w, h := icon.ViewBox.W, icon.ViewBox.H
	if w <= 0 || h <= 0 {
		return nil, errNoViewBox
	}
	height := int(math.Round(h * float64(width) / w))
	icon.SetTarget(0, 0, float64(width), float64(height))
	dst := image.NewRGBA(image.Rect(0, 0, width, height))
	draw.Draw(dst, dst.Bounds(), image.White, image.Point{}, draw.Src)
	scanner := rasterx.NewScannerGV(width, height, dst, dst.Bounds())
	icon.Draw(rasterx.NewDasher(width, height, scanner), 1)
	return dst, nil
}

type wmError string

func (e wmError) Error() string { return string(e) }

const errNoViewBox = wmError("svg without a viewBox")
