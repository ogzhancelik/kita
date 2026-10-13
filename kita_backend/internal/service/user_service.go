package service

import (
	"context"
	"errors"
	"strings"
	"time"

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
	if strings.HasPrefix(userID, "guest-") {
		return &domain.UserProfile{
			ID:          userID,
			Username:    "Guest",
			AvatarIndex: 0,
			Rating:      1200,
		}, nil
	}
	if userID == "bot" {
		return &domain.UserProfile{
			ID:          "bot",
			Username:    "AI Bot",
			AvatarIndex: 7,
			Rating:      1200,
		}, nil
	}
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

func (s *userService) UpdateAvatar(ctx context.Context, userID string, avatarIndex int) (*domain.UserProfile, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	user.AvatarIndex = avatarIndex
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	profile := user.ToProfile()
	return &profile, nil
}

func (s *userService) UpdateUsername(ctx context.Context, userID string, username string) (*domain.UserProfile, error) {
	username = strings.TrimSpace(username)
	if err := ValidateUsername(username); err != nil {
		return nil, err
	}

	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	if strings.EqualFold(user.Username, username) {
		if user.Username == username {
			profile := user.ToProfile()
			return &profile, nil
		}
	} else {
		existing, err := s.userRepo.FindByUsername(ctx, username)
		if err != nil {
			return nil, err
		}
		if existing != nil && existing.ID != userID {
			return nil, ErrUserAlreadyExists
		}
	}

	user.Username = username
	user.UpdatedAt = time.Now()
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	profile := user.ToProfile()
	return &profile, nil
}

func (s *userService) DeleteAccount(ctx context.Context, userID string) error {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return errors.New("user not found")
	}

	return s.userRepo.Delete(ctx, userID)
}



