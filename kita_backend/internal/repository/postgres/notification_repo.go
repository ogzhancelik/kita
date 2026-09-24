package postgres

import (
	"context"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type notificationRepository struct {
	db *gorm.DB
}

func NewNotificationRepository(db *gorm.DB) ports.NotificationRepository {
	return &notificationRepository{db: db}
}

func (r *notificationRepository) Create(ctx context.Context, notif *domain.Notification) error {
	return r.db.WithContext(ctx).Create(notif).Error
}

func (r *notificationRepository) FindByID(ctx context.Context, id string) (*domain.Notification, error) {
	var notif domain.Notification
	err := r.db.WithContext(ctx).First(&notif, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &notif, nil
}

func (r *notificationRepository) ListByUserID(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error) {
	var notifs []domain.Notification
	q := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("created_at DESC")

	if limit > 0 {
		q = q.Limit(limit)
	}
	if offset > 0 {
		q = q.Offset(offset)
	}

	err := q.Find(&notifs).Error
	return notifs, err
}

func (r *notificationRepository) GetUnreadCount(ctx context.Context, userID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&domain.Notification{}).
		Where("user_id = ? AND status IN ('pending', 'unread')", userID).
		Count(&count).Error
	return count, err
}

func (r *notificationRepository) UpdateStatus(ctx context.Context, id string, userID string, status string) error {
	return r.db.WithContext(ctx).
		Model(&domain.Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("status", status).Error
}

func (r *notificationRepository) MarkAllAsRead(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).
		Model(&domain.Notification{}).
		Where("user_id = ? AND status IN ('pending', 'unread') AND type = ?", userID, domain.NotificationTypeInfo).
		Update("status", domain.NotificationStatusRead).Error
}

func (r *notificationRepository) Delete(ctx context.Context, id string, userID string) error {
	return r.db.WithContext(ctx).
		Where("id = ? AND user_id = ?", id, userID).
		Delete(&domain.Notification{}).Error
}

func (r *notificationRepository) DeletePendingChallenge(ctx context.Context, actorID string, friendID string) error {
	return r.db.WithContext(ctx).
		Where("actor_id = ? AND user_id = ? AND type = ?", actorID, friendID, domain.NotificationTypeChallenge).
		Delete(&domain.Notification{}).Error
}
