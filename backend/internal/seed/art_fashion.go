package seed

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// renderFashionArt draws a deterministic illustration for a fashion category.
// variant selects the design (any int; use variant % N internally); w,h are viewBox units;
// the returned SVG has width/height attributes of 2*w x 2*h like renderDress.
//
// Kinds: "sac" (hair styles), "makiyaj" (make-up), "dyrnak" (nail design),
// "shay" (Turkmen jewellery), "keshde" (hand embroidery), "yaka" (necklines),
// "aksessuar" (accessories) and "gundelik" (casual outfits). Every kind has
// eight distinct compositions; variant/8 additionally shifts the palettes.
func renderFashionArt(kind string, variant int, w, h float64) string {
	if variant < 0 {
		variant = -variant
	}
	var hsh uint32 = 2166136261
	for i := 0; i < len(kind); i++ {
		hsh = (hsh ^ uint32(kind[i])) * 16777619
	}
	c := &faCanvas{w: w, h: h, seed: uint32(variant)*2654435761 ^ hsh, cache: map[string]string{}}
	style, pal := variant%8, variant/8
	switch kind {
	case "sac":
		faHair(c, style, pal)
	case "makiyaj":
		faMakeup(c, style, pal)
	case "dyrnak":
		faNails(c, style, pal, false)
	case "shay":
		faJewellery(c, style, pal)
	case "keshde":
		faEmbroidery(c, style, pal)
	case "yaka":
		faCollar(c, style, pal)
	case "aksessuar":
		faAccessories(c, style, pal)
	default: // "gundelik"
		faCasual(c, style, pal)
	}
	return c.String()
}

// ---------------------------------------------------------------- toolkit

type faPt struct{ X, Y float64 }

func faP(x, y float64) faPt            { return faPt{x, y} }
func (p faPt) add(q faPt) faPt         { return faPt{p.X + q.X, p.Y + q.Y} }
func (p faPt) sub(q faPt) faPt         { return faPt{p.X - q.X, p.Y - q.Y} }
func (p faPt) mul(k float64) faPt      { return faPt{p.X * k, p.Y * k} }
func (p faPt) len() float64            { return math.Hypot(p.X, p.Y) }
func faLerp(a, b faPt, t float64) faPt { return a.add(b.sub(a).mul(t)) }
func (p faPt) unit() faPt {
	l := p.len()
	if l == 0 {
		return faPt{0, 1}
	}
	return p.mul(1 / l)
}
func faBez2(a, b, c faPt, t float64) faPt  { return faLerp(faLerp(a, b, t), faLerp(b, c, t), t) }
func faBez2D(a, b, c faPt, t float64) faPt { return faLerp(b.sub(a), c.sub(b), t).mul(2) }
func faBez3(a, b, c, d faPt, t float64) faPt {
	return faLerp(faBez2(a, b, c, t), faBez2(b, c, d, t), t)
}
func faBez3D(a, b, c, d faPt, t float64) faPt {
	return faBez2(b.sub(a), c.sub(b), d.sub(c), t).mul(3)
}

func faNum(x float64) string {
	if math.Abs(x) < 0.05 {
		return "0"
	}
	return strings.TrimSuffix(strconv.FormatFloat(x, 'f', 1, 64), ".0")
}

func faNum2(x float64) string {
	if math.Abs(x) < 0.005 {
		return "0"
	}
	s := strings.TrimRight(strconv.FormatFloat(x, 'f', 2, 64), "0")
	return strings.TrimSuffix(s, ".")
}

// fp is Sprintf with compact numbers: float64 args print with one decimal and
// faPt args print as "x y".
func fp(format string, a ...any) string {
	for i, v := range a {
		switch x := v.(type) {
		case float64:
			a[i] = faNum(x)
		case faPt:
			a[i] = faNum(x.X) + " " + faNum(x.Y)
		}
	}
	return fmt.Sprintf(format, a...)
}

func faOp(x float64) string { return `opacity="` + faNum2(x) + `"` }

func faMix(a, b string, t float64) string {
	var r1, g1, b1, r2, g2, b2 int
	fmt.Sscanf(strings.TrimPrefix(a, "#"), "%02x%02x%02x", &r1, &g1, &b1)
	fmt.Sscanf(strings.TrimPrefix(b, "#"), "%02x%02x%02x", &r2, &g2, &b2)
	m := func(x, y int) int { return int(float64(x) + (float64(y)-float64(x))*t + .5) }
	return fmt.Sprintf("#%02x%02x%02x", m(r1, r2), m(g1, g2), m(b1, b2))
}

// faSmooth draws a Catmull-Rom spline through pts as cubic Béziers.
func faSmooth(pts []faPt, closed bool) string {
	var b strings.Builder
	b.WriteString(fp("M%v", pts[0]))
	b.WriteString(faCurve(pts, closed))
	if closed {
		b.WriteString("Z")
	}
	return b.String()
}

func faCurve(pts []faPt, closed bool) string {
	n := len(pts)
	get := func(i int) faPt {
		if closed {
			return pts[((i%n)+n)%n]
		}
		return pts[max(0, min(n-1, i))]
	}
	segs := n - 1
	if closed {
		segs = n
	}
	var b strings.Builder
	for i := 0; i < segs; i++ {
		p0, p1, p2, p3 := get(i-1), get(i), get(i+1), get(i+2)
		b.WriteString(fp("C%v %v %v", p1.add(p2.sub(p0).mul(1.0/6)), p2.sub(p3.sub(p1).mul(1.0/6)), p2))
	}
	return b.String()
}

// faOffset shifts a polyline along its normals (positive = to the right of travel).
func faOffset(pts []faPt, d float64) []faPt {
	out := make([]faPt, len(pts))
	for i := range pts {
		a, b := pts[max(0, i-1)], pts[min(len(pts)-1, i+1)]
		t := b.sub(a).unit()
		out[i] = pts[i].add(faPt{-t.Y, t.X}.mul(d))
	}
	return out
}

// faBand is a closed ribbon of width w0→w1 centred on pts.
func faBand(pts []faPt, w0, w1 float64) string {
	n := len(pts)
	l, r := make([]faPt, n), make([]faPt, n)
	for i := range pts {
		a, b := pts[max(0, i-1)], pts[min(n-1, i+1)]
		t := b.sub(a).unit()
		nrm := faPt{-t.Y, t.X}
		w := (w0 + (w1-w0)*float64(i)/float64(max(1, n-1))) / 2
		l[i], r[i] = pts[i].add(nrm.mul(w)), pts[i].sub(nrm.mul(w))
	}
	rev := make([]faPt, n)
	for i := range r {
		rev[i] = r[n-1-i]
	}
	return fp("M%v", l[0]) + faCurve(l, false) + fp("L%v", rev[0]) + faCurve(rev, false) + "Z"
}

func faSampleQ(a, b, c faPt, n int) []faPt {
	out := make([]faPt, n+1)
	for i := 0; i <= n; i++ {
		out[i] = faBez2(a, b, c, float64(i)/float64(n))
	}
	return out
}

func faPoly(cx, cy, r float64, n int, rot float64) string {
	var b strings.Builder
	for k := 0; k < n; k++ {
		a := rot + float64(k)*2*math.Pi/float64(n)
		if k == 0 {
			b.WriteString("M")
		} else {
			b.WriteString("L")
		}
		b.WriteString(fp("%v %v", cx+math.Cos(a)*r, cy+math.Sin(a)*r))
	}
	return b.String() + "Z"
}

type faCanvas struct {
	b     strings.Builder
	w, h  float64
	seed  uint32
	n     int
	cache map[string]string
}

func (c *faCanvas) String() string {
	return fp(`<svg xmlns="http://www.w3.org/2000/svg" width="%v" height="%v" viewBox="0 0 %v %v">`, int(c.w*2), int(c.h*2), c.w, c.h) + c.b.String() + `</svg>`
}

func (c *faCanvas) p(format string, a ...any) { c.b.WriteString(fp(format, a...)) }

func (c *faCanvas) rnd() float64 {
	c.seed = c.seed*1664525 + 1013904223
	return float64(c.seed>>8) / float64(1<<24)
}

func (c *faCanvas) rr(a, b float64) float64 { return a + (b-a)*c.rnd() }

// grad writes a gradient once and returns its url(); stops are "#rrggbb",
// optionally followed by "/opacity" and "@offset".
func (c *faCanvas) grad(tag, attrs string, stops []string) string {
	key := tag + attrs + strings.Join(stops, ",")
	if u, ok := c.cache[key]; ok {
		return u
	}
	c.n++
	id := "g" + strconv.Itoa(c.n)
	c.b.WriteString("<defs><" + tag + ` id="` + id + `"` + attrs + ">")
	for i, st := range stops {
		off := 0.0
		if len(stops) > 1 {
			off = float64(i) / float64(len(stops)-1)
		}
		if k := strings.IndexByte(st, '@'); k >= 0 {
			off, _ = strconv.ParseFloat(st[k+1:], 64)
			st = st[:k]
		}
		o := ""
		if k := strings.IndexByte(st, '/'); k >= 0 {
			o = ` stop-opacity="` + st[k+1:] + `"`
			st = st[:k]
		}
		c.b.WriteString(`<stop offset="` + faNum2(off) + `" stop-color="` + st + `"` + o + `/>`)
	}
	c.b.WriteString("</" + tag + "></defs>")
	u := "url(#" + id + ")"
	c.cache[key] = u
	return u
}

func (c *faCanvas) lin(x1, y1, x2, y2 float64, stops ...string) string {
	return c.grad("linearGradient", ` x1="`+faNum2(x1)+`" y1="`+faNum2(y1)+`" x2="`+faNum2(x2)+`" y2="`+faNum2(y2)+`"`, stops)
}

func (c *faCanvas) linU(x1, y1, x2, y2 float64, stops ...string) string {
	return c.grad("linearGradient", fp(` gradientUnits="userSpaceOnUse" x1="%v" y1="%v" x2="%v" y2="%v"`, x1, y1, x2, y2), stops)
}

func (c *faCanvas) rad(cx, cy, r float64, stops ...string) string {
	return c.grad("radialGradient", ` cx="`+faNum2(cx)+`" cy="`+faNum2(cy)+`" r="`+faNum2(r)+`"`, stops)
}

func (c *faCanvas) clip(d string) string {
	c.n++
	id := "c" + strconv.Itoa(c.n)
	c.b.WriteString(`<defs><clipPath id="` + id + `"><path d="` + d + `"/></clipPath></defs>`)
	return `clip-path="url(#` + id + `)"`
}

func (c *faCanvas) attrs(extra []string) {
	for _, e := range extra {
		if e != "" {
			c.b.WriteString(" " + e)
		}
	}
	c.b.WriteString("/>")
}

func (c *faCanvas) path(d, fill string, extra ...string) {
	c.b.WriteString(`<path d="` + d + `" fill="` + fill + `"`)
	c.attrs(extra)
}

func (c *faCanvas) stroke(d, col string, w float64, extra ...string) {
	c.b.WriteString(`<path d="` + d + `" fill="none" stroke="` + col + `" stroke-width="` + faNum2(w) + `" stroke-linecap="round" stroke-linejoin="round"`)
	c.attrs(extra)
}

func (c *faCanvas) ell(cx, cy, rx, ry float64, fill string, extra ...string) {
	c.p(`<ellipse cx="%v" cy="%v" rx="%v" ry="%v" fill="%v"`, cx, cy, rx, ry, fill)
	c.attrs(extra)
}

func (c *faCanvas) circ(cx, cy, r float64, fill string, extra ...string) {
	c.p(`<circle cx="%v" cy="%v" r="%v" fill="%v"`, cx, cy, r, fill)
	c.attrs(extra)
}

func (c *faCanvas) rect(x, y, w, h, r float64, fill string, extra ...string) {
	c.p(`<rect x="%v" y="%v" width="%v" height="%v" rx="%v" fill="%v"`, x, y, w, h, r, fill)
	c.attrs(extra)
}

// g opens a group translated to (x,y), rotated by rot degrees and scaled by sc.
func (c *faCanvas) g(x, y, rot, sc float64) {
	c.p(`<g transform="translate(%v %v) rotate(%v) scale(%v)">`, x, y, rot, faNum2(sc))
}

func (c *faCanvas) end() { c.b.WriteString("</g>") }

// fit opens a group mapping a rw x rh design box into the canvas (contain),
// aligned by ax, ay in 0..1.
func (c *faCanvas) fit(rw, rh, ax, ay float64) {
	k := math.Min(c.w/rw, c.h/rh)
	c.p(`<g transform="translate(%v %v) scale(%v)">`, (c.w-rw*k)*ax, (c.h-rh*k)*ay, faNum2(k))
}

func (c *faCanvas) glow(cx, cy, rx, ry float64, col string, o float64) {
	c.ell(cx, cy, rx, ry, c.rad(.5, .5, .5, col+"/"+faNum2(o), col+"/"+faNum2(o*.45)+"@0.45", col+"/0"))
}

// drop paints a soft-ish flat-lay shadow of d.
func (c *faCanvas) drop(d string, dx, dy float64) {
	c.path(d, "#3d2a20", fp(`transform="translate(%v %v)"`, dx*.5, dy*.5), faOp(.07))
	c.path(d, "#3d2a20", fp(`transform="translate(%v %v)"`, dx, dy), faOp(.06))
}

func (c *faCanvas) glint(x, y, r, o float64) {
	c.glow(x, y, r*1.3, r*1.3, "#ffffff", o*.55)
	q := r * .16
	c.path(fp("M%v %vQ%v %v %v %vQ%v %v %v %vQ%v %v %v %vQ%v %v %v %vZ",
		x, y-r, x+q, y-q, x+r*.7, y, x+q, y+q, x, y+r, x-q, y+q, x-r*.7, y, x-q, y-q, x, y-r), "#ffffff", faOp(o))
}

func (c *faCanvas) metal(kind string) []string {
	switch kind {
	case "gold":
		return []string{"#8a5f1d", "#e6c068", "#fff2c6", "#c9972f", "#f0d27f", "#8a5f1d"}
	case "silver":
		return []string{"#62666c", "#d9dbdf", "#ffffff", "#a5a9af", "#eceef0", "#6d7177"}
	case "rose":
		return []string{"#9b5f4f", "#e3a996", "#fde4da", "#c88371", "#f1c6b6", "#9b5f4f"}
	case "black":
		return []string{"#141414", "#3a3a3c", "#707074", "#232325", "#4a4a4d", "#141414"}
	case "gilt": // gilded silver, typical of Turkmen pieces
		return []string{"#7d6230", "#d8c08a", "#fff6da", "#b39456", "#efdcaa", "#7d6230"}
	}
	return []string{"#cfc8c1", "#f3efea", "#ffffff", "#e3ddd6", "#f7f4f0", "#c9c1b9"}
}

func (c *faCanvas) metalD(kind string) string { return c.lin(0, 0, 1, 1, c.metal(kind)...) }
func (c *faCanvas) metalH(kind string) string { return c.lin(0, 0, 1, 0, c.metal(kind)...) }

func (c *faCanvas) stone(x, y, rx, ry float64, metal string) {
	if metal != "" {
		c.ell(x, y, rx+1.7, ry+1.7, c.metalD(metal))
	}
	c.ell(x, y, rx, ry, c.rad(.4, .35, .7, "#ffb49a", "#d8402a@0.35", "#a3230f@0.75", "#5c0d06"))
	c.ell(x-rx*.32, y-ry*.4, rx*.3, ry*.2, "#ffffff", faOp(.75))
}

// ---------------------------------------------------------------- backgrounds

func (c *faCanvas) backdrop(top, bottom string) {
	c.rect(0, 0, c.w, c.h, 0, c.lin(0, 0, 0, 1, top, bottom))
	c.glow(c.w*c.rr(.15, .45), c.h*c.rr(.1, .3), c.w*.8, c.h*.5, "#ffffff", .55)
	c.glow(c.w*c.rr(.55, .9), c.h*c.rr(.65, .9), c.w*.6, c.h*.4, "#ffffff", .25)
}

func (c *faCanvas) softBand(x, w, op float64, col string) {
	a, b, d := c.w*c.rr(-.25, .25), c.w*c.rr(-.2, .3), c.w*c.rr(-.1, .35)
	c.path(fp("M%v -10C%v %v %v %v %v %vL%v %vC%v %v %v %v %v -10Z",
		x, x+a, c.h*.35, x+b, c.h*.7, x+d, c.h+10, x+d+w, c.h+10, x+b+w, c.h*.7, x+a+w, c.h*.35, x+w),
		c.lin(0, 0, 1, 0, col+"/0", col+"/"+faNum2(op), col+"/0"))
}

