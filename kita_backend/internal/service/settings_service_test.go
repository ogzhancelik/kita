package service

import (
	"context"
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockSettingsRepo struct {
	data map[string]*domain.UserSettings
}

func newMockSettingsRepo() *mockSettingsRepo {
	return &mockSettingsRepo{data: make(map[string]*domain.UserSettings)}
}

func (m *mockSettingsRepo) GetByUserID(ctx context.Context, userID string) (*domain.UserSettings, error) {
	if s, ok := m.data[userID]; ok {
		copied := *s
		return &copied, nil
	}
	return nil, nil
}

func (m *mockSettingsRepo) Upsert(ctx context.Context, settings *domain.UserSettings) error {
	copied := *settings
	m.data[settings.UserID] = &copied
	return nil
}

func (m *mockSettingsRepo) ResetToDefaults(ctx context.Context, userID string) (*domain.UserSettings, error) {
	defaults := domain.DefaultSettings(userID)
	m.data[userID] = &defaults
	return &defaults, nil
}

type mockUserRepo struct{}

func (m *mockUserRepo) Create(ctx context.Context, user *domain.User) error                 { return nil }
func (m *mockUserRepo) FindByID(ctx context.Context, id string) (*domain.User, error)       { return nil, nil }
func (m *mockUserRepo) FindByUsername(ctx context.Context, u string) (*domain.User, error) { return nil, nil }
func (m *mockUserRepo) FindByEmail(ctx context.Context, e string) (*domain.User, error)    { return nil, nil }
func (m *mockUserRepo) Update(ctx context.Context, user *domain.User) error                 { return nil }
func (m *mockUserRepo) GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error) {
	return nil, nil
}

func TestSettingsService_GetSettings_DefaultFallback(t *testing.T) {
	repo := newMockSettingsRepo()
	svc := NewSettingsService(repo, &mockUserRepo{})

	settings, err := svc.GetSettings(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if settings.UserID != "user-1" {
		t.Errorf("expected user-1, got %s", settings.UserID)
	}
	if settings.BoardTheme != "emerald" {
		t.Errorf("expected emerald, got %s", settings.BoardTheme)
	}
}

func TestSettingsService_UpdateSettings(t *testing.T) {
	repo := newMockSettingsRepo()
	svc := NewSettingsService(repo, &mockUserRepo{})

	newTheme := "cyber_purple"
	soundOff := false
	vertical := "vertical"
	dto := &domain.UpdateSettingsDTO{
		BoardTheme:       &newTheme,
		SoundEnabled:     &soundOff,
		BoardOrientation: &vertical,
	}

	updated, err := svc.UpdateSettings(context.Background(), "user-1", dto)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if updated.BoardTheme != "cyber_purple" {
		t.Errorf("expected cyber_purple, got %s", updated.BoardTheme)
	}
	if updated.SoundEnabled != false {
		t.Errorf("expected soundEnabled false, got %v", updated.SoundEnabled)
	}
	if updated.BoardOrientation != "vertical" {
		t.Errorf("expected boardOrientation vertical, got %s", updated.BoardOrientation)
	}

	// Fetch again from repo to confirm persistence
	fetched, err := svc.GetSettings(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if fetched.BoardTheme != "cyber_purple" {
		t.Errorf("expected persistent cyber_purple, got %s", fetched.BoardTheme)
	}
}

func TestSettingsService_ResetSettings(t *testing.T) {
	repo := newMockSettingsRepo()
	svc := NewSettingsService(repo, &mockUserRepo{})

	customTheme := "slate_monochrome"
	dto := &domain.UpdateSettingsDTO{BoardTheme: &customTheme}
	_, _ = svc.UpdateSettings(context.Background(), "user-1", dto)

	reset, err := svc.ResetSettings(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if reset.BoardTheme != "emerald" {
		t.Errorf("expected reset to emerald, got %s", reset.BoardTheme)
	}
}

func TestSettingsService_ValidationErrors(t *testing.T) {
	repo := newMockSettingsRepo()
	svc := NewSettingsService(repo, &mockUserRepo{})

	badOrientation := "diagonal"
	dto := &domain.UpdateSettingsDTO{BoardOrientation: &badOrientation}

	_, err := svc.UpdateSettings(context.Background(), "user-1", dto)
	if err == nil {
		t.Fatalf("expected validation error for invalid orientation, got nil")
	}
}
