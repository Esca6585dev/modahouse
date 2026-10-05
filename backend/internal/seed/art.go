package seed

import (
	"fmt"
	"strings"
)

// Palettes: background, main, light, dark.
var palettes = [][4]string{
	{"#ffcfa8", "#ff8a65", "#ffe082", "#6d4c41"},
	{"#dfe7d5", "#a7c4a0", "#f4e9d8", "#4f6d4a"},
	{"#fde2e4", "#f7a1b5", "#fff1e6", "#9c3d54"},
	{"#cfe8ef", "#5fa8d3", "#f6f1d1", "#1b4965"},
	{"#f2d0b6", "#d9825b", "#f7ece1", "#7a3e2b"},
	{"#e6dcf5", "#a990dd", "#fdf6ff", "#4b3a73"},
	{"#fff1c1", "#f2b134", "#fbfaf4", "#4a4a3a"},
	{"#2b2d42", "#8d99ae", "#edf2f4", "#ef233c"},
	{"#d8f3dc", "#74c69d", "#fefae0", "#2d6a4f"},
	{"#f8e1d7", "#e0a899", "#fffaf5", "#5e3b36"},
}

const artW = 300.0

// renderArt draws a flat illustration of the given kind as a standalone SVG.
// It returns the SVG plus its pixel size (rendered at 2x).
func renderArt(kind string, palette int, ratio float64) (svg string, w, h int) {
	W, H := artW, float64(int(artW*ratio))
	pal := palettes[palette%len(palettes)]
	a, b, c, d := pal[0], pal[1], pal[2], pal[3]
	f := func(v float64) string { return fmt.Sprintf("%.1f", v) }

	var s strings.Builder
	grad := func(to string) {
		fmt.Fprintf(&s, `<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs><rect width="%s" height="%s" fill="url(#g)"/>`, a, to, f(W), f(H))
	}
	rect := func(fill string) { fmt.Fprintf(&s, `<rect width="%s" height="%s" fill="%s"/>`, f(W), f(H), fill) }
	circle := func(cx, cy, r float64, fill string, op float64) {
		fmt.Fprintf(&s, `<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%.2f"/>`, f(cx), f(cy), f(r), fill, op)
	}
	path := func(dd, fill string, op float64) {
		fmt.Fprintf(&s, `<path d="%s" fill="%s" opacity="%.2f"/>`, dd, fill, op)
	}
	wave := func(y, amp float64) string {
		return fmt.Sprintf("M0 %s Q %s %s %s %s T %s %s V %s H 0 Z", f(y), f(W*0.25), f(y-amp), f(W*0.5), f(y), f(W), f(y), f(H))
	}
	blob := func(cx, cy, r float64) string {
		return fmt.Sprintf("M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s Z",
			f(cx), f(cy-r), f(cx+r*0.9), f(cy-r), f(cx+r*1.1), f(cy+r*0.6), f(cx+r*0.2), f(cy+r),
			f(cx-r*0.7), f(cy+r*1.3), f(cx-r*1.2), f(cy+r*0.1), f(cx-r*0.8), f(cy-r*0.5),
			f(cx-r*0.5), f(cy-r), f(cx-r*0.3), f(cy-r), f(cx), f(cy-r))
	}
	arch := func(x1, x2, top, bottom float64) string {
		r := (x2 - x1) / 2
		return fmt.Sprintf("M %s %s V %s A %s %s 0 0 1 %s %s V %s Z", f(x1), f(bottom), f(top+r), f(r), f(r), f(x2), f(top+r), f(bottom))
	}

	switch kind {
	case "mountains":
		grad(b)
		circle(W*0.68, H*0.35, W*0.14, c, 1)
		path(fmt.Sprintf("M0 %s L%s %s L%s %s L%s %s L%s %s V%s H0Z", f(H*0.72), f(W*0.3), f(H*0.48), f(W*0.55), f(H*0.7), f(W*0.75), f(H*0.55), f(W), f(H*0.75), f(H)), d, 0.5)
		path(fmt.Sprintf("M0 %s L%s %s L%s %s L%s %s L%s %s V%s H0Z", f(H*0.86), f(W*0.25), f(H*0.66), f(W*0.5), f(H*0.82), f(W*0.8), f(H*0.62), f(W), f(H*0.8), f(H)), d, 1)
	case "waves":
		grad(c)
		circle(W*0.3, H*0.3, W*0.12, "#ffffff", 0.7)
		path(wave(H*0.55, 28), b, 0.55)
		path(wave(H*0.7, 22), b, 1)
		path(wave(H*0.85, 18), d, 1)
	case "circles":
		rect(a)
		circle(W*0.1, H*0.08, W*0.3, b, 0.35)
		circle(W*0.5, H*0.52, W*0.36, c, 1)
		circle(W*0.5, H*0.52, W*0.28, b, 0.3)
		circle(W*0.42, H*0.47, W*0.08, b, 1)
		circle(W*0.6, H*0.5, W*0.06, d, 1)
		circle(W*0.5, H*0.6, W*0.07, d, 0.6)
		circle(W*0.62, H*0.62, W*0.035, b, 1)
		circle(W*0.9, H*0.92, W*0.2, d, 0.15)
	case "arch":
		rect(a)
		fmt.Fprintf(&s, `<rect y="%s" width="%s" height="%s" fill="%s" opacity="0.2"/>`, f(H*0.86), f(W), f(H*0.14), d)
		path(arch(W*0.2, W*0.8, H*0.14, H*0.86), b, 1)
		path(arch(W*0.3, W*0.7, H*0.24, H*0.86), c, 1)
		circle(W*0.5, H*0.42, W*0.07, d, 0.7)
		fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="6" fill="%s"/>`, f(W*0.42), f(H*0.72), f(W*0.16), f(H*0.14), d)
	case "stripes":
		rect(c)
		fmt.Fprintf(&s, `<g transform="rotate(-20 %s %s)">`, f(W/2), f(H/2))
		for i := 0; i < 16; i++ {
			fill := []string{d, b, a}[i%3]
			fmt.Fprintf(&s, `<rect x="%s" y="%d" width="%s" height="22" fill="%s"/>`, f(-W), i*44-120, f(W*3), fill)
		}
		s.WriteString(`</g>`)
		fmt.Fprintf(&s, `<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="6"/>`, f(W/2), f(H/2), f(W*0.22), c, d)
		circle(W/2, H/2, W*0.1, b, 1)
	case "blob":
		rect(a)
		path(blob(W*0.35, H*0.35, W*0.28), b, 0.8)
		path(blob(W*0.65, H*0.62, W*0.3), c, 1)
		path(blob(W*0.45, H*0.75, W*0.14), d, 0.75)
		circle(W*0.78, H*0.2, 6, d, 1)
		circle(W*0.86, H*0.26, 4, d, 1)
		circle(W*0.18, H*0.86, 5, b, 1)
	case "dress":
		grad(c)
		fmt.Fprintf(&s, `<path d="M %s %s L %s %s L %s %s" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`,
			f(W*0.36), f(H*0.21), f(W*0.5), f(H*0.15), f(W*0.64), f(H*0.21), d)
		fmt.Fprintf(&s, `<path d="M %s %s V %s a 9 9 0 1 1 9 -9" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round"/>`, f(W*0.5), f(H*0.15), f(H*0.12), d)
		path(fmt.Sprintf("M %s %s L %s %s Q %s %s %s %s L %s %s L %s %s L %s %s Q %s %s %s %s L %s %s Z",
			f(W*0.42), f(H*0.22), f(W*0.46), f(H*0.22), f(W*0.5), f(H*0.28), f(W*0.54), f(H*0.22), f(W*0.58), f(H*0.22),
			f(W*0.61), f(H*0.44), f(W*0.8), f(H*0.84), f(W*0.5), f(H*0.9), f(W*0.2), f(H*0.84), f(W*0.39), f(H*0.44)), b, 1)
		fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="%s"/>`, f(W*0.39), f(H*0.43), f(W*0.22), f(H*0.03), d)
	default: // plant
		rect(a)
		baseY, L := H*0.66, H*0.42
		fmt.Fprintf(&s, `<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity="0.15"/>`, f(W/2), f(H*0.9), f(W*0.24), f(H*0.025), d)
		for i, deg := range []int{-62, -32, 0, 30, 58} {
			fill, op := b, 1.0
			if i%2 == 1 {
				fill, op = d, 0.75
			}
			fmt.Fprintf(&s, `<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity="%.2f" transform="rotate(%d %s %s)"/>`,
				f(W/2), f(baseY-L/2), f(W*0.075), f(L/2), fill, op, deg, f(W/2), f(baseY))
		}
		path(fmt.Sprintf("M %s %s H %s L %s %s H %s Z", f(W*0.32), f(H*0.68), f(W*0.68), f(W*0.63), f(H*0.89), f(W*0.37)), c, 1)
		fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="4" fill="%s"/>`, f(W*0.3), f(H*0.65), f(W*0.4), f(H*0.05), d)
	}

	w, h = int(W*2), int(H*2)
	svg = fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s">%s</svg>`, w, h, f(W), f(H), s.String())
	return svg, w, h
}
