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
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

// fashionArt draws the category illustrations (art_fashion.go).
var fashionArt = renderFashionArt

type creator struct{ username, name, bio, focus string }

var creators = []creator{
	{"aysoltan.style", "Aýsoltan", "Toý köýnekleri we agşam obrazlary 💃 Aşgabat", "toy"},
	{"jeren.style", "Jeren", "Gündelik moda we ýönekeý obrazlar", "gundelik"},
	{"bahar.gozel", "Bahar", "Milli köýnekler we keşdeler 🌸", "milli"},
	{"selbi.saclar", "Selbi", "Saç düzümleri: örüm, topbak, tolkun ✨", "sac"},
	{"leyli.makiyaj", "Leýli", "Makiýaž ussasy. Toý we gündelik makiýaž", "makiyaj"},
	{"nurana.nails", "Nurana", "Dyrnak dizaýny 💅 Sargyt üçin DM", "dyrnak"},
	{"aygul.kesde", "Aýgül", "El keşdesi — ejemden galan sungat", "keshde"},
	{"gulalek.milli", "Gülälek", "Türkmen milli lybaslary we ýakalar", "yaka"},
	{"maysa.gelin", "Maýsa", "Gelin bolmaga taýýarlyk: ideýalar we maslahatlar 👰", "gelin"},
	{"ogulnabat", "Ogulnabat", "Şaý-sepler we kümüş bezegler", "shay"},
	{"yazgul.stil", "Ýazgül", "Aksessuarlar we sumkalar", "aksessuar"},
	{"enejan.moda", "Enejan", "Toý we baýramçylyk köýnekleri", "toy"},
	{"sona.daily", "Sona", "Her gün täze obraz", "gundelik"},
	{"dunya.moda", "Dünýä", "Ýaka fasonlary we tikin ideýalary", "yaka"},
	{"aybolek", "Aýbölek", "Keşdeli köýnekler we milli nagyşlar", "keshde"},
	{"zyba.style", "Zyba", "Saç we makiýaž ideýalary", "sac"},
	{"mahym.fason", "Mähim", "Köýnek fasonlary we matalar", "koynekler"},
	{"lale.art", "Läle", "Dyrnak sungaty we reňkler", "dyrnak"},
	{"gunca.moda", "Gunça", "Gelin we toý obrazlary", "gelin"},
	{"arzuw.stil", "Arzuw", "Şaý-sep we aksessuar saýlamak", "shay"},
}

type extraBusiness struct {
	demoBusiness
	listing string // what its products are: rent, custom, sale
	kind    string // art kind for products
	cat     string
}

var extraBusinesses = []extraBusiness{
	{demoBusiness{"altyn.gelin", "Altyn Gelin Salony", "Gelin köýnekleri kärendä we satlyga. Synap görmek mugt 👰", "rental", "Aşgabat", "+993 65 778800", "10:00-20:00", "altyn.gelin", true, 34, 0}, "rent", "", "gelin"},
	{demoBusiness{"kesde.atelye", "Keşde Atelýesi", "Ölçegiňize görä milli köýnek we el keşdesi ✂️", "atelier", "Mary", "+993 63 221100", "09:00-18:00", "kesde.atelye", true, 28, 0}, "custom", "", "milli"},
	{demoBusiness{"kumush.shay", "Kümüş Şaý", "Türkmen kümüş şaý-sepleri, el işi", "jewelry", "Aşgabat", "+993 61 330044", "10:00-19:00", "kumush.shay", false, 22, 0}, "sale", "shay", "shay"},
	{demoBusiness{"gozel.salon", "Gözel Salon", "Saç, makiýaž we dyrnak. Gelin bezegi 💄", "beauty", "Türkmenabat", "+993 62 909090", "09:00-21:00", "gozel.salon", false, 20, 0}, "custom", "makiyaj", "makiyaj"},
}

