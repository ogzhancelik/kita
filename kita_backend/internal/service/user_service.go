package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"golang.org/x/crypto/bcrypt"
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
			Roles:       []string{},
		}, nil
	}
	if userID == "bot" {
		return &domain.UserProfile{
			ID:          "bot",
			Username:    "AI Bot",
			AvatarIndex: 7,
			Rating:      1200,
			Roles:       []string{"bot"},
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

	profiles := make([]domain.UserProfile, 0, len(users))
	for _, u := range users {
		if u.IsSystem() {
			continue
		}
		profiles = append(profiles, u.ToProfile())
	}
	return profiles, nil
}

func (s *userService) UpdateAvatar(ctx context.Context, userID string, avatarIndex int, avatarCustom ...string) (*domain.UserProfile, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	user.AvatarIndex = avatarIndex
	if len(avatarCustom) > 0 {
		user.AvatarCustom = avatarCustom[0]
	}
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

func (s *userService) DeleteAccount(ctx context.Context, userID string, password string) error {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return errors.New("user not found")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return ErrWrongPassword
	}

	return s.userRepo.Delete(ctx, userID)
}

func (s *userService) SearchUsers(ctx context.Context, query string, currentUserID string, limit int) ([]domain.UserSearchResult, error) {
	trimmed := strings.TrimSpace(query)
	if trimmed == "" {
		return []domain.UserSearchResult{}, nil
	}

	users, err := s.userRepo.Search(ctx, trimmed, currentUserID, limit)
	if err != nil {
		return nil, err
	}

	if len(users) == 0 {
		return []domain.UserSearchResult{}, nil
	}

	// If current user is authenticated, check friendship status
	statusMap := make(map[string]string)       // targetUserID -> status ("friend", "incoming", "outgoing")
	friendshipIDMap := make(map[string]string) // targetUserID -> friendshipID

	if currentUserID != "" && s.friendRepo != nil {
		// 1. Get accepted friends
		friends, err := s.friendRepo.ListFriends(ctx, currentUserID)
		if err == nil {
			for _, f := range friends {
				otherID := f.RequesterID
				if otherID == currentUserID {
					otherID = f.AddresseeID
				}
				statusMap[otherID] = "friend"
				friendshipIDMap[otherID] = f.ID
			}
		}

		// 2. Get pending requests
		requests, err := s.friendRepo.ListPendingRequests(ctx, currentUserID)
		if err == nil {
			for _, r := range requests {
				if r.Status == domain.FriendshipStatusPending {
					if r.RequesterID == currentUserID {
						statusMap[r.AddresseeID] = "outgoing"
						friendshipIDMap[r.AddresseeID] = r.ID
					} else if r.AddresseeID == currentUserID {
						statusMap[r.RequesterID] = "incoming"
						friendshipIDMap[r.RequesterID] = r.ID
					}
				}
			}
		}
	}

	results := make([]domain.UserSearchResult, 0, len(users))
	for _, u := range users {
		if u.IsSystem() {
			continue
		}
		prof := u.ToProfile()
		status := "none"
		fID := ""

		if st, ok := statusMap[u.ID]; ok {
			status = st
			fID = friendshipIDMap[u.ID]
		}

		results = append(results, domain.UserSearchResult{
			ID:               prof.ID,
			Username:         prof.Username,
			AvatarIndex:      prof.AvatarIndex,
			AvatarCustom:     prof.AvatarCustom,
			Rating:           prof.Rating,
			IsProvisional:    prof.IsProvisional,
			Wins:             prof.Wins,
			Losses:           prof.Losses,
			Draws:            prof.Draws,
			WinRate:          prof.WinRate,
			Roles:            prof.Roles,
			FriendshipStatus: status,
			FriendshipID:     fID,
		})
	}

	return results, nil
}

func (s *userService) UpdateRoles(ctx context.Context, userID string, roles []string) (*domain.UserProfile, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("user not found")
	}

	sanitized := make([]string, 0, len(roles))
	seen := make(map[string]bool)
	for _, r := range roles {
		trimmed := strings.ToLower(strings.TrimSpace(r))
		if trimmed != "" && !seen[trimmed] {
			seen[trimmed] = true
			sanitized = append(sanitized, trimmed)
		}
	}

	user.Roles = sanitized
	user.UpdatedAt = time.Now()
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	profile := user.ToProfile()
	return &profile, nil
}




