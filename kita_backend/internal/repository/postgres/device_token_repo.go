package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type deviceTokenRepo struct {
	db *gorm.DB
}

// NewDeviceTokenRepository creates a PostgreSQL implementation of ports.DeviceTokenRepository.
func NewDeviceTokenRepository(db *gorm.DB) ports.DeviceTokenRepository {
	return &deviceTokenRepo{db: db}
}

func (r *deviceTokenRepo) Upsert(ctx context.Context, token *domain.DeviceToken) error {
	if token.ID == "" {
		token.ID = uuid.New().String()
	}
	now := time.Now()
	token.UpdatedAt = now
	if token.CreatedAt.IsZero() {
		token.CreatedAt = now
	}

	return r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "token"}},
		DoUpdates: clause.AssignmentColumns([]string{"user_id", "platform", "updated_at"}),
	}).Create(token).Error
}

func (r *deviceTokenRepo) FindByToken(ctx context.Context, token string) (*domain.DeviceToken, error) {
	var dt domain.DeviceToken
	if err := r.db.WithContext(ctx).First(&dt, "token = ?", token).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &dt, nil
}

func (r *deviceTokenRepo) ListByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	var tokens []domain.DeviceToken
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).Find(&tokens).Error; err != nil {
		return nil, err
	}
	return tokens, nil
}

func (r *deviceTokenRepo) DeleteByToken(ctx context.Context, token string) error {
	return r.db.WithContext(ctx).Where("token = ?", token).Delete(&domain.DeviceToken{}).Error
}

func (r *deviceTokenRepo) DeleteByUserID(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Where("user_id = ?", userID).Delete(&domain.DeviceToken{}).Error
}