type postTemplate struct {
	titles []string
	lines  []string
	tags   []string
	count  int
	art    string // fashionArt kind, or "dress"
}

var postTemplates = map[string]postTemplate{
	"toy": {count: 18, art: "dress",
		titles: []string{"Toý üçin agşam köýnegi", "Ýalpyldawuk atlas köýnek", "Uzyn ýeňli toý köýnegi", "Barhat agşam köýnegi", "Gyzyl toý obrazy", "Şifon toý köýnegi", "Ýeňil ýaz toý köýnegi", "Altyn guşakly köýnek", "Toýda gelişjek fason"},
		lines:  []string{"Dogan toýy üçin saýladym, gaty rahat eken 😍", "Reňki edil suratdaky ýaly, matasy ýumşak.", "Şu fasony tikinçä görkezdim, edil şeýle tikdi!", "Toý möwsümine iň gowy saýlaw ✨", "Ýeňi, ýakasy we etegi — hemmesi gelişýär."},
		tags:   []string{"toýköýnek", "agşamköýnek", "toý", "türkmenmoda"}},
	"gelin": {count: 14, art: "dress-white",
		titles: []string{"Dantelli gelin köýnegi", "Nika köýnegi", "Ak gelin lybasy", "Gelin alyşyk köýnegi", "Ýönekeý we näzik nika köýnegi", "Uzyn etekli gelin köýnegi"},
		lines:  []string{"Gelinlik arzuwym şeýle köýnekdi 🤍", "Dantel işleri el bilen tikilipdir.", "Nika güni üçin iň gowy saýlaw.", "Synap gördüm — duýgularymy aýdyp bilemok 😭"},
		tags:   []string{"gelinlik", "gelinköýnek", "nika", "toý"}},
	"milli": {count: 16, art: "dress-milli",
		titles: []string{"Milli nagyşly köýnek", "Keteni köýnek", "Gyrmyzy keteni", "Keşdeli milli köýnek", "Ýaşyl milli köýnek", "Gülýaka bilen milli lybas"},
		lines:  []string{"Ejemiň keşdesi bilen bezeldi 🧵", "Milli lybas her wagt gelişýär.", "Keteni matanyň reňki täsin!", "Baýramçylyk üçin taýýarladym."},
		tags:   []string{"milliköýnek", "keteni", "türkmenlibasy", "milli"}},
	"koynekler": {count: 12, art: "dress",
		titles: []string{"Gündelik köýnek", "Gül nagyşly köýnek", "Midi köýnek", "Zolakly ýaz köýnegi", "Pagta köýnek", "Ofis üçin köýnek"},
		lines:  []string{"Her gün geýmek üçin rahat.", "Matasy howa geçirýär, tomus üçin ajaýyp.", "Şu fasony köp soradyňyz — ine!", "Reňkleri ýumşak we arassa."},
		tags:   []string{"köýnek", "moda", "stil", "fason"}},
	"yaka": {count: 16, art: "yaka",
		titles: []string{"Keşdeli ýaka", "V ýaka fasony", "Tegelek ýaka keşde bilen", "Dik ýaka", "Inedördül ýaka dantel bilen", "Gaýyk ýaka", "Ýürek görnüşli ýaka"},
		lines:  []string{"Tikinçä görkezmek üçin saklaň 📌", "Ýaka köýnegiň ruhy!", "Şu ýaka milli köýnekde has gowy görünýär.", "Haýsy ýakany halaýarsyňyz? Teswirde ýazyň 👇"},
		tags:   []string{"ýakafason", "ýakakeşde", "tikin", "fason"}},
	"keshde": {count: 18, art: "keshde",
		titles: []string{"El keşdesi", "Gül nagyşly keşde", "Goçak nagyşly keşde", "Ýylan yz keşdesi", "Sapak bilen keşde", "Altyn sapakly keşde", "Gyzyl-ýaşyl keşde"},
		lines:  []string{"Bu keşde üçin bir hepde işledim 🧵", "Nagyşlaryň her biriniň manysy bar.", "Ejemden öwrenen nagyşym.", "Keşde sungaty ýaşaýar! ❤️"},
		tags:   []string{"elkeşde", "keşde", "elişi", "türkmennagyş"}},
	"gundelik": {count: 12, art: "gundelik",
		titles: []string{"Gündelik obraz", "Hepdäniň obrazy", "Ýaz obrazy", "Ofis obrazy", "Gezelenç üçin obraz"},
		lines:  []string{"Ýönekeý, ýöne täsirli.", "Reňkleri utgaşdyrmagy öwreneliň!", "Bu obraz bilen bütin gün rahat.", "Haýsy obrazy halaýarsyňyz?"},
		tags:   []string{"gündelikmoda", "obraz", "stil", "moda"}},
	"sac": {count: 16, art: "sac",
		titles: []string{"Iki örüm", "Topbak saç", "Tolkunly saç", "Örüm täç", "Ýarym ýygnalan saç", "Tahýa bilen örüm", "Ýaglyk bilen saç düzümi"},
		lines:  []string{"Toý üçin 15 minutda taýýar!", "Uzyn saçlylar üçin iň gowy ideýa 💇‍♀️", "Ädimme-ädim wideosyny goýaýynmy?", "Ejemiň öwreden örümi."},
		tags:   []string{"saçdüzüm", "örüm", "saç", "gözellik"}},
	"makiyaj": {count: 14, art: "makiyaj",
		titles: []string{"Toý makiýažy", "Ýumşak gündelik makiýaž", "Göz makiýažy", "Gyzyl dodak", "Agşam makiýažy", "Makiýaž palitrasy"},
		lines:  []string{"Gelin makiýažy üçin ideýa 💄", "Tebigy görnüş — iň gowusy.", "Bu reňkler güýz üçin ajaýyp.", "Haýsy palitrany ulanýarsyňyz?"},
		tags:   []string{"makiýaž", "gözellik", "makeup", "toýmakiýaž"}},
	"dyrnak": {count: 14, art: "dyrnak",
		titles: []string{"Fransuz dyrnak", "Gül nagyşly dyrnak", "Ombre dyrnak", "Ýalpyldawuk dyrnak", "Gyrmyzy mat dyrnak", "Milli nagyşly dyrnak"},
		lines:  []string{"Toý möwsümi üçin 💅", "Ussama şu suraty görkezdim.", "Ýönekeý we owadan.", "Reňki gaty halandym!"},
		tags:   []string{"dyrnak", "dyrnakdizaýny", "manikýur", "gözellik"}},
	"shay": {count: 14, art: "shay",
		titles: []string{"Kümüş bilezik", "Gupba", "Gülýaka", "Altyn ýüzük", "Gyzyl daşly şaý", "Gelin şaý-sepleri"},
		lines:  []string{"Mamamdan galan kümüş şaý ✨", "Türkmen şaý-sepleri — hakyky sungat.", "Gelin üçin doly toplum.", "Daşy gyzyl akyk."},
		tags:   []string{"şaýsep", "kümüş", "türkmenşaý", "gelinşaý"}},
	"aksessuar": {count: 10, art: "aksessuar",
		titles: []string{"Agşam sumkasy", "Ýüpek ýaglyk", "Klassyk aýakgap", "Guşak we sumka", "Gün äýnegi"},
		lines:  []string{"Obrazy aksessuar tamamlaýar 👜", "Bu sumka her köýnege gelişýär.", "Ýaz üçin täze tapyndy!", "Bahasy elýeterli, hili ýokary."},
		tags:   []string{"aksessuar", "sumka", "stil", "moda"}},
}

