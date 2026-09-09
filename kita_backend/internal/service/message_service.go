package service

import (
	"context"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type messageService struct {
	messageRepo ports.MessageRepository
}

func NewMessageService(messageRepo ports.MessageRepository) ports.MessageService {
	return &messageService{messageRepo: messageRepo}
}

func (s *messageService) SaveMessage(ctx context.Context, matchID, senderID, content string) (*domain.Message, error) {
	msg := &domain.Message{
		MatchID:   matchID,
		SenderID:  senderID,
		Content:   content,
		CreatedAt: time.Now(),
	}

	if err := s.messageRepo.Save(ctx, msg); err != nil {
		return nil, err
	}
	return msg, nil
}

func (s *messageService) GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	return s.messageRepo.GetMatchMessages(ctx, matchID, limit)
}
