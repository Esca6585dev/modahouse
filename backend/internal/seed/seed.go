// Package seed fills an empty database with demo content: shoppers, shops with
// products and orders, and a Turkmen fashion community with ~170 posts and reels.
package seed

import (
	"log"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

const DemoPassword = "modahouse123"

type demoUser struct{ username, name, bio string }

// Shoppers: personal accounts that buy from the demo shops.
var users = []demoUser{
	{"aylar.studio", "Aýlar Studio", "Dizaýner köýnekler we güýz kolleksiýasy. Aşgabat"},
	{"ayna.gozel", "Aýna", "Moda we gözellik halaýan gyz 🌷"},
	{"merjen.ay", "Merjen", "Toý ideýalaryny ýygnaýaryn"},
	{"gulshat.style", "Gülşat", "Gündelik obrazlar we aksessuarlar"},
	{"nazik.moda", "Nazik", "Milli lybaslara aşyk"},
	{"bagul.ay", "Bägül", "Saç, makiýaž we dyrnak ideýalary"},
}

// Run seeds an empty database and adds later demo layers (shops, the fashion
// community) once, so databases created by older versions get them too.
func Run(db *gorm.DB, store *storage.Storage) error {
	var n int64
	db.Model(&models.User{}).Count(&n)
	if n == 0 {
		if err := seedBase(db); err != nil {
			return err
		}
	}
	var b int64
	db.Model(&models.User{}).Where("is_business = ?", true).Count(&b)
	if b == 0 {
		if err := seedShop(db, store); err != nil {
			return err
		}
	}
	var f int64
	db.Model(&models.User{}).Where("username = ?", creators[0].username).Count(&f)
	if f == 0 {
		return seedFashion(db, store)
	}
	return nil
}

func seedBase(db *gorm.DB) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(DemoPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return db.Transaction(func(tx *gorm.DB) error {
		for _, u := range users {
			m := models.User{Username: u.username, Name: u.name, Bio: u.bio, Email: u.username + "@modahouse.tm", PasswordHash: string(hash)}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
			if err := tx.Create(&models.Board{UserID: m.ID, Name: "Saklananlar"}).Error; err != nil {
				return err
			}
		}
		log.Printf("seed: created %d users (password %q)", len(users), DemoPassword)
		return nil
	})
}
