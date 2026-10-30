// Package search makes post search work the way people type: Turkmen with or
// without its letters (köýnek, koynek), Russian (платье) and English (dress).
//
// Posts are indexed with their text, the same text folded to plain Latin
// letters and the root words of their category. A query word is folded and,
// when it is a known word in any of the three languages, replaced by the
// Turkmen roots it means. Words that mean "anything fashion" (moda, фасон,
// fashion) do not filter at all.
package search

import (
	"strings"
	"unicode"
)

var folder = strings.NewReplacer(
	"ä", "a", "ç", "c", "ň", "n", "ö", "o", "ş", "s", "ü", "u", "ý", "y", "ž", "z",
	"á", "a", "é", "e", "í", "i", "ó", "o", "ú", "u", "ı", "i", "ğ", "g", "â", "a",
)

// Fold lower-cases s and writes Turkmen (and Turkish) letters as plain Latin.
func Fold(s string) string { return folder.Replace(strings.ToLower(s)) }

// roots maps a word (folded; Russian and English stems are prefixes) to the
// folded Turkmen roots stored in the index. An empty list means "generic".
var roots = map[string][]string{
	// generic: fashion, style, girls, Turkmen…
	"moda": nil, "fason": nil, "fasonlar": nil, "gyz": nil, "gyzlar": nil, "turkmen": nil, "zenan": nil, "ideya": nil,
	"fashion": nil, "style": nil, "styles": nil, "girl": nil, "girls": nil, "women": nil, "woman": nil, "outfit": nil, "design": nil, "designs": nil,
	"мод": nil, "фасон": nil, "стил": nil, "девуш": nil, "женск": nil, "туркмен": nil, "одежд": nil, "образ": nil,
	// dresses
	"koynek": {"koynek"}, "dress": {"koynek"}, "dresses": {"koynek"}, "gown": {"koynek"}, "gowns": {"koynek"}, "плать": {"koynek"},
	"stapel": {"stapel"}, "штапел": {"stapel"}, "staple": {"stapel"},
	"kurte": {"kurte"}, "курте": {"kurte"}, "kurta": {"kurte"}, "курта": {"kurte"},
	"bukja": {"bukja"}, "букдж": {"bukja"}, "букча": {"bukja"},
	"agsam": {"agsam"}, "evening": {"agsam"}, "вечерн": {"agsam"},
	"gundelik": {"gundelik"}, "casual": {"gundelik"}, "everyday": {"gundelik"}, "повседнев": {"gundelik"},
	"milli": {"milli"}, "national": {"milli"}, "traditional": {"milli"}, "национал": {"milli"}, "традицион": {"milli"},
	"yaka": {"yaka"}, "collar": {"yaka"}, "neckline": {"yaka"}, "воротн": {"yaka"},
	"atlas": {"atlas"}, "satin": {"atlas"}, "атлас": {"atlas"}, "silk": {"yupek"}, "yupek": {"yupek"}, "шелк": {"yupek"}, "шёлк": {"yupek"},
	// wedding
	"gelin": {"gelin"}, "bride": {"gelin"}, "bridal": {"gelin"}, "невест": {"gelin"},
	"toy": {"toy", "gelin"}, "wedding": {"toy", "gelin"}, "свадеб": {"toy", "gelin"}, "свадьб": {"toy", "gelin"},
	"fata": {"fata"}, "veil": {"fata"}, "фат": {"fata"},
	// crafts and beauty
	"kesde": {"kesde", "keshde"}, "keshde": {"kesde", "keshde"}, "embroidery": {"kesde", "keshde"}, "embroidered": {"kesde", "keshde"}, "вышив": {"kesde", "keshde"},
	"dyrnak": {"dyrnak"}, "nail": {"dyrnak"}, "nails": {"dyrnak"}, "manicure": {"dyrnak"}, "ногт": {"dyrnak"}, "маникюр": {"dyrnak"}, "manikyur": {"dyrnak"},
	"sac": {"sac"}, "hair": {"sac"}, "hairstyle": {"sac"}, "hairstyles": {"sac"}, "причес": {"sac"}, "волос": {"sac"}, "orum": {"orum"}, "braid": {"orum"},
	"makiyaj": {"makiyaj"}, "makeup": {"makiyaj"}, "make-up": {"makiyaj"}, "макияж": {"makiyaj"},
	"kirpik": {"kirpik"}, "lashes": {"kirpik"}, "eyelashes": {"kirpik"}, "ресниц": {"kirpik"},
	"say-sep": {"say-sep", "shay"}, "shay": {"say-sep", "shay"}, "jewelry": {"say-sep", "shay"}, "jewellery": {"say-sep", "shay"}, "украшен": {"say-sep", "shay"}, "бижутер": {"say-sep", "shay"},
	"aksessuar": {"aksessuar"}, "accessories": {"aksessuar"}, "accessory": {"aksessuar"}, "аксессуар": {"aksessuar"},
	"tikinci": {"tikin"}, "tailor": {"tikin"}, "портн": {"tikin"}, "швея": {"tikin"}, "ателье": {"atelye"},
}

