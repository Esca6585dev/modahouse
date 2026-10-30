// Package database opens the GORM connection and migrates the schema.
package database

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/esca6585dev/modahouse/backend/internal/models"
	"github.com/esca6585dev/modahouse/backend/internal/search"
)

func Open(driver, dsn string) (*gorm.DB, error) {
	var dialector gorm.Dialector
	switch driver {
	case "postgres":
		dialector = postgres.Open(dsn)
	case "sqlite":
		// Foreign keys must be enabled per connection in SQLite.
		sep := "?"
		if strings.Contains(dsn, "?") {
			sep = "&"
		}
		dialector = sqlite.Open(dsn + sep + "_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)")
	default:
		return nil, fmt.Errorf("unknown DB_DRIVER %q (use postgres or sqlite)", driver)
	}

	db, err := gorm.Open(dialector, &gorm.Config{Logger: logger.New(log.New(os.Stderr, "", log.LstdFlags), logger.Config{
		SlowThreshold:             500 * time.Millisecond,
		LogLevel:                  logger.Warn,
		IgnoreRecordNotFoundError: true, // 404s are normal API traffic
	})})
	if err != nil {
		return nil, err
	}
	if driver == "sqlite" {
		sqlDB, err := db.DB()
		if err != nil {
			return nil, err
		}
		sqlDB.SetMaxOpenConns(1) // SQLite allows one writer at a time
	}
	if err := db.AutoMigrate(models.All()...); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	// Business profiles had their craft only on the business row.
	db.Exec(`UPDATE users SET category = (SELECT category FROM businesses WHERE businesses.user_id = users.id)
		WHERE is_business = ? AND (category IS NULL OR category = '')`, true)
	reindex(db)
	return db, nil
}

// searchIndexVersion changes whenever search.IndexText does; posts are then reindexed once.
const searchIndexVersion = "2"

func reindex(db *gorm.DB) {
	var s models.Setting
	if db.First(&s, "key = ?", "search_index").Error == nil && s.Value == searchIndexVersion {
		return
	}
	var pins []models.Pin
	db.Select("id", "title", "description", "tags", "category").FindInBatches(&pins, 500, func(tx *gorm.DB, _ int) error {
		for _, p := range pins {
			tx.Model(&models.Pin{}).Where("id = ?", p.ID).UpdateColumn("search_text", search.IndexText(p.Title, p.Description, p.Tags, p.Category))
		}
		return nil
	})
	db.Save(&models.Setting{Key: "search_index", Value: searchIndexVersion})
}
