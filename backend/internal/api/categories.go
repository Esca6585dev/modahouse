package api

import "github.com/gofiber/fiber/v3"

type Category struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

var Categories = []Category{
	{"moda", "Moda"},
	{"ic-bezeg", "Içki bezeg"},
	{"tagamlar", "Tagamlar"},
	{"syyahat", "Syýahat"},
	{"sungat", "Sungat"},
	{"osumlikler", "Ösümlikler"},
}

func validCategory(slug string) bool {
	for _, c := range Categories {
		if c.Slug == slug {
			return true
		}
	}
	return false
}

func listCategories(c fiber.Ctx) error { return c.JSON(Categories) }