var commentPool = []string{
	"Örän owadan! 😍", "Nireden aldyňyz?", "Men hem şeýle isleýän!", "Bahasy näçe?", "Ajaýyp iş 👏", "Tagtama sakladym 📌",
	"Reňki täsin eken", "Toýuma edil şeýle isleýärin!", "Ussanyň belgisini berip bilersiňizmi?", "Gaty gelişýär ❤️",
	"Haýsy şäherde?", "Sargyt edip bolýarmy?", "Ejeme görkezdim, halady 😊", "Indiki toýa şuny geýjek!",
}

var palettesDress = [][3]string{ // fabric, wall, accent
	{"#7B1E3A", "#EADBC8", "#C9A227"}, {"#C62828", "#EFE3D6", "#F2C14E"}, {"#1F6F5C", "#E3DACB", "#C9A227"}, {"#E7C1B5", "#F1E6DC", "#B5838D"},
	{"#7FA7D9", "#E7E1D8", "#F4F1EA"}, {"#1C1A1F", "#E8DED1", "#C9A227"}, {"#9C2742", "#EADDCF", "#E8C25A"}, {"#E8A0B4", "#F3E7E1", "#FFFFFF"},
	{"#D8B65A", "#EFE4D2", "#F6E7B0"}, {"#5E3B6E", "#ECE2EA", "#E8C25A"}, {"#E07A3F", "#F0E5D8", "#7B1E3A"}, {"#2E4A7D", "#E6E3DC", "#D9A441"},
}

