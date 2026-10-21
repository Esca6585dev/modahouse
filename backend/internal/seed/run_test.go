package seed

import (
	"path/filepath"
	"testing"

	"github.com/esca6585dev/modahouse/backend/internal/database"
	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

func TestRunStopsAfterDemoRemoval(t *testing.T) {
	db, err := database.Open("sqlite", filepath.Join(t.TempDir(), "t.db"))
	if err != nil {
		t.Fatal(err)
	}
	store, err := storage.New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	db.Create(&models.Setting{Key: DemoRemovedKey, Value: "true"})
	if err := Run(db, store); err != nil {
		t.Fatal(err)
	}
	var n int64
	db.Model(&models.User{}).Count(&n)
	if n != 0 {
		t.Fatalf("seeded %d users after the demo was removed", n)
	}
	if len(DemoUsernames()) < 30 {
		t.Fatalf("demo usernames: %v", DemoUsernames())
	}
}
