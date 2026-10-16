package service

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type pushNotificationService struct {
	tokenRepo ports.DeviceTokenRepository
	provider  PushProvider
}

// NewPushNotificationService creates a unified PushNotificationService instance.
func NewPushNotificationService(tokenRepo ports.DeviceTokenRepository, provider PushProvider) ports.PushNotificationService {
	if provider == nil {
		provider = NewNoOpPushProvider()
	}
	return &pushNotificationService{
		tokenRepo: tokenRepo,
		provider:  provider,
	}
}

func (s *pushNotificationService) RegisterToken(ctx context.Context, userID, token, platform string) error {
	token = strings.TrimSpace(token)
	if token == "" || userID == "" {
		return fmt.Errorf("token and userID are required")
	}
	platform = strings.ToLower(strings.TrimSpace(platform))
	if platform == "" {
		platform = "unknown"
	}

	dt := &domain.DeviceToken{
		UserID:   userID,
		Token:    token,
		Platform: platform,
	}
	return s.tokenRepo.Upsert(ctx, dt)
}

func (s *pushNotificationService) RemoveToken(ctx context.Context, token string) error {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil
	}
	return s.tokenRepo.DeleteByToken(ctx, token)
}

func (s *pushNotificationService) SendToUser(ctx context.Context, userID string, payload ports.PushNotificationPayload) error {
	if userID == "" {
		return nil
	}

	if _, hasDeadline := ctx.Deadline(); !hasDeadline {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, 10*time.Second)
		defer cancel()
	}

	tokens, err := s.tokenRepo.ListByUserID(ctx, userID)
	if err != nil {
		return fmt.Errorf("failed to fetch device tokens: %w", err)
	}
	if len(tokens) == 0 {
		return nil
	}

	tokenStrings := make([]string, 0, len(tokens))
	for _, t := range tokens {
		if t.Token != "" {
			tokenStrings = append(tokenStrings, t.Token)
		}
	}
	if len(tokenStrings) == 0 {
		return nil
	}

	title := payload.TitleFallback
	if title == "" {
		title = payload.TitleKey
	}
	body := payload.BodyFallback
	if body == "" {
		body = payload.BodyKey
	}

	// Dispatch to transport provider
	unregistered, err := s.provider.Send(ctx, tokenStrings, title, body, payload.Data, payload.Tag)
	if err != nil {
		log.Printf("[PushNotificationService] Provider delivery error for user %s: %v", userID, err)
	}

	// Prune dead/invalid tokens
	for _, unregToken := range unregistered {
		log.Printf("[PushNotificationService] Pruning invalid device token: %s", unregToken)
		_ = s.tokenRepo.DeleteByToken(ctx, unregToken)
	}

	return err
}
