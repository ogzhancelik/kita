package service

import (
	"context"
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockUserRepoForUserService struct {
	users []domain.User
}

func (m *mockUserRepoForUserService) Create(ctx context.Context, user *domain.User) error { return nil }
func (m *mockUserRepoForUserService) FindByID(ctx context.Context, id string) (*domain.User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return &u, nil
		}
	}
	return nil, nil
}
func (m *mockUserRepoForUserService) FindByUsername(ctx context.Context, u string) (*domain.User, error) {
	return nil, nil
}
func (m *mockUserRepoForUserService) FindByEmail(ctx context.Context, e string) (*domain.User, error) {
	return nil, nil
}
func (m *mockUserRepoForUserService) Update(ctx context.Context, user *domain.User) error {
	for i, u := range m.users {
		if u.ID == user.ID {
			m.users[i] = *user
			return nil
		}
	}
	return nil
}
func (m *mockUserRepoForUserService) GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error) {
	if len(userIDs) == 0 {
		return m.users, nil
	}
	allowed := make(map[string]bool)
	for _, id := range userIDs {
		allowed[id] = true
	}
	var filtered []domain.User
	for _, u := range m.users {
		if allowed[u.ID] {
			filtered = append(filtered, u)
		}
	}
	return filtered, nil
}

type mockFriendRepoForUserService struct {
	friends []domain.Friendship
}

func (m *mockFriendRepoForUserService) Create(ctx context.Context, friendship *domain.Friendship) error {
	return nil
}
func (m *mockFriendRepoForUserService) FindByID(ctx context.Context, id string) (*domain.Friendship, error) {
	return nil, nil
}
func (m *mockFriendRepoForUserService) FindByUsers(ctx context.Context, user1, user2 string) (*domain.Friendship, error) {
	return nil, nil
}
func (m *mockFriendRepoForUserService) UpdateStatus(ctx context.Context, id string, status string) error {
	return nil
}
func (m *mockFriendRepoForUserService) Delete(ctx context.Context, id string) error { return nil }
func (m *mockFriendRepoForUserService) ListFriends(ctx context.Context, userID string) ([]domain.Friendship, error) {
	var res []domain.Friendship
	for _, f := range m.friends {
		if f.Status == domain.FriendshipStatusAccepted && (f.RequesterID == userID || f.AddresseeID == userID) {
			res = append(res, f)
		}
	}
	return res, nil
}
func (m *mockFriendRepoForUserService) ListPendingRequests(ctx context.Context, userID string) ([]domain.Friendship, error) {
	return nil, nil
}

func TestUserService_GetLeaderboard_Global(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", Rating: 1600, Wins: 10},
			{ID: "u2", Username: "Bob", Rating: 1550, Wins: 8},
			{ID: "u3", Username: "Charlie", Rating: 1500, Wins: 5},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	profiles, err := svc.GetLeaderboard(context.Background(), 10, "global", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(profiles) != 3 {
		t.Fatalf("expected 3 profiles, got %d", len(profiles))
	}
	if profiles[0].Username != "Alice" {
		t.Errorf("expected Alice first, got %s", profiles[0].Username)
	}
}

func TestUserService_GetLeaderboard_Friends(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", Rating: 1600, Wins: 10},
			{ID: "u2", Username: "Bob", Rating: 1550, Wins: 8},
			{ID: "u3", Username: "Charlie", Rating: 1500, Wins: 5},
		},
	}
	friendRepo := &mockFriendRepoForUserService{
		friends: []domain.Friendship{
			{
				ID:          "f1",
				RequesterID: "u2",
				AddresseeID: "u3",
				Status:      domain.FriendshipStatusAccepted,
			},
		},
	}
	svc := NewUserService(userRepo, friendRepo)

	// Bob requests friends leaderboard. Expected: Bob (u2) and Charlie (u3). Alice (u1) should NOT be in result.
	profiles, err := svc.GetLeaderboard(context.Background(), 10, "friends", "u2")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(profiles) != 2 {
		t.Fatalf("expected 2 profiles, got %d", len(profiles))
	}
	foundAlice := false
	for _, p := range profiles {
		if p.Username == "Alice" {
			foundAlice = true
		}
	}
	if foundAlice {
		t.Errorf("Alice is not Bob's friend and should not appear in friends leaderboard")
	}
}

func TestUserService_GetLeaderboard_Friends_Unauthenticated(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", Rating: 1600},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	profiles, err := svc.GetLeaderboard(context.Background(), 10, "friends", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(profiles) != 0 {
		t.Errorf("expected empty profiles for unauthenticated friends leaderboard, got %d", len(profiles))
	}
}

func TestUserService_UpdateAvatar(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", AvatarIndex: 0},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	profile, err := svc.UpdateAvatar(context.Background(), "u1", 4)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if profile.AvatarIndex != 4 {
		t.Errorf("expected avatar_index 4, got %d", profile.AvatarIndex)
	}

	// Verify persistence in repo
	user, err := userRepo.FindByID(context.Background(), "u1")
	if err != nil || user == nil {
		t.Fatalf("failed to find user: %v", err)
	}
	if user.AvatarIndex != 4 {
		t.Errorf("expected repo user avatar_index 4, got %d", user.AvatarIndex)
	}
}

func TestUserService_UpdateAvatar_UserNotFound(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	_, err := svc.UpdateAvatar(context.Background(), "nonexistent", 2)
	if err == nil {
		t.Error("expected error for nonexistent user, got nil")
	}
}

