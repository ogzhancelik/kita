package postgres

import (
	"context"
	"time"

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

type interactionRow struct {
	OtherID  string    `gorm:"column:other_id"`
	LastTime time.Time `gorm:"column:last_time"`
}

func (r *friendRepository) GetLastInteractions(ctx context.Context, userID string, friendIDs []string) (map[string]time.Time, error) {
	result := make(map[string]time.Time)
	if len(friendIDs) == 0 {
		return result, nil
	}

	// 1. Matches between userID and friendIDs
	var matchRows []interactionRow
	err := r.db.WithContext(ctx).Table("matches").
		Select("CASE WHEN white_player_id = ? THEN black_player_id ELSE white_player_id END AS other_id, MAX(COALESCE(ended_at, started_at)) AS last_time", userID).
		Where("(white_player_id = ? AND black_player_id IN (?)) OR (black_player_id = ? AND white_player_id IN (?))", userID, friendIDs, userID, friendIDs).
		Group("other_id").
		Scan(&matchRows).Error
	if err == nil {
		for _, row := range matchRows {
			result[row.OtherID] = row.LastTime
		}
	}

	// 2. Direct Messages between userID and friendIDs
	var dmRows []interactionRow
	err = r.db.WithContext(ctx).Table("direct_messages").
		Select("CASE WHEN CAST(sender_id AS text) = ? THEN CAST(recipient_id AS text) ELSE CAST(sender_id AS text) END AS other_id, MAX(created_at) AS last_time", userID).
		Where("(sender_id = ? AND recipient_id IN (?)) OR (recipient_id = ? AND sender_id IN (?))", userID, friendIDs, userID, friendIDs).
		Group("other_id").
		Scan(&dmRows).Error
	if err == nil {
		for _, row := range dmRows {
			if current, ok := result[row.OtherID]; !ok || row.LastTime.After(current) {
				result[row.OtherID] = row.LastTime
			}
		}
	}

	return result, nil
}