func randomDress(seed uint32) dressStyle {
	r := seed*2654435761 + 12345
	next := func(n int) int {
		r = r*1664525 + 1013904223
		return int(r>>8) % n
	}
	p := palettesDress[next(len(palettesDress))]
	return dressStyle{
		Fabric: p[0], Wall: p[1], Accent: p[2],
		Sleeves:  []string{"long", "puff", "none", "cap"}[next(4)],
		Neck:     []string{"square", "v", "round", "sweetheart"}[next(4)],
		Skirt:    []string{"aline", "ball", "mermaid", "midi"}[next(4)],
		Pattern:  []string{"", "", "floral", "dots", "lace"}[next(5)],
		Belt:     next(3) == 0,
		ArchSide: []float64{0.2, 0.25, 0.75, 0.8}[next(4)],
	}
}

func artFor(kind string, i int) string {
	switch kind {
	case "dress":
		return renderDress(randomDress(uint32(i*7+1)), viewFront, 300, 400+float64((i%4)*35))
	case "dress-white":
		st := randomDress(uint32(i*11 + 3))
		st.Fabric, st.Pattern, st.Accent = []string{"#F3EEE6", "#FAF7F2", "#F1E6D6"}[i%3], "lace", "#D9CBB5"
		if st.Skirt == "midi" {
			st.Skirt = "ball"
		}
		return renderDress(st, view(i%2), 300, 400+float64((i%3)*40))
	case "dress-milli":
		st := randomDress(uint32(i*13 + 5))
		st.Pattern, st.Belt = "milli", true
		st.Fabric = []string{"#1F6F5C", "#9C2742", "#7B1E3A", "#1C1A1F", "#2E4A7D"}[i%5]
		st.Accent = []string{"#C9A227", "#E8C25A", "#F2C14E"}[i%3]
		return renderDress(st, view(i%2), 300, 400+float64((i%3)*40))
	default:
		h := []float64{400, 300, 450, 380, 520}[i%5]
		return fashionArt(kind, i, 300, h)
	}
}

