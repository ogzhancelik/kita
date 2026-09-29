package postgres

import (
	"context"
	"sort"
	"strings"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type directMessageRepo struct {
	db *gorm.DB
}

func NewDirectMessageRepository(db *gorm.DB) ports.DirectMessageRepository {
	return &directMessageRepo{db: db}
}

func (r *directMessageRepo) Save(ctx context.Context, msg *domain.DirectMessage) error {
	return r.db.WithContext(ctx).Create(msg).Error
}

func (r *directMessageRepo) GetConversation(ctx context.Context, conversationID string, limit, offset int) ([]domain.DirectMessage, error) {
	var msgs []domain.DirectMessage
	err := r.db.WithContext(ctx).
		Where("conversation_id = ?", conversationID).
		Order("created_at ASC").
		Limit(limit).
		Offset(offset).
		Find(&msgs).Error
	return msgs, err
}

// GetConversationPreviews returns the latest message for each conversation the user participates in.
func (r *directMessageRepo) GetConversationPreviews(ctx context.Context, userID string) ([]domain.DirectMessage, error) {
	// Subquery: find the max id per conversation_id where user is sender or recipient
	subQuery := r.db.WithContext(ctx).
		Model(&domain.DirectMessage{}).
		Select("MAX(id) as max_id").
		Where("sender_id = ? OR recipient_id = ?", userID, userID).
		Group("conversation_id")

	var msgs []domain.DirectMessage
	err := r.db.WithContext(ctx).
		Where("id IN (?)", subQuery).
		Order("created_at DESC").
		Find(&msgs).Error
	return msgs, err
}

// ConversationID returns a stable identifier for a pair of users (alphabetically sorted).
func ConversationID(userA, userB string) string {
	ids := []string{userA, userB}
	sort.Strings(ids)
	return strings.Join(ids, "_")
}
