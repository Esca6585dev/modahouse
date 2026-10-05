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
	return db, nil
}