func (c *faCanvas) marble(base string) {
	c.backdrop(shade(base, .45), base)
	vein := shade(base, -.25)
	for i := 0; i < 7; i++ {
		y0 := c.h * c.rr(-.2, 1)
		y3 := y0 + c.h*c.rr(-.3, .6)
		d := fp("M-10 %vC%v %v %v %v %v %v", y0, c.w*c.rr(.2, .5), y0+c.h*c.rr(-.25, .25), c.w*c.rr(.5, .8), y3+c.h*c.rr(-.25, .25), c.w+10, y3)
		c.stroke(d, vein, c.rr(.4, 1.6), faOp(c.rr(.12, .32)))
	}
}

func (c *faCanvas) velvet(col string) {
	c.rect(0, 0, c.w, c.h, 0, c.rad(.45, .4, .8, shade(col, .25), col+"@0.45", shade(col, -.6)))
	for i := 0; i < 3; i++ {
		c.glow(c.w*c.rr(0, 1), c.h*c.rr(0, 1), c.w*.55, c.h*.2, shade(col, .45), .16)
	}
}

func (c *faCanvas) silk(col string) {
	c.backdrop(shade(col, .4), shade(col, -.03))
	for i := 0; i < 4; i++ {
		c.softBand(c.w*c.rr(-.3, 1), c.w*c.rr(.12, .3), .45, "#ffffff")
		c.softBand(c.w*c.rr(-.3, 1), c.w*c.rr(.08, .2), .12, shade(col, -.4))
	}
}

// salon draws the wall/arch backdrop used by the dress illustrations.
func (c *faCanvas) salon(wall string, archX float64) {
	c.rect(0, 0, c.w, c.h, 0, c.lin(0, 0, 0, 1, shade(wall, .25), wall))
	ax, r := c.w*archX, c.w*.3
	c.path(fp("M%v %vV%vA%v %v 0 0 1 %v %vV%vZ", ax-r, c.h*1.1, c.h*.3, r, r, ax+r, c.h*.3, c.h*1.1), shade(wall, .45), faOp(.5))
	c.stroke(fp("M%v %vV%vA%v %v 0 0 1 %v %vV%v", ax-r, c.h*1.1, c.h*.3, r, r, ax+r, c.h*.3, c.h*1.1), shade(wall, -.2), 3, faOp(.45))
	c.glow(c.w*.3, c.h*.25, c.w*.6, c.h*.4, "#ffffff", .3)
}

func (c *faCanvas) confetti(n int, cols []string, rmin, rmax float64) {
	for i := 0; i < n; i++ {
		c.circ(c.w*c.rnd(), c.h*c.rnd(), c.rr(rmin, rmax), cols[i%len(cols)], faOp(c.rr(.5, .95)))
	}
}

func (c *faCanvas) petal(x, y, s, rot float64, col string) {
	c.g(x, y, rot, s)
	c.path("M0 -10C7 -8 8 4 0 10C-8 4 -7 -8 0 -10Z", c.lin(0, 0, 1, 1, shade(col, .35), col, shade(col, -.15)))
	c.end()
}

// ---------------------------------------------------------------- sac (hair)

var faHairCols = [][3]string{ // base, light, dark
	{"#2a1b16", "#6a4b3c", "#110a08"},
	{"#3d2519", "#8a5c40", "#1a0e09"},
	{"#5a3420", "#a8744a", "#28140b"},
	{"#1e1715", "#56463f", "#0a0706"},
	{"#6e3a22", "#bb7a45", "#34180b"},
	{"#47291d", "#946650", "#1f110b"},
}

var faSkins = []string{"#eac4a8", "#dcab8b", "#f2d2bb", "#cd9676", "#e5b899"}

const faHead = "M150 72C192 72 212 104 212 142C212 172 202 190 186 200Q150 214 114 200C98 190 88 172 88 142C88 104 108 72 150 72Z"

func faHair(c *faCanvas, style, pal int) {
	bgs := [][2]string{{"#f7ebe2", "#e3cbbb"}, {"#eef1ea", "#d1dacb"}, {"#f5e7ee", "#ddc2cf"}, {"#ece8f4", "#cfc5e0"}, {"#f8efe0", "#e4d0b2"}, {"#e9f0f3", "#c9d7df"}, {"#f3ebe3", "#d9c7b6"}, {"#f6e6e1", "#dfc0b5"}}
	dresses := []string{"#1f5e4a", "#8a2440", "#2d3f6b", "#c46a72", "#efe4d6", "#5b3a6e", "#b88a4a", "#21483c"}
	trims := []string{"#a3162b", "#e0b44c", "#e8c77a", "#7a1f2b", "#b3202a", "#e0b44c", "#6b1626", "#c8102e"}
	k := (style + pal*3) % 8
	bg := bgs[(style+pal*5)%8]
	hair := faHairCols[(style*5+pal)%len(faHairCols)]
	skin := faSkins[(style*2+pal)%len(faSkins)]
	dress, trim := dresses[k], trims[k]

	c.backdrop(bg[0], bg[1])
	ax := c.w * c.rr(.2, .8)
	r := c.w * .26
	c.stroke(fp("M%v %vV%vA%v %v 0 0 1 %v %vV%v", ax-r, c.h*1.1, c.h*.32, r, r, ax+r, c.h*.32, c.h*1.1), shade(bg[1], -.15), 2.5, faOp(.4))
	c.glow(c.w*.5, c.h*.4, c.w*.45, c.h*.35, "#ffffff", .35)
	c.fit(300, 400, .5, 1)

	turn := []float64{0, 1, -1, 0, 1, -1, 0, 0}[style]
	hl := c.lin(0, 0, 1, 1, hair[1], hair[0]+"@0.45", hair[2])
	skinG := c.lin(0, 0, 0, 1, shade(skin, .12), skin, shade(skin, -.12))

	// neck and upper back
	c.path("M127 176C129 214 124 240 100 262L100 300H200V262C176 240 171 214 173 176Z", skinG)
	c.glow(150, 232, 22, 40, shade(skin, .5), .35)
	if turn != 0 { // three-quarter: a sliver of cheek and jaw
		c.g(150, 0, 0, 1)
		c.p(`<g transform="scale(%v 1)">`, turn)
		c.path("M50 132C64 160 62 192 44 212L30 200Z", skinG)
		c.end()
		c.end()
	}
	// dress back
	db := "M-10 400V330C0 292 40 276 92 268Q110 265 117 262Q150 296 183 262Q190 265 208 268C260 276 300 292 310 330V400Z"
	c.path(db, c.lin(0, 0, 1, 1, shade(dress, .18), dress, shade(dress, -.32)))
	c.glow(70, 300, 70, 30, "#ffffff", .2)
	c.glow(230, 300, 70, 30, "#ffffff", .14)
	c.stroke("M150 280V400", shade(dress, -.35), 1.2, faOp(.35))
	if style%2 == 0 {
		c.stroke("M117 262Q150 296 183 262", trim, 7)
		c.stroke("M117 262Q150 296 183 262", "#f3d98b", 1.4, `stroke-dasharray="2.5 2"`)
		c.stroke("M150 279.5V400", trim, 5)
		c.stroke("M150 280V400", "#f3d98b", 1.2, `stroke-dasharray="2.5 2"`)
	}
	c.glow(150, 204, 46, 18, "#4a2c20", .35)
	// ears
	for _, sd := range []float64{-1, 1} {
		ex := 150 + sd*60
		if turn == sd {
			ex = 150 + sd*55
		}
		c.ell(ex, 152, 7, 13, skinG)
	}

	strands := func(d string, clip string) {
		c.stroke(d, hair[1], 1.1, faOp(.45), clip)
		c.stroke(d, hair[2], .9, faOp(.35), clip, `transform="translate(2.5 1)"`)
	}
	headRays := func(target faPt, a0, a1 float64, n int) string {
		var b strings.Builder
		for i := 0; i < n; i++ {
			a := (a0 + (a1-a0)*float64(i)/float64(n-1)) * math.Pi / 180
			s := faP(150+66*math.Cos(a), 142+74*math.Sin(a))
			m := faLerp(s, target, .5).add(s.sub(faP(150, 142)).mul(.22))
			b.WriteString(fp("M%vQ%v %v", s, m, target))
		}
		return b.String()
	}
	headBase := func() string {
		c.path(faHead, hl)
		cl := c.clip(faHead)
		c.glow(132, 106, 44, 26, hair[1], .55)
		return cl
	}
	earring := func() {
		for _, sd := range []float64{-1, 1} {
			ex := 150 + sd*60
			if turn == sd {
				ex = 150 + sd*55
			}
			c.stroke(fp("M%v 163V172", ex), "#c9972f", 1)
			c.ell(ex, 178, 3.2, 6, c.metalD("gold"))
			c.circ(ex, 186, 2, "#c8102e")
		}
	}

	switch style {
	case 0: // double braids with tahya
		cl := headBase()
		strands(headRays(faP(124, 200), 200, 268, 7)+headRays(faP(176, 200), 272, 340, 7), cl)
		c.stroke("M150 76V200", shade(skin, -.1), 1.4, faOp(.6))
		for _, sd := range []float64{-1, 1} {
			end, ang := c.braid(faP(150+sd*26, 190), faP(150+sd*46, 268), faP(150+sd*38, 340), 30, 20, 12, hl, hair)
			c.tassel(end, ang, "#b3202a", "silver")
		}
		c.tahya("#7a1f2b", "#e9c46a")
	case 1: // single thick braid with ribbon
		cl := headBase()
		strands(headRays(faP(150, 202), 160, 380, 15), cl)
		end, ang := c.braid(faP(150, 194), faP(144, 290), faP(156, 368), 38, 22, 14, hl, hair)
		c.bow(end.X, end.Y+2, ang, 1, "#e9a6b4")
	case 2: // low bun with pins
		cl := headBase()
		strands(headRays(faP(150, 196), 150, 390, 17), cl)
		c.ell(150, 194, 36, 26, hl)
		c.stroke("M122 194C126 176 168 172 176 190M126 202C138 214 166 212 176 198M134 188C142 180 160 182 166 192", hair[1], 1.2, faOp(.5))
		c.glow(140, 186, 18, 9, hair[1], .45)
		for i, a := range []float64{-150, -120, -55, -25} {
			rd := a * math.Pi / 180
			x0, y0 := 150+28*math.Cos(rd), 194+20*math.Sin(rd)
			x1, y1 := 150+46*math.Cos(rd), 194+34*math.Sin(rd)
			c.stroke(fp("M%v %vL%v %v", x0, y0, x1, y1), "#c9972f", 1.6)
			if i%2 == 0 {
				c.circ(x1, y1, 3.4, c.rad(.35, .3, .7, "#ffffff", "#efe6dc", "#b9ad9f"))
			} else {
				c.circ(x1, y1, 3, c.metalD("gold"))
			}
		}
		earring()
	case 3: // high bun
		cl := headBase()
		strands(headRays(faP(150, 74), -10, 190, 17), cl)
		c.ell(150, 62, 38, 30, hl)
		c.stroke("M118 64C120 44 176 40 184 60M122 72C136 84 168 84 182 70M132 56C140 46 162 46 168 58", hair[1], 1.2, faOp(.5))
		c.glow(140, 52, 18, 10, hair[1], .5)
		c.path("M114 84Q150 100 186 84L184 92Q150 108 116 92Z", c.lin(0, 0, 0, 1, shade(trim, .25), trim, shade(trim, -.3)))
		c.stroke("M122 88Q150 101 178 88", shade(trim, .45), 1, faOp(.6), `stroke-dasharray="3 3"`)
		earring()
	case 4, 5: // long waves / half-up
		wave := 9.0
		if style == 5 {
			wave = 4
		}
		mass := c.hairMass(wave, 372)
		c.path(mass, hl)
		cl := c.clip(mass)
		c.glow(132, 108, 44, 26, hair[1], .55)
		c.glow(110, 250, 30, 90, hair[1], .22)
		strands(c.hairStrands(wave, 372, 14), cl)
		if style == 5 {
			strands(headRays(faP(150, 132), 160, 380, 13), c.clip("M84 92H216V140H84Z"))
			c.ell(150, 132, 14, 11, hl)
			c.bow(150, 128, 0, 1.1, "#f2efe9")
		}
	case 6: // braided crown with flowers
		cl := headBase()
		strands(headRays(faP(150, 206), 150, 390, 17), cl)
		c.braid(faP(96, 112), faP(150, 232), faP(204, 112), 18, 18, 13, hl, hair)
		for i, x := range []float64{112, 150, 188} {
			y := 162.0 + float64(i%2)*12
			if i == 1 {
				y = 176
			}
			c.flower(x, y, 7, "#ffffff", "#f2c14e")
		}
		c.flower(130, 172, 4.5, "#f4c6d0", "#f2c14e")
		c.flower(170, 172, 4.5, "#f4c6d0", "#f2c14e")
	case 7: // headscarf (ýaglyk) tied at the back, braids underneath
		for _, sd := range []float64{-1, 1} {
			c.braid(faP(150+sd*22, 200), faP(150+sd*34, 280), faP(150+sd*30, 352), 24, 16, 11, hl, hair)
		}
		c.yaglyk(trim, "#f3d98b", dress)
	}
	c.end()
}

// braid draws plaited lobes along a quadratic curve; returns the end point and angle.
func (c *faCanvas) braid(p0, p1, p2 faPt, w0, w1 float64, n int, fill string, hair [3]string) (faPt, float64) {
	length := 0.0
	prev := p0
	for i := 1; i <= 20; i++ {
		q := faBez2(p0, p1, p2, float64(i)/20)
		length += q.sub(prev).len()
		prev = q
	}
	seg := length / float64(n)
	c.path(faBand(faSampleQ(p0, p1, p2, 8), w0*.75, w1*.7), hair[2])
	c.p(`<g stroke="%v" stroke-width=".9" stroke-opacity=".7">`, hair[2])
	for i := 0; i < n; i++ {
		t := (float64(i) + .5) / float64(n)
		p := faBez2(p0, p1, p2, t)
		d := faBez2D(p0, p1, p2, t)
		a := math.Atan2(d.Y, d.X)*180/math.Pi - 90
		w := w0 + (w1-w0)*t
		s := 1.0
		if i%2 == 1 {
			s = -1
		}
		L, W := math.Max(seg*1.2, w*.52), w*.8
		c.p(`<g transform="translate(%v %v) rotate(%v) translate(%v 0) rotate(%v)">`, p.X, p.Y, a, s*w*.17, s*-34)
		c.path(fp("M0 %vQ%v 0 0 %vQ%v 0 0 %vZ", -L, W, L, -W, -L), fill)
		c.stroke(fp("M%v %vQ%v 0 %v %v", -W*.08, -L*.6, W*.22, -W*.06, L*.55), hair[1], 1, faOp(.55), `stroke-opacity=".55"`)
		c.end()
	}
	c.end()
	d := faBez2D(p0, p1, p2, 1)
	return p2, math.Atan2(d.Y, d.X)*180/math.Pi - 90
}

func (c *faCanvas) tassel(p faPt, ang float64, thread, metal string) {
	c.g(p.X, p.Y, ang, 1)
	c.path("M-4 10L-11 50Q0 55 11 50L4 10Z", c.lin(0, 0, 1, 0, shade(thread, -.35), thread, shade(thread, .25), shade(thread, -.35)))
	c.stroke("M-2 14L-6 50M0 14V52M2 14L6 50", shade(thread, -.45), .7, faOp(.5))
	c.rect(-6, -4, 12, 12, 4, c.metalH(metal))
	c.circ(0, 10, 3.4, c.rad(.35, .3, .7, "#ff9a7a", "#c8301c", "#6d1208"))
	c.end()
}

func (c *faCanvas) bow(x, y, ang, s float64, col string) {
	c.g(x, y, ang, s)
	g := c.lin(0, 0, 1, 1, shade(col, .3), col, shade(col, -.25))
	c.path("M-2 2L-10 26L-4 25L0 30L2 4Z", g)
	c.path("M2 2L12 24L6 24L4 29L-1 4Z", g)
	c.path("M0 0C-8 -12 -24 -10 -20 2C-18 10 -8 6 0 0Z", g)
	c.path("M0 0C8 -12 24 -10 20 2C18 10 8 6 0 0Z", g)
	c.ell(0, 0, 4, 3.5, shade(col, -.1))
	c.end()
}

func (c *faCanvas) flower(x, y, r float64, petal, center string) {
	g := c.rad(.5, .5, .5, shade(petal, -.08), petal)
	for k := 0; k < 5; k++ {
		a := float64(k)*2*math.Pi/5 - math.Pi/2
		c.circ(x+math.Cos(a)*r*.62, y+math.Sin(a)*r*.62, r*.5, g)
	}
	c.circ(x, y, r*.3, center)
}

// flowers draws many small five-petal flowers as two paths.
func (c *faCanvas) flowers(pts []faPt, r float64, petal, center string) {
	var b, m strings.Builder
	pr := r * .5
	for _, p := range pts {
		for k := 0; k < 5; k++ {
			a := float64(k)*2*math.Pi/5 - math.Pi/2
			x, y := p.X+math.Cos(a)*r*.62, p.Y+math.Sin(a)*r*.62
			b.WriteString(fp("M%v %va%v %v 0 1 0 %v 0a%v %v 0 1 0 %v 0", x-pr, y, pr, pr, 2*pr, pr, pr, -2*pr))
		}
		m.WriteString(fp("M%v %vh.1", p.X, p.Y))
	}
	c.path(b.String(), petal)
	c.stroke(m.String(), center, r*.6)
}

