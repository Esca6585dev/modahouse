package seed

import (
	"fmt"
	"log"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/search"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

var colorHex = map[string]string{
	"Gyzyl": "#C62828", "Goýy gyzyl": "#7B1E3A", "Gara": "#111111", "Ak": "#F5F3EE", "Krem": "#E9DCC6",
	"Gülgüne": "#E8A0B4", "Gök": "#7FA7D9", "Ýaşyl": "#1F6F5C", "Pudra": "#E7C1B5", "Altyn": "#C9A227",
	"Gyrmyzy": "#9C2742", "Mämişi": "#E07A3F",
}

type demoBusiness struct {
	username, name, bio, category, city, phone, hours, instagram string
	verified                                                     bool
	viewsBase, orders                                            int // drive the demo Top 10
}

var businesses = []demoBusiness{
	{"gyzyl.guyze", "Gyzyl Güýze", "Agşam we baýramçylyk köýnekleri. Ölçegiňize görä tikýäris ✂️", "dress", "Aşgabat", "+993 65 112233", "09:00-20:00", "gyzyl.guyze", true, 60, 11},
	{"soygi.tikincilik", "Söýgi Tikinçilik", "Gündelik we toý köýnekleri. 10 ýyllyk tejribe.", "tailor", "Mary", "+993 63 445566", "08:30-19:00", "soygi_tikin", true, 48, 9},
	{"ak.gelin", "Ak Gelin", "Gelin köýnekleri we toý lybaslary. Synap görmek mugt.", "dress", "Aşgabat", "+993 62 778899", "10:00-21:00", "akgelin.tm", true, 40, 7},
	{"merjen.tikincilik", "Merjen Tikinçilik", "Klassyk we häzirki zaman köýnekleri, milli nagyşlar.", "tailor", "Daşoguz", "+993 64 334455", "09:00-18:00", "merjen.tikin", false, 32, 6},
	{"mahri.stili", "Mähri Stili", "Butik: täze moda, ýumşak reňkler we aksessuarlar.", "boutique", "Türkmenabat", "+993 61 556677", "10:00-20:00", "mahri.stili", false, 26, 4},
	{"aylar.studio", "Aýlar Studio", "Dizaýner köýnekler we güýz kolleksiýasy. Aşgabat", "designer", "Aşgabat", "+993 61 223344", "10:00-19:00", "aylar.studio", true, 22, 4},
	{"yyldyz.butik", "Ýyldyz Butik", "Ýaşlar üçin owadan we elýeterli köýnekler.", "boutique", "Balkanabat", "+993 65 990011", "09:00-19:00", "yyldyz.butik", false, 18, 3},
}

type demoProduct struct {
	biz, title, desc, category string
	price, oldPrice            int
	colors                     []string
	sizes                      string
	stock                      int // -1 = not tracked
	delivery                   int
	material                   string
	style                      dressStyle
}

var products = []demoProduct{
	{"gyzyl.guyze", "Zarif köýnek", "Uzyn ýeňli, inedördül ýakaly agşam köýnegi. Ýeňil we rahat.", "koynekler", 450, 0, []string{"Goýy gyzyl", "Gara", "Gülgüne", "Krem"}, "42,44,46,48,50", 12, 12, "Poliester (ýokary hil)",
		dressStyle{Fabric: "#7B1E3A", Wall: "#EADBC8", Sleeves: "puff", Neck: "square", Skirt: "aline", ArchSide: 0.78}},
	{"gyzyl.guyze", "Gyzyl agşam köýnegi", "Toý we baýramçylyklar üçin ýalpyldawuk atlas köýnek.", "koynekler", 620, 720, []string{"Gyzyl", "Gyrmyzy"}, "42,44,46,48", 5, 10, "Atlas",
		dressStyle{Fabric: "#C62828", Wall: "#EFE3D6", Sleeves: "long", Neck: "v", Skirt: "ball", ArchSide: 0.2}},
	{"gyzyl.guyze", "Ýaşyl barhat köýnek", "Gyşky agşamlar üçin galyň barhat, altyn guşak bilen.", "koynekler", 540, 0, []string{"Ýaşyl", "Gara"}, "44,46,48,50", 7, 12, "Barhat",
		dressStyle{Fabric: "#1F6F5C", Wall: "#E3DACB", Sleeves: "long", Neck: "v", Skirt: "aline", Accent: "#C9A227", Belt: true, ArchSide: 0.75}},
	{"gyzyl.guyze", "Pudra reňkli köýnek", "Ýumşak şifon, ýeňil we howa geçirýän.", "koynekler", 410, 0, []string{"Pudra", "Krem"}, "42,44,46", 9, 8, "Şifon",
		dressStyle{Fabric: "#E7C1B5", Wall: "#F1E6DC", Sleeves: "cap", Neck: "sweetheart", Skirt: "midi", ArchSide: 0.25}},
	{"soygi.tikincilik", "Gül nagyşly köýnek", "Ýaz paslyna gül nagyşly, ýeňil keten köýnek.", "koynekler", 420, 0, []string{"Krem", "Gülgüne"}, "42,44,46,48,50,52", 14, 7, "Keten",
		dressStyle{Fabric: "#F4E9DA", Wall: "#EBDDCB", Sleeves: "puff", Neck: "square", Skirt: "midi", Pattern: "floral", Accent: "#D98BA0", Belt: true, ArchSide: 0.2}},
	{"soygi.tikincilik", "Ýumşak reňkli köýnek", "Gündelik geýim üçin rahat we owadan köýnek.", "koynekler", 390, 450, []string{"Gülgüne", "Gök", "Krem"}, "44,46,48,50", 6, 7, "Pagta",
		dressStyle{Fabric: "#E8A0B4", Wall: "#F1E4DA", Sleeves: "puff", Neck: "round", Skirt: "aline", ArchSide: 0.8}},
	{"soygi.tikincilik", "Gök ýüpek köýnek", "Ýalpyldawuk ýüpek, uzyn ýeňli we näzik.", "koynekler", 560, 0, []string{"Gök", "Ak"}, "42,44,46,48", 4, 10, "Ýüpek",
		dressStyle{Fabric: "#7FA7D9", Wall: "#E7E1D8", Sleeves: "long", Neck: "v", Skirt: "ball", ArchSide: 0.22}},
	{"soygi.tikincilik", "Gara klassyk köýnek", "Her ýerde gelişýän klassyk gara köýnek.", "koynekler", 480, 0, []string{"Gara"}, "42,44,46,48,50", -1, 7, "Krep",
		dressStyle{Fabric: "#1C1A1F", Wall: "#E8DED1", Sleeves: "puff", Neck: "square", Skirt: "aline", ArchSide: 0.7}},
	{"ak.gelin", "Ak gelin köýnegi", "Dantelli gelin köýnegi, uzyn ýeňli we giň etekli.", "toy", 1850, 0, []string{"Ak", "Krem"}, "40,42,44,46,48", 3, 21, "Dantel we atlas",
		dressStyle{Fabric: "#F3EEE6", Wall: "#E8DCCB", Sleeves: "long", Neck: "v", Skirt: "ball", Pattern: "lace", Accent: "#D9CBB5", ArchSide: 0.22}},
	{"ak.gelin", "Nika köýnegi", "Ýönekeý we näzik nika köýnegi, ýeňil dantel bilen.", "toy", 1200, 1400, []string{"Ak"}, "42,44,46", 2, 18, "Dantel",
		dressStyle{Fabric: "#FAF7F2", Wall: "#EDE3D6", Sleeves: "cap", Neck: "sweetheart", Skirt: "mermaid", Pattern: "lace", Accent: "#DCCFBC", ArchSide: 0.78}},
	{"ak.gelin", "Toý üçin altyn köýnek", "Gelin alyşyk üçin altyn öwüşginli lybas.", "toy", 980, 0, []string{"Altyn", "Krem"}, "42,44,46,48", 4, 14, "Brokat",
		dressStyle{Fabric: "#D8B65A", Wall: "#EFE4D2", Sleeves: "long", Neck: "round", Skirt: "ball", Pattern: "dots", Accent: "#F6E7B0", ArchSide: 0.25}},
	{"merjen.tikincilik", "Milli nagyşly köýnek", "Türkmen nagyşly, el bilen keşdelenen köýnek.", "milli", 690, 0, []string{"Ýaşyl", "Gyzyl", "Gara"}, "44,46,48,50,52", 6, 15, "Ýüpek, el keşdesi",
		dressStyle{Fabric: "#1F6F5C", Wall: "#E3DACB", Sleeves: "cap", Neck: "round", Skirt: "aline", Pattern: "milli", Accent: "#C9A227", Belt: true, ArchSide: 0.75}},
	{"merjen.tikincilik", "Gyrmyzy keteni", "Milli keteni köýnek, ýakasy keşdeli.", "milli", 750, 0, []string{"Gyrmyzy", "Gyzyl"}, "44,46,48,50", 5, 15, "Keteni",
		dressStyle{Fabric: "#9C2742", Wall: "#EADDCF", Sleeves: "long", Neck: "round", Skirt: "aline", Pattern: "milli", Accent: "#E8C25A", ArchSide: 0.2}},
	{"merjen.tikincilik", "Gara agşam köýnegi", "Ýönekeý we täsirli agşam köýnegi.", "koynekler", 520, 0, []string{"Gara", "Goýy gyzyl"}, "42,44,46,48", 8, 9, "Krep",
		dressStyle{Fabric: "#18161B", Wall: "#E5DCCE", Sleeves: "long", Neck: "v", Skirt: "mermaid", ArchSide: 0.7}},
	{"mahri.stili", "Gök gündelik köýnek", "Iş we gündelik geýim üçin rahat köýnek.", "koynekler", 340, 0, []string{"Gök", "Ak"}, "S,M,L,XL", 15, 5, "Pagta",
		dressStyle{Fabric: "#8DB3E0", Wall: "#EEE6DC", Sleeves: "puff", Neck: "v", Skirt: "midi", Belt: true, Accent: "#F4F1EA", ArchSide: 0.8}},
	{"mahri.stili", "Gülgüne kokteýl köýnegi", "Kokteýl we doglan gün üçin ýeňil köýnek.", "koynekler", 360, 420, []string{"Gülgüne", "Pudra"}, "S,M,L", 0, 5, "Şifon",
		dressStyle{Fabric: "#E8A0B4", Wall: "#F3E7E1", Sleeves: "none", Neck: "sweetheart", Skirt: "midi", ArchSide: 0.25}},
	{"mahri.stili", "Nokatly ýaz köýnegi", "Retro nokatly köýnek, guşagy bilen.", "koynekler", 310, 0, []string{"Gara", "Gyzyl"}, "S,M,L,XL", 11, 5, "Wiskoza",
		dressStyle{Fabric: "#1E1C22", Wall: "#ECE4D8", Sleeves: "cap", Neck: "round", Skirt: "midi", Pattern: "dots", Accent: "#F2EFE8", Belt: true, ArchSide: 0.75}},
	{"aylar.studio", "Dizaýner palto-köýnek", "Güýz üçin dizaýner köýnek, gyzyl guşakly.", "koynekler", 640, 0, []string{"Krem", "Gara"}, "42,44,46,48", 6, 14, "Ýüň garyndysy",
		dressStyle{Fabric: "#E9DCC6", Wall: "#EAE0D2", Sleeves: "long", Neck: "v", Skirt: "aline", Belt: true, Accent: "#C62828", ArchSide: 0.22}},
	{"aylar.studio", "Mämişi agşam köýnegi", "Ýaz agşamlary üçin açyk reňkli köýnek.", "koynekler", 470, 0, []string{"Mämişi", "Krem"}, "42,44,46", 7, 10, "Atlas",
		dressStyle{Fabric: "#E07A3F", Wall: "#F0E5D8", Sleeves: "none", Neck: "v", Skirt: "aline", ArchSide: 0.78}},
	{"yyldyz.butik", "Ýaşlar üçin gül köýnek", "Ýeňil, gül nagyşly ýaz köýnegi.", "koynekler", 260, 300, []string{"Ak", "Gök"}, "S,M,L", 20, 4, "Pagta",
		dressStyle{Fabric: "#F5F3EE", Wall: "#E6EDF0", Sleeves: "cap", Neck: "square", Skirt: "midi", Pattern: "floral", Accent: "#7FA7D9", ArchSide: 0.2}},
	{"yyldyz.butik", "Gyrmyzy midi köýnek", "Gündelik midi köýnek, rahat biçim.", "koynekler", 290, 0, []string{"Gyrmyzy", "Gara"}, "S,M,L,XL", 10, 4, "Wiskoza",
		dressStyle{Fabric: "#9C2742", Wall: "#EFE6DA", Sleeves: "puff", Neck: "round", Skirt: "midi", ArchSide: 0.75}},
}

var reviewTexts = []string{
	"Örän gowy tikilipdir, ölçegi edil boldy. Sag boluň!",
	"Matasy ýokary hilli, wagtynda eltip berdiler.",
	"Suratdakydan hem owadan eken 😍",
	"Reňki birneme açyk, ýöne gaty halandym.",
	"Toýda hemmeler sorady, nireden aldyň diýip!",
	"Bahasyna görä ajaýyp. Ýene sargyt ederin.",
}

// seedShop creates the demo shops, their products, stories, orders, reviews and views.
func seedShop(db *gorm.DB, store *storage.Storage) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(DemoPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	rnd := uint32(7)
	next := func(n int) int {
		rnd = rnd*1664525 + 1013904223
		return int(rnd>>8) % n
	}

	return db.Transaction(func(tx *gorm.DB) error {
		ids := map[string]uint{}
		for i, b := range businesses {
			var u models.User
			if tx.Where("username = ?", b.username).First(&u).Error != nil {
				u = models.User{Username: b.username, Name: b.name, Bio: b.bio, Email: b.username + "@modahouse.tm", PasswordHash: string(hash)}
				if err := tx.Create(&u).Error; err != nil {
					return err
				}
				tx.Create(&models.Board{UserID: u.ID, Name: "Saklananlar"})
			}
			// Avatar: a close-up of the shop's first dress.
			for _, p := range products {
				if p.biz == b.username {
					url, err := store.WriteFile("seed", fmt.Sprintf("avatar-%s.svg", strings.ReplaceAll(b.username, ".", "-")), []byte(renderDress(p.style, viewZoom, 300, 300)))
					if err != nil {
						return err
					}
					u.AvatarURL = url
					break
				}
			}
			u.IsBusiness, u.Verified, u.Bio, u.Category = true, b.verified, b.bio, b.category
			if err := tx.Save(&u).Error; err != nil {
				return err
			}
			biz := models.Business{UserID: u.ID, Category: b.category, Phone: b.phone, City: b.city, Address: b.city + ", merkezi bazar golaýy",
				Instagram: b.instagram, WorkingHours: b.hours, DeliveryDays: 7, ReturnDays: 14}
			if err := tx.Save(&biz).Error; err != nil {
				return err
			}
			ids[b.username] = u.ID
			_ = i
		}

		// Personal accounts act as buyers.
		var buyers []models.User
		tx.Where("is_business = ?", false).Order("id").Find(&buyers)

		type made struct {
			id    uint
			biz   string
			title string
			image string
			price int
		}
		var all []made
		for i, p := range products {
			images := make([]models.PinImage, 0, 4)
			for v := viewFront; v <= viewBack; v++ {
				url, err := store.WriteFile("seed", fmt.Sprintf("product-%02d-%d.svg", i+1, v), []byte(renderDress(p.style, v, 300, 400)))
				if err != nil {
					return err
				}
				images = append(images, models.PinImage{URL: url, Width: 600, Height: 800, Color: p.style.Wall, Position: int(v)})
			}
			var colors []string
			for _, c := range p.colors {
				colors = append(colors, fmt.Sprintf(`{"name":%q,"hex":%q}`, c, colorHex[c]))
			}
			pin := models.Pin{
				UserID: ids[p.biz], Title: p.title, Description: p.desc, Category: p.category, Tags: "köýnek," + strings.ToLower(p.material),
				ImageURL: images[0].URL, Width: 600, Height: 800, Color: p.style.Wall,
				Price: p.price, OldPrice: p.oldPrice, Colors: "[" + strings.Join(colors, ",") + "]", Sizes: p.sizes,
				DeliveryDays: p.delivery, ReturnDays: 14, Material: p.material,
				CreatedAt: now.Add(-time.Duration(i*9+2) * 24 * time.Hour / 3),
			}
			if p.stock >= 0 {
				st := p.stock
				pin.Stock = &st
			}
			pin.SearchText = search.IndexText(pin.Title, pin.Description, pin.Tags, pin.Category)
			if err := tx.Create(&pin).Error; err != nil {
				return err
			}
			for k := range images {
				images[k].PinID = pin.ID
			}
			if err := tx.Create(&images).Error; err != nil {
				return err
			}
			all = append(all, made{pin.ID, p.biz, p.title, images[0].URL, p.price})
		}

		bizIndex := map[string]demoBusiness{}
		for _, b := range businesses {
			bizIndex[b.username] = b
		}

		// Views: one row per synthetic viewer per day over the last 30 days, plus older history.
		var views []models.PinView
		for _, m := range all {
			base := bizIndex[m.biz].viewsBase
			total := 0
			for d := 0; d < 30; d++ {
				day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -d)
				n := base/6 + next(base/4+1)
				for k := 0; k < n; k++ {
					views = append(views, models.PinView{PinID: m.id, Viewer: fmt.Sprintf("seed:%d", k), Day: day})
				}
				total += n
			}
			tx.Model(&models.Pin{}).Where("id = ?", m.id).Update("views_count", total+base*40)
		}
		if err := tx.CreateInBatches(&views, 500).Error; err != nil {
			return err
		}

		// Likes from buyers, spread over the month.
		for i, m := range all {
			for j, u := range buyers {
				if (i+j)%3 != 0 {
					tx.Create(&models.Like{UserID: u.ID, PinID: m.id, CreatedAt: now.Add(-time.Duration((i*7+j*5)%30) * 24 * time.Hour)})
				}
			}
		}

		// Followers for shops.
		for _, u := range buyers {
			for _, b := range businesses {
				if ids[b.username] != u.ID {
					tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Follow{FollowerID: u.ID, FollowingID: ids[b.username]})
				}
			}
		}

		// Orders: mostly delivered (with reviews), a few still open for the dashboard.
		reviewed := map[string]bool{}
		statuses := []string{models.OrderDelivered, models.OrderDelivered, models.OrderDelivered, models.OrderShipped, models.OrderConfirmed, models.OrderNew}
		k := 0
		for _, b := range businesses {
			var mine []made
			for _, m := range all {
				if m.biz == b.username {
					mine = append(mine, m)
				}
			}
			for n := 0; n < b.orders && len(buyers) > 0; n++ {
				buyer := buyers[(k+n)%len(buyers)]
				m := mine[n%len(mine)]
				qty := 1 + next(2)
				status := statuses[n%len(statuses)]
				created := now.Add(-time.Duration(1+(n*4+k)%28) * 24 * time.Hour)
				pid := m.id
				o := models.Order{BuyerID: buyer.ID, BusinessID: ids[b.username], Status: status, Total: m.price * qty,
					FullName: buyer.Name, Phone: "+993 6" + fmt.Sprintf("%d %06d", 1+next(5), 100000+next(899999)), Address: bizIndex[b.username].city + ", 1-nji köçe, 12-nji jaý",
					CreatedAt: created, UpdatedAt: created,
					Items: []models.OrderItem{{PinID: &pid, Title: m.title, ImageURL: m.image, Price: m.price, Quantity: qty, Color: "", Size: ""}}}
				if err := tx.Create(&o).Error; err != nil {
					return err
				}
				tx.Model(&models.Pin{}).Where("id = ?", m.id).UpdateColumn("orders_count", gorm.Expr("orders_count + 1"))
				if status == models.OrderNew || status == models.OrderConfirmed {
					oid := o.ID
					tx.Create(&models.Notification{UserID: ids[b.username], ActorID: buyer.ID, Type: models.NotifyOrder, PinID: &pid, OrderID: &oid, CreatedAt: created})
				}
				key := fmt.Sprintf("%d-%d", m.id, buyer.ID)
				if status == models.OrderDelivered && !reviewed[key] {
					reviewed[key] = true
					rating := 5
					if (n+k)%4 == 3 {
						rating = 4
					}
					tx.Create(&models.Review{PinID: m.id, UserID: buyer.ID, BusinessID: ids[b.username], Rating: rating,
						Text: reviewTexts[(n+k)%len(reviewTexts)], CreatedAt: created.Add(72 * time.Hour)})
				}
			}
			k += 3
		}

		// Stories (24 hours) from the top shops, linked to a product.
		for i, b := range businesses[:5] {
			for j, m := range all {
				if m.biz != b.username || j%2 == 1 {
					continue
				}
				url, err := store.WriteFile("seed", fmt.Sprintf("story-%d-%d.svg", i, j), []byte(renderDress(products[j].style, viewFront, 300, 533)))
				if err != nil {
					return err
				}
				pid := m.id
				captions := []string{"Täze kolleksiýa geldi! ✨", "Şu hepdäniň iň köp satylany 🔥", "Sargyt üçin DM ýa-da jaň ediň 📞"}
				tx.Create(&models.Story{UserID: ids[b.username], ImageURL: url, Width: 600, Height: 1066, Color: products[j].style.Wall,
					Caption: captions[(i+j)%len(captions)], PinID: &pid, CreatedAt: now.Add(-time.Duration(i+1) * time.Hour), ExpiresAt: now.Add(time.Duration(23-i) * time.Hour)})
				break
			}
		}

		log.Printf("seed: created %d shops with %d products", len(businesses), len(all))
		return nil
	})
}