// stems are the Cyrillic keys, matched as prefixes (платье, платья, платьев…).
var stems []string

func init() {
	for k := range roots {
		if k != "" && unicode.Is(unicode.Cyrillic, []rune(k)[0]) {
			stems = append(stems, k)
		}
	}
}

// categoryRoots are indexed with every post of a category, so "платье" or
// "nails" find posts written only in Turkmen.
var categoryRoots = map[string]string{
	"toy": "toy koynek agsam", "gelin": "gelin koynek toy", "milli": "milli koynek", "koynekler": "koynek",
	"yaka": "yaka", "keshde": "kesde keshde", "gundelik": "gundelik", "sac": "sac", "makiyaj": "makiyaj",
	"dyrnak": "dyrnak", "shay": "say-sep shay", "aksessuar": "aksessuar",
}

// IndexText is what Pin.SearchText stores.
func IndexText(title, description, tags, category string) string {
	text := strings.ToLower(strings.Join([]string{title, description, tags}, " "))
	parts := []string{text}
	if f := Fold(text); f != text {
		parts = append(parts, f)
	}
	if r := categoryRoots[category]; r != "" {
		parts = append(parts, r)
	}
	return strings.Join(parts, " ")
}

func lookup(w string) ([]string, bool) {
	if r, ok := roots[w]; ok {
		return r, true
	}
	// Plural or case endings: dresses, fasonlary, köýnekler, платья.
	for _, suf := range []string{"lary", "leri", "lar", "ler", "es", "s", "y", "i"} {
		if len(w) > len(suf)+2 && strings.HasSuffix(w, suf) {
			if r, ok := roots[strings.TrimSuffix(w, suf)]; ok {
				return r, true
			}
		}
	}
	best := ""
	for _, s := range stems {
		if strings.HasPrefix(w, s) && len(s) > len(best) {
			best = s
		}
	}
	if best != "" {
		return roots[best], true
	}
	return nil, false
}

// Terms turns a query into AND-ed groups of OR-ed alternatives to look for
// in the index. Generic words are dropped, so "fasonlar" alone matches all.
func Terms(q string) [][]string {
	var out [][]string
	for _, w := range strings.Fields(Fold(strings.TrimSpace(q))) {
		w = strings.Trim(w, "#.,!?;:()\"'«»")
		if w == "" {
			continue
		}
		if r, ok := lookup(w); ok {
			if len(r) > 0 {
				out = append(out, r)
			}
			continue
		}
		if len([]rune(w)) >= 3 || len(strings.Fields(q)) == 1 { // skip "we", "на", "of" in longer queries
			out = append(out, []string{w})
		}
	}
	return out
}