func (c *faCanvas) tahya(col, gold string) {
	d := "M98 108C98 64 202 64 202 108Q150 120 98 108Z"
	c.path(d, c.lin(0, 0, 1, 1, shade(col, .25), col, shade(col, -.4)))
	cl := c.clip(d)
	for _, x := range []float64{110, 130, 150, 170, 190} {
		c.stroke(fp("M%v 116Q%v 88 150 72", x, (x+150)/2), gold, .9, faOp(.6), cl, `stroke-dasharray="2 1.6"`)
	}
	for i, x := range []float64{120, 150, 180} {
		y := 96.0
		if i == 1 {
			y = 92
		}
		c.path(faPoly(x, y, 7, 8, math.Pi/8), "none", `stroke="`+gold+`" stroke-width="1.4"`)
		c.path(faPoly(x, y, 3.2, 4, 0), "#f4efe6")
	}
	c.stroke("M98 108Q150 120 202 108", gold, 4)
	c.stroke("M98 108Q150 120 202 108", "#b3202a", 1.2, `stroke-dasharray="2 2"`)
	c.glow(132, 84, 26, 10, "#ffffff", .25)
	c.circ(150, 72, 3.5, gold)
}

func (c *faCanvas) yaglyk(col, acc, dress string) {
	head := "M150 62C198 62 222 100 221 144C220 172 210 192 192 204Q150 216 108 204C90 192 80 172 79 144C78 100 102 62 150 62Z"
	tri := "M104 198Q150 214 196 198L158 306Q150 314 142 306Z"
	g := c.lin(0, 0, 1, 1, shade(col, .22), col, shade(col, -.35))
	c.path(tri, g)
	c.path(head, g)
	for _, d := range []string{head, tri} {
		c.p(`<g %v>`, c.clip(d))
		var pts []faPt
		for i := 0; i < 17; i++ {
			pts = append(pts, faP(c.rr(76, 224), c.rr(60, 312)))
		}
		c.flowers(pts, 3.6, acc, shade(col, -.25))
		c.end()
	}
	c.stroke("M104 198L142 306M196 198L158 306", acc, 3)
	c.stroke("M108 196L144 300M192 196L156 300", shade(col, -.4), .8, `stroke-dasharray="2 2"`)
	c.stroke("M144 308L142 318M148 311L147 321M152 311L153 321M156 308L158 318", acc, 1)
	c.stroke("M150 206C126 170 112 120 120 74M150 206C174 170 188 120 180 74M150 206C150 160 150 110 150 64", shade(col, -.45), 1.4, faOp(.25), c.clip(head))
	c.glow(126, 104, 40, 30, "#ffffff", .25)
	for _, sd := range []float64{-1, 1} {
		c.path(fp("M%v 206C%v 222 %v 244 %v 268L%v 270C%v 248 %v 226 %v 210Z", 150+sd*4, 150+sd*16, 150+sd*26, 150+sd*30, 150+sd*18, 150+sd*14, 150+sd*8, 150-sd*2), g)
	}
	c.ell(150, 207, 10, 8, c.lin(0, 0, 1, 1, shade(col, .1), shade(col, -.3)))
	_ = dress
}

func (c *faCanvas) hairMass(wave, bottom float64) string {
	var pts []faPt
	for a := 180.0; a <= 360; a += 22.5 {
		r := a * math.Pi / 180
		pts = append(pts, faP(150+63*math.Cos(r), 142+71*math.Sin(r)))
	}
	right := func(y float64) float64 {
		return 213 + (y-142)*.13 + wave*math.Sin((y-142)/34+1)
	}
	left := func(y float64) float64 {
		return 87 - (y-142)*.13 + wave*math.Sin((y-142)/34+2.5)
	}
	for y := 172.0; y < bottom-10; y += 30 {
		pts = append(pts, faP(right(y), y))
	}
	lb, rb := left(bottom), right(bottom)
	for i := 0; i <= 6; i++ {
		x := rb + (lb-rb)*float64(i)/6
		dy := 0.0
		if i%2 == 1 {
			dy = -12
		}
		pts = append(pts, faP(x, bottom+dy+math.Sin(float64(i))*4))
	}
	for y := bottom - 30; y > 160; y -= 30 {
		pts = append(pts, faP(left(y), y))
	}
	return faSmooth(pts, true)
}

func (c *faCanvas) hairStrands(wave, bottom float64, n int) string {
	var b strings.Builder
	for j := 1; j < n; j++ {
		u := float64(j) / float64(n)
		var pts []faPt
		for y := 78.0; y <= bottom; y += 24 {
			l := 87 - (math.Max(y, 142)-142)*.13 + wave*math.Sin((y-142)/34+2.5)
			r := 213 + (math.Max(y, 142)-142)*.13 + wave*math.Sin((y-142)/34+1)
			x := l + (r-l)*u
			if y < 142 {
				k := (y - 74) / 68
				x = 150 + (x-150)*math.Sqrt(math.Max(0, k))
			}
			pts = append(pts, faP(x+wave*.4*math.Sin(y/20+float64(j)), y))
		}
		b.WriteString(faSmooth(pts, false))
	}
	return b.String()
}

// ---------------------------------------------------------------- makiyaj

var faShadowSets = [][]string{
	{"#f6e0d0", "#ecc2a6", "#dca07e", "#c47f5c", "#a45f43", "#7c4330", "#e9c9a2", "#b88654", "#5a3326"},
	{"#fbe3e6", "#f4bcc6", "#e58ea2", "#c96882", "#a14a66", "#6e2c48", "#f3d2c4", "#d99a8e", "#4f2236"},
	{"#efe9e6", "#d8cbc6", "#b7a39d", "#8e7a75", "#5f504c", "#2f2826", "#e6d3b5", "#a88c6e", "#171313"},
	{"#fbe5c8", "#f6c27a", "#ee9a4b", "#d96c33", "#b2482b", "#7d2c25", "#f3d36b", "#c98a2e", "#4d1e1b"},
	{"#e9f1ec", "#b9d8c8", "#7fb39b", "#3f8a6c", "#256650", "#173f33", "#e8d8a8", "#c3a463", "#0f2a22"},
}

var faLipCols = []string{"#b0213a", "#c8455a", "#9c2b4c", "#d0646a", "#8e1f2c", "#c75b5b", "#a8475e", "#7a1f35"}

func faMakeup(c *faCanvas, style, pal int) {
	W, H := c.w, c.h
	s := math.Min(W, H) / 300
	set := faShadowSets[(style+pal)%len(faShadowSets)]
	lip := faLipCols[(style*3+pal)%len(faLipCols)]
	switch style {
	case 0:
		c.marble("#ece6e1")
		c.brush(W*.72, H*.72, -38, s*1.05, 0, "black", set[3])
		c.palette(W*.42, H*.42, -8, s, set, 3, 3, false, "rose", false)
		c.swatch(W*.72, H*.18, W*.9, H*.12, set[4], 12*s)
		c.swatch(W*.66, H*.24, W*.86, H*.2, set[2], 12*s)
	case 1:
		c.backdrop("#fbe9ea", "#f1cfd3")
		cols := []string{lip, shade(lip, .25), faMix(lip, "#d98a7a", .6)}
		for i, col := range cols {
			c.swatch(W*(.2+.16*float64(i)), H*.78, W*(.42+.16*float64(i)), H*.68, col, 15*s)
		}
		for i, col := range cols {
			c.lipstick(W*(.32+.18*float64(i)), H*(.4+.04*float64(i)), -62+float64(i)*8, s*.95, col, []string{"gold", "black", "rose"}[(i+pal)%3])
		}
		c.petal(W*.86, H*.14, s*1.5, 30, "#f4b6c2")
		c.petal(W*.12, H*.12, s*1.2, -40, "#f4b6c2")
	case 2:
		c.backdrop("#f8f1e8", "#ead9c6")
		c.compact(W*.68, H*.68, 0, s*.95, "gold", set[2], false)
		for i := 0; i < 5; i++ {
			c.brush(W*(.18+.1*float64(i)), H*.5, -70+float64(i)*12, s*.95, i%4, []string{"rose", "black", "gold", "wood"}[(i+pal)%4], set[(i*2)%len(set)])
		}
		c.petal(W*.86, H*.2, s*1.6, 20, "#e8c3a6")
	case 3:
		c.marble("#e9e3ee")
		c.compact(W*.4, H*.38, 0, s*1.15, "silver", "#ead0bd", true)
		c.lipstick(W*.68, H*.74, -30, s, lip, "gold")
		c.palette(W*.3, H*.78, 10, s*.6, set[4:], 2, 2, true, "black", false)
		c.glint(W*.3, H*.3, 9*s, .9)
	case 4, 7:
		skin := faSkins[(style+pal)%len(faSkins)]
		c.rect(0, 0, W, H, 0, c.lin(0, 0, 1, 1, shade(skin, .25), skin, shade(skin, -.08)))
		c.glow(W*.3, H*.2, W*.6, H*.3, "#ffffff", .3)
		iris := "#6b4022"
		ws := faShadowSets[[]int{0, 3, 1}[pal%3]]
		sh := []string{ws[0], ws[3], ws[5]}
		if style == 7 {
			sh = []string{"#f3e3c4", "#3f8a6c", "#173f33"}
			if pal%2 == 1 {
				sh = []string{"#efd9e6", "#7d4a7a", "#2c1630"}
			}
			iris = "#4b6b3a"
		}
		c.eye(W*.47, H*.58, math.Min(W*.6, H*.62), sh, iris, skin, style == 7)
	case 5:
		skin := faSkins[(style+pal+2)%len(faSkins)]
		c.rect(0, 0, W, H, 0, c.lin(0, 0, 1, 1, shade(skin, .25), skin, shade(skin, -.08)))
		c.glow(W*.3, H*.25, W*.6, H*.3, "#ffffff", .3)
		c.lips(W*.5, H*.52, W*.68, []string{"#b51f3a", "#c94f62", "#9e2a48"}[pal%3], skin)
	case 6:
		c.backdrop("#efe8f6", "#d9cfea")
		c.palette(W*.45, H*.62, 6, s*.85, set, 3, 4, false, "black", true)
		c.lipstick(W*.8, H*.8, -125, s*.85, lip, "gold")
		c.brush(W*.2, H*.84, 62, s*.8, 2, "rose", set[4])
	}
}

func (c *faCanvas) palette(x, y, rot, s float64, cols []string, rows, ncol int, round bool, caseKind string, mirror bool) {
	ps, gap := 34.0, 8.0
	w := float64(ncol)*ps + float64(ncol+1)*gap + 12
	h := float64(rows)*ps + float64(rows+1)*gap + 12
	c.g(x, y, rot, s)
	if mirror {
		y0 := -h*1.5 - 6
		md := fp("M%v %vh%vv%vh%vZ", -w/2, y0, w, h, -w)
		c.drop(md, 5, 7)
		c.rect(-w/2, y0, w, h, 10, c.metalD(caseKind))
		c.rect(-w/2+8, y0+8, w-16, h-16, 6, c.lin(0, 0, 1, 1, "#f4f6f8", "#c9ced4", "#eef0f2", "#aeb4bb"))
		c.path(fp("M%v %vL%v %vL%v %vL%v %vZ", -w/2+20, y0+h-8, -w/2+60, y0+8, -w/2+80, y0+8, -w/2+40, y0+h-8), "#ffffff", faOp(.45))
		c.g(0, -h/2-3, 0, 1)
		c.end()
		y = 0
	}
	d := fp("M%v %vh%vv%vh%vZ", -w/2, -h/2, w, h, -w)
	c.drop(d, 6, 8)
	c.rect(-w/2, -h/2, w, h, 12, c.metalD(caseKind))
	c.rect(-w/2+5, -h/2+5, w-10, h-10, 9, shade(c.metal(caseKind)[3], -.25), faOp(.6))
	i := 0
	for r := 0; r < rows; r++ {
		for k := 0; k < ncol; k++ {
			col := cols[i%len(cols)]
			px := -w/2 + 6 + gap + float64(k)*(ps+gap)
			py := -h/2 + 6 + gap + float64(r)*(ps+gap)
			g := c.rad(.38, .32, .8, shade(col, .35), col+"@0.55", shade(col, -.18))
			if round {
				c.circ(px+ps/2, py+ps/2, ps/2+1.5, c.metalD("silver"))
				c.circ(px+ps/2, py+ps/2, ps/2-1, g)
			} else {
				c.rect(px-1.2, py-1.2, ps+2.4, ps+2.4, 6, c.metalD("silver"))
				c.rect(px, py, ps, ps, 5, g)
			}
			if i%3 == 1 {
				for j := 0; j < 5; j++ {
					c.circ(px+c.rr(5, ps-5), py+c.rr(5, ps-5), c.rr(.5, 1.1), "#ffffff", faOp(.8))
				}
			}
			if i%4 == 2 {
				c.ell(px+ps*.5, py+ps*.55, ps*.25, ps*.18, shade(col, .25), faOp(.6))
			}
			i++
		}
	}
	c.end()
}

func (c *faCanvas) lipstick(x, y, rot, s float64, col, caseKind string) {
	c.g(x, y, rot, s)
	c.drop("M-60 -13H40L60 0L40 13H-60Z", 4, 7)
	c.rect(-62, -13, 58, 26, 4, c.lin(0, 0, 0, 1, c.metal(caseKind)...))
	c.stroke("M-52 -13V13M-46 -13V13", shade(c.metal(caseKind)[0], .2), 1, faOp(.5))
	c.rect(-6, -10, 26, 20, 2, c.lin(0, 0, 0, 1, c.metal("gold")...))
	c.path("M20 -8H42Q56 -6 60 8H20Z", c.lin(0, 0, 0, 1, shade(col, .3), col, shade(col, -.35)))
	c.stroke("M24 -4H42Q50 -3 54 2", "#ffffff", 1.5, faOp(.45))
	c.end()
}

func (c *faCanvas) brush(x, y, rot, s float64, kind int, handle, tip string) {
	c.g(x, y, rot, s)
	hd := "M-92 -3L18 -6V6L-92 3Q-96 0 -92 -3Z"
	c.drop(hd, 3, 6)
	if handle == "wood" {
		c.path(hd, c.lin(0, 0, 0, 1, "#d9b48a", "#b98b5a", "#8a5f37"))
	} else {
		c.path(hd, c.lin(0, 0, 0, 1, c.metal(handle)...))
	}
	c.rect(16, -7.5, 26, 15, 2, c.lin(0, 0, 0, 1, c.metal("silver")...))
	var bd string
	switch kind {
	case 0: // powder
		bd = "M40 -8C56 -20 86 -18 94 0C86 18 56 20 40 8Z"
	case 1: // angled
		bd = "M40 -7C52 -11 66 -12 76 -14L68 12C58 11 48 10 40 7Z"
	case 2: // fluffy eye
		bd = "M40 -6C50 -10 64 -9 70 0C64 9 50 10 40 6Z"
	default: // flat fan
		bd = "M40 -5L74 -22Q80 0 74 22L40 5Z"
	}
	c.drop(bd, 3, 6)
	c.path(bd, c.lin(0, 0, 1, 0, "#2b2421", "#5a4a42@0.45", shade(tip, -.05)))
	c.path(bd, c.lin(0, 0, 1, 0, tip+"/0", tip+"/0@0.5", tip+"/0.7"))
	c.stroke("M46 -3Q62 -5 76 -3M46 3Q62 5 76 3", "#ffffff", .7, faOp(.25))
	c.end()
}

func (c *faCanvas) compact(x, y, rot, s float64, caseKind, powder string, mirror bool) {
	c.g(x, y, rot, s)
	if mirror {
		c.drop(faPoly(-50, -44, 46, 24, 0), 5, 7)
		c.circ(-50, -44, 46, c.metalD(caseKind))
		c.circ(-50, -44, 39, c.lin(0, 0, 1, 1, "#ffffff", "#d3d8dd", "#f2f4f6", "#b8bec5"))
		c.path("M-80 -24L-46 -82L-34 -78L-68 -18Z", "#ffffff", faOp(.4))
		c.rect(-12, -18, 14, 10, 3, c.metalD(caseKind), `transform="rotate(-40 -5 -13)"`)
		c.g(18, 18, 0, 1)
	} else {
		c.g(0, 0, 0, 1)
	}
	c.drop(faPoly(0, 0, 46, 24, 0), 5, 7)
	c.circ(0, 0, 46, c.metalD(caseKind))
	c.circ(0, 0, 38, c.rad(.4, .35, .7, shade(powder, .3), powder, shade(powder, -.15)))
	for k := 0; k < 8; k++ {
		a := float64(k) * math.Pi / 4
		c.path(fp("M0 0Q%v %v %v %vQ%v %v 0 0Z", 18*math.Cos(a-.3), 18*math.Sin(a-.3), 28*math.Cos(a), 28*math.Sin(a), 18*math.Cos(a+.3), 18*math.Sin(a+.3)), shade(powder, .22), faOp(.55))
	}
	c.circ(0, 0, 6, shade(powder, .28))
	c.glow(-12, -14, 18, 12, "#ffffff", .5)
	c.end()
	c.end()
}

