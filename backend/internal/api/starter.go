package api

import (
	"context"
	"log"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
)

// starterSearch is one Wikimedia Commons file search of the starter pack.
type starterSearch struct {
	Query    string // CirrusSearch query over files
	Category string // ModaHouse category
	Tags     string
}

// starterPack fills an empty ModaHouse with real, openly licensed fashion
// photos (CC0 / CC BY / CC BY-SA, credited on each post) under @modahouse.
var starterPack = []starterSearch{
	{"Turkmen national dress woman", "milli", "fason,milli köýnek,türkmen"},
	{"Turkmen women traditional clothing", "milli", "fason,milli köýnek,türkmen"},
	{"Turkmen wedding bride", "gelin", "gelin,toý,türkmen"},
	{"Turkmen embroidery", "keshde", "keşde,el keşdesi,türkmen"},
	{"Turkmen jewelry silver", "shay", "şaý-sep,kümüş,türkmen"},
	{"Central Asian ikat dress", "milli", "fason,atlas,ikat"},
	{"Uzbek national dress atlas", "milli", "fason,atlas,milli köýnek"},
	{"suzani embroidery", "keshde", "keşde,suzani"},
	{"embroidered dress", "koynekler", "fason,köýnek,keşde"},
	{"evening gown fashion show", "toy", "fason,agşam köýnegi,toý"},
	{"ball gown", "toy", "fason,toý köýnegi"},
	{"wedding dress bride", "gelin", "gelin,gelin köýnegi"},
	{"maxi dress fashion", "koynekler", "fason,uzyn köýnek"},
	{"silk dress fashion", "koynekler", "fason,ýüpek köýnek"},
	{"velvet dress", "koynekler", "fason,barhat köýnek"},
	{"kaftan dress", "koynekler", "fason,kaftan"},
	{"dress collar embroidery", "yaka", "ýaka,fason,keşde"},
	{"women casual fashion street style", "gundelik", "gündelik,obraz"},
	{"braided hairstyle", "sac", "saç,örüm"},
	{"bridal hairstyle", "sac", "saç,gelin"},
	{"bridal makeup", "makiyaj", "makiýaž,gelin"},
	{"nail art manicure", "dyrnak", "dyrnak,manikýur"},
	{"headscarf fashion", "aksessuar", "ýaglyk,aksessuar"},
	{"handbag fashion", "aksessuar", "sumka,aksessuar"},
}

// StarterStatus reports the background starter pack import.
type StarterStatus struct {
	Running  bool       `json:"running"`
	Target   int        `json:"target"`
	Created  int        `json:"created"`
	Skipped  int        `json:"skipped"`
	Step     string     `json:"step"` // search being imported
	Error    string     `json:"error,omitempty"`
	Started  *time.Time `json:"started,omitempty"`
	Finished *time.Time `json:"finished,omitempty"`
}

type starterJob struct {
	mu     sync.Mutex
	status StarterStatus
}

func (j *starterJob) get() StarterStatus {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.status
}

func (j *starterJob) update(f func(*StarterStatus)) {
	j.mu.Lock()
	f(&j.status)
	j.mu.Unlock()
}

// adminStarterStatus: GET /admin/import/starter
func (h *Handler) adminStarterStatus(c fiber.Ctx) error { return c.JSON(h.starter.get()) }

// adminStarterImport: POST /admin/import/starter {"total": 200} starts the
// import in the background; poll GET for progress.
func (h *Handler) adminStarterImport(c fiber.Ctx) error {
	var req struct {
		Total int `json:"total"`
	}
	_ = c.Bind().Body(&req)
	if req.Total <= 0 {
		req.Total = 200
	}
	req.Total = min(req.Total, 400)
	author, err := h.importAuthor("")
	if err != nil {
		return err
	}
	started := false
	h.starter.update(func(s *StarterStatus) {
		if s.Running {
			return
		}
		now := time.Now()
		*s = StarterStatus{Running: true, Target: req.Total, Started: &now}
		started = true
	})
	if !started {
		return fail(c, fiber.StatusConflict, "Import eýýäm dowam edýär")
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()
		per := max(4, (req.Total+len(starterPack)-1)/len(starterPack))
		created := 0
		// Two rounds: searches with few usable photos leave room for the others.
		for round := 0; round < 2 && created < req.Total; round++ {
			for _, s := range starterPack {
				if created >= req.Total || ctx.Err() != nil {
					break
				}
				h.starter.update(func(st *StarterStatus) { st.Step = s.Query })
				want := min(per, req.Total-created)
				gen := url.Values{"generator": {"search"}, "gsrsearch": {s.Query + " filetype:bitmap"},
					"gsrnamespace": {"6"}, "gsrlimit": {"50"}, "gsroffset": {strconv.Itoa(round * 50)}}
				pins, skipped, err := h.importCommons(ctx, gen, want, author, s.Category, s.Tags)
				if err != nil {
					log.Printf("starter %q: %v", s.Query, err)
					h.starter.update(func(st *StarterStatus) { st.Error = "Wikimedia Commons bilen baglanyşyk ýok" })
					continue
				}
				created += len(pins)
				h.starter.update(func(st *StarterStatus) { st.Created, st.Skipped = created, st.Skipped+len(skipped) })
			}
		}
		h.starter.update(func(st *StarterStatus) {
			now := time.Now()
			st.Running, st.Step, st.Finished = false, "", &now
			if created > 0 {
				st.Error = ""
			}
		})
		log.Printf("starter pack: %d photos imported", created)
	}()
	return c.Status(fiber.StatusAccepted).JSON(h.starter.get())
}
