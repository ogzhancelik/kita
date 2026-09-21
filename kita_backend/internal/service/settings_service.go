package service

import (
	"context"
	"errors"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type settingsService struct {
	settingsRepo ports.SettingsRepository
	userRepo     ports.UserRepository
}

func NewSettingsService(settingsRepo ports.SettingsRepository, userRepo ports.UserRepository) ports.SettingsService {
	return &settingsService{
		settingsRepo: settingsRepo,
		userRepo:     userRepo,
	}
}

func (s *settingsService) GetSettings(ctx context.Context, userID string) (*domain.UserSettings, error) {
	if userID == "" {
		return nil, errors.New("user ID is required")
	}

	settings, err := s.settingsRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// If no settings exist yet for this user, return defaults
	if settings == nil {
		defaults := domain.DefaultSettings(userID)
		// Optionally persist defaults so future queries find it directly
		_ = s.settingsRepo.Upsert(ctx, &defaults)
		return &defaults, nil
	}

	return settings, nil
}

func (s *settingsService) UpdateSettings(ctx context.Context, userID string, dto *domain.UpdateSettingsDTO) (*domain.UserSettings, error) {
	if userID == "" {
		return nil, errors.New("user ID is required")
	}

	if dto == nil {
		return nil, errors.New("settings update payload is required")
	}

	if err := dto.Validate(); err != nil {
		return nil, err
	}

	// Retrieve existing settings or initialize defaults
	settings, err := s.settingsRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	if settings == nil {
		defaults := domain.DefaultSettings(userID)
		settings = &defaults
	}

	// Apply updates
	dto.ApplyTo(settings)

	if err := s.settingsRepo.Upsert(ctx, settings); err != nil {
		return nil, err
	}

	return settings, nil
}

func (s *settingsService) ResetSettings(ctx context.Context, userID string) (*domain.UserSettings, error) {
	if userID == "" {
		return nil, errors.New("user ID is required")
	}

	return s.settingsRepo.ResetToDefaults(ctx, userID)
}

func (s *settingsService) GetDefaultSettings() domain.UserSettings {
	return domain.DefaultSettings("")
}
