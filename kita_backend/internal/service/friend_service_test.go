package service

import (
	"context"
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockUserRepoForFriendService struct {
	users []domain.User
}

func (m *mockUserRepoForFriendService) Create(ctx context.Context, user *domain.User) error { return nil }
func (m *mockUserRepoForFriendService) FindByID(ctx context.Context, id string) (*domain.User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return &u, nil
		}
	}
	return nil, nil
}
func (m *mockUserRepoForFriendService) FindByUsername(ctx context.Context, username string) (*domain.User, error) {
	for _, u := range m.users {
		if u.Username == username {
			return &u, nil
		}
	}
	return nil, nil // User not found returns nil, nil like GORM userRepo
}
func (m *mockUserRepoForFriendService) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	return nil, nil
}
func (m *mockUserRepoForFriendService) Update(ctx context.Context, user *domain.User) error { return nil }
func (m *mockUserRepoForFriendService) GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error) {
	return nil, nil
}

type mockFriendRepoForFriendService struct {
	friendships []*domain.Friendship
}

func (m *mockFriendRepoForFriendService) Create(ctx context.Context, friendship *domain.Friendship) error {
	m.friendships = append(m.friendships, friendship)
	return nil
}
func (m *mockFriendRepoForFriendService) FindByID(ctx context.Context, id string) (*domain.Friendship, error) {
	for _, f := range m.friendships {
		if f.ID == id {
			return f, nil
		}
	}
	return nil, nil
}
func (m *mockFriendRepoForFriendService) FindByUsers(ctx context.Context, user1, user2 string) (*domain.Friendship, error) {
	for _, f := range m.friendships {
		if (f.RequesterID == user1 && f.AddresseeID == user2) || (f.RequesterID == user2 && f.AddresseeID == user1) {
			return f, nil
		}
	}
	return nil, nil
}
func (m *mockFriendRepoForFriendService) UpdateStatus(ctx context.Context, id string, status string) error {
	for _, f := range m.friendships {
		if f.ID == id {
			f.Status = status
			return nil
		}
	}
	return nil
}
func (m *mockFriendRepoForFriendService) Delete(ctx context.Context, id string) error {
	return nil
}
func (m *mockFriendRepoForFriendService) ListFriends(ctx context.Context, userID string) ([]domain.Friendship, error) {
	return nil, nil
}
func (m *mockFriendRepoForFriendService) ListPendingRequests(ctx context.Context, userID string) ([]domain.Friendship, error) {
	return nil, nil
}

func TestFriendService_SendRequest_UserNotFound(t *testing.T) {
	userRepo := &mockUserRepoForFriendService{
		users: []domain.User{
			{ID: "u1", Username: "alice"},
		},
	}
	friendRepo := &mockFriendRepoForFriendService{}
	svc := NewFriendService(friendRepo, userRepo)

	// Sending request to non-existent user "nonexistent" should NOT panic and should return not found
	f, err := svc.SendRequest(context.Background(), "u1", "nonexistent")
	if err == nil {
		t.Fatalf("expected error for non-existent user, got nil")
	}
	if f != nil {
		t.Fatalf("expected nil friendship, got %v", f)
	}
}

func TestFriendService_SendRequest_ToSelf(t *testing.T) {
	userRepo := &mockUserRepoForFriendService{
		users: []domain.User{
			{ID: "u1", Username: "alice"},
		},
	}
	friendRepo := &mockFriendRepoForFriendService{}
	svc := NewFriendService(friendRepo, userRepo)

	_, err := svc.SendRequest(context.Background(), "u1", "alice")
	if err == nil {
		t.Fatalf("expected error when sending request to self, got nil")
	}
}

func TestFriendService_SendRequest_Success(t *testing.T) {
	userRepo := &mockUserRepoForFriendService{
		users: []domain.User{
			{ID: "u1", Username: "alice"},
			{ID: "u2", Username: "bob"},
		},
	}
	friendRepo := &mockFriendRepoForFriendService{}
	svc := NewFriendService(friendRepo, userRepo)

	f, err := svc.SendRequest(context.Background(), "u1", "bob")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f == nil {
		t.Fatalf("expected non-nil friendship")
	}
	if f.RequesterID != "u1" || f.AddresseeID != "u2" {
		t.Errorf("unexpected friendship: %+v", f)
	}
}
