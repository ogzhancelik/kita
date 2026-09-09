package service

import (
	"context"
	"errors"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type userService struct {
	userRepo ports.UserRepository
}

func NewUserService(userRepo ports.UserRepository) ports.UserService {
	return &userService{userRepo: userRepo}
}

func (s *userService) GetProfile(ctx context.Context, userID string) (*domain.UserProfile, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	profile := user.ToProfile()
	return &profile, nil
}

func (s *userService) GetLeaderboard(ctx context.Context, limit int) ([]domain.UserProfile, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	users, err := s.userRepo.GetLeaderboard(ctx, limit)
	if err != nil {
		return nil, err
	}

	profiles := make([]domain.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = u.ToProfile()
	}
	return profiles, nil
}
