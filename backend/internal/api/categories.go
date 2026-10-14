package api

import "github.com/gofiber/fiber/v3"

type Category struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

var Categories = []Category{
	{"toy", "Toý köýnekleri"},
	{"gelin", "Gelin lybaslary"},
	{"milli", "Milli köýnekler"},
	{"koynekler", "Köýnekler"},
	{"yaka", "Ýaka fasonlary"},
	{"keshde", "El keşdeleri"},
	{"gundelik", "Gündelik moda"},
	{"sac", "Saç düzümleri"},
	{"makiyaj", "Makiýaž"},
	{"dyrnak", "Dyrnak dizaýny"},
	{"shay", "Şaý-sepler"},
	{"aksessuar", "Aksessuarlar"},
}

// legacyCategories are no longer offered but old posts may still use them.
var legacyCategories = map[string]bool{
	"aksessuarlar": true, "moda": true, "ic-bezeg": true, "tagamlar": true, "syyahat": true, "sungat": true, "osumlikler": true,
}

func validCategory(slug string) bool {
	for _, c := range Categories {
		if c.Slug == slug {
			return true
		}
	}
	return legacyCategories[slug]
}

func listCategories(c fiber.Ctx) error { return c.JSON(Categories) }
