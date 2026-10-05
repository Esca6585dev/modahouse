// Package seed fills an empty database with demo users, pins and boards.
package seed

import (
	"fmt"
	"log"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

const DemoPassword = "modahouse123"

type demoUser struct{ username, name, bio string }

var users = []demoUser{
	{"aylar.studio", "Aýlar Studio", "Moda we gündelik stil boýunça ideýalar. Aşgabat"},
	{"ic.bezeg", "Içki Bezeg", "Öýüňizi rahat we owadan etmek üçin ideýalar."},
	{"tagam.tm", "Tagam TM", "Ýönekeý we tagamly reseptler."},
	{"gezelenc", "Gezelenç", "Daglar, deňizler we ýollar."},
	{"renk.lab", "Reňk Lab", "Reňk, görnüş we sungat."},
	{"yasyl.burc", "Ýaşyl Burç", "Öý ösümlikleri we kiçijik baglar."},
}

var authorByCategory = map[string]string{
	"moda": "aylar.studio", "ic-bezeg": "ic.bezeg", "tagamlar": "tagam.tm",
	"syyahat": "gezelenc", "sungat": "renk.lab", "osumlikler": "yasyl.burc",
}

type demoPin struct {
	title, desc, category, kind string
	palette                     int
	tags                        string
}

var pins = []demoPin{
	{"Güýz üçin gatlakly geýim", "Salkyn günler üçin ýeňil we ýyly gatlaklary utgaşdyrmagyň ýönekeý usullary.", "moda", "dress", 4, "güýz,geýim,stil"},
	{"Minimalist myhman otagy", "Az zat, köp ýagtylyk: arassa çyzykly we ýumşak reňkli otag.", "ic-bezeg", "arch", 1, "minimalizm,otag"},
	{"Daglarda gün ýaşmasy", "Agşam ýodasynda iň owadan pursat. Fotoaparatyňyzy unutmaň!", "syyahat", "mountains", 0, "dag,gün ýaşmasy"},
	{"Ýaşyl öý ösümlikleri", "Az aladany talap edýän we otagy janlandyrýan ösümlikler.", "osumlikler", "plant", 8, "ösümlik,öý"},
	{"Ertirlik üçin miweli tabak", "Täze miweler, gatyk we bal bilen 5 minutda taýýar ertirlik.", "tagamlar", "circles", 6, "ertirlik,miwe"},
	{"Abstrakt reňk kompozisiýasy", "Ýumşak görnüşler we pastel reňkler bilen diwar sungaty.", "sungat", "blob", 5, "abstrakt,pastel"},
	{"Zolakly tomus köýnegi", "Tomus günleri üçin ýeňil, howa geçirýän zolakly köýnek.", "moda", "stripes", 3, "tomus,köýnek"},
	{"Deňiz kenarynda dynç alyş", "Tolkunlaryň sesi, ýyly gum we uzyn agşamlar.", "syyahat", "waves", 3, "deňiz,dynç alyş"},
	{"Boho stilindäki ýatylýan otag", "Tebigy dokumalar, ýyly reňkler we arka görnüşli bezegler.", "ic-bezeg", "arch", 4, "boho,ýatylýan otag"},
	{"Kaktus kolleksiýasy", "Penjire öňünde ösdürip boljak kiçijik kaktuslar.", "osumlikler", "plant", 6, "kaktus"},
	{"Agşamlyk köýnek ideýalary", "Toý we baýramçylyklar üçin näzik agşamlyk köýnekler.", "moda", "dress", 7, "köýnek,toý"},
	{"Geometrik diwar suraty", "Tegelekler we çyzyklar bilen döredilen ýönekeý kompozisiýa.", "sungat", "circles", 0, "geometriýa,diwar"},
	{"Gök çaý we desertler", "Myhmanlar üçin ýeňil desertler we hoşboý gök çaý.", "tagamlar", "circles", 8, "çaý,desert"},
	{"Ýaýla ýodasy", "Dag ýodalary boýunça bir günlük gezelenç meýilnamasy.", "syyahat", "mountains", 1, "dag,gezelenç"},
	{"Retro plakat dizaýny", "Ýetmişinji ýyllaryň ruhunda zolakly plakat.", "sungat", "stripes", 6, "retro,plakat"},
	{"Aşhana üçin tebigy reňkler", "Toprak reňkleri aşhanany has ýyly we rahat edýär.", "ic-bezeg", "blob", 4, "aşhana,reňk"},
	{"Ýüpek şarf baglamagyň usullary", "Bir şarf, on dürli görnüş. Gündelik geýim üçin ideýalar.", "moda", "waves", 2, "şarf,aksessuar"},
	{"Balkondaky kiçijik bag", "Kiçi meýdanda gök önüm we gül ösdürmegiň tilsimleri.", "osumlikler", "plant", 1, "balkon,bag"},
	{"Okean tolkunlary", "Mawy reňkiň ähli öwüşginleri bir suratda.", "syyahat", "waves", 3, "okean,mawy"},
	{"Pastel reňkli köýnekler", "Ýaz paslyna laýyk ýumşak we açyk reňkler.", "moda", "dress", 2, "pastel,köýnek,ýaz"},
	{"Gijeki şäher", "Şäheriň ýagtylyklary we ümsüm köçeleri.", "syyahat", "mountains", 7, "şäher,gije"},
	{"Akwarel tehnikasy", "Başlangyçlar üçin akwarel bilen işlemegiň esaslary.", "sungat", "blob", 2, "akwarel"},
	{"Öýde bişirilen çörek", "Tamdyr tagamly ýumşak çörek, ädimme-ädim resept.", "tagamlar", "circles", 4, "çörek,resept"},
	{"Arka görnüşli aýna", "Dälizi giňeldýän we ýagtylandyrýan bezeg aýnasy.", "ic-bezeg", "arch", 9, "aýna,däliz"},
	{"Klassyk palto", "Her möwsümde moda bolup galýan klassyk palto.", "moda", "dress", 9, "palto,klassyk"},
	{"Monstera aladasy", "Monstera ösümligini suwarmak we ýagtylyk boýunça maslahatlar.", "osumlikler", "plant", 8, "monstera"},
	{"Çöl gün dogşy", "Gum depeleriniň üstünde täze günüň başlanyşy.", "syyahat", "mountains", 6, "çöl,gün dogşy"},
	{"Minimal şaý-sepler", "Ýönekeý, ýöne täsirli altyn şaý-sepler.", "moda", "circles", 9, "şaý-sep,altyn"},
	{"Reňkli smuzi", "Üç gatlakly, witaminlere baý miweli smuzi.", "tagamlar", "stripes", 2, "smuzi,witamin"},
	{"Keramika wazalar", "El bilen ýasalan keramika wazalar bilen stol bezegi.", "sungat", "arch", 5, "keramika,waza"},
}

var ratios = []float64{1.4, 1.0, 1.6, 1.25, 1.8, 1.15, 1.5, 0.9}

var boards = []struct {
	name string
	pins []int // 1-based indexes into pins
}{
	{"Güýz geýimleri", []int{1, 11, 25, 20, 7}},
	{"Arzuw öýi", []int{2, 9, 24, 16}},
	{"Syýahat sanawy", []int{3, 8, 14, 19, 21, 27}},
	{"Reseptler", []int{5, 13, 23, 29}},
	{"Ilham", []int{6, 12, 15, 22, 30}},
	{"Ösümliklerim", []int{4, 10, 18, 26}},
}

var comments = []struct {
	pin  int
	user string
	text string
}{
	{1, "gezelenc", "Örän owadan! Reňkleri haýsy programmada saýladyňyz?"},
	{1, "renk.lab", "Men hem şuňa meňzeş zat edip görjek. Ideýa üçin sag boluň 🙌"},
	{3, "aylar.studio", "Bu ýer nirede? Indiki syýahatym üçin belläp goýdum."},
	{5, "yasyl.burc", "Ertirlik üçin ajaýyp ideýa!"},
	{12, "ic.bezeg", "Myhman otagymyň diwaryna laýyk gelýär."},
	{26, "tagam.tm", "Meniň monsteram hem edil şeýle ösýär 🌿"},
}

// Run seeds the database only when it has no users yet.
func Run(db *gorm.DB, store *storage.Storage) error {
	var n int64
	db.Model(&models.User{}).Count(&n)
	if n > 0 {
		return nil
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(DemoPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	return db.Transaction(func(tx *gorm.DB) error {
		ids := map[string]uint{}
		for _, u := range users {
			m := models.User{Username: u.username, Name: u.name, Bio: u.bio, Email: u.username + "@modahouse.tm", PasswordHash: string(hash)}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
			ids[u.username] = m.ID
			if err := tx.Create(&models.Board{UserID: m.ID, Name: "Saklananlar"}).Error; err != nil {
				return err
			}
		}

		now := time.Now()
		pinIDs := make([]uint, len(pins))
		for i, p := range pins {
			svg, w, h := renderArt(p.kind, p.palette, ratios[i%len(ratios)])
			url, err := store.WriteFile("seed", fmt.Sprintf("pin-%02d.svg", i+1), []byte(svg))
			if err != nil {
				return err
			}
			m := models.Pin{
				UserID: ids[authorByCategory[p.category]], Title: p.title, Description: p.desc, Category: p.category,
				Tags: p.tags, ImageURL: url, Width: w, Height: h, Color: palettes[p.palette][0],
				SearchText: strings.ToLower(p.title + " " + p.desc + " " + p.tags),
				CreatedAt:  now.Add(-time.Duration(i) * time.Hour),
			}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
			pinIDs[i] = m.ID
		}

		owner := ids["aylar.studio"]
		for _, b := range boards {
			m := models.Board{UserID: owner, Name: b.name}
			if err := tx.Create(&m).Error; err != nil {
				return err
			}
			for _, idx := range b.pins {
				if err := tx.Create(&models.BoardPin{BoardID: m.ID, PinID: pinIDs[idx-1]}).Error; err != nil {
					return err
				}
			}
		}

		for _, c := range comments {
			if err := tx.Create(&models.Comment{PinID: pinIDs[c.pin-1], UserID: ids[c.user], Text: c.text}).Error; err != nil {
				return err
			}
		}

		// Everyone likes a deterministic spread of pins; follows form a small network.
		for ui, u := range users {
			for pi := range pinIDs {
				if (pi+ui)%4 == 0 {
					if err := tx.Create(&models.Like{UserID: ids[u.username], PinID: pinIDs[pi]}).Error; err != nil {
						return err
					}
				}
			}
			if u.username != "aylar.studio" {
				tx.Create(&models.Follow{FollowerID: ids[u.username], FollowingID: owner})
			}
		}
		tx.Create(&models.Follow{FollowerID: owner, FollowingID: ids["gezelenc"]})
		tx.Create(&models.Follow{FollowerID: owner, FollowingID: ids["renk.lab"]})
		tx.Create(&models.Notification{UserID: owner, ActorID: ids["gezelenc"], Type: models.NotifyComment, PinID: &pinIDs[0]})
		tx.Create(&models.Notification{UserID: owner, ActorID: ids["renk.lab"], Type: models.NotifyFollow})

		log.Printf("seed: created %d users, %d pins (password %q)", len(users), len(pins), DemoPassword)
		return nil
	})
}
