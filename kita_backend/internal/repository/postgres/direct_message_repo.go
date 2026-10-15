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
	if err := r.db.WithContext(ctx).Create(msg).Error; err != nil {
		return err
	}
	slice := []domain.DirectMessage{*msg}
	r.populateUserMetadata(ctx, slice)
	msg.SenderUsername = slice[0].SenderUsername
	msg.SenderAvatarIndex = slice[0].SenderAvatarIndex
	msg.SenderAvatarCustom = slice[0].SenderAvatarCustom
	msg.RecipientUsername = slice[0].RecipientUsername
	msg.RecipientAvatarIndex = slice[0].RecipientAvatarIndex
	msg.RecipientAvatarCustom = slice[0].RecipientAvatarCustom
	return nil
}

func (r *directMessageRepo) GetConversation(ctx context.Context, conversationID string, limit, offset int) ([]domain.DirectMessage, error) {
	var msgs []domain.DirectMessage
	err := r.db.WithContext(ctx).
		Where("conversation_id = ?", conversationID).
		Order("created_at DESC, id DESC").
		Limit(limit).
		Offset(offset).
		Find(&msgs).Error
	if err != nil {
		return nil, err
	}
	// Reverse to return them in chronological order (oldest to newest)
	for i, j := 0, len(msgs)-1; i < j; i, j = i+1, j-1 {
		msgs[i], msgs[j] = msgs[j], msgs[i]
	}
	r.populateUserMetadata(ctx, msgs)
	return msgs, nil
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
	if err != nil {
		return nil, err
	}
	r.populateUserMetadata(ctx, msgs)
	return msgs, nil
}

func (r *directMessageRepo) populateUserMetadata(ctx context.Context, msgs []domain.DirectMessage) {
	if len(msgs) == 0 {
		return
	}
	userIDsMap := make(map[string]struct{})
	for _, m := range msgs {
		if m.SenderID != "" {
			userIDsMap[m.SenderID] = struct{}{}
		}
		if m.RecipientID != "" {
			userIDsMap[m.RecipientID] = struct{}{}
		}
	}
	if len(userIDsMap) == 0 {
		return
	}
	var userIDs []string
	for uid := range userIDsMap {
		userIDs = append(userIDs, uid)
	}

	var users []domain.User
	userMap := make(map[string]domain.User)
	if err := r.db.WithContext(ctx).Where("id IN (?)", userIDs).Find(&users).Error; err == nil {
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	for i := range msgs {
		if su, ok := userMap[msgs[i].SenderID]; ok {
			msgs[i].SenderUsername = su.Username
			msgs[i].SenderAvatarIndex = su.AvatarIndex
			msgs[i].SenderAvatarCustom = su.AvatarCustom
		} else {
			msgs[i].SenderUsername = "[Deleted]"
			msgs[i].SenderAvatarIndex = 0
			msgs[i].SenderAvatarCustom = ""
		}
		if ru, ok := userMap[msgs[i].RecipientID]; ok {
			msgs[i].RecipientUsername = ru.Username
			msgs[i].RecipientAvatarIndex = ru.AvatarIndex
			msgs[i].RecipientAvatarCustom = ru.AvatarCustom
		} else {
			msgs[i].RecipientUsername = "[Deleted]"
			msgs[i].RecipientAvatarIndex = 0
			msgs[i].RecipientAvatarCustom = ""
		}
	}
}

// ConversationID returns a stable identifier for a pair of users (alphabetically sorted).
func ConversationID(userA, userB string) string {
	ids := []string{userA, userB}
	sort.Strings(ids)
	return strings.Join(ids, "_")
}
