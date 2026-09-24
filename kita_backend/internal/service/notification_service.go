package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	appErrors "github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type notificationService struct {
	repo ports.NotificationRepository
}

func NewNotificationService(repo ports.NotificationRepository) ports.NotificationService {
	return &notificationService{repo: repo}
}

func (s *notificationService) CreateNotification(ctx context.Context, notif *domain.Notification) (*domain.Notification, error) {
	if notif.ID == "" {
		notif.ID = uuid.New().String()
	}
	if notif.Status == "" {
		if notif.Type == domain.NotificationTypeInfo {
			notif.Status = domain.NotificationStatusUnread
		} else {
			notif.Status = domain.NotificationStatusPending
		}
	}
	if notif.CreatedAt.IsZero() {
		notif.CreatedAt = time.Now()
	}
	notif.UpdatedAt = time.Now()

	if err := s.repo.Create(ctx, notif); err != nil {
		return nil, appErrors.New(appErrors.ErrInternalServer, "failed to save notification")
	}
	return notif, nil
}

func (s *notificationService) GetUserNotifications(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, int64, error) {
	notifs, err := s.repo.ListByUserID(ctx, userID, limit, offset)
	if err != nil {
		return nil, 0, appErrors.New(appErrors.ErrInternalServer, "failed to list notifications")
	}

	count, err := s.repo.GetUnreadCount(ctx, userID)
	if err != nil {
		return notifs, 0, nil
	}

	return notifs, count, nil
}

func (s *notificationService) UpdateStatus(ctx context.Context, id string, userID string, status string) error {
	validStatuses := map[string]bool{
		domain.NotificationStatusPending:  true,
		domain.NotificationStatusUnread:   true,
		domain.NotificationStatusRead:     true,
		domain.NotificationStatusAccepted: true,
		domain.NotificationStatusDeclined: true,
		domain.NotificationStatusIgnored:  true,
	}
	if !validStatuses[status] {
		return appErrors.New(appErrors.ErrValidationFailed, "invalid notification status")
	}

	if err := s.repo.UpdateStatus(ctx, id, userID, status); err != nil {
		return appErrors.New(appErrors.ErrInternalServer, "failed to update notification status")
	}
	return nil
}

func (s *notificationService) MarkAllAsRead(ctx context.Context, userID string) error {
	if err := s.repo.MarkAllAsRead(ctx, userID); err != nil {
		return appErrors.New(appErrors.ErrInternalServer, "failed to mark notifications as read")
	}
	return nil
}

func (s *notificationService) DeleteNotification(ctx context.Context, id string, userID string) error {
	if err := s.repo.Delete(ctx, id, userID); err != nil {
		return appErrors.New(appErrors.ErrInternalServer, "failed to delete notification")
	}
	return nil
}

func (s *notificationService) DeletePendingChallenge(ctx context.Context, actorID string, friendID string) error {
	if err := s.repo.DeletePendingChallenge(ctx, actorID, friendID); err != nil {
		return appErrors.New(appErrors.ErrInternalServer, "failed to delete pending challenge notification")
	}
	return nil
}