func (c *faCanvas) swatch(x1, y1, x2, y2 float64, col string, w float64) {
	d := fp("M%v %vQ%v %v %v %v", x1, y1, (x1+x2)/2, (y1+y2)/2-w*.6, x2, y2)
	c.stroke(d, col, w, faOp(.88))
	c.stroke(d, "#ffffff", w*.3, faOp(.22), `transform="translate(0 -2)"`)
}

func (c *faCanvas) eye(cx, cy, e float64, sh []string, iris, skin string, glitter bool) {
	in, out := faP(cx-.48*e, cy+.03*e), faP(cx+.5*e, cy-.05*e)
	u1, u2 := faP(cx-.22*e, cy-.34*e), faP(cx+.24*e, cy-.34*e)
	l1, l2 := faP(cx+.24*e, cy+.2*e), faP(cx-.24*e, cy+.2*e)
	eyeD := fp("M%vC%v %v %vC%v %v %vZ", in, u1, u2, out, l1, l2, in)
	wing := faP(cx+.7*e, cy-.24*e)
	// brow bone highlight + eyeshadow
	c.glow(cx+.05*e, cy-.62*e, .55*e, .14*e, "#ffffff", .35)
	lid := fp("M%vC%v %v %vQ%v %vC%v %v %vZ", in, faP(cx-.32*e, cy-.62*e), faP(cx+.28*e, cy-.7*e), faP(cx+.72*e, cy-.36*e), faP(cx+.6*e, cy-.14*e), out, u2, u1, in)
	c.glow(cx+.18*e, cy-.42*e, .62*e, .24*e, sh[1], .45)
	c.path(lid, c.lin(0, .3, 1, 0, sh[0], sh[1]+"@0.55", sh[2]))
	c.glow(cx-.12*e, cy-.24*e, .17*e, .1*e, "#ffffff", .55)
	n := 14
	if glitter {
		n = 40
	}
	cl := c.clip(lid)
	for i := 0; i < n; i++ {
		c.circ(cx+c.rr(-.4, .55)*e, cy+c.rr(-.5, -.15)*e, c.rr(.003, .008)*e, "#ffffff", faOp(c.rr(.5, .95)), cl)
	}
	// brow
	brow := fp("M%vC%v %v %vQ%v %vQ%v %vC%v %v %vZ", faP(cx-.48*e, cy-.6*e), faP(cx-.3*e, cy-.8*e), faP(cx+.1*e, cy-.9*e), faP(cx+.3*e, cy-.86*e),
		faP(cx+.48*e, cy-.8*e), faP(cx+.62*e, cy-.62*e), faP(cx+.44*e, cy-.72*e), faP(cx+.28*e, cy-.75*e), faP(cx+.05*e, cy-.77*e), faP(cx-.3*e, cy-.7*e), faP(cx-.48*e, cy-.6*e))
	c.path(brow, "#4a3026", faOp(.85))
	var hb strings.Builder
	for i := 0; i < 26; i++ {
		t := float64(i) / 25
		x := cx + (-.46+t)*e
		y := cy - (.64+.22*math.Sin(t*math.Pi*.9))*e
		hb.WriteString(fp("M%v %vl%v %v", x, y+.03*e, .05*e, -.05*e))
	}
	c.stroke(hb.String(), "#2e1c15", .006*e, faOp(.7))
	// eyeball
	c.path(eyeD, c.rad(.5, .5, .6, "#ffffff", "#f6efea", "#d6c4ba"))
	ecl := c.clip(eyeD)
	ix, iy, ir := cx+.03*e, cy-.06*e, .2*e
	c.circ(ix, iy, ir, c.rad(.5, .5, .5, "#120b08", "#120b08@0.36", shade(iris, .35)+"@0.42", iris+"@0.8", shade(iris, -.55)), ecl)
	c.ell(cx, cy-.26*e, .55*e, .14*e, "#3a241b", faOp(.35), ecl)
	c.circ(ix-.07*e, iy-.07*e, .035*e, "#ffffff", faOp(.9))
	c.circ(ix+.08*e, iy+.06*e, .015*e, "#ffffff", faOp(.7))
	// lower lid soft liner
	c.stroke(fp("M%vC%v %v %v", out, l1, l2, in), sh[2], .025*e, faOp(.35))
	// eyeliner + wing
	c.stroke(fp("M%vC%v %v %v", in, u1, u2, out), "#1a1210", .03*e)
	c.path(fp("M%vL%vL%vZ", faP(out.X-.1*e, out.Y-.05*e), wing, faP(out.X+.02*e, out.Y+.012*e)), "#1a1210")
	// lashes
	var lb strings.Builder
	for i := 0; i < 30; i++ {
		t := .12 + .88*float64(i)/29
		p := faBez3(in, u1, u2, out, t)
		tg := faBez3D(in, u1, u2, out, t).unit()
		nrm := faP(tg.Y, -tg.X)
		L := e * (.07 + .13*t)
		lb.WriteString(fp("M%vQ%v %v", p, p.add(nrm.mul(L*.7)).add(tg.mul(L*.12)), p.add(nrm.mul(L)).add(tg.mul(L*.5))))
	}
	c.stroke(lb.String(), "#1a1210", .011*e)
	lb.Reset()
	for i := 0; i < 12; i++ {
		t := .05 + .55*float64(i)/11
		p := faBez3(out, l1, l2, in, t)
		lb.WriteString(fp("M%vl%v %v", p, .012*e, .05*e*(1-t)+.012*e))
	}
	c.stroke(lb.String(), "#1a1210", .006*e, faOp(.7))
	_ = skin
}

func (c *faCanvas) lips(cx, cy, lw float64, col, skin string) {
	P := func(x, y float64) faPt { return faP(cx+x*lw, cy+y*lw) }
	L, R := P(-.5, 0), P(.5, 0)
	mouth := fp("C%v %v %vC%v %v %v", P(.25, .035), P(.08, -.025), P(0, .02), P(-.08, -.025), P(-.25, .035), L)
	upper := fp("M%vC%v %v %vQ%v %vQ%v %vC%v %v %v", L, P(-.32, -.1), P(-.2, -.24), P(-.1, -.24), P(-.04, -.24), P(0, -.17), P(.04, -.24), P(.1, -.24), P(.2, -.24), P(.32, -.1), R) + mouth + "Z"
	lower := fp("M%vC%v %v %vC%v %v %v", L, P(-.25, .035), P(-.08, -.025), P(0, .02), P(.08, -.025), P(.25, .035), R) + fp("C%v %v %vZ", P(.32, .32), P(-.32, .32), L)
	c.glow(cx, cy+.3*lw, .4*lw, .08*lw, shade(skin, -.4), .35)
	c.glow(cx, cy-.32*lw, .06*lw, .1*lw, shade(skin, -.25), .3)
	c.path(upper, c.lin(0, 0, 0, 1, shade(col, .05), shade(col, -.25)))
	c.path(lower, c.lin(0, 0, 0, 1, shade(col, -.2), col+"@0.35", shade(col, -.3)))
	c.glow(cx, cy+.12*lw, .2*lw, .06*lw, "#ffffff", .55)
	c.glow(cx-.1*lw, cy-.17*lw, .07*lw, .025*lw, "#ffffff", .45)
	c.glow(cx+.1*lw, cy-.17*lw, .07*lw, .025*lw, "#ffffff", .35)
	var b strings.Builder
	for i := 0; i < 28; i++ {
		x := -.42 + .84*float64(i)/27
		b.WriteString(fp("M%vl0 %v", P(x, .03), .12*lw*(1-math.Abs(x)*1.6)))
	}
	c.stroke(b.String(), shade(col, -.45), .004*lw, faOp(.3), c.clip(lower))
	c.stroke(fp("M%v", R)+mouth, shade(col, -.6), .012*lw)
}

// ---------------------------------------------------------------- dyrnak (nails)

type faFinger struct{ x, y, ang, L, w float64 }

var faHand = []faFinger{
	{90, 320, -50, 88, 33},
	{110, 250, -14, 116, 29},
	{143, 240, -3, 130, 30},
	{175, 248, 8, 120, 28},
	{203, 268, 19, 94, 25},
}

func faNails(c *faCanvas, design, pal int, bare bool) {
	faNailsPose(c, design, design, pal, bare)
}

// faNailsPose separates the hand pose/background (pose) from the nail art
// (design) so the same hand can be shown with different manicures.
func faNailsPose(c *faCanvas, pose, design, pal int, bare bool) {
	bgs := [][2]string{{"#fbeef0", "#f1d4dc"}, {"#f3eefb", "#ddd2ef"}, {"#eef4f1", "#d3e4dc"}, {"#fdf3e7", "#f2dcc2"}, {"#f8ece6", "#ead0c4"}, {"#eef2f8", "#d5deec"}, {"#fbf1ee", "#efd5cf"}, {"#f4f0e8", "#e3d9c6"}}
	bg := bgs[(pose+pal*3)%8]
	skin := faSkins[(pose+pal)%len(faSkins)]
	c.backdrop(bg[0], bg[1])
	accent := []string{"#f4b6c2", "#c7b3e6", "#a7d3bf", "#f2c98a", "#e6a6a0", "#b4c6e8", "#e6a6b8", "#d9c49a"}[(pose+pal)%8]
	for i := 0; i < 5; i++ {
		c.petal(c.w*c.rr(.05, .95), c.h*c.rr(.05, .5), c.rr(.8, 1.6), c.rr(0, 360), accent)
	}
	c.confetti(10, []string{"#e2b65a", "#ffffff"}, .8, 2)
	c.glow(c.w*.5, c.h*.55, c.w*.5, c.h*.35, "#ffffff", .4)
	c.fit(300, 400, .5, 1)
	rot := []float64{-8, 6, -4, 10, -10, 4, 0, -6}[pose]
	mirror := (pose+pal)%3 == 1
	sx := 1.0
	if mirror {
		sx = -1
	}
	c.p(`<g transform="rotate(%v 150 400) translate(150 0) scale(%v 1) translate(-150 0)">`, rot, sx)
	// soft shadow of the hand on the surface
	c.p(`<g transform="translate(10 14)" opacity=".1">`)
	c.handShape("#3d2a20")
	c.end()
	c.handShape(skin)
	shapes := []int{0, 1, 0, 2, 0, 1, 1, 2}
	for i, f := range faHand {
		c.p(`<g transform="translate(%v %v) rotate(%v)">`, f.x, f.y, f.ang)
		wt := f.w * .86
		fd := fp("M%v 24L%v %vA%v %v 0 0 1 %v %vL%v 24Z", -f.w/2, -wt/2, -(f.L - wt/2), wt/2, wt/2, wt/2, -(f.L - wt/2), f.w/2)
		c.path(fd, c.lin(0, 0, 1, 0, "#5a3020/0.22", "#5a3020/0@0.3", "#5a3020/0@0.65", "#5a3020/0.25"))
		c.stroke(fp("M%v %vQ0 %v %v %v", -wt*.3, -f.L*.45, -f.L*.45-3, wt*.3, -f.L*.45), shade(skin, -.3), .8, faOp(.35))
		c.stroke(fp("M%v %vQ0 %v %v %v", -wt*.25, -f.L*.7, -f.L*.7-2, wt*.25, -f.L*.7), shade(skin, -.3), .7, faOp(.25))
		if i == 3 && pose%2 == 0 {
			c.rect(-f.w/2-1, -f.L*.4, f.w+2, 6, 3, c.metalH("gold"))
			c.circ(0, -f.L*.4+3, 3, c.rad(.35, .3, .7, "#ffffff", "#f3eadf", "#b9ad9f"))
		}
		c.nail(design, i, shapes[design], wt, f.L, pal, bare)
		c.end()
	}
	// knuckle highlights
	for _, f := range faHand[1:] {
		c.glow(f.x, f.y+4, 12, 7, "#ffffff", .25)
	}
	// sleeve
	sl := []string{"#efe6da", "#2d3f6b", "#c46a72", "#1f5e4a", "#d9c2a7", "#5b3a6e", "#8a2440", "#f2efe9"}[(pose*3+pal)%8]
	c.path("M76 372Q150 356 228 372L236 440H68Z", c.lin(0, 0, 1, 1, shade(sl, .2), sl, shade(sl, -.3)))
	c.stroke("M80 372Q150 356 226 372", shade(sl, -.35), 2, faOp(.4))
	var rib strings.Builder
	for x := 86.0; x < 226; x += 7 {
		rib.WriteString(fp("M%v %vV420", x, 372-10*math.Sin((x-76)/152*math.Pi)))
	}
	c.stroke(rib.String(), shade(sl, -.3), .8, faOp(.3))
	c.end()
	c.end()
}

func (c *faCanvas) handShape(fill string) {
	solid := fill
	if fill != "#3d2a20" {
		solid = fill
	}
	for _, f := range faHand {
		wt := f.w * .86
		c.p(`<g transform="translate(%v %v) rotate(%v)">`, f.x, f.y, f.ang)
		c.path(fp("M%v 24L%v %vA%v %v 0 0 1 %v %vL%v 24Z", -f.w/2, -wt/2, -(f.L-wt/2), wt/2, wt/2, wt/2, -(f.L-wt/2), f.w/2), solid)
		c.end()
	}
	c.path("M66 342C62 302 84 266 98 252C128 230 182 238 216 264C230 296 228 344 222 380H86C80 370 68 360 66 342Z", solid)
	if fill != "#3d2a20" {
		c.path("M66 342C62 302 84 266 98 252C128 230 182 238 216 264C230 296 228 344 222 380H86C80 370 68 360 66 342Z", c.lin(0, 0, 1, 1, "#ffffff/0.18", "#ffffff/0@0.5", "#5a3020/0.18"))
		c.stroke("M118 266C116 300 112 330 110 372M146 258V372M174 266C176 300 178 330 182 372", shade(fill, -.25), 1.2, faOp(.18))
	}
}

