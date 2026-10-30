package search

import (
	"reflect"
	"strings"
	"testing"
)

func TestTerms(t *testing.T) {
	cases := map[string][][]string{
		"köýnek":               {{"koynek"}},
		"koynek":               {{"koynek"}},
		"köýnekler":            {{"koynek"}},
		"платья":               {{"koynek"}},
		"Свадебное платье":     {{"toy", "gelin"}, {"koynek"}},
		"wedding dresses":      {{"toy", "gelin"}, {"koynek"}},
		"fasonlar":             nil,
		"мода":                 nil,
		"fashion girls":        nil,
		"ştapel fasonlar":      {{"stapel"}},
		"маникюр":              {{"dyrnak"}},
		"nails":                {{"dyrnak"}},
		"kürte":                {{"kurte"}},
		"bukja":                {{"bukja"}},
		"#gelin":               {{"gelin"}},
		"zerbap":               {{"zerbap"}},
		"вышивка на воротнике": {{"kesde", "keshde"}, {"yaka"}},
	}
	for q, want := range cases {
		if got := Terms(q); !reflect.DeepEqual(got, want) {
			t.Errorf("Terms(%q) = %v, want %v", q, got, want)
		}
	}
}

func TestIndexText(t *testing.T) {
	idx := IndexText("Gyzyl ştapel köýnek", "Ýakasy keşdeli", "fason,ştapel", "koynekler")
	for _, want := range []string{"ştapel", "stapel", "koynek", "yakasy", "kesdeli"} {
		if !strings.Contains(idx, want) {
			t.Errorf("index %q lacks %q", idx, want)
		}
	}
	// A Turkmen-only nail post is found by an English or Russian query.
	if !strings.Contains(IndexText("Gül nagyşly", "", "", "dyrnak"), Terms("маникюр")[0][0]) {
		t.Error("category roots missing")
	}
}