// seedFashion adds the Turkmen fashion community: creators, ~170 posts, comments,
// likes, boards, more businesses with rent/custom/sale listings, and reels.
func seedFashion(db *gorm.DB, store *storage.Storage) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(DemoPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	rnd := uint32(2026)
	next := func(n int) int {
		rnd = rnd*1664525 + 1013904223
		return int(rnd>>8) % n
	}

	return db.Transaction(func(tx *gorm.DB) error {
		ids := map[string]uint{}
		var people []uint
		for i, c := range creators {
			u := models.User{Username: c.username, Name: c.name, Bio: c.bio, Email: c.username + "@modahouse.tm", PasswordHash: string(hash)}
			if err := tx.Where("username = ?", c.username).FirstOrCreate(&u).Error; err != nil {
				return err
			}
			avatar, err := store.WriteFile("seed", fmt.Sprintf("creator-%02d.svg", i), []byte(fashionArt(c.focus, i+100, 300, 300)))
			if err != nil {
				return err
			}
			tx.Model(&u).Update("avatar_url", avatar)
			tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Board{UserID: u.ID, Name: "Saklananlar"})
			ids[c.username] = u.ID
			people = append(people, u.ID)
		}

		// Extra businesses: bridal rental, atelier, jeweller, beauty salon.
		for i, eb := range extraBusinesses {
			b := eb.demoBusiness
			u := models.User{Username: b.username, Name: b.name, Bio: b.bio, Email: b.username + "@modahouse.tm", PasswordHash: string(hash), IsBusiness: true, Verified: b.verified}
			if err := tx.Where("username = ?", b.username).FirstOrCreate(&u).Error; err != nil {
				return err
			}
			kind := eb.kind
			avatarArt := ""
			if kind == "" {
				avatarArt = renderDress(randomDress(uint32(i*5+9)), viewZoom, 300, 300)
			} else {
				avatarArt = fashionArt(kind, i+200, 300, 300)
			}
			avatar, err := store.WriteFile("seed", fmt.Sprintf("biz-%s.svg", strings.ReplaceAll(b.username, ".", "-")), []byte(avatarArt))
			if err != nil {
				return err
			}
			tx.Model(&u).Updates(map[string]any{"avatar_url": avatar, "is_business": true, "verified": b.verified})
			tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Board{UserID: u.ID, Name: "Saklananlar"})
			biz := models.Business{UserID: u.ID, Category: b.category, Phone: b.phone, City: b.city, Address: b.city + ", Magtymguly şaýoly",
				Instagram: b.instagram, Whatsapp: b.phone, Telegram: b.instagram, Imo: b.phone, WorkingHours: b.hours, DeliveryDays: 5, ReturnDays: 7}
			if err := tx.Save(&biz).Error; err != nil {
				return err
			}
			ids[b.username] = u.ID
		}

		// Listings of the extra businesses.
		type listing struct {
			biz, title, desc, cat, typ string
			price, deposit, minDays    int
			readyDays                  int
		}
		listings := []listing{
			{"altyn.gelin", "Dantelli gelin köýnegi — kärende", "Uzyn ýeňli, dantelli gelin köýnegi. Arassalanan, täze ýaly. Synap görmek mugt.\n#gelinköýnek #kärende", "gelin", "rent", 350, 800, 2, 0},
			{"altyn.gelin", "Ak nika köýnegi — kärende", "Ýeňil we näzik nika köýnegi. Ölçegleri: 42-46.\n#nika #kärende", "gelin", "rent", 250, 500, 1, 0},
			{"altyn.gelin", "Gelin alyşyk lybasy", "Altyn öwüşginli lybas, gelin alyşyk üçin.\n#gelinlik #toý", "gelin", "rent", 300, 600, 2, 0},
			{"altyn.gelin", "Toý üçin agşam köýnegi", "Gyz dogan üçin agşam köýnegi kärende.\n#toýköýnek #kärende", "toy", "rent", 150, 300, 1, 0},
			{"kesde.atelye", "Ölçegiňize görä milli köýnek", "Keteni ýa-da ýüpek matadan, el keşdeli ýaka bilen.\n#milliköýnek #tikinçi", "milli", "custom", 900, 0, 0, 14},
			{"kesde.atelye", "Keşdeli ýaka tikmek", "Köne köýnegiňize täze keşdeli ýaka.\n#ýakakeşde #elkeşde", "yaka", "custom", 250, 0, 0, 7},
			{"kesde.atelye", "Toý köýnegini tikmek", "Isleýän fasonyňyzy getiriň — bilelikde tikeliň.\n#toýköýnek #tikinçi", "toy", "custom", 1200, 0, 0, 21},
			{"kumush.shay", "Kümüş bilezik", "El bilen ýasalan kümüş bilezik, gyzyl akyk daşly.\n#kümüş #şaýsep", "shay", "sale", 850, 0, 0, 0},
			{"kumush.shay", "Gülýaka toplumy", "Gelin üçin gülýaka we gupba toplumy.\n#gelinşaý #türkmenşaý", "shay", "sale", 2400, 0, 0, 0},
			{"kumush.shay", "Kümüş ýüzük", "Ýönekeý we täsirli kümüş ýüzük.\n#kümüş", "shay", "sale", 320, 0, 0, 0},
			{"gozel.salon", "Gelin makiýažy", "Toý güni üçin doly gelin bezegi: makiýaž we saç.\n#toýmakiýaž #gelinlik", "makiyaj", "custom", 600, 0, 0, 1},
			{"gozel.salon", "Örüm we saç düzümi", "Toý we baýramçylyk üçin saç düzümleri.\n#saçdüzüm #örüm", "sac", "custom", 200, 0, 0, 1},
			{"gozel.salon", "Dyrnak dizaýny", "Gel-lak we dizaýn, 1 sagat.\n#dyrnakdizaýny", "dyrnak", "custom", 150, 0, 0, 1},
		}
		for i, l := range listings {
			var art string
			switch l.cat {
			case "gelin":
				art = artFor("dress-white", i)
			case "milli":
				art = artFor("dress-milli", i)
			case "toy":
				art = artFor("dress", i+50)
			default:
				art = fashionArt(l.cat, i+300, 300, 400)
			}
			url, err := store.WriteFile("seed", fmt.Sprintf("listing-%02d.svg", i), []byte(art))
			if err != nil {
				return err
			}
			p := models.Pin{UserID: ids[l.biz], Title: l.title, Description: l.desc, Category: l.cat, ListingType: l.typ,
				Price: l.price, Deposit: l.deposit, MinDays: l.minDays, ReadyDays: l.readyDays, ReturnDays: 7, DeliveryDays: 3,
				ImageURL: url, Width: 600, Height: 800, Color: "#EADBC8", CreatedAt: now.Add(-time.Duration(i*5+1) * time.Hour)}
			p.Tags = strings.Join(captionHashtags(l.desc), ",")
			p.SearchText = strings.ToLower(p.Title + " " + p.Description + " " + p.Tags)
			if err := tx.Create(&p).Error; err != nil {
				return err
			}
			tx.Create(&models.PinImage{PinID: p.ID, Kind: "image", URL: url, Width: 600, Height: 800, Color: "#EADBC8"})

			// Engagement so the new shops appear in the ranking.
			var views []models.PinView
			for d := 0; d < 30; d++ {
				day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -d)
				for v := 0; v < 2+next(6); v++ {
					views = append(views, models.PinView{PinID: p.ID, Viewer: fmt.Sprintf("seed:%d", v), Day: day})
				}
			}
			if err := tx.CreateInBatches(&views, 500).Error; err != nil {
				return err
			}
			tx.Model(&p).UpdateColumn("views_count", len(views)+400+next(800))
			for j := 0; j < 3+next(8); j++ {
				tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Like{UserID: people[next(len(people))], PinID: p.ID,
					CreatedAt: now.Add(-time.Duration(next(20*24)) * time.Hour)})
			}
		}

		// Community posts.
		var postIDs []uint
		i := 0
		for _, cat := range []string{"toy", "gelin", "milli", "koynekler", "yaka", "keshde", "gundelik", "sac", "makiyaj", "dyrnak", "shay", "aksessuar"} {
			tpl := postTemplates[cat]
			var authors []creator
			for _, c := range creators {
				if c.focus == cat {
					authors = append(authors, c)
				}
			}
			if len(authors) == 0 {
				authors = creators
			}
			for k := 0; k < tpl.count; k++ {
				i++
				a := authors[k%len(authors)]
				title := tpl.titles[k%len(tpl.titles)]
				if k >= len(tpl.titles) {
					title += []string{" ✨", " — täze", " ideýasy", " 2"}[k%4]
				}
				tags := append([]string{}, tpl.tags...)
				desc := tpl.lines[(k+i)%len(tpl.lines)] + "\n#" + strings.Join(tags[:3], " #")
				svg := artFor(tpl.art, i)
				h := 800
				if idx := strings.Index(svg, `height="`); idx > 0 {
					fmt.Sscanf(svg[idx+8:], "%d", &h)
				}
				url, err := store.WriteFile("seed", fmt.Sprintf("post-%03d.svg", i), []byte(svg))
				if err != nil {
					return err
				}
				p := models.Pin{UserID: ids[a.username], Title: title, Description: desc, Category: cat, ListingType: "post",
					Tags: strings.Join(tags, ","), ImageURL: url, Width: 600, Height: h, Color: "#EFE6DC",
					CreatedAt: now.Add(-time.Duration(i*3+next(3)) * time.Hour), ViewsCount: 40 + next(900)}
				p.SearchText = strings.ToLower(p.Title + " " + p.Description + " " + p.Tags)
				if err := tx.Create(&p).Error; err != nil {
					return err
				}
				tx.Create(&models.PinImage{PinID: p.ID, Kind: "image", URL: url, Width: 600, Height: h, Color: "#EFE6DC"})
				postIDs = append(postIDs, p.ID)

				// Engagement.
				for j := 0; j < 2+next(9); j++ {
					tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Like{UserID: people[next(len(people))], PinID: p.ID,
						CreatedAt: p.CreatedAt.Add(time.Duration(1+next(48)) * time.Hour)})
				}
				for j := 0; j < next(4); j++ {
					tx.Create(&models.Comment{PinID: p.ID, UserID: people[next(len(people))], Text: commentPool[next(len(commentPool))],
						CreatedAt: p.CreatedAt.Add(time.Duration(1+next(24)) * time.Hour)})
				}
			}
		}

		// Creators follow each other and the shops; boards with saved posts.
		var shopIDs []uint
		tx.Model(&models.User{}).Where("is_business = ?", true).Pluck("id", &shopIDs)
		for k, u := range people {
			for j := 1; j <= 5; j++ {
				tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Follow{FollowerID: u, FollowingID: people[(k+j*3)%len(people)]})
			}
			for j, s := range shopIDs {
				if (k+j)%2 == 0 && s != u {
					tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Follow{FollowerID: u, FollowingID: s})
				}
			}
			for b, name := range []string{"Toý ideýalary", "Saç we makiýaž"} {
				board := models.Board{UserID: u, Name: name}
				tx.Create(&board)
				for j := 0; j < 6; j++ {
					tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.BoardPin{BoardID: board.ID, PinID: postIDs[(k*7+j*11+b*3)%len(postIDs)]})
				}
			}
		}

		if err := seedReels(tx, store, ids, people, now); err != nil {
			return err
		}
		log.Printf("seed: added %d creators, %d posts and %d listings", len(creators), len(postIDs), len(listings))
		return nil
	})
}