func (c *faCanvas) nail(design, idx, shape int, wt, L float64, pal int, bare bool) {
	nw := wt * .76
	y0 := -L + wt*1.12
	ext := []float64{.55, .22, .3}[shape] * wt
	yT := -L - ext
	nl := y0 - yT
	var nd string
	switch shape {
	case 1:
		r := nw * .2
		nd = fp("M%v %vL%v %vQ%v %v %v %vL%v %vQ%v %v %v %vL%v %vQ0 %v %v %vZ",
			-nw/2, y0, -nw/2, yT+r, -nw/2, yT, -nw/2+r, yT, nw/2-r, yT, nw/2, yT, nw/2, yT+r, nw/2, y0, y0+nw*.3, -nw/2, y0)
	case 2:
		nd = fp("M%v %vC%v %v %v %v 0 %vC%v %v %v %v %v %vQ0 %v %v %vZ",
			-nw/2, y0, -nw/2, yT+nw*.15, -nw*.32, yT, yT, nw*.32, yT, nw/2, yT+nw*.15, nw/2, y0, y0+nw*.3, -nw/2, y0)
	default:
		nd = fp("M%v %vC%v %v %v %v 0 %vC%v %v %v %v %v %vQ0 %v %v %vZ",
			-nw/2, y0, -nw/2, y0-nl*.6, -nw*.16, yT+2, yT, nw*.16, yT+2, nw/2, y0-nl*.6, nw/2, y0, y0+nw*.3, -nw/2, y0)
	}
	c.stroke(nd, "#7a4a3a", 1.4, faOp(.18))
	if bare {
		c.path(nd, c.lin(0, 0, 0, 1, "#f6e6df", "#efc9c0@0.3", "#e8b3a8"))
		c.glow(-nw*.15, y0-nl*.45, nw*.15, nl*.3, "#ffffff", .5)
		return
	}
	cl := c.clip(nd)
	matte := false
	switch design {
	case 0: // French tips
		c.path(nd, c.lin(0, 0, 0, 1, "#f9e1dc", "#f2c9c3"))
		ys := yT + nl*.34
		c.path(fp("M%v %vQ0 %v %v %vV%vH%vZ", -nw, ys, ys+nl*.22, nw, ys, yT-4, -nw), "#fffdfb", cl)
	case 1: // ombré
		pairs := [][2]string{{"#f7a6b9", "#fde6ec"}, {"#b9a4e3", "#fbe0ea"}, {"#f4a582", "#fdeadf"}}
		p := pairs[pal%3]
		c.path(nd, c.lin(0, 0, 0, 1, p[0], faMix(p[0], p[1], .5)+"@0.5", p[1]))
	case 2: // glitter dots on navy, one gold accent nail
		if idx == 3 {
			c.path(nd, c.lin(0, 0, 1, 1, c.metal("gold")...))
			for i := 0; i < 26; i++ {
				c.circ(c.rr(-nw/2, nw/2), c.rr(yT, y0), c.rr(.3, .8), "#fff6d8", cl)
			}
		} else {
			c.path(nd, c.lin(0, 0, 0, 1, "#2a3a64", "#16203d"))
			for i := 0; i < 10; i++ {
				c.circ(c.rr(-nw/2, nw/2), c.rr(yT+nl*.1, y0), c.rr(.5, 1.5), "#e8c66a", cl)
			}
		}
	case 3: // flowers
		if idx == 2 || idx == 4 {
			c.path(nd, c.lin(0, 0, 0, 1, "#fbf5f1", "#efe4dc"))
			c.flower(0, yT+nl*.45, nw*.42, "#f19bb0", "#f2c14e")
			c.flower(nw*.32, yT+nl*.78, nw*.22, "#f6c1cf", "#f2c14e")
			c.path("M0 0Q4 -3 6 0Q3 3 0 0Z", "#8fbf9a", fp(`transform="translate(%v %v) scale(%v)"`, -nw*.38, yT+nl*.72, faNum2(nw*.06)))
		} else {
			c.path(nd, c.lin(0, 0, 0, 1, "#f6bccb", "#eea3b6"))
		}
	case 4: // Turkmen gul
		c.path(nd, c.lin(0, 0, 0, 1, "#8a2236", "#5c0f22"))
		gy := yT + nl*.5
		c.path(faPoly(0, gy, nw*.36, 8, math.Pi/8), "none", `stroke="#e8c66a" stroke-width="1.1"`, cl)
		c.path(faPoly(0, gy, nw*.17, 4, 0), "#e8c66a")
		c.circ(0, gy, nw*.06, "#c8102e")
		c.stroke(fp("M%v %vQ0 %v %v %v", -nw*.45, y0-2.5, y0+nw*.22, nw*.45, y0-2.5), "#e8c66a", 1, cl)
	case 5: // gold foil lines on nude
		c.path(nd, c.lin(0, 0, 0, 1, "#f1d6c8", "#e2b9a6"))
		for i := 0; i < 3; i++ {
			y := c.rr(yT, y0)
			c.stroke(fp("M%v %vL%v %vL%v %v", -nw*.6, y, c.rr(-.2, .2)*nw, y+c.rr(-8, 8), nw*.6, y+c.rr(-10, 10)), c.lin(0, 0, 1, 1, c.metal("gold")...), c.rr(.6, 1.6), cl)
		}
		c.path(fp("M%v %vL%v %vL%v %vZ", c.rr(-.3, 0)*nw, yT+nl*.3, c.rr(0, .4)*nw, yT+nl*.36, c.rr(-.1, .2)*nw, yT+nl*.5), c.metalD("gold"), cl)
	case 6: // burgundy matte, gold half-moon accent
		matte = true
		c.path(nd, "#5e1324")
		c.path(nd, c.lin(0, 0, 1, 0, "#7a2236/0.6", "#7a2236/0"))
		if idx == 3 || idx == 0 {
			c.path(fp("M%v %vQ0 %v %v %vQ0 %v %v %vZ", -nw/2, y0, y0-nw*.55, nw/2, y0, y0+nw*.3, -nw/2, y0), c.metalD("gold"), cl)
		}
	default: // pastel rainbow
		cols := []string{"#f6b5c4", "#f9d29c", "#bfe3c8", "#b9d3f2", "#d8c3ef"}
		col := cols[(idx+pal)%5]
		c.path(nd, c.lin(0, 0, 0, 1, shade(col, .15), col))
		c.circ(0, y0-nl*.2, 1.6, "#ffffff", faOp(.9))
	}
	if !matte {
		c.stroke(fp("M%v %vQ%v %v %v %v", -nw*.22, y0-nl*.18, -nw*.26, yT+nl*.5, -nw*.12, yT+nl*.18), "#ffffff", nw*.12, faOp(.5))
		c.circ(nw*.18, y0-nl*.2, nw*.05, "#ffffff", faOp(.5))
	}
}

// ---------------------------------------------------------------- shay (jewellery)

func faJewellery(c *faCanvas, style, pal int) {
	W, H := c.w, c.h
	s := math.Min(W, H) / 300
	velvets := []string{"#4a1424", "#1f3b30", "#1b2340", "#1c1817", "#163a3f", "#3b1830"}
	vel := velvets[(style+pal)%len(velvets)]
	silks := []string{"#efe3d0", "#ecd6cf", "#e8e1d3"}
	switch style {
	case 0:
		c.velvet(vel)
		c.glow(W*.5, H*.72, 110*s, 22*s, "#000000", .45)
		c.gupba(W*.5, H*.68, s*1.1, "gilt")
		c.glint(W*.42, H*.4, 10*s, .9)
		c.glint(W*.64, H*.58, 7*s, .8)
	case 1:
		c.velvet(vel)
		c.glow(W*.42, H*.7, 90*s, 22*s, "#000000", .45)
		c.cuff(W*.62, H*.48, 52*s, 54*s, "silver", 5)
		c.cuff(W*.38, H*.58, 58*s, 62*s, "gilt", 6)
		c.glint(W*.3, H*.6, 9*s, .9)
		c.glint(W*.7, H*.46, 7*s, .8)
	case 2:
		c.silk(silks[pal%3])
		c.ring(W*.3, H*.42, s*1.05, -12, "gilt")
		c.ring(W*.66, H*.36, s*.95, 14, "silver")
		c.ring(W*.5, H*.7, s*1.15, 4, "gold")
		c.glint(W*.56, H*.62, 9*s, .9)
	case 3:
		c.velvet(vel)
		c.necklace(W*.5, H*.12, W*.82, H*.62, s, "silver")
		c.glint(W*.6, H*.68, 9*s, .9)
	case 4:
		c.silk(silks[(pal+1)%3])
		c.glow(W*.53, H*.53, 100*s, 100*s, "#5a3a20", .25)
		c.brooch(W*.5, H*.45, 80*s, "gilt")
		c.glint(W*.4, H*.35, 10*s, .9)
	case 5:
		c.velvet(vel)
		c.earring(W*.32, H*.3, s, -6, "gilt")
		c.earring(W*.68, H*.36, s, 8, "gilt")
		c.glint(W*.3, H*.42, 8*s, .9)
	case 6:
		c.silk(silks[(pal+2)%3])
		c.glow(W*.53, H*.56, 90*s, 100*s, "#5a3a20", .22)
		c.asyk(W*.5, H*.52, s*1.25, "gilt")
		c.glint(W*.6, H*.4, 9*s, .9)
	default:
		c.velvet(vel)
		c.cuff(W*.3, H*.36, 44*s, 44*s, "gilt", 5)
		c.ring(W*.72, H*.28, s*.85, 10, "silver")
		c.earring(W*.68, H*.6, s*.85, -4, "silver")
		c.ring(W*.3, H*.74, s*.8, -18, "gold")
		c.glint(W*.42, H*.5, 8*s, .9)
	}
}

func (c *faCanvas) dangles(x0, x1, y float64, n int, metal string, length float64) {
	for i := 0; i < n; i++ {
		x := x0 + (x1-x0)*float64(i)/float64(max(1, n-1))
		l := length * (1 + .25*float64(i%2))
		c.stroke(fp("M%v %vV%v", x, y, y+l), c.metal(metal)[1], .9)
		c.g(x, y+l, 0, 1)
		c.path("M0 0C3 2 4 7 0 11C-4 7 -3 2 0 0Z", c.metalD(metal))
		c.end()
		if i%2 == 0 {
			c.circ(x, y+l*.45, 1.6, "#c8301c")
		}
	}
}

func (c *faCanvas) gupba(x, y, s float64, metal string) {
	c.g(x, y, 0, s)
	m := c.metalH(metal)
	c.path("M-72 -14C-72 -84 -40 -118 0 -122C40 -118 72 -84 72 -14Z", m)
	c.path("M-72 -14C-72 -84 -40 -118 0 -122C40 -118 72 -84 72 -14Z", c.rad(.35, .3, .7, "#ffffff/0.35", "#ffffff/0", "#000000/0.25"))
	var rb strings.Builder
	for i := -3; i <= 3; i++ {
		x := float64(i) * 20
		rb.WriteString(fp("M%v -16Q%v -95 %v -118", x, x*.85, x*.2))
	}
	c.stroke(rb.String(), "#4a3416", 1.6, faOp(.4))
	c.stroke(rb.String(), "#fff6da", .8, faOp(.5), `transform="translate(2 0)"`)
	c.stroke("M-62 -66Q0 -92 62 -66", m, 7)
	for i := -2; i <= 2; i++ {
		t := float64(i) / 5
		px := t * 124
		py := -66 - 26*(1-(2*t)*(2*t))*.5 - 2
		c.stone(px, py+2, 3.4, 4.2, metal)
	}
	for i := 0; i < 14; i++ {
		a := math.Pi + math.Pi*float64(i+1)/15
		c.circ(52*math.Cos(a), -36+40*math.Sin(a), 1.6, "#fff6da", faOp(.8))
	}
	c.rect(-76, -24, 152, 20, 5, m)
	c.stroke("M-74 -21H74M-74 -7H74", "#4a3416", .8, faOp(.5))
	for i := 0; i < 8; i++ {
		c.stone(-66+float64(i)*18.9, -14, 4.6, 5.6, "")
	}
	c.rect(-5, -138, 10, 18, 3, m)
	c.path("M-2 -148L0 -170L2 -148Z", m)
	c.stone(0, -144, 6, 6, metal)
	c.dangles(-70, 70, -4, 15, metal, 14)
	c.end()
}

func (c *faCanvas) cuff(x, y, R, H float64, metal string, n int) {
	ry := R * .32
	c.g(x, y-H/2, 0, 1)
	c.ell(0, 0, R, ry, c.lin(0, 0, 0, 1, shade(c.metal(metal)[0], -.3), shade(c.metal(metal)[3], -.2)))
	c.ell(0, ry*.15, R*.92, ry*.82, c.lin(0, 0, 0, 1, shade(c.metal(metal)[0], -.5), shade(c.metal(metal)[0], -.2)))
	body := fp("M%v 0A%v %v 0 0 0 %v 0V%vA%v %v 0 0 1 %v %vZ", -R, R, ry, R, H, R, ry, -R, H)
	c.path(body, c.metalH(metal))
	c.path(body, c.lin(0, 0, 0, 1, "#ffffff/0.25", "#ffffff/0@0.3", "#000000/0.2"))
	for _, yy := range []float64{5, H - 5} {
		c.stroke(fp("M%v %vA%v %v 0 0 0 %v %v", -R+1, yy, R-1, ry, R-1, yy), "#3a2a10", 1.1, faOp(.45))
	}
	var dots strings.Builder
	for i := 0; i < 26; i++ {
		th := -1.45 + 2.9*float64(i)/25
		for _, yy := range []float64{10, H - 10} {
			px, py := R*math.Sin(th), yy+ry*math.Cos(th)
			dots.WriteString(fp("M%v %vh.1", px, py))
		}
	}
	c.stroke(dots.String(), "#fff6da", 2.2, faOp(.8))
	for j := 0; j < n; j++ {
		th := -1.15 + 2.3*float64(j)/float64(n-1)
		px, py := R*math.Sin(th), H/2+ry*math.Cos(th)
		c.stone(px, py, 7*math.Cos(th)+1, 9, metal)
	}
	c.end()
}

func (c *faCanvas) ring(x, y, s, rot float64, metal string) {
	c.g(x, y, rot, s)
	c.glow(4, 40, 34, 8, "#000000", .3)
	c.ell(0, 12, 25, 25, "none", `stroke="`+shade(c.metal(metal)[0], -.2)+`" stroke-width="4"`)
	c.path("M-27 12A27 27 0 0 0 27 12A27 27 0 0 0 -27 12Z", "none", `stroke="`+c.metalH(metal)+`" stroke-width="5"`)
	c.ell(0, 12, 27, 27, "none", `stroke="`+c.metalD(metal)+`" stroke-width="5"`, `stroke-dasharray="0 42 85"`)
	c.ell(0, -16, 19, 15, c.metalD(metal))
	for k := 0; k < 16; k++ {
		a := float64(k) * math.Pi / 8
		c.circ(17*math.Cos(a), -16+13*math.Sin(a), 1.5, "#fff6da", faOp(.85))
	}
	c.stone(0, -16, 11, 8.5, "")
	c.end()
}

func (c *faCanvas) necklace(cx, top, span, depth, s float64, metal string) {
	p0, p2 := faP(cx-span/2, top), faP(cx+span/2, top)
	p1 := faP(cx, top+depth*2-top*0)
	n := 26
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		p := faBez2(p0, p1, p2, t)
		if i%2 == 0 {
			c.circ(p.X, p.Y, 4.2*s, c.rad(.35, .3, .7, "#ffffff", c.metal(metal)[1], c.metal(metal)[0]))
		} else if i%4 == 1 {
			c.stone(p.X, p.Y, 4*s, 5*s, "")
		} else {
			c.circ(p.X, p.Y, 2.6*s, c.metalD("gold"))
		}
	}
	mid := faBez2(p0, p1, p2, .5)
	c.brooch(mid.X, mid.Y+34*s, 30*s, "gilt")
}

func (c *faCanvas) brooch(x, y, R float64, metal string) {
	c.g(x, y, 0, R/80)
	c.circ(0, 0, 80, c.metalD(metal))
	c.circ(0, 0, 80, c.rad(.35, .3, .75, "#ffffff/0.3", "#ffffff/0", "#000000/0.3"))
	var gr strings.Builder
	for k := 0; k < 32; k++ {
		a := float64(k) * math.Pi / 16
		gr.WriteString(fp("M%v %vh.1", 73*math.Cos(a), 73*math.Sin(a)))
	}
	c.stroke(gr.String(), "#fff6da", 5.5, faOp(.85))
	c.ell(0, 0, 64, 64, "none", `stroke="#4a3416" stroke-width="1.2" stroke-opacity=".5"`)
	for k := 0; k < 8; k++ {
		c.p(`<g transform="rotate(%v)">`, k*45)
		c.path("M0 -26Q14 -46 0 -62Q-14 -46 0 -26Z", c.metalD("gold"))
		c.stroke("M0 -30V-58", "#4a3416", .8, faOp(.4))
		c.stone(0, -46, 4.2, 5.4, "")
		c.end()
	}
	c.circ(0, 0, 25, c.metalH(metal))
	c.stone(0, 0, 19, 19, "")
	c.end()
	c.g(x, y, 0, R/80)
	c.dangles(-46, 46, 64, 7, metal, 22)
	c.end()
}

func (c *faCanvas) earring(x, y, s, rot float64, metal string) {
	c.g(x, y, rot, s)
	c.stroke("M0 -40C-10 -54 8 -66 12 -54", c.metal(metal)[1], 2.4)
	c.circ(0, -36, 5, "none", `stroke="`+c.metalD(metal)+`" stroke-width="2.5"`)
	cres := "M-44 -10A44 44 0 0 0 44 -10A44 30 0 0 1 -44 -10Z"
	c.glow(6, 40, 50, 12, "#000000", .3)
	c.path(cres, c.metalD(metal))
	c.path("M-38 -16Q0 -40 38 -16Q0 -26 -38 -16Z", c.metalD(metal))
	c.stone(0, -30, 6, 6, metal)
	for k := 0; k < 5; k++ {
		a := math.Pi*.18 + math.Pi*.64*float64(k)/4
		c.stone(-35*math.Cos(a), -10+30*math.Sin(a)*.62+4, 4, 4.4, "")
	}
	c.dangles(-34, 34, 24, 7, metal, 18)
	c.end()
}

func (c *faCanvas) asyk(x, y, s float64, metal string) {
	heart := "M0 66C-30 44 -64 12 -64 -22C-64 -50 -40 -64 -18 -58C-8 -55 -2 -48 0 -42C2 -48 8 -55 18 -58C40 -64 64 -50 64 -22C64 12 30 44 0 66Z"
	c.g(x, y, 0, s)
	c.stroke("M-30 -80Q0 -50 30 -80", c.metal(metal)[1], 1.4)
	c.circ(0, -52, 6, "none", `stroke="`+c.metalD(metal)+`" stroke-width="3"`)
	c.path(heart, c.metalD(metal))
	c.path(heart, c.rad(.35, .3, .75, "#ffffff/0.3", "#ffffff/0", "#000000/0.3"))
	c.p(`<g transform="scale(.82) translate(0 -2)">`)
	c.path(heart, "none", `stroke="#4a3416" stroke-width="1.4" stroke-opacity=".45"`)
	c.end()
	c.stroke("M-40 -20C-30 -40 -14 -30 -20 -18C-26 -8 -12 4 -2 -6M40 -20C30 -40 14 -30 20 -18C26 -8 12 4 2 -6M-30 14C-20 28 -6 26 0 40C6 26 20 28 30 14", c.metalD("gold"), 3)
	for _, p := range []faPt{{-44, -28}, {44, -28}, {-34, 16}, {34, 16}, {0, 46}} {
		c.stone(p.X, p.Y, 4, 4.6, "")
	}
	c.stone(0, -6, 13, 16, "gold")
	c.dangles(-26, 26, 46, 5, metal, 22)
	c.end()
}

