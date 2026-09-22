package service

import (
	"context"
	"errors"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type userService struct {
	userRepo   ports.UserRepository
	friendRepo ports.FriendRepository
}

func NewUserService(userRepo ports.UserRepository, friendRepo ports.FriendRepository) ports.UserService {
	return &userService{
		userRepo:   userRepo,
		friendRepo: friendRepo,
	}
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

func (s *userService) GetLeaderboard(ctx context.Context, limit int, filter string, currentUserID string) ([]domain.UserProfile, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	var targetIDs []string
	if filter == "friends" {
		if currentUserID == "" {
			return []domain.UserProfile{}, nil
		}

		friends, err := s.friendRepo.ListFriends(ctx, currentUserID)
		if err != nil {
			return nil, err
		}

		targetIDs = append(targetIDs, currentUserID)
		for _, f := range friends {
			if f.RequesterID == currentUserID {
				targetIDs = append(targetIDs, f.AddresseeID)
			} else {
				targetIDs = append(targetIDs, f.RequesterID)
			}
		}
	}

	users, err := s.userRepo.GetLeaderboard(ctx, limit, targetIDs)
	if err != nil {
		return nil, err
	}

	profiles := make([]domain.UserProfile, len(users))
	for i, u := range users {
		profiles[i] = u.ToProfile()
	}
	return profiles, nil
}
