package seed

import (
	"fmt"
	"math"
	"strings"
)

// dressStyle describes a seed product illustration: a dress on a dress form
// in a softly lit salon, drawn as SVG so the repo needs no photo assets.
type dressStyle struct {
	Fabric   string // main dress color
	Wall     string // background wall color
	Sleeves  string // "long", "puff", "none", "cap"
	Neck     string // "square", "v", "round", "sweetheart"
	Skirt    string // "aline", "ball", "mermaid", "midi"
	Pattern  string // "", "floral", "dots", "lace", "milli"
	Accent   string // pattern / belt color
	Belt     bool
	ArchSide float64 // 0..1 horizontal position of the background arch (mirror/window)
}

type view int

const (
	viewFront view = iota
	viewZoom
	viewFabric
	viewBack
)

func shade(hex string, f float64) string {
	var r, g, b int
	fmt.Sscanf(strings.TrimPrefix(hex, "#"), "%02x%02x%02x", &r, &g, &b)
	adj := func(c int) int {
		v := float64(c)
		if f < 0 {
			v *= 1 + f
		} else {
			v += (255 - v) * f
		}
		return int(math.Max(0, math.Min(255, v)))
	}
	return fmt.Sprintf("#%02x%02x%02x", adj(r), adj(g), adj(b))
}