func captionHashtags(s string) []string {
	var out []string
	for _, w := range strings.Fields(s) {
		if strings.HasPrefix(w, "#") && len(w) > 2 {
			out = append(out, strings.ToLower(strings.TrimPrefix(w, "#")))
		}
	}
	return out
}

type demoReel struct {
	author, title, desc, category string
}

// The clips in assets/reels, in file order (reel-1 … reel-8).
var demoReels = []demoReel{
	{"aysoltan.style", "Toý köýnegi hereketde ✨", "Matasy nähili akýar — görüň! #toýköýnek #reels #türkmenmoda", "toy"},
	{"aygul.kesde", "Gül nagşyny tikýärin 🧵", "Bir gülüň dünýä inişi. #elkeşde #keşde #reels", "keshde"},
	{"ogulnabat", "Mamamyň şaý-sepleri", "Gupba, bilezik, gülýaka — hemmesi el işi. #şaýsep #kümüş #reels", "shay"},
	{"nurana.nails", "5 dyrnak dizaýny 💅", "Haýsysyny saýlaýarsyňyz? Teswirde ýazyň! #dyrnak #dyrnakdizaýny #reels", "dyrnak"},
	{"selbi.saclar", "Iki örüm we çaçbag", "Türkmen gyzlarynyň iň owadan saç düzümi. #örüm #saçdüzüm #reels", "sac"},
	{"aybolek", "Keşdeli matanyň owadanlygy", "Ýakyndan görüň — her sapak el bilen. #elkeşde #milli #reels", "keshde"},
	{"mahym.fason", "Täze kolleksiýa", "Bu möwsümiň iň owadan köýnekleri. #köýnek #moda #reels", "koynekler"},
	{"leyli.makiyaj", "Üç makiýaž obrazy", "Gündelikden toý makiýažyna çenli. #makiýaž #gözellik #reels", "makiyaj"},
}

