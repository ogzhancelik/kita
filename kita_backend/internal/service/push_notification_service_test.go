package service_test

import (
	"context"
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"github.com/oguzhancelik/kita/internal/service"
)

type mockDeviceTokenRepo struct {
	tokens       map[string]*domain.DeviceToken // key: token
	userTokens   map[string][]domain.DeviceToken // key: user_id
	deletedTokens []string
}

func newMockDeviceTokenRepo() *mockDeviceTokenRepo {
	return &mockDeviceTokenRepo{
		tokens:     make(map[string]*domain.DeviceToken),
		userTokens: make(map[string][]domain.DeviceToken),
	}
}

func (m *mockDeviceTokenRepo) Upsert(ctx context.Context, token *domain.DeviceToken) error {
	m.tokens[token.Token] = token
	m.userTokens[token.UserID] = append(m.userTokens[token.UserID], *token)
	return nil
}

func (m *mockDeviceTokenRepo) FindByToken(ctx context.Context, token string) (*domain.DeviceToken, error) {
	if t, ok := m.tokens[token]; ok {
		return t, nil
	}
	return nil, nil
}

func (m *mockDeviceTokenRepo) ListByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	return m.userTokens[userID], nil
}

func (m *mockDeviceTokenRepo) DeleteByToken(ctx context.Context, token string) error {
	delete(m.tokens, token)
	m.deletedTokens = append(m.deletedTokens, token)
	return nil
}

func (m *mockDeviceTokenRepo) DeleteByUserID(ctx context.Context, userID string) error {
	delete(m.userTokens, userID)
	return nil
}

type mockPushProvider struct {
	sentTokens        []string
	lastTitle         string
	lastBody          string
	lastData          map[string]string
	returnUnregistered []string
}

func (p *mockPushProvider) Send(ctx context.Context, tokens []string, title, body string, data map[string]string, tag string) ([]string, error) {
	p.sentTokens = append(p.sentTokens, tokens...)
	p.lastTitle = title
	p.lastBody = body
	p.lastData = data
	return p.returnUnregistered, nil
}

func TestPushNotificationService_RegisterAndRemove(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	provider := &mockPushProvider{}
	svc := service.NewPushNotificationService(repo, provider)

	ctx := context.Background()
	err := svc.RegisterToken(ctx, "user-1", "fcm-token-abc", "android")
	if err != nil {
		t.Fatalf("unexpected error registering token: %v", err)
	}

	if repo.tokens["fcm-token-abc"] == nil {
		t.Fatalf("expected token to be saved in repo")
	}

	err = svc.RemoveToken(ctx, "fcm-token-abc")
	if err != nil {
		t.Fatalf("unexpected error removing token: %v", err)
	}
	if len(repo.deletedTokens) != 1 || repo.deletedTokens[0] != "fcm-token-abc" {
		t.Fatalf("expected token to be pruned, got %v", repo.deletedTokens)
	}
}

func TestPushNotificationService_SendAndPruneInvalid(t *testing.T) {
	repo := newMockDeviceTokenRepo()
	provider := &mockPushProvider{
		returnUnregistered: []string{"dead-token-123"},
	}
	svc := service.NewPushNotificationService(repo, provider)

	ctx := context.Background()
	_ = svc.RegisterToken(ctx, "user-42", "live-token-1", "android")
	_ = svc.RegisterToken(ctx, "user-42", "dead-token-123", "ios")

	payload := ports.PushNotificationPayload{
		TitleKey:      "notification.test_title",
		TitleFallback: "Test Title",
		BodyKey:       "notification.test_body",
		BodyFallback:  "Test Body",
		Tag:           "test_tag",
		Data: map[string]string{
			"type": "room_joined",
		},
	}

	err := svc.SendToUser(ctx, "user-42", payload)
	if err != nil {
		t.Fatalf("unexpected error in SendToUser: %v", err)
	}

	if provider.lastTitle != "Test Title" {
		t.Errorf("expected title 'Test Title', got %q", provider.lastTitle)
	}
	if len(provider.sentTokens) != 2 {
		t.Errorf("expected 2 tokens to receive notification, got %d", len(provider.sentTokens))
	}

	// Verify that the provider pruned the dead token
	foundPruned := false
	for _, dt := range repo.deletedTokens {
		if dt == "dead-token-123" {
			foundPruned = true
			break
		}
	}
	if !foundPruned {
		t.Errorf("expected dead-token-123 to be deleted from repo")
	}
}