// ---------------------------------------------------------------- keshde (embroidery)

const (
	faRed   = "#c41e2e"
	faGold  = "#e3b23c"
	faGreen = "#2f7d4a"
	faWhite = "#f4efe6"
	faBlack = "#1c1a19"
)

func faEmbroidery(c *faCanvas, style, pal int) {
	W, H := c.w, c.h
	fabrics := []string{"#1f4a3a", "#6b1626", "#171515", "#efe6d2", "#f0e8d6", "#1d4536", "#5e1424", "#e9dfc8"}
	fab := fabrics[(style+pal*2)%8]
	if style == 7 {
		fab = "#e3d6bd"
	}
	c.fabric(fab)
	light := fab == "#efe6d2" || fab == "#f0e8d6" || fab == "#e9dfc8"
	thr := []string{faRed, faGold, faGreen, faWhite}
	if light {
		thr = []string{faRed, faBlack, faGreen, faGold}
	}
	switch style {
	case 0: // borders with gul row
		for _, yb := range []float64{H * .3, H * .74} {
			c.zigzag(yb-34, 6, 16, 4, thr[1], thr[3])
			c.zigzag(yb+34, 6, 16, 4, thr[1], thr[3])
			c.running(fp("M-5 %vH%v", yb-24, W+5), thr[3])
			c.running(fp("M-5 %vH%v", yb+24, W+5), thr[3])
			var dm []faPt
			for x := W/2 - 72*math.Floor(W/144+.5); x < W+30; x += 72 {
				c.gul(x, yb, 19, thr[0], shade(thr[0], -.35), thr[1], thr[3], false)
				dm = append(dm, faP(x+36, yb), faP(x-36, yb))
			}
			c.diamonds(dm, 6, thr[2], thr[1])
		}
		c.crossField(0, H*.44, W, H*.16, 16, thr[1])
	case 1: // central gul with ram's horns
		c.sawRow(H*.06, 12, thr[1], false)
		c.sawRow(H*.94, 12, thr[1], true)
		c.gul(W/2, H/2, math.Min(W, H)*.24, thr[0], shade(thr[0], -.35), thr[1], thr[3], true)
		r := math.Min(W, H) * .24
		for _, d := range []faPt{{-1, -1}, {1, -1}, {-1, 1}, {1, 1}} {
			c.horns(W/2+d.X*r*1.25, H/2+d.Y*r*1.25+12, 20, thr[1], 3)
			c.diamond(W/2+d.X*r*1.6, H/2+d.Y*r*1.75, 7, thr[2], thr[3])
		}
	case 2: // rows of goçak curls
		rows := int(H / 62)
		for r := 0; r < rows; r++ {
			y := H*.08 + float64(r)*62 + 46
			col := thr[r%3]
			off := 0.0
			if r%2 == 1 {
				off = 30
			}
			var hb strings.Builder
			for x := -30 + off; x < W+30; x += 60 {
				hb.WriteString(faHornPath(x, y, 22))
			}
			c.chain(hb.String(), col, 2.6)
			c.running(fp("M-5 %vH%v", y+10, W+5), thr[3])
		}
	case 3: // ýylan yz zigzag bands
		cols := []string{thr[0], thr[2], thr[1], thr[0], thr[2], thr[1]}
		n := int(H/56) + 1
		for i := 0; i < n; i++ {
			y := 26 + float64(i)*56
			c.zigzag(y, 12, 30, 7, cols[i%len(cols)], thr[3])
			var lo, hi []faPt
			for x := 0.0; x < W+30; x += 30 {
				lo = append(lo, faP(x+7.5, y+16))
				hi = append(hi, faP(x+22.5, y-16))
			}
			c.diamonds(lo, 3.2, cols[(i+1)%len(cols)], "")
			c.diamonds(hi, 3.2, cols[(i+2)%len(cols)], "")
		}
	case 4: // cross-stitch lattice
		c.crossPattern(thr[0], thr[1])
	case 5: // curved yaka border + needle
		cx := W * .5
		pts := faSampleQ(faP(-20, H*.12), faP(cx, H*1.15), faP(W+20, H*.12), 30)
		c.path(faBand(pts, 46, 46), c.lin(0, 0, 0, 1, shade(thr[0], -.1), shade(thr[0], -.4)), faOp(.9))
		c.chain(faSmooth(faOffset(pts, 23), false), thr[1], 2.6)
		c.chain(faSmooth(faOffset(pts, -23), false), thr[1], 2.6)
		for i := 2; i < len(pts)-1; i += 3 {
			c.diamond(pts[i].X, pts[i].Y, 9, thr[1], thr[3])
		}
		c.zigzag(H*.82, 7, 18, 4, thr[1], thr[3])
		c.needle(W*.62, H*.58, W*.9, H*.44, thr[1], W*.5, H*.62)
	case 6: // rhombus lattice with border
		c.lattice(46, thr[1], thr[0])
		c.rect(0, 0, W*.2, H, 0, shade(fab, -.25), faOp(.85))
		c.zigzag(0, 0, 1, 0, thr[1], thr[1])
		var bp []faPt
		for y := 12.0; y < H; y += 26 {
			bp = append(bp, faP(W*.1, y))
		}
		c.diamonds(bp, 8, thr[0], thr[1])
		c.running(fp("M%v -5V%v", W*.2, H+5), thr[1])
	default: // embroidery hoop with gul in progress
		c.hoop(W/2, H/2, math.Min(W, H)*.42, thr)
	}
	c.rect(0, 0, W, H, 0, c.rad(.5, .5, .75, "#000000/0@0.6", "#000000/0.28"))
}

func (c *faCanvas) fabric(col string) {
	c.rect(0, 0, c.w, c.h, 0, c.lin(0, 0, 1, 1, shade(col, .12), col, shade(col, -.18)))
	var b strings.Builder
	for y := 2.0; y < c.h; y += 4 {
		b.WriteString(fp("M0 %vH%v", y, c.w))
	}
	c.stroke(b.String(), "#ffffff", .5, faOp(.06))
	b.Reset()
	for x := 2.0; x < c.w; x += 4 {
		b.WriteString(fp("M%v 0V%v", x, c.h))
	}
	c.stroke(b.String(), "#000000", .5, faOp(.07))
	c.glow(c.w*.3, c.h*.25, c.w*.7, c.h*.5, "#ffffff", .14)
}

// satin fills a shape with a thread sheen and parallel stitch lines at angle.
func (c *faCanvas) satin(d, col string, ang, x, y, r float64) {
	c.path(d, c.lin(0, 0, 1, 1, shade(col, .28), col, shade(col, -.28)))
	if r < 22 {
		return
	}
	a := (ang + 90) * math.Pi / 180
	c.p(`<path d="M%v %vL%v %v" stroke="%v" stroke-width="%v" stroke-dasharray=".7 1.1" opacity=".35" %v/>`,
		x-math.Cos(a)*r, y-math.Sin(a)*r, x+math.Cos(a)*r, y+math.Sin(a)*r, shade(col, -.5), r*2, c.clip(d))
}

func (c *faCanvas) chain(d, col string, w float64) {
	c.stroke(d, shade(col, -.45), w+.8, `stroke-dasharray="`+faNum2(w*1.2)+` `+faNum2(w*1.1)+`"`, faOp(.5))
	c.stroke(d, col, w, `stroke-dasharray="`+faNum2(w*1.2)+` `+faNum2(w*1.1)+`"`)
	c.stroke(d, shade(col, .45), w*.35, `stroke-dasharray="`+faNum2(w*1.2)+` `+faNum2(w*1.1)+`"`, faOp(.7))
}

func (c *faCanvas) running(d, col string) {
	c.p(`<path d="%v" fill="none" stroke="%v" stroke-width="1.3" stroke-dasharray="3.5 2.5"/>`, d, col)
}

func (c *faCanvas) diamond(x, y, r float64, col, inner string) {
	d := fp("M%v %vL%v %vL%v %vL%v %vZ", x, y-r, x+r, y, x, y+r, x-r, y)
	c.satin(d, col, 45, x, y, r)
	if inner != "" {
		c.path(fp("M%v %vL%v %vL%v %vL%v %vZ", x, y-r*.4, x+r*.4, y, x, y+r*.4, x-r*.4, y), inner)
	}
}

// diamonds draws many small satin diamonds as one path.
func (c *faCanvas) diamonds(pts []faPt, r float64, col, inner string) {
	var b, in strings.Builder
	for _, p := range pts {
		b.WriteString(fp("M%v %vl%v %vl%v %vl%v %vZ", p.X, p.Y-r, r, r, -r, r, -r, -r))
		if inner != "" {
			q := r * .4
			in.WriteString(fp("M%v %vl%v %vl%v %vl%v %vZ", p.X, p.Y-q, q, q, -q, q, -q, -q))
		}
	}
	c.path(b.String(), shade(col, -.5), faOp(.45), `transform="translate(.6 .8)"`)
	c.path(b.String(), col)
	if inner != "" {
		c.path(in.String(), inner)
	}
}

func (c *faCanvas) gul(x, y, r float64, a, b, d, e string, big bool) {
	ri := r * math.Cos(math.Pi/8)
	for k := 0; k < 4; k++ {
		a0 := float64(k) * math.Pi / 2
		pts := []faPt{{x, y}, {x + ri*math.Cos(a0), y + ri*math.Sin(a0)}}
		for _, da := range []float64{math.Pi / 8, 3 * math.Pi / 8} {
			pts = append(pts, faP(x+r*math.Cos(a0+da), y+r*math.Sin(a0+da)))
		}
		pts = append(pts, faP(x+ri*math.Cos(a0+math.Pi/2), y+ri*math.Sin(a0+math.Pi/2)))
		var qd strings.Builder
		for i, p := range pts {
			if i == 0 {
				qd.WriteString(fp("M%v", p))
			} else {
				qd.WriteString(fp("L%v", p))
			}
		}
		qd.WriteString("Z")
		col := a
		if k%2 == 1 {
			col = b
		}
		c.satin(qd.String(), col, float64(k)*90+45, x, y, r)
		m := faP(x+r*.62*math.Cos(a0+math.Pi/4), y+r*.62*math.Sin(a0+math.Pi/4))
		c.path(faPoly(m.X, m.Y, r*.14, 4, 0), e)
	}
	oct := faPoly(x, y, r, 8, math.Pi/8)
	c.chain(oct, d, math.Max(1.4, r*.07))
	c.satin(faPoly(x, y, r*.38, 8, math.Pi/8), d, 0, x, y, r*.38)
	c.satin(faPoly(x, y, r*.2, 4, 0), e, 45, x, y, r*.2)
	if big {
		for k := 0; k < 4; k++ {
			a0 := float64(k)*math.Pi/2 + math.Pi/4
			px, py := x+r*1.08*math.Cos(a0), y+r*1.08*math.Sin(a0)
			c.p(`<g transform="translate(%v %v) rotate(%v)">`, px, py, float64(k)*90+135)
			c.horns(0, 0, r*.3, d, math.Max(1.6, r*.06))
			c.end()
		}
	}
}

// horns draws a goçak (ram's horn) motif: a stem splitting into two curls.
func (c *faCanvas) horns(x, y, s float64, col string, w float64) {
	c.chain(faHornPath(x, y, s), col, w)
}

func faHornPath(x, y, s float64) string {
	y0 := y - s*.3
	r1, r2, r3 := s*.42, s*.28, s*.16
	return fp("M%v %vV%vM%v %va%v %v 0 0 1 %v 0a%v %v 0 0 1 %v 0a%v %v 0 0 1 %v 0M%v %va%v %v 0 0 0 %v 0a%v %v 0 0 0 %v 0a%v %v 0 0 0 %v 0",
		x, y+s*.5, y0, x, y0, r1, r1, 2*r1, r2, r2, -2*r2, r3, r3, 2*r3,
		x, y0, r1, r1, -2*r1, r2, r2, 2*r2, r3, r3, -2*r3)
}

func (c *faCanvas) zigzag(y, amp, period, w float64, col, inner string) {
	if amp == 0 {
		return
	}
	var b strings.Builder
	b.WriteString(fp("M%v %v", -period, y))
	up := true
	for x := -period / 2; x < c.w+period; x += period / 2 {
		dy := amp
		if up {
			dy = -amp
		}
		up = !up
		b.WriteString(fp("L%v %v", x, y+dy))
	}
	d := b.String()
	c.stroke(d, shade(col, -.5), w+1.6, faOp(.45))
	c.stroke(d, col, w)
	if inner != col {
		c.stroke(d, inner, .9, `stroke-dasharray="1.5 2.5"`, fp(`transform="translate(0 %v)"`, w*.9+2))
	}
}

func (c *faCanvas) sawRow(y, size float64, col string, flip bool) {
	var b strings.Builder
	dir := 1.0
	if flip {
		dir = -1
	}
	for x := 0.0; x < c.w+size; x += size {
		b.WriteString(fp("M%v %vL%v %vL%v %vZ", x, y-dir*size*.5, x+size/2, y+dir*size*.5, x+size, y-dir*size*.5))
	}
	c.path(b.String(), c.lin(0, 0, 0, 1, shade(col, .3), col, shade(col, -.3)))
	c.running(fp("M-5 %vH%v", y+dir*size*.9, c.w+5), col)
}

func (c *faCanvas) crossField(x0, y0, w, h, step float64, col string) {
	var b strings.Builder
	for y := y0 + step/2; y < y0+h; y += step {
		for x := x0 + step/2; x < x0+w; x += step {
			if int((x+y)/step)%2 == 0 {
				b.WriteString(fp("M%v %vl3 3m-3 0l3 -3", x-1.5, y-1.5))
			}
		}
	}
	c.stroke(b.String(), col, 1.1, faOp(.85))
}

func (c *faCanvas) crossPattern(a, b string) {
	st := 8.0
	var pa, pb strings.Builder
	nx, ny := int(c.w/st), int(c.h/st)
	for j := 0; j < ny; j++ {
		for i := 0; i < nx; i++ {
			u, v := i%16, j%16
			du, dv := u-8, v-8
			if du < 0 {
				du = -du
			}
			if dv < 0 {
				dv = -dv
			}
			m := du + dv
			var w *strings.Builder
			switch {
			case m == 7 || m == 3:
				w = &pa
			case m == 0 || (m == 5 && (u == 8 || v == 8)):
				w = &pb
			case (u == 0 || v == 0) && (i+j)%2 == 0:
				w = &pb
			}
			if w != nil {
				w.WriteString(fp("M%v %vl5 5m-5 0l5-5", i*8+1, j*8+1))
			}
		}
	}
	c.stroke(pa.String(), a, 1.9)
	c.stroke(pa.String(), shade(a, .4), .6, faOp(.5))
	c.stroke(pb.String(), b, 1.9)
}

func (c *faCanvas) lattice(step float64, col, dot string) {
	var b strings.Builder
	for x := -c.h; x < c.w+c.h; x += step {
		b.WriteString(fp("M%v 0L%v %vM%v 0L%v %v", x, x+c.h, c.h, x, x-c.h, c.h))
	}
	d := b.String()
	c.stroke(d, shade(col, -.5), 4.2, faOp(.4))
	c.p(`<path d="%v" fill="none" stroke="%v" stroke-width="3" stroke-dasharray="2.6 1.4"/>`, d, col)
	var pts []faPt
	for y := 0.0; y < c.h+step; y += step / 2 {
		off := 0.0
		if int(math.Round(y/(step/2)))%2 == 1 {
			off = step / 2
		}
		for x := off; x < c.w+step; x += step {
			pts = append(pts, faP(x, y+step/2))
		}
	}
	c.diamonds(pts, 6, dot, faGold)
}

func (c *faCanvas) needle(x1, y1, x2, y2 float64, thread string, tx, ty float64) {
	c.stroke(fp("M%v %vC%v %v %v %v %v %v", x2, y2, x2+30, y2+40, tx+10, ty+30, tx, ty), thread, 1.5)
	c.stroke(fp("M%v %vL%v %v", x1+3, y1+4, x2+3, y2+4), "#000000", 2.6, faOp(.25))
	c.stroke(fp("M%v %vL%v %v", x1, y1, x2, y2), c.linU(x1, y1, x2, y2, c.metal("silver")...), 2.6)
	c.p(`<ellipse cx="%v" cy="%v" rx="2.4" ry=".8" fill="#3a3a3a" transform="rotate(%v %v %v)"/>`,
		x2-(x2-x1)*.06, y2-(y2-y1)*.06, math.Atan2(y2-y1, x2-x1)*180/math.Pi, x2-(x2-x1)*.06, y2-(y2-y1)*.06)
}

