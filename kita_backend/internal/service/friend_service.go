package service

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
	appErrors "github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type friendService struct {
	friendRepo ports.FriendRepository
	userRepo   ports.UserRepository
}

func NewFriendService(friendRepo ports.FriendRepository, userRepo ports.UserRepository) ports.FriendService {
	return &friendService{
		friendRepo: friendRepo,
		userRepo:   userRepo,
	}
}

func (s *friendService) SendRequest(ctx context.Context, requesterID, targetUsername string) (*domain.Friendship, error) {
	targetUser, err := s.userRepo.FindByUsername(ctx, targetUsername)
	if err != nil || targetUser == nil {
		return nil, appErrors.New(appErrors.ErrNotFound, "user not found")
	}

	if targetUser.ID == requesterID {
		return nil, appErrors.New(appErrors.ErrValidationFailed, "cannot send friend request to yourself")
	}

	existing, err := s.friendRepo.FindByUsers(ctx, requesterID, targetUser.ID)
	if err == nil && existing != nil {
		if existing.Status == domain.FriendshipStatusAccepted {
			return nil, appErrors.New(appErrors.ErrValidationFailed, "already friends with this user")
		}
		if existing.Status == domain.FriendshipStatusPending {
			return nil, appErrors.New(appErrors.ErrValidationFailed, "friend request already pending")
		}
		// If previously rejected, update back to pending
		existing.Status = domain.FriendshipStatusPending
		existing.RequesterID = requesterID
		existing.AddresseeID = targetUser.ID
		existing.UpdatedAt = time.Now()
		if err := s.friendRepo.UpdateStatus(ctx, existing.ID, domain.FriendshipStatusPending); err != nil {
			return nil, appErrors.New(appErrors.ErrInternalServer, "failed to update friend request")
		}
		return existing, nil
	}

	friendship := &domain.Friendship{
		ID:          uuid.New().String(),
		RequesterID: requesterID,
		AddresseeID: targetUser.ID,
		Status:      domain.FriendshipStatusPending,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := s.friendRepo.Create(ctx, friendship); err != nil {
		return nil, appErrors.New(appErrors.ErrInternalServer, "failed to create friend request")
	}

	return friendship, nil
}

func (s *friendService) AcceptRequest(ctx context.Context, userID, friendshipID string) error {
	f, err := s.friendRepo.FindByID(ctx, friendshipID)
	if err != nil || f == nil {
		return appErrors.New(appErrors.ErrNotFound, "friend request not found")
	}

	if f.AddresseeID != userID {
		return appErrors.New(appErrors.ErrUnauthorized, "you can only accept requests sent to you")
	}

	if f.Status != domain.FriendshipStatusPending {
		return appErrors.New(appErrors.ErrValidationFailed, "request is no longer pending")
	}

	return s.friendRepo.UpdateStatus(ctx, friendshipID, domain.FriendshipStatusAccepted)
}

func (s *friendService) DeclineRequest(ctx context.Context, userID, friendshipID string) error {
	f, err := s.friendRepo.FindByID(ctx, friendshipID)
	if err != nil || f == nil {
		return appErrors.New(appErrors.ErrNotFound, "friend request not found")
	}

	if f.AddresseeID != userID && f.RequesterID != userID {
		return appErrors.New(appErrors.ErrUnauthorized, "unauthorized to decline this request")
	}

	return s.friendRepo.Delete(ctx, friendshipID)
}

func (s *friendService) RemoveFriend(ctx context.Context, userID, friendID string) error {
	f, err := s.friendRepo.FindByUsers(ctx, userID, friendID)
	if err != nil || f == nil {
		return appErrors.New(appErrors.ErrNotFound, "friendship not found")
	}

	return s.friendRepo.Delete(ctx, f.ID)
}

func (s *friendService) GetFriends(ctx context.Context, userID string) ([]domain.FriendItem, error) {
	list, err := s.friendRepo.ListFriends(ctx, userID)
	if err != nil {
		return nil, appErrors.New(appErrors.ErrInternalServer, "failed to load friends")
	}

	items := make([]domain.FriendItem, 0, len(list))
	for _, f := range list {
		var otherUser *domain.User
		if f.RequesterID == userID {
			otherUser = f.Addressee
		} else {
			otherUser = f.Requester
		}

		if otherUser != nil {
			items = append(items, domain.FriendItem{
				FriendshipID: f.ID,
				UserID:       otherUser.ID,
				Username:     otherUser.Username,
				Rating:       int(math.Round(otherUser.Rating)),
				Status:       f.Status,
				Direction:    "friend",
				IsOnline:     false, // Can be matched against Hub
				CreatedAt:    f.CreatedAt,
			})
		}
	}
	return items, nil
}

func (s *friendService) GetPendingRequests(ctx context.Context, userID string) ([]domain.FriendItem, error) {
	list, err := s.friendRepo.ListPendingRequests(ctx, userID)
	if err != nil {
		return nil, appErrors.New(appErrors.ErrInternalServer, "failed to load pending requests")
	}

	items := make([]domain.FriendItem, 0, len(list))
	for _, f := range list {
		isOutgoing := f.RequesterID == userID
		var otherUser *domain.User
		direction := "incoming"
		if isOutgoing {
			otherUser = f.Addressee
			direction = "outgoing"
		} else {
			otherUser = f.Requester
			direction = "incoming"
		}

		if otherUser != nil {
			items = append(items, domain.FriendItem{
				FriendshipID: f.ID,
				UserID:       otherUser.ID,
				Username:     otherUser.Username,
				Rating:       int(math.Round(otherUser.Rating)),
				Status:       f.Status,
				Direction:    direction,
				IsOnline:     false,
				CreatedAt:    f.CreatedAt,
			})
		}
	}
	return items, nil
}