// seedReels publishes the generated demo clips as video posts and stories.
func seedReels(tx *gorm.DB, store *storage.Storage, ids map[string]uint, people []uint, now time.Time) error {
	for i, r := range demoReels {
		n := i + 1
		video, err := reelFS.ReadFile(fmt.Sprintf("assets/reels/reel-%d.webm", n))
		if err != nil {
			return err
		}
		poster, err := reelFS.ReadFile(fmt.Sprintf("assets/reels/reel-%d.jpg", n))
		if err != nil {
			return err
		}
		videoURL, err := store.WriteFile("seed", fmt.Sprintf("reel-%d.webm", n), video)
		if err != nil {
			return err
		}
		posterURL, err := store.WriteFile("seed", fmt.Sprintf("reel-%d.jpg", n), poster)
		if err != nil {
			return err
		}
		p := models.Pin{UserID: ids[r.author], Title: r.title, Description: r.desc, Category: r.category, ListingType: "post",
			Tags: strings.Join(captionHashtags(r.desc), ","), ImageURL: posterURL, Width: 360, Height: 640, Color: "#2B2328",
			HasVideo: true, ViewsCount: 300 + i*157, CreatedAt: now.Add(-time.Duration(i*5+2) * time.Hour)}
		p.SearchText = strings.ToLower(p.Title + " " + p.Description + " " + p.Tags)
		if err := tx.Create(&p).Error; err != nil {
			return err
		}
		if err := tx.Create(&models.PinImage{PinID: p.ID, Kind: "video", URL: videoURL, PosterURL: posterURL, Duration: 6.07,
			Width: 360, Height: 640, Color: "#2B2328"}).Error; err != nil {
			return err
		}
		for j := 0; j < 6+i; j++ {
			tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.Like{UserID: people[(i*3+j)%len(people)], PinID: p.ID})
		}
		tx.Create(&models.Comment{PinID: p.ID, UserID: people[(i+5)%len(people)], Text: commentPool[i%len(commentPool)]})
		// Video stories from three of the creators.
		if i%3 == 0 {
			pid := p.ID
			tx.Create(&models.Story{UserID: ids[r.author], ImageURL: posterURL, VideoURL: videoURL, Width: 360, Height: 640,
				Color: "#2B2328", Caption: r.title, PinID: &pid, CreatedAt: now.Add(-time.Duration(i+1) * time.Hour),
				ExpiresAt: now.Add(time.Duration(20-i) * time.Hour)})
		}
	}
	return nil
}