func (c *faCanvas) hoop(x, y, r float64, thr []string) {
	inner := faPoly(x, y, r-6, 48, 0)
	c.circ(x+6, y+8, r+10, "#3d2a20", faOp(.18))
	c.path(inner, "#20473a")
	cl := c.clip(inner)
	c.p(`<g %v>`, cl)
	var b strings.Builder
	for yy := y - r; yy < y+r; yy += 3.5 {
		b.WriteString(fp("M%v %vH%v", x-r, yy, x+r))
	}
	c.stroke(b.String(), "#ffffff", .5, faOp(.06))
	c.gul(x, y, r*.42, faRed, shade(faRed, -.35), faGold, faWhite, true)
	c.running(faPoly(x, y, r*.78, 8, math.Pi/8), faGold)
	c.end()
	c.circ(x, y, r, "none", fp(`stroke="%v" stroke-width="12"`, c.lin(0, 0, 1, 1, "#e6c08e", "#c29563", "#8f6538")))
	c.circ(x, y, r-6, "none", `stroke="#6b4a2a" stroke-width="1" stroke-opacity=".5"`)
	c.circ(x, y, r+6, "none", `stroke="#6b4a2a" stroke-width="1" stroke-opacity=".5"`)
	c.rect(x-9, y-r-14, 18, 16, 3, c.metalH("silver"))
	c.rect(x-3, y-r-24, 6, 12, 2, c.metalH("silver"))
	c.needle(x+r*.5, y+r*.1, x+r*.9, y-r*.35, faGold, x+r*.25, y+r*.18)
}

// ---------------------------------------------------------------- yaka (necklines)

func faCollar(c *faCanvas, style, pal int) {
	walls := []string{"#efe4d8", "#e8e1ea", "#e6ebe4", "#f1e6e4", "#ebe5dc", "#e4e8ee", "#f0e8de", "#ece4e8"}
	fabrics := []string{"#1f5e4a", "#8a2440", "#efe4d4", "#2d3f6b", "#c46a72", "#5b3a6e", "#b88a4a", "#2b2b33"}
	k := (style + pal*3) % 8
	wall, fab := walls[(style+pal)%8], fabrics[k]
	c.salon(wall, []float64{.8, .2, .75, .25, .8, .2, .7, .3}[style])
	c.fit(300, 400, .5, 1)
	form := "#e9d6c4"
	// dress form neck and torso
	c.rect(130, -10, 40, 92, 5, c.lin(0, 0, 1, 0, "#2c221e", "#4a3b34", "#2c221e"))
	c.path("M108 76Q150 64 192 76C232 82 262 96 272 120V410H28V120C38 96 68 82 108 76Z", c.lin(0, 0, 1, 1, shade(form, .1), form, shade(form, -.15)))
	nl, nr := faP(112, 92), faP(188, 92)
	var neck string
	switch style {
	case 0, 6, 7:
		neck = "Q150 128 188 92"
	case 1:
		neck = "L150 196L188 92"
	case 2:
		neck = "Q150 108 188 92"
	case 3:
		neck = "L112 156H188V92"
	case 4:
		neck = "C110 122 102 150 118 162Q138 172 150 150Q162 172 182 162C198 150 190 122 188 92"
	case 5:
		nl, nr = faP(80, 100), faP(220, 100)
		neck = "Q150 130 220 100"
	}
	bodice := fp("M%v", nl) + neck + fp("C%v %v 246 106 260 118C276 160 270 220 250 262C238 300 232 350 236 410H64C68 350 62 300 50 262C30 220 24 160 40 118C54 106 %v %v %vZ", nr.X+32, nr.Y+4, nl.X-32, nl.Y+4, nl)
	fg := c.lin(0, 0, 1, 1, shade(fab, .2), fab+"@0.5", shade(fab, -.32))
	// sleeves
	switch style {
	case 0, 1, 2, 6:
		for _, sd := range []float64{1, -1} {
			c.p(`<g transform="translate(150 0) scale(%v 1) translate(-150 0)">`, sd)
			c.path("M46 112C20 124 10 172 8 232L4 410H56L62 240C60 190 58 150 46 112Z", fg)
			c.glow(30, 220, 12, 90, "#000000", .12)
			c.end()
		}
	case 5:
		for _, sd := range []float64{1, -1} {
			c.p(`<g transform="translate(150 0) scale(%v 1) translate(-150 0)">`, sd)
			c.path("M50 106C22 112 6 150 12 186C30 180 46 176 62 172Z", fg)
			c.end()
		}
	}
	c.path(bodice, fg)
	bcl := c.clip(bodice)
	c.stroke("M100 104C104 180 96 260 100 410M200 104C196 180 204 260 200 410", shade(fab, -.4), 1.4, faOp(.3), bcl)
	c.glow(110, 190, 70, 120, "#ffffff", .16)
	switch style {
	case 0: // round neck, Turkmen yaka band and front slit
		pts := faSampleQ(nl, faP(150, 128), nr, 16)
		c.yakaBand(faOffset(pts, 7), 14, "#7a1424", faGold, faRed, bcl)
		c.path("M147 108L150 200L153 108Z", form)
		for _, sd := range []float64{-1, 1} {
			c.yakaBand([]faPt{{150 + sd*10, 110}, {150 + sd*10, 155}, {150 + sd*10, 200}}, 13, "#7a1424", faGold, faRed, "")
		}
		c.tasselTie(150, 112)
	case 1: // V with keşde trim
		for _, leg := range [][2]faPt{{nl, faP(150, 196)}, {faP(150, 196), nr}} {
			a, b := leg[0], leg[1]
			pts := []faPt{a, faLerp(a, b, .5), b}
			off := 6.0
			c.yakaBand(faOffset(pts, off), 11, shade(fab, -.45), faGold, "#e8e1d0", bcl)
		}
	case 2: // high stand collar with buttons
		c.path("M116 50Q150 60 184 50L188 94Q150 106 112 94Z", c.lin(0, 0, 1, 0, shade(fab, -.25), shade(fab, .2), shade(fab, -.3)))
		c.stroke("M114 64Q150 74 186 64M114 82Q150 92 186 82", faGold, 2)
		c.stroke("M114 73Q150 83 186 73", faRed, 3, `stroke-dasharray="3 2"`)
		c.stroke("M150 60V100", shade(fab, -.5), 1.2)
		c.stroke("M150 102V410", shade(fab, -.45), 1.4, faOp(.5))
		for y := 120.0; y < 400; y += 34 {
			c.circ(150, y, 5, c.rad(.35, .3, .7, "#fffaf0", "#e9dfcf", "#a99c88"))
		}
	case 3: // square neck with lace
		c.lace([]faPt{{112, 92}, {112, 156}, {188, 156}, {188, 92}})
	case 4: // sweetheart, satin sheen
		c.glow(124, 196, 26, 70, "#ffffff", .3)
		c.glow(178, 196, 20, 60, "#ffffff", .2)
		var b strings.Builder
		for _, x := range []float64{116, 134, 166, 184} {
			b.WriteString(fp("M%v 172Q%v 260 %v 410", x, x+(x-150)*.3, x+(x-150)*.5))
		}
		c.stroke(b.String(), shade(fab, -.4), 3, faOp(.12), bcl)
		c.stroke(b.String(), "#ffffff", 1.5, faOp(.15), bcl, `transform="translate(3 0)"`)
		c.circ(150, 160, 6, c.rad(.35, .3, .7, "#ffffff", "#f3eadf", "#b9ad9f"))
		c.glint(146, 156, 5, .8)
	case 5: // boat neck with dots
		for i := 0; i < 70; i++ {
			c.circ(c.rr(20, 280), c.rr(100, 400), 2.6, "#f6f1e8", faOp(.85), bcl)
		}
		c.stroke(fp("M%v", nl)+neck, shade(fab, -.4), 3.5)
	case 6: // keyhole with embroidery
		pts := faSampleQ(nl, faP(150, 128), nr, 16)
		c.yakaBand(faOffset(pts, 6), 11, shade(fab, -.4), faGold, faRed, bcl)
		key := "M150 112C136 124 134 150 150 166C166 150 164 124 150 112Z"
		c.path(key, form)
		c.stroke(key, faGold, 3)
		c.stroke(key, faRed, 1.4, `stroke-dasharray="2 2"`, `transform="translate(150 140) scale(1.18) translate(-150 -140)"`)
		c.circ(150, 108, 4.5, c.metalD("gold"))
	case 7: // Peter Pan collar with bow
		for _, sd := range []float64{1, -1} {
			c.p(`<g transform="translate(150 0) scale(%v 1) translate(-150 0)">`, sd)
			cd := "M112 90C94 96 84 114 90 132C96 148 128 150 149 128Q132 116 112 90Z"
			c.path(cd, "#000000", faOp(.15), `transform="translate(1 4)"`)
			c.path(cd, c.lin(0, 0, 1, 1, "#ffffff", "#f3eee6", "#d9d0c4"))
			c.stroke("M100 104C94 116 98 136 120 138", "#c9bfb2", 1, `stroke-dasharray="2.5 2"`)
			c.end()
		}
		c.bow(150, 130, 0, .7, "#b3202a")
	}
	c.end()
}

func (c *faCanvas) yakaBand(pts []faPt, w float64, bg, gold, motif, clip string) {
	band := faBand(pts, w, w)
	c.path(band, c.lin(0, 0, 1, 1, shade(bg, .15), bg, shade(bg, -.25)), clip)
	for _, side := range []float64{-w / 2, w / 2} {
		c.stroke(faSmooth(faOffset(pts, side), false), gold, 1.6, clip)
	}
	// motifs evenly along the band
	total := 0.0
	for i := 1; i < len(pts); i++ {
		total += pts[i].sub(pts[i-1]).len()
	}
	step := w * 1.2
	acc, next := 0.0, step/2
	k := 0
	for i := 1; i < len(pts); i++ {
		seg := pts[i].sub(pts[i-1]).len()
		for next <= acc+seg {
			p := faLerp(pts[i-1], pts[i], (next-acc)/seg)
			col := motif
			if k%2 == 1 {
				col = gold
			}
			c.path(faPoly(p.X, p.Y, w*.32, 4, 0), col, clip)
			if k%2 == 0 {
				c.circ(p.X, p.Y, w*.08, gold)
			}
			next += step
			k++
		}
		acc += seg
	}
}

func (c *faCanvas) tasselTie(x, y float64) {
	c.circ(x, y, 3.5, c.metalD("gold"))
	c.stroke(fp("M%v %vQ%v %v %v %v", x, y, x-6, y+20, x-4, y+40), faRed, 1.4)
	c.stroke(fp("M%v %vQ%v %v %v %v", x, y, x+6, y+20, x+5, y+42), faRed, 1.4)
	c.tassel(faP(x-4, y+40), 6, faRed, "gold")
}

func (c *faCanvas) lace(pts []faPt) {
	var b, holes strings.Builder
	for i := 1; i < len(pts); i++ {
		a, z := pts[i-1], pts[i]
		seg := z.sub(a)
		n := int(seg.len() / 9)
		dir := seg.unit()
		nrm := faP(dir.Y, -dir.X)
		if i == 2 {
			nrm = faP(-dir.Y, dir.X)
		}
		for k := 0; k <= n; k++ {
			p := a.add(dir.mul(float64(k) * seg.len() / float64(max(1, n))))
			q := p.add(nrm.mul(-7))
			b.WriteString(fp("M%v %va5 5 0 1 0 10 0a5 5 0 1 0 -10 0", q.X-5, q.Y))
			holes.WriteString(fp("M%v %vh.1", q.X, q.Y))
		}
	}
	c.path(b.String(), "#fbf7ef", faOp(.95))
	c.stroke(holes.String(), "#d9cdbb", 2.6)
	var edge strings.Builder
	for i, p := range pts {
		if i == 0 {
			edge.WriteString(fp("M%v", p))
		} else {
			edge.WriteString(fp("L%v", p))
		}
	}
	c.stroke(edge.String(), "#fbf7ef", 4)
	c.stroke(edge.String(), "#d9cdbb", 1, `stroke-dasharray="1.5 2"`)
}

// ---------------------------------------------------------------- aksessuar

type faItem struct {
	kind     string
	x, y     float64 // fractions of the canvas
	rot, sc  float64
	col, acc string
}

func faAccessories(c *faCanvas, style, pal int) {
	bgs := [][2]string{{"#f6efe6", "#eadccb"}, {"#f7e9ea", "#ecd2d5"}, {"#eef0ea", "#d9dfd2"}, {"#f1ecf5", "#dcd2e6"}, {"#f8f1e2", "#ead9b8"}, {"#e9eef1", "#d0dbe2"}, {"#f4ece8", "#e3d2c9"}, {"#efe9e2", "#d9cdbf"}}
	bg := bgs[(style+pal*3)%8]
	sets := [][]faItem{
		{{"tote", .4, .44, -6, 1.1, "#c08a5a", "#7a4a2a"}, {"sunglasses", .72, .16, 14, .75, "#2a2220", "#5a4a40"}, {"scarf", .76, .78, 18, .8, "#b3202a", "#f3d98b"}},
		{{"clutch", .46, .32, -8, 1.05, "#e6b8b8", "#d4a74a"}, {"heels", .52, .72, -4, 1.0, "#b3202a", "#7a1424"}, {"sunglasses", .2, .88, -20, .55, "#c08a5a", "#3a2a20"}},
		{{"flapbag", .44, .4, 6, 1.1, "#2a2a30", "#d4a74a"}, {"belt", .54, .82, -6, .95, "#7a4a2a", "#d4a74a"}, {"sunglasses", .82, .14, 24, .6, "#c46a72", "#4a2a30"}},
		{{"heels", .5, .38, 8, 1.25, "#efe2d0", "#c9a46a"}, {"clutch", .5, .78, -6, .85, "#1f5e4a", "#d4a74a"}},
		{{"scarf", .34, .3, -10, 1.15, "#2d3f6b", "#e8c77a"}, {"topbag", .6, .66, 6, 1.05, "#8a2440", "#d4a74a"}},
		{{"belt", .36, .76, 10, 1.0, "#1f1a18", "#c9c9c9"}, {"sunglasses", .58, .2, -8, .85, "#3a2a20", "#2a3a3a"}, {"clutch", .7, .56, 12, .8, "#c9a46a", "#f3e4c4"}},
		{{"bucket", .38, .4, -4, 1.1, "#5b3a6e", "#d4a74a"}, {"heels", .6, .8, -10, .85, "#2a2a30", "#5b3a6e"}, {"scarf", .84, .16, 30, .6, "#efe2d0", "#5b3a6e"}},
		{{"tote", .58, .5, 8, 1.05, "#1f5e4a", "#d4a74a"}, {"sunglasses", .26, .2, -12, .7, "#7a1424", "#3a2a20"}, {"belt", .3, .84, 0, .8, "#c08a5a", "#d4a74a"}},
	}
	c.backdrop(bg[0], bg[1])
	c.confetti(6, []string{shade(bg[1], -.1)}, 2, 5)
	items := sets[style]
	s := math.Min(c.w, c.h) / 300
	for _, it := range items {
		col := it.col
		if pal > 0 {
			col = faMix(col, []string{"#c08a5a", "#8a2440", "#2d3f6b", "#1f5e4a"}[pal%4], .55)
		}
		c.item(it.kind, c.w*it.x, c.h*it.y, it.rot, it.sc*s, col, it.acc)
	}
}