// renderDress returns an SVG of w x h (viewBox units) for the given view.
func renderDress(st dressStyle, v view, w, h float64) string {
	f := func(x float64) string { return fmt.Sprintf("%.1f", x) }
	var s strings.Builder
	fmt.Fprintf(&s, `<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %s %s">`, int(w*2), int(h*2), f(w), f(h))
	dark, light := shade(st.Fabric, -0.3), shade(st.Fabric, 0.12)
	fmt.Fprintf(&s, `<defs>
<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<linearGradient id="fab" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%s"/><stop offset=".55" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<radialGradient id="glow" cx=".3" cy=".25" r=".8"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
</defs>`, shade(st.Wall, 0.25), st.Wall, shade(st.Wall, -0.06), shade(st.Wall, -0.18), light, st.Fabric, dark)

	if v == viewFabric {
		// Close-up of the fabric: folds and pattern fill the frame.
		fmt.Fprintf(&s, `<rect width="%s" height="%s" fill="url(#fab)"/>`, f(w), f(h))
		for i := 0; i < 7; i++ {
			x := w * (0.08 + 0.14*float64(i))
			fmt.Fprintf(&s, `<path d="M %s 0 C %s %s %s %s %s %s" fill="none" stroke="%s" stroke-width="%s" opacity=".35"/>`,
				f(x), f(x+w*0.08), f(h*0.3), f(x-w*0.06), f(h*0.7), f(x+w*0.04), f(h), dark, f(w*0.035))
			fmt.Fprintf(&s, `<path d="M %s 0 C %s %s %s %s %s %s" fill="none" stroke="%s" stroke-width="%s" opacity=".25"/>`,
				f(x+w*0.05), f(x+w*0.13), f(h*0.3), f(x-w*0.01), f(h*0.7), f(x+w*0.09), f(h), light, f(w*0.02))
		}
		pattern(&s, st, 0, 0, w, h, 2.2)
		fmt.Fprintf(&s, `<rect width="%s" height="%s" fill="url(#glow)"/></svg>`, f(w), f(h))
		return s.String()
	}

	// Salon: wall, arch mirror/window, floor.
	fmt.Fprintf(&s, `<rect width="%s" height="%s" fill="url(#wall)"/>`, f(w), f(h))
	ax := w * st.ArchSide
	fmt.Fprintf(&s, `<path d="M %s %s V %s A %s %s 0 0 1 %s %s V %s Z" fill="%s" opacity=".55"/>`,
		f(ax-w*0.17), f(h*0.78), f(h*0.3), f(w*0.17), f(w*0.17), f(ax+w*0.17), f(h*0.3), f(h*0.78), shade(st.Wall, 0.45))
	fmt.Fprintf(&s, `<path d="M %s %s V %s A %s %s 0 0 1 %s %s V %s" fill="none" stroke="%s" stroke-width="3" opacity=".6"/>`,
		f(ax-w*0.17), f(h*0.78), f(h*0.3), f(w*0.17), f(w*0.17), f(ax+w*0.17), f(h*0.3), f(h*0.78), shade(st.Wall, -0.2))
	fmt.Fprintf(&s, `<rect y="%s" width="%s" height="%s" fill="url(#floor)"/>`, f(h*0.8), f(w), f(h*0.2))
	fmt.Fprintf(&s, `<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#000" opacity=".12"/>`, f(w*0.5), f(h*0.9), f(w*0.3), f(h*0.025))

	if v == viewZoom {
		// Focus on the bodice: scale around the upper body.
		fmt.Fprintf(&s, `<g transform="translate(%s %s) scale(1.9)">`, f(-w*0.45), f(-h*0.18))
	} else {
		s.WriteString(`<g>`)
	}

	cx := w / 2
	top, waist, hem := h*0.17, h*0.39, h*0.87
	// Dress form: neck stand and pole.
	fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="4" fill="#3b2f2a"/>`, f(cx-w*0.035), f(h*0.07), f(w*0.07), f(h*0.1))
	fmt.Fprintf(&s, `<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#4a3b34"/>`, f(cx), f(h*0.07), f(w*0.045), f(h*0.012))
	fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" fill="#3b2f2a"/>`, f(cx-w*0.008), f(hem), f(w*0.016), f(h*0.05))

	shoulder, waistW := w*0.15, w*0.09
	var hemW, kneeW float64
	switch st.Skirt {
	case "ball":
		hemW = w * 0.36
	case "mermaid":
		hemW, kneeW = w*0.27, w*0.11
	case "midi":
		hemW, hem = w*0.25, h*0.76
	default:
		hemW = w * 0.29
	}

	// Sleeves (behind the bodice).
	switch st.Sleeves {
	case "long", "puff":
		for _, side := range []float64{-1, 1} {
			sx := cx + side*shoulder
			puff := w * 0.035
			if st.Sleeves == "puff" {
				puff = w * 0.06
			}
			fmt.Fprintf(&s, `<path d="M %s %s Q %s %s %s %s L %s %s L %s %s Q %s %s %s %s Z" fill="url(#fab)"/>`,
				f(sx-side*w*0.02), f(top+h*0.01),
				f(sx+side*(w*0.05+puff)), f(top+h*0.06), f(sx+side*w*0.075), f(top+h*0.16),
				f(sx+side*w*0.065), f(waist+h*0.12), f(sx+side*w*0.03), f(waist+h*0.12),
				f(sx+side*w*0.02), f(top+h*0.12), f(sx-side*w*0.02), f(top+h*0.06))
			fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="%s"/>`,
				f(math.Min(sx+side*w*0.03, sx+side*w*0.065)), f(waist+h*0.115), f(w*0.035), f(h*0.012), dark)
		}
	case "cap":
		for _, side := range []float64{-1, 1} {
			sx := cx + side*shoulder
			fmt.Fprintf(&s, `<path d="M %s %s Q %s %s %s %s L %s %s Z" fill="url(#fab)"/>`,
				f(sx-side*w*0.02), f(top), f(sx+side*w*0.07), f(top+h*0.01), f(sx+side*w*0.06), f(top+h*0.07), f(sx-side*w*0.01), f(top+h*0.07))
		}
	}

	// Skirt + bodice as one silhouette.
	var skirt string
	if st.Skirt == "mermaid" {
		knee := h * 0.7
		skirt = fmt.Sprintf("L %s %s C %s %s %s %s %s %s Q %s %s %s %s C %s %s %s %s %s %s",
			f(cx+waistW*1.15), f(waist+h*0.06),
			f(cx+waistW*1.6), f(h*0.55), f(cx+kneeW), f(knee-h*0.04), f(cx+kneeW), f(knee),
			f(cx), f(hem+h*0.03), f(cx-kneeW), f(knee),
			f(cx-kneeW), f(knee-h*0.04), f(cx-waistW*1.6), f(h*0.55), f(cx-waistW*1.15), f(waist+h*0.06))
		// flare under the knee
		skirt = strings.Replace(skirt, fmt.Sprintf("Q %s %s %s %s", f(cx), f(hem+h*0.03), f(cx-kneeW), f(knee)),
			fmt.Sprintf("L %s %s Q %s %s %s %s L %s %s", f(cx+hemW/2*1.6), f(hem), f(cx), f(hem+h*0.03), f(cx-hemW/2*1.6), f(hem), f(cx-kneeW), f(knee)), 1)
	} else {
		skirt = fmt.Sprintf("C %s %s %s %s %s %s Q %s %s %s %s C %s %s %s %s %s %s",
			f(cx+waistW+w*0.04), f(waist+h*0.1), f(cx+hemW*0.85), f(hem-h*0.2), f(cx+hemW), f(hem),
			f(cx), f(hem+h*0.035), f(cx-hemW), f(hem),
			f(cx-hemW*0.85), f(hem-h*0.2), f(cx-waistW-w*0.04), f(waist+h*0.1), f(cx-waistW), f(waist))
	}
	body := fmt.Sprintf("M %s %s Q %s %s %s %s L %s %s %s Z",
		f(cx-shoulder), f(top), f(cx), f(top-h*0.012), f(cx+shoulder), f(top),
		f(cx+waistW), f(waist), skirt)
	fmt.Fprintf(&s, `<clipPath id="dress"><path d="%s"/></clipPath>`, body)
	fmt.Fprintf(&s, `<path d="%s" fill="url(#fab)"/>`, body)
	// Folds in the skirt.
	for i := -2; i <= 2; i++ {
		x := cx + float64(i)*hemW*0.32
		fmt.Fprintf(&s, `<path d="M %s %s Q %s %s %s %s" fill="none" stroke="%s" stroke-width="%s" opacity=".28" clip-path="url(#dress)"/>`,
			f(cx+float64(i)*waistW*0.4), f(waist+h*0.03), f(x+w*0.01), f((waist+hem)/2), f(x), f(hem), dark, f(w*0.012))
	}
	pattern(&s, st, cx-hemW*1.2, top, hemW*2.4, hem-top+h*0.04, 1)

	// Neckline (shows the dark dress form behind) — on the back view a seam instead.
	if v == viewBack {
		fmt.Fprintf(&s, `<path d="M %s %s V %s" stroke="%s" stroke-width="2" opacity=".5"/>`, f(cx), f(top+h*0.02), f(hem), dark)
		fmt.Fprintf(&s, `<path d="M %s %s Q %s %s %s %s Z" fill="#3b2f2a"/>`, f(cx-w*0.06), f(top), f(cx), f(top+h*0.13), f(cx+w*0.06), f(top))
	} else {
		var neck string
		switch st.Neck {
		case "v":
			neck = fmt.Sprintf("M %s %s L %s %s L %s %s Z", f(cx-w*0.06), f(top-h*0.004), f(cx), f(top+h*0.1), f(cx+w*0.06), f(top-h*0.004))
		case "square":
			neck = fmt.Sprintf("M %s %s V %s H %s V %s Z", f(cx-w*0.065), f(top-h*0.004), f(top+h*0.06), f(cx+w*0.065), f(top-h*0.004))
		case "sweetheart":
			neck = fmt.Sprintf("M %s %s Q %s %s %s %s Q %s %s %s %s Z", f(cx-w*0.08), f(top-h*0.004), f(cx-w*0.06), f(top+h*0.07), f(cx), f(top+h*0.05), f(cx+w*0.06), f(top+h*0.07), f(cx+w*0.08), f(top-h*0.004))
		default:
			neck = fmt.Sprintf("M %s %s Q %s %s %s %s Z", f(cx-w*0.055), f(top-h*0.004), f(cx), f(top+h*0.055), f(cx+w*0.055), f(top-h*0.004))
		}
		fmt.Fprintf(&s, `<path d="%s" fill="#e9c9b3"/>`, neck)
	}
	if st.Belt {
		fmt.Fprintf(&s, `<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="%s"/>`, f(cx-waistW*1.05), f(waist-h*0.012), f(waistW*2.1), f(h*0.022), st.Accent)
	}
	fmt.Fprintf(&s, `<path d="%s" fill="url(#glow)"/>`, body)
	s.WriteString(`</g></svg>`)
	return s.String()
}

// pattern scatters a deterministic print over the given box, clipped to the dress.
func pattern(s *strings.Builder, st dressStyle, x0, y0, bw, bh, scale float64) {
	if st.Pattern == "" {
		return
	}
	f := func(x float64) string { return fmt.Sprintf("%.1f", x) }
	clip := ` clip-path="url(#dress)"`
	if scale > 1 {
		clip = ""
	}
	seed := uint32(len(st.Fabric)*7919 + int(st.ArchSide*1000))
	rnd := func() float64 {
		seed = seed*1664525 + 1013904223
		return float64(seed>>8) / float64(1<<24)
	}
	n := 70
	if scale > 1 {
		n = 40
	}
	if st.Pattern == "milli" {
		n /= 2
	}
	for i := 0; i < n; i++ {
		x, y := x0+rnd()*bw, y0+rnd()*bh
		r := (2 + rnd()*3) * scale
		if st.Pattern == "milli" {
			r *= 0.6
		}
		switch st.Pattern {
		case "floral":
			for k := 0; k < 5; k++ {
				a := float64(k) * 2 * math.Pi / 5
				fmt.Fprintf(s, `<circle cx="%s" cy="%s" r="%s" fill="%s" opacity=".85"%s/>`, f(x+math.Cos(a)*r), f(y+math.Sin(a)*r), f(r*0.7), st.Accent, clip)
			}
			fmt.Fprintf(s, `<circle cx="%s" cy="%s" r="%s" fill="#f6d365"%s/>`, f(x), f(y), f(r*0.5), clip)
		case "dots":
			fmt.Fprintf(s, `<circle cx="%s" cy="%s" r="%s" fill="%s"%s/>`, f(x), f(y), f(r*0.8), st.Accent, clip)
		case "lace":
			fmt.Fprintf(s, `<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="%s" opacity=".7"%s/>`, f(x), f(y), f(r*1.4), st.Accent, f(0.8*scale), clip)
			fmt.Fprintf(s, `<path d="M %s %s q %s %s %s 0" fill="none" stroke="%s" stroke-width="%s" opacity=".6"%s/>`, f(x-r*2), f(y+r*2), f(r*2), f(-r*2), f(r*4), st.Accent, f(0.8*scale), clip)
		case "milli":
			// Turkmen-inspired gul (octagon) motif.
			var pts []string
			for k := 0; k < 8; k++ {
				a := float64(k)*math.Pi/4 + math.Pi/8
				pts = append(pts, f(x+math.Cos(a)*r*2.2)+","+f(y+math.Sin(a)*r*2.2))
			}
			fmt.Fprintf(s, `<polygon points="%s" fill="none" stroke="%s" stroke-width="%s"%s/>`, strings.Join(pts, " "), st.Accent, f(1.2*scale), clip)
			fmt.Fprintf(s, `<rect x="%s" y="%s" width="%s" height="%s" transform="rotate(45 %s %s)" fill="%s"%s/>`, f(x-r*0.7), f(y-r*0.7), f(r*1.4), f(r*1.4), f(x), f(y), st.Accent, clip)
		}
	}
}
