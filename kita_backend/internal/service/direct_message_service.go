package service

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type directMessageService struct {
	repo ports.DirectMessageRepository
}

func NewDirectMessageService(repo ports.DirectMessageRepository) ports.DirectMessageService {
	return &directMessageService{repo: repo}
}

func (s *directMessageService) ConversationID(userA, userB string) string {
	ids := []string{userA, userB}
	sort.Strings(ids)
	return strings.Join(ids, "_")
}

func (s *directMessageService) Send(ctx context.Context, senderID, recipientID, content string) (*domain.DirectMessage, error) {
	msg := &domain.DirectMessage{
		ConversationID: s.ConversationID(senderID, recipientID),
		SenderID:       senderID,
		RecipientID:    recipientID,
		Content:        content,
		CreatedAt:      time.Now(),
	}
	if err := s.repo.Save(ctx, msg); err != nil {
		return nil, err
	}
	return msg, nil
}

func (s *directMessageService) GetConversation(ctx context.Context, conversationID string, limit, offset int) ([]domain.DirectMessage, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.repo.GetConversation(ctx, conversationID, limit, offset)
}

func (s *directMessageService) GetConversationPreviews(ctx context.Context, userID string) ([]domain.DirectMessage, error) {
	return s.repo.GetConversationPreviews(ctx, userID)
}
