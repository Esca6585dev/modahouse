// Package visual finds visually similar images without external services.
//
// Each image gets a compact descriptor: a centre-weighted colour histogram
// (what colours the item is), a difference hash (overall layout) and an edge
// orientation histogram (cut, folds and patterns). Similarity mixes the three.
package visual

import (
	"bytes"
	"encoding/binary"
	"errors"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"math"
	"math/bits"
	"strings"

	"github.com/srwiley/oksvg"
	"github.com/srwiley/rasterx"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp"
)

const (
	hueBins   = 12
	satBins   = 3
	valBins   = 3
	grayBins  = 4
	colorDims = hueBins*satBins*valBins + grayBins // 112
	edgeDims  = 8 * 4                              // 8 orientations x 2x2 regions
	// Version changes whenever the descriptor layout changes, so stored rows get rebuilt.
	Version = 1
)

type Descriptor struct {
	Color [colorDims]float32
	Edges [edgeDims]float32
	Hash  uint64
}

// Rect is a crop in relative coordinates (0..1). The zero value means "whole image".
type Rect struct{ X, Y, W, H float64 }

func (r Rect) empty() bool { return r.W <= 0 || r.H <= 0 }

// IsSVG reports whether data looks like an SVG document.
func IsSVG(data []byte) bool {
	head := strings.TrimSpace(string(data[:min(len(data), 256)]))
	return strings.HasPrefix(head, "<svg") || strings.HasPrefix(head, "<?xml")
}

