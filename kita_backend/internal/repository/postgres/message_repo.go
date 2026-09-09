package postgres

import (
	"context"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type messageRepo struct {
	db *gorm.DB
}

func NewMessageRepository(db *gorm.DB) ports.MessageRepository {
	return &messageRepo{db: db}
}

func (r *messageRepo) Save(ctx context.Context, msg *domain.Message) error {
	return r.db.WithContext(ctx).Create(msg).Error
}

func (r *messageRepo) GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error) {
	var messages []domain.Message
	err := r.db.WithContext(ctx).
		Preload("Sender").
		Where("match_id = ?", matchID).
		Order("created_at ASC").
		Limit(limit).
		Find(&messages).Error

	if err != nil {
		return nil, err
	}
	return messages, nil
}
