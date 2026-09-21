package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type settingsRepo struct {
	db *gorm.DB
}

func NewSettingsRepository(db *gorm.DB) ports.SettingsRepository {
	return &settingsRepo{db: db}
}

func (r *settingsRepo) GetByUserID(ctx context.Context, userID string) (*domain.UserSettings, error) {
	var settings domain.UserSettings
	if err := r.db.WithContext(ctx).First(&settings, "user_id = ?", userID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &settings, nil
}

func (r *settingsRepo) Upsert(ctx context.Context, settings *domain.UserSettings) error {
	settings.UpdatedAt = time.Now().UTC()
	return r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "user_id"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"board_theme",
			"board_orientation",
			"sound_enabled",
			"haptics_enabled",
			"highlight_last_move",
			"theme_mode",
			"language",
			"updated_at",
		}),
	}).Create(settings).Error
}

func (r *settingsRepo) ResetToDefaults(ctx context.Context, userID string) (*domain.UserSettings, error) {
	defaults := domain.DefaultSettings(userID)
	if err := r.Upsert(ctx, &defaults); err != nil {
		return nil, err
	}
	return &defaults, nil
}