// Decode reads JPEG/PNG/GIF/WEBP, or rasterizes SVG (used for the generated seed art).
func Decode(data []byte) (image.Image, error) {
	if IsSVG(data) {
		return rasterizeSVG(data, 256)
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	return img, err
}

func rasterizeSVG(data []byte, size int) (image.Image, error) {
	icon, err := oksvg.ReadIconStream(bytes.NewReader(data), oksvg.IgnoreErrorMode)
	if err != nil {
		return nil, err
	}
	w, h := icon.ViewBox.W, icon.ViewBox.H
	if w <= 0 || h <= 0 {
		return nil, errors.New("svg without a viewBox")
	}
	scale := float64(size) / math.Max(w, h)
	pw, ph := int(w*scale), int(h*scale)
	icon.SetTarget(0, 0, float64(pw), float64(ph))
	rgba := image.NewRGBA(image.Rect(0, 0, pw, ph))
	draw.Draw(rgba, rgba.Bounds(), image.White, image.Point{}, draw.Src)
	scanner := rasterx.NewScannerGV(pw, ph, rgba, rgba.Bounds())
	icon.Draw(rasterx.NewDasher(pw, ph, scanner), 1)
	return rgba, nil
}

// Compute builds the descriptor of img (optionally cropped).
func Compute(img image.Image, crop Rect) Descriptor {
	b := img.Bounds()
	if !crop.empty() {
		x0 := b.Min.X + int(clamp(crop.X)*float64(b.Dx()))
		y0 := b.Min.Y + int(clamp(crop.Y)*float64(b.Dy()))
		x1 := b.Min.X + int(clamp(crop.X+crop.W)*float64(b.Dx()))
		y1 := b.Min.Y + int(clamp(crop.Y+crop.H)*float64(b.Dy()))
		if x1-x0 >= 8 && y1-y0 >= 8 {
			b = image.Rect(x0, y0, x1, y1)
		}
	}
	const n = 64
	small := image.NewRGBA(image.Rect(0, 0, n, n))
	draw.ApproxBiLinear.Scale(small, small.Bounds(), img, b, draw.Src, nil)

	var d Descriptor
	gray := make([]float64, n*n)
	var total float64
	for y := 0; y < n; y++ {
		for x := 0; x < n; x++ {
			c := small.RGBAAt(x, y)
			r, g, bl := float64(c.R)/255, float64(c.G)/255, float64(c.B)/255
			gray[y*n+x] = 0.299*r + 0.587*g + 0.114*bl
			// Weight the centre: the photographed item is usually in the middle.
			dx, dy := (float64(x)+0.5)/n-0.5, (float64(y)+0.5)/n-0.5
			w := math.Exp(-(dx*dx + dy*dy) / 0.08)
			d.Color[colorBin(r, g, bl)] += float32(w)
			total += w
		}
	}
	for i := range d.Color {
		d.Color[i] /= float32(total)
	}

	// Difference hash on a 9x8 grayscale thumbnail.
	var hash uint64
	for y := 0; y < 8; y++ {
		for x := 0; x < 8; x++ {
			if sample(gray, n, x, y, 9, 8) > sample(gray, n, x+1, y, 9, 8) {
				hash |= 1 << uint(y*8+x)
			}
		}
	}
	d.Hash = hash

	// Edge orientations (Sobel) in 2x2 regions.
	var norm float64
	for y := 1; y < n-1; y++ {
		for x := 1; x < n-1; x++ {
			g := func(xx, yy int) float64 { return gray[yy*n+xx] }
			gx := g(x+1, y-1) + 2*g(x+1, y) + g(x+1, y+1) - g(x-1, y-1) - 2*g(x-1, y) - g(x-1, y+1)
			gy := g(x-1, y+1) + 2*g(x, y+1) + g(x+1, y+1) - g(x-1, y-1) - 2*g(x, y-1) - g(x+1, y-1)
			mag := math.Hypot(gx, gy)
			if mag < 0.1 {
				continue
			}
			ang := math.Atan2(gy, gx)
			if ang < 0 {
				ang += math.Pi
			}
			bin := int(ang/math.Pi*8) % 8
			region := (y*2/n)*2 + x*2/n
			d.Edges[region*8+bin] += float32(mag)
		}
	}
	for _, v := range d.Edges {
		norm += float64(v) * float64(v)
	}
	if norm > 0 {
		s := float32(1 / math.Sqrt(norm))
		for i := range d.Edges {
			d.Edges[i] *= s
		}
	}
	return d
}

func clamp(v float64) float64 { return math.Max(0, math.Min(1, v)) }

func sample(gray []float64, n, x, y, w, h int) float64 {
	// average the block of the n x n image that maps to cell (x, y) of a w x h grid
	x0, x1 := x*n/w, (x+1)*n/w
	y0, y1 := y*n/h, (y+1)*n/h
	var s float64
	for yy := y0; yy < y1; yy++ {
		for xx := x0; xx < x1; xx++ {
			s += gray[yy*n+xx]
		}
	}
	return s / float64(max((x1-x0)*(y1-y0), 1))
}

func colorBin(r, g, b float64) int {
	mx, mn := math.Max(r, math.Max(g, b)), math.Min(r, math.Min(g, b))
	v, delta := mx, mx-mn
	s := 0.0
	if mx > 0 {
		s = delta / mx
	}
	if s < 0.15 || v < 0.12 {
		return hueBins*satBins*valBins + min(int(v*grayBins), grayBins-1)
	}
	var h float64
	switch mx {
	case r:
		h = math.Mod((g-b)/delta, 6)
	case g:
		h = (b-r)/delta + 2
	default:
		h = (r-g)/delta + 4
	}
	h *= 60
	if h < 0 {
		h += 360
	}
	hb := int(h/360*hueBins) % hueBins
	sb := min(int((s-0.15)/0.85*satBins), satBins-1)
	vb := min(int(v*valBins), valBins-1)
	return (hb*satBins+sb)*valBins + vb
}

// Similarity is in 0..1; higher is more similar.
func Similarity(a, b *Descriptor) float64 {
	var inter float64
	for i := range a.Color {
		inter += float64(min(a.Color[i], b.Color[i]))
	}
	var cos float64
	for i := range a.Edges {
		cos += float64(a.Edges[i]) * float64(b.Edges[i])
	}
	hash := 1 - float64(bits.OnesCount64(a.Hash^b.Hash))/64
	return 0.55*inter + 0.25*math.Max(cos, 0) + 0.20*hash
}

// Marshal / Unmarshal store a descriptor compactly in the database.
func (d *Descriptor) Marshal() []byte {
	var buf bytes.Buffer
	_ = binary.Write(&buf, binary.LittleEndian, d)
	return buf.Bytes()
}

func Unmarshal(data []byte) (*Descriptor, error) {
	var d Descriptor
	if err := binary.Read(bytes.NewReader(data), binary.LittleEndian, &d); err != nil && err != io.EOF {
		return nil, err
	}
	return &d, nil
}
