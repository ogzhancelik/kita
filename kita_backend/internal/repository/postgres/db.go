package postgres

import (
	"fmt"
	"log"
	"os"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func NewDatabase() (*gorm.DB, error) {
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "postgres")
	password := getEnv("DB_PASSWORD", "postgres")
	dbname := getEnv("DB_NAME", "kita")
	sslmode := getEnv("DB_SSLMODE", "disable")

	// 1. Veritabanı (kita) yoksa varsayılan 'postgres' veritabanına bağlanıp otomatik oluştur
	if err := ensureDatabaseExists(host, port, user, password, dbname, sslmode); err != nil {
		log.Printf("[Postgres Warning] Could not ensure database '%s' exists: %v", dbname, err)
	}

	// 2. 'kita' veritabanına bağlan
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s TimeZone=UTC",
		host, port, user, password, dbname, sslmode,
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// 3. Tabloları otomatik oluştur (Auto-Migrate)
	if err := db.AutoMigrate(
		&domain.User{},
		&domain.Match{},
		&domain.MatchMove{},
		&domain.Message{},
	); err != nil {
		return nil, fmt.Errorf("failed to run database auto-migration: %w", err)
	}

	log.Println("[Postgres] Database connected and schema migrated successfully")
	return db, nil
}

func ensureDatabaseExists(host, port, user, password, dbname, sslmode string) error {
	adminDsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=postgres sslmode=%s TimeZone=UTC",
		host, port, user, password, sslmode,
	)
	adminDb, err := gorm.Open(postgres.Open(adminDsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return err
	}
	defer func() {
		if sqlDB, err := adminDb.DB(); err == nil {
			_ = sqlDB.Close()
		}
	}()

	var count int64
	adminDb.Raw("SELECT count(*) FROM pg_database WHERE datname = ?", dbname).Scan(&count)
	if count == 0 {
		log.Printf("[Postgres] Database '%s' not found. Creating automatically...", dbname)
		if err := adminDb.Exec(fmt.Sprintf("CREATE DATABASE %s", dbname)).Error; err != nil {
			return err
		}
		log.Printf("[Postgres] Database '%s' created successfully!", dbname)
	}
	return nil
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
