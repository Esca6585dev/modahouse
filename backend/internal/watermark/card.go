package watermark

import (
	"image"
	"image/color"
	"image/draw"
	"math"

	xdraw "golang.org/x/image/draw"
)

// Card sizes: a 9:16 story.
const (
	CardW = 1080
	CardH = 1920
)

// CardInput describes a share card: images[0] is the post's cover, the rest fill the collage.
type CardInput struct {
	Images []image.Image
	Title  string
	Handle string // author username, without "@"
}

// Card renders a Pinterest-style share collage: two columns of rounded images, the
// ModaHouse logo pill under the cover, and the title and author along the bottom.
func Card(in CardInput) *image.RGBA {
	dst := image.NewRGBA(image.Rect(0, 0, CardW, CardH))
	draw.Draw(dst, dst.Bounds(), image.NewUniform(color.RGBA{0xF6, 0xF2, 0xEE, 0xff}), image.Point{}, draw.Src)

	const (
		pad     = 56
		gap     = 24
		radius  = 44
		footerH = 250
		pillH   = 150
	)
	colW := (CardW - 2*pad - gap) / 2
	top, bottom := pad, CardH-footerH
	gridH := bottom - top

	imgs := in.Images
	pick := func(i int) image.Image {
		if len(imgs) == 0 {
			return nil
		}
		return imgs[i%len(imgs)]
	}
	leftX, rightX := pad, pad+colW+gap

	// Left: cover, logo pill, third image. Right: two images, staggered.
	hA := int(float64(gridH) * 0.47)
	rA := image.Rect(leftX, top, leftX+colW, top+hA)
	rPill := image.Rect(leftX, rA.Max.Y+gap, leftX+colW, rA.Max.Y+gap+pillH)
	rC := image.Rect(leftX, rPill.Max.Y+gap, leftX+colW, bottom)
	hB := int(float64(gridH)*0.56) - gap/2
	rB := image.Rect(rightX, top, rightX+colW, top+hB)
	rD := image.Rect(rightX, rB.Max.Y+gap, rightX+colW, bottom)

	for i, r := range []image.Rectangle{rA, rB, rC, rD} {
		drawCover(dst, r, pick(i), radius)
	}

	// Logo pill: brand red with the white wordmark.
	fillRounded(dst, rPill, Red, pillH/2)
	logoW := pillH * 155 / 100
	logo := Logo(logoW, White, White)
	lx := rPill.Min.X + (rPill.Dx()-logo.Bounds().Dx())/2
	ly := rPill.Min.Y + (rPill.Dy()-logo.Bounds().Dy())/2 + 4
	draw.Draw(dst, logo.Bounds().Add(image.Pt(lx, ly)), logo, image.Point{}, draw.Over)

	// Footer: title and author.
	maxW := float64(CardW - 2*pad)
	titleFace := face(56)
	title := fit(titleFace, renderable(titleFace, in.Title), maxW)
	drawText(dst, titleFace, title, pad, float64(bottom)+100, 0, Ink)
	titleFace.Close()
	small := face(36)
	line := "ModaHouse"
	if h := renderable(small, in.Handle); h != "" {
		line = "@" + h + "  ·  ModaHouse"
	}
	drawText(dst, small, fit(small, line, maxW), pad, float64(bottom)+170, 0, Muted)
	small.Close()
	return dst
}

// drawCover fills r with img scaled to cover it (centre crop), with rounded corners.
func drawCover(dst *image.RGBA, r image.Rectangle, img image.Image, radius int) {
	if img == nil {
		fillRounded(dst, r, color.RGBA{0xE5, 0xE5, 0xE5, 0xff}, radius)
		return
	}
	b := img.Bounds()
	scale := math.Max(float64(r.Dx())/float64(b.Dx()), float64(r.Dy())/float64(b.Dy()))
	sw, sh := float64(r.Dx())/scale, float64(r.Dy())/scale
	src := image.Rect(
		b.Min.X+int((float64(b.Dx())-sw)/2), b.Min.Y+int((float64(b.Dy())-sh)/2),
		b.Min.X+int((float64(b.Dx())+sw)/2), b.Min.Y+int((float64(b.Dy())+sh)/2),
	)
	tile := image.NewRGBA(image.Rect(0, 0, r.Dx(), r.Dy()))
	xdraw.CatmullRom.Scale(tile, tile.Bounds(), img, src, xdraw.Src, nil)
	draw.DrawMask(dst, r, tile, image.Point{}, roundedMask(r.Dx(), r.Dy(), radius), image.Point{}, draw.Over)
}

func fillRounded(dst *image.RGBA, r image.Rectangle, c color.Color, radius int) {
	draw.DrawMask(dst, r, image.NewUniform(c), image.Point{}, roundedMask(r.Dx(), r.Dy(), radius), image.Point{}, draw.Over)
}

// roundedMask is an anti-aliased rounded-rectangle alpha mask.
func roundedMask(w, h, radius int) *image.Alpha {
	m := image.NewAlpha(image.Rect(0, 0, w, h))
	rad := float64(min(radius, min(w, h)/2))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			fx, fy := float64(x)+0.5, float64(y)+0.5
			cx := math.Max(rad-fx, math.Max(0, fx-(float64(w)-rad)))
			cy := math.Max(rad-fy, math.Max(0, fy-(float64(h)-rad)))
			a := 1.0
			if cx > 0 && cy > 0 {
				d := math.Hypot(cx, cy) - rad
				a = math.Max(0, math.Min(1, 0.5-d))
			}
			m.Pix[y*m.Stride+x] = uint8(255 * a)
		}
	}
	return m
}
