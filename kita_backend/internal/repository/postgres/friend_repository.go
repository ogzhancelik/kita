package postgres

import (
	"context"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type friendRepository struct {
	db *gorm.DB
}

func NewFriendRepository(db *gorm.DB) ports.FriendRepository {
	return &friendRepository{db: db}
}

func (r *friendRepository) Create(ctx context.Context, friendship *domain.Friendship) error {
	return r.db.WithContext(ctx).Create(friendship).Error
}

func (r *friendRepository) FindByID(ctx context.Context, id string) (*domain.Friendship, error) {
	var friendship domain.Friendship
	err := r.db.WithContext(ctx).
		Preload("Requester").
		Preload("Addressee").
		First(&friendship, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &friendship, nil
}

func (r *friendRepository) FindByUsers(ctx context.Context, user1, user2 string) (*domain.Friendship, error) {
	var friendship domain.Friendship
	err := r.db.WithContext(ctx).
		Preload("Requester").
		Preload("Addressee").
		Where("(requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)", user1, user2, user2, user1).
		First(&friendship).Error
	if err != nil {
		return nil, err
	}
	return &friendship, nil
}

func (r *friendRepository) UpdateStatus(ctx context.Context, id string, status string) error {
	return r.db.WithContext(ctx).
		Model(&domain.Friendship{}).
		Where("id = ?", id).
		Update("status", status).Error
}

func (r *friendRepository) Delete(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Delete(&domain.Friendship{}, "id = ?", id).Error
}

func (r *friendRepository) ListFriends(ctx context.Context, userID string) ([]domain.Friendship, error) {
	var friendships []domain.Friendship
	err := r.db.WithContext(ctx).
		Preload("Requester").
		Preload("Addressee").
		Where("status = ? AND (requester_id = ? OR addressee_id = ?)", domain.FriendshipStatusAccepted, userID, userID).
		Order("updated_at DESC").
		Find(&friendships).Error
	return friendships, err
}

func (r *friendRepository) ListPendingRequests(ctx context.Context, userID string) ([]domain.Friendship, error) {
	var friendships []domain.Friendship
	err := r.db.WithContext(ctx).
		Preload("Requester").
		Preload("Addressee").
		Where("status = ? AND (requester_id = ? OR addressee_id = ?)", domain.FriendshipStatusPending, userID, userID).
		Order("created_at DESC").
		Find(&friendships).Error
	return friendships, err
}