func (c *faCanvas) item(kind string, x, y, rot, s float64, col, acc string) {
	c.g(x, y, rot, s)
	body := c.lin(0, 0, 1, 1, shade(col, .2), col, shade(col, -.3))
	dark := shade(col, -.45)
	switch kind {
	case "tote":
		d := "M-52 -30H52L60 50Q60 58 52 58H-52Q-60 58 -60 50Z"
		c.drop(d, 6, 9)
		c.stroke("M-30 -28C-30 -78 30 -78 30 -28", dark, 6)
		c.stroke("M-30 -28C-30 -78 30 -78 30 -28", shade(col, .2), 1.5, faOp(.5), `transform="translate(-1 -1)"`)
		c.path(d, body)
		c.p(`<path d="M-48 -24H48L55 46Q55 52 49 52H-49Q-55 52 -55 46Z" fill="none" stroke="%v" stroke-width="1" stroke-dasharray="3 2.5" opacity=".6"/>`, shade(col, .45))
		c.rect(-14, -26, 28, 12, 3, c.metalH("gold"))
		c.glow(-24, -4, 30, 26, "#ffffff", .22)
	case "flapbag":
		d := "M-50 -34H50Q56 -34 56 -28V30Q56 38 48 38H-48Q-56 38 -56 30V-28Q-56 -34 -50 -34Z"
		c.stroke("M-46 -30C-60 -90 60 -90 46 -30", c.metal("gold")[1], 3, `stroke-dasharray="4 2"`)
		c.drop(d, 6, 9)
		c.path(d, body)
		c.path("M-56 -28Q-56 -34 -50 -34H50Q56 -34 56 -28V6Q0 28 -56 6Z", c.lin(0, 0, 0, 1, shade(col, .1), shade(col, -.2)))
		var q strings.Builder
		for x := -48.0; x <= 48; x += 12 {
			q.WriteString(fp("M%v -34L%v 10", x, x+18))
		}
		c.stroke(q.String(), shade(col, .3), .8, faOp(.3), c.clip("M-56 -34H56V6Q0 28 -56 6Z"))
		c.rect(-9, 6, 18, 14, 4, c.metalD("gold"))
		c.rect(-4, 10, 8, 6, 2, shade(col, -.2))
		c.glow(-24, -14, 28, 18, "#ffffff", .2)
	case "clutch":
		d := "M-58 -30H58Q62 -30 62 -26V26Q62 30 58 30H-58Q-62 30 -62 26V-26Q-62 -30 -58 -30Z"
		c.drop(d, 6, 8)
		c.path(d, body)
		c.path("M-62 -26Q-62 -30 -58 -30H58Q62 -30 62 -26L0 12Z", c.lin(0, 0, 0, 1, shade(col, .15), shade(col, -.15)))
		c.stroke("M-60 -26L0 12L60 -26", dark, 1, faOp(.4))
		c.circ(0, 10, 6, c.metalD("gold"))
		c.circ(0, 10, 2.6, "#c8102e")
		c.glow(-30, -8, 26, 14, "#ffffff", .25)
	case "topbag":
		d := "M-46 -26H46L54 40Q54 46 48 46H-48Q-54 46 -54 40Z"
		c.stroke("M-22 -26C-22 -60 22 -60 22 -26", dark, 5)
		c.drop(d, 6, 9)
		c.path(d, body)
		c.stroke("M-50 -6H50", dark, 1, faOp(.4))
		c.rect(-12, -12, 24, 12, 3, c.metalD("gold"))
		c.circ(-22, -26, 3, c.metalD("gold"))
		c.circ(22, -26, 3, c.metalD("gold"))
		c.glow(-22, 8, 26, 20, "#ffffff", .2)
	case "bucket":
		d := "M-40 -40Q0 -48 40 -40L48 44Q0 58 -48 44Z"
		c.stroke("M-38 -38C-50 -100 50 -100 38 -38", dark, 3)
		c.drop(d, 6, 9)
		c.path(d, body)
		c.ell(0, -40, 40, 7, shade(col, -.4))
		c.stroke("M-38 -32Q0 -24 38 -32", acc, 2)
		c.stroke("M10 -28L16 6M14 -28L24 2", acc, 1.6)
		c.circ(16, 8, 3, c.metalD("gold"))
		c.circ(24, 4, 3, c.metalD("gold"))
		c.glow(-18, 0, 20, 30, "#ffffff", .2)
	case "heels":
		for _, off := range []float64{1, 0} {
			c.g(off*22, off*18, 0, 1)
			shoe := "M-58 -32Q-57 -16 -54 -12L-44 -10Q-12 2 20 28Q30 38 46 40H60Q70 40 68 33Q62 22 40 18Q18 14 4 4Q-30 -6 -46 -26Q-52 -32 -58 -32Z"
			heel := "M-55 -13L-43 -10L-47 40H-51Z"
			c.drop(shoe+heel, 5, 7)
			c.path(heel, c.lin(0, 0, 1, 0, shade(col, -.4), shade(col, -.1)))
			c.rect(-52, 38, 6, 3, 1, "#2a2220")
			c.path(shoe, body)
			c.path("M4 4Q-30 -6 -46 -26Q-50 -14 -42 -10Q-12 0 4 4Z", shade(col, -.5), faOp(.8))
			c.stroke("M-44 -10Q-12 2 20 28Q30 38 46 40H60", dark, 1.6, faOp(.5))
			c.glow(30, 26, 20, 6, "#ffffff", .35)
			c.end()
		}
	case "sunglasses":
		c.stroke("M-64 -14L52 0M64 -14L-52 0", col, 3)
		lens := "M-64 -18Q-62 -26 -50 -26H-14Q-6 -26 -6 -16Q-6 10 -30 14Q-56 16 -64 -6Z"
		for _, sd := range []float64{1, -1} {
			c.p(`<g transform="scale(%v 1)">`, sd)
			c.drop(lens, 4, 6)
			c.path(lens, c.lin(0, 0, 1, 1, shade(acc, .25), acc, shade(acc, -.4)))
			c.path("M-56 -20L-40 -20L-56 4Z", "#ffffff", faOp(.18))
			c.path(lens, "none", `stroke="`+col+`" stroke-width="3.2"`)
			c.end()
		}
		c.stroke("M-6 -16Q0 -22 6 -16", col, 3)
	case "scarf":
		d := "M0 -62L62 0L0 62L-62 0Z"
		c.drop(d, 6, 9)
		c.path(d, body)
		c.path("M0 -50L50 0L0 50L-50 0Z", "none", `stroke="`+acc+`" stroke-width="3"`)
		c.path("M0 -42L42 0L0 42L-42 0Z", "none", `stroke="`+acc+`" stroke-width="1" stroke-dasharray="2 2"`)
		c.path(faPoly(0, 0, 16, 8, math.Pi/8), acc)
		c.path(faPoly(0, 0, 8, 4, 0), col)
		for _, p := range []faPt{{0, -30}, {30, 0}, {0, 30}, {-30, 0}} {
			c.circ(p.X, p.Y, 3, acc)
		}
		c.path("M62 0C70 20 60 40 76 60L66 64C52 44 58 22 50 4Z", body)
		c.glow(-16, -16, 30, 18, "#ffffff", .25)
		c.stroke("M-60 4L-4 60M4 -60L60 -4", "#ffffff", 6, faOp(.12))
	case "belt":
		pts := faSampleQ(faP(-80, 20), faP(0, -50), faP(90, 10), 14)
		band := faBand(pts, 14, 14)
		c.drop(band, 4, 6)
		c.path(band, body)
		c.stroke(faSmooth(faOffset(pts, 4.5), false), shade(col, .35), .8, `stroke-dasharray="2.5 2"`, faOp(.7))
		c.stroke(faSmooth(faOffset(pts, -4.5), false), shade(col, .35), .8, `stroke-dasharray="2.5 2"`, faOp(.7))
		for i := 10; i < 14; i++ {
			c.circ(pts[i].X, pts[i].Y, 1.6, dark)
		}
		c.rect(-92, 8, 22, 26, 5, "none", `stroke="`+c.metalD("gold")+`" stroke-width="4"`)
		c.stroke("M-81 21H-66", c.metal("gold")[1], 2)
	}
	c.end()
}

// ---------------------------------------------------------------- gundelik (casual outfits)

func faCasual(c *faCanvas, style, pal int) {
	type look struct {
		top, bottom, shoes, bag, small string
		tc, bc, sc, gc                 string
	}
	looks := []look{
		{"tee", "jeans", "sneakers", "tote", "sunglasses", "#f6f3ee", "#5b7fa8", "#f4f1ea", "#c08a5a"},
		{"sweater", "pleated", "loafers", "flapbag", "hoops", "#efe4d2", "#8fa98a", "#6b3f26", "#3a2f2a"},
		{"shirt", "trousers", "flats", "clutch", "sunglasses", "#cfdcec", "#d9c7aa", "#e9d6c4", "#8a2440"},
		{"blouse", "aline", "heels", "bucket", "hoops", "#f2c6cf", "#2d3f6b", "#2d3f6b", "#efe2d0"},
		{"sweater", "jeans", "sneakers", "flapbag", "sunglasses", "#c86a46", "#3f5f86", "#f4f1ea", "#6b3f26"},
		{"tee", "pleated", "loafers", "tote", "hoops", "#262528", "#8a2440", "#2a2220", "#c9a46a"},
		{"shirt", "trousers", "flats", "topbag", "sunglasses", "#f7f5f0", "#6b7550", "#c9a46a", "#c46a72"},
		{"blouse", "aline", "sneakers", "clutch", "hoops", "#d9cdec", "#efe6d6", "#f4f1ea", "#5b3a6e"},
	}
	lk := looks[(style+pal*5)%8]
	bgs := [][2]string{{"#f5f1ea", "#e7ddcf"}, {"#f2efe8", "#e2dccd"}, {"#f7efec", "#eadad3"}, {"#eef1f4", "#d9e0e8"}, {"#f6f0e6", "#e8dac4"}, {"#f1eef3", "#ddd6e3"}, {"#eff2ec", "#dce3d4"}, {"#f8f2ee", "#ecdcd2"}}
	bg := bgs[(style*3+pal)%8]
	c.backdrop(bg[0], bg[1])
	W, H := c.w, c.h
	s := math.Min(W, H) / 300
	pos := [][5]float64{ // x, y, rot, scale for top, bottom, bag, shoes, small
		{.32, .26, -4, 1.05}, {.34, .67, 3, 1.0}, {.76, .28, 8, .75}, {.75, .76, -6, .72}, {.78, .52, 12, .45},
	}
	if style%2 == 1 {
		pos = [][5]float64{{.66, .26, 5, 1.05}, {.64, .68, -3, 1.0}, {.24, .3, -8, .72}, {.24, .78, 6, .72}, {.24, .54, -10, .45}}
	}
	c.garment(lk.top, W*pos[0][0], H*pos[0][1], pos[0][2], pos[0][3]*s, lk.tc)
	c.garment(lk.bottom, W*pos[1][0], H*pos[1][1], pos[1][2], pos[1][3]*s, lk.bc)
	switch lk.bag {
	case "tote", "flapbag", "clutch", "bucket", "topbag":
		c.item(lk.bag, W*pos[2][0], H*pos[2][1], pos[2][2], pos[2][3]*s, lk.gc, "#d4a74a")
	}
	c.garment(lk.shoes, W*pos[3][0], H*pos[3][1], pos[3][2], pos[3][3]*s, lk.sc)
	if lk.small == "sunglasses" {
		c.item("sunglasses", W*pos[4][0], H*pos[4][1], pos[4][2], pos[4][3]*s, "#2a2220", "#5a4a40")
	} else {
		c.g(W*pos[4][0], H*pos[4][1], 0, pos[4][3]*s)
		for _, dx := range []float64{-22, 22} {
			c.circ(dx+2, 3, 18, "none", `stroke="#3d2a20" stroke-width="5" stroke-opacity=".08"`)
			c.circ(dx, 0, 18, "none", `stroke="`+c.metalD("gold")+`" stroke-width="5"`)
		}
		c.end()
	}
}

func (c *faCanvas) garment(kind string, x, y, rot, s float64, col string) {
	c.g(x, y, rot, s)
	body := c.lin(0, 0, 1, 1, shade(col, .18), col, shade(col, -.22))
	dark := shade(col, -.35)
	if col == "#262528" || col == "#2a2220" {
		dark = shade(col, .3)
	}
	switch kind {
	case "tee":
		d := "M-22 -52Q0 -40 22 -52L52 -40L66 -8L44 0L40 -18V56Q0 60 -40 56V-18L-44 0L-66 -8L-52 -40Z"
		c.drop(d, 6, 9)
		c.path(d, body)
		c.stroke("M-22 -52Q0 -34 22 -52", dark, 3, faOp(.5))
		c.stroke("M-40 -18L-50 -38M40 -18L50 -38", dark, .8, faOp(.3))
		c.glow(-10, -10, 30, 30, "#ffffff", .2)
	case "sweater", "shirt", "blouse":
		d := "M-24 -54Q0 -42 24 -54L54 -42Q66 -30 70 0L78 54L60 58L48 4L42 -14V58Q0 62 -42 58V-14L-48 4L-60 58L-78 54L-70 0Q-66 -30 -54 -42Z"
		if kind == "blouse" {
			d = "M-24 -54Q0 -42 24 -54L56 -44Q76 -30 76 0L80 46Q70 56 60 50L48 4L42 -14V58Q0 62 -42 58V-14L-48 4L-60 50Q-70 56 -80 46L-76 0Q-76 -30 -56 -44Z"
		}
		c.drop(d, 6, 9)
		c.path(d, body)
		switch kind {
		case "sweater":
			var b strings.Builder
			for xx := -40.0; xx <= 40; xx += 4 {
				b.WriteString(fp("M%v 48V58", xx))
			}
			b.WriteString("M62 48L78 52M60 52L78 56M-62 48L-78 52M-60 52L-78 56")
			c.stroke(b.String(), dark, .8, faOp(.45))
			c.stroke("M-24 -54Q0 -38 24 -54", dark, 4, faOp(.5))
			var k strings.Builder
			for xx := -30.0; xx <= 30; xx += 10 {
				k.WriteString(fp("M%v -30V44", xx))
			}
			c.stroke(k.String(), dark, .8, faOp(.18), `stroke-dasharray="3 2"`)
		case "shirt":
			c.path("M-24 -54L-6 -32L2 -48Z", shade(col, .25))
			c.path("M24 -54L6 -32L-2 -48Z", shade(col, .1))
			c.stroke("M0 -40V58", dark, .9, faOp(.5))
			for yy := -30.0; yy < 58; yy += 16 {
				c.circ(3, yy, 1.8, dark, faOp(.6))
			}
			c.rect(-32, -18, 16, 14, 2, "none", `stroke="`+dark+`" stroke-width=".8" stroke-opacity=".4"`)
		case "blouse":
			c.stroke("M-24 -54Q0 -30 24 -54", dark, 1.5, faOp(.5))
			c.bow(0, -40, 0, .55, shade(col, -.15))
			c.stroke("M-62 44Q-70 50 -78 44M62 44Q70 50 78 44", dark, 1, faOp(.4))
		}
		c.glow(-10, -10, 32, 34, "#ffffff", .2)
	case "jeans", "trousers":
		d := "M-34 -64H34L40 70H8L0 -10L-8 70H-40Z"
		if kind == "trousers" {
			d = "M-34 -64H34L50 70H8L0 -6L-8 70H-50Z"
		}
		c.drop(d, 6, 9)
		c.path(d, body)
		c.rect(-34, -64, 68, 9, 1, shade(col, -.15))
		if kind == "jeans" {
			c.stroke("M-30 -55Q-24 -36 -10 -44M30 -55Q24 -36 10 -44M0 -55V-12", "#e0a24a", .8, `stroke-dasharray="2 1.6"`)
			c.circ(0, -60, 2, c.metalD("gold"))
		} else {
			c.stroke("M-22 -55L-26 70M22 -55L26 70", dark, .8, faOp(.35))
		}
		c.glow(-16, -20, 18, 40, "#ffffff", .18)
	case "pleated", "aline":
		d := "M-30 -54H30L54 56Q0 66 -54 56Z"
		if kind == "aline" {
			d = "M-30 -54H30L48 50Q0 58 -48 50Z"
		}
		c.drop(d, 6, 9)
		c.path(d, body)
		c.rect(-30, -56, 60, 9, 1, shade(col, -.15))
		var b strings.Builder
		n := 6
		if kind == "pleated" {
			n = 12
		}
		for i := 1; i < n; i++ {
			t := float64(i)/float64(n)*2 - 1
			b.WriteString(fp("M%v -47L%v 58", t*30, t*52))
		}
		c.stroke(b.String(), dark, 1, faOp(.35))
		c.glow(-12, -10, 20, 40, "#ffffff", .18)
	case "sneakers", "loafers", "flats":
		for _, sd := range []float64{-1, 1} {
			c.g(sd*22, sd*4, sd*6, 1)
			d := "M0 -44C15 -44 19 -22 18 0C17 26 12 44 0 44C-12 44 -17 26 -18 0C-19 -22 -15 -44 0 -44Z"
			c.drop(d, 4, 6)
			switch kind {
			case "sneakers":
				c.path(d, "#e9e4dc")
				c.path("M0 -40C13 -40 16 -20 15 0C14 24 10 40 0 40C-10 40 -14 24 -15 0C-16 -20 -13 -40 0 -40Z", body)
				c.ell(0, 14, 9, 14, shade(col, -.15))
				c.stroke("M-7 -14L7 -8M7 -14L-7 -8M-7 -4L7 2M7 -4L-7 2", "#bdb6aa", 1.4)
				c.path("M-14 -30Q0 -46 14 -30Q0 -36 -14 -30Z", shade(col, -.1))
			case "loafers":
				c.path(d, body)
				c.ell(0, 16, 11, 20, shade(col, -.45))
				c.stroke("M-14 -6Q0 -1 14 -6", shade(col, .25), 3)
				c.rect(-5, -7, 10, 4, 2, c.metalD("gold"))
			default:
				c.path(d, body)
				c.ell(0, 12, 12, 24, shade(col, -.3))
				c.bow(0, -12, 0, .3, shade(col, -.2))
			}
			c.glow(-5, -20, 6, 12, "#ffffff", .3)
			c.end()
		}
	case "heels":
		c.item("heels", 0, 0, 0, .75, col, col)
	}
	c.end()
}
