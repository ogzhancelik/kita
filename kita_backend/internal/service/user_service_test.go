package service

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"golang.org/x/crypto/bcrypt"
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
	for _, user := range m.users {
		if strings.EqualFold(user.Username, u) {
			return &user, nil
		}
	}
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

func (m *mockUserRepoForUserService) Delete(ctx context.Context, id string) error {
	for i, u := range m.users {
		if u.ID == id {
			m.users = append(m.users[:i], m.users[i+1:]...)
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

func (m *mockUserRepoForUserService) Search(ctx context.Context, query string, excludeUserID string, limit int) ([]domain.User, error) {
	var res []domain.User
	q := strings.ToLower(query)
	for _, u := range m.users {
		if excludeUserID != "" && u.ID == excludeUserID {
			continue
		}
		if strings.Contains(strings.ToLower(u.Username), q) {
			res = append(res, u)
		}
	}
	return res, nil
}

func (m *mockUserRepoForUserService) UpdateRoles(ctx context.Context, userID string, roles []string) error {
	for i, u := range m.users {
		if u.ID == userID {
			m.users[i].Roles = roles
			return nil
		}
	}
	return nil
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
func (m *mockFriendRepoForUserService) GetLastInteractions(ctx context.Context, userID string, friendIDs []string) (map[string]time.Time, error) {
	return make(map[string]time.Time), nil
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

func TestUserService_UpdateAvatar_WithCustomEmoji(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", AvatarIndex: 0, AvatarCustom: ""},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	profile, err := svc.UpdateAvatar(context.Background(), "u1", 3, "🦊")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if profile.AvatarIndex != 3 {
		t.Errorf("expected avatar_index 3, got %d", profile.AvatarIndex)
	}
	if profile.AvatarCustom != "🦊" {
		t.Errorf("expected avatar_custom '🦊', got '%s'", profile.AvatarCustom)
	}

	user, err := userRepo.FindByID(context.Background(), "u1")
	if err != nil || user == nil {
		t.Fatalf("failed to find user: %v", err)
	}
	if user.AvatarCustom != "🦊" {
		t.Errorf("expected repo user avatar_custom '🦊', got '%s'", user.AvatarCustom)
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

func TestUserService_UpdateUsername(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "playerOne", Rating: 1200},
			{ID: "u2", Username: "playerTwo", Rating: 1300},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)
	ctx := context.Background()

	// 1. Invalid username (too short)
	_, err := svc.UpdateUsername(ctx, "u1", "a")
	if err != ErrInvalidUsername {
		t.Fatalf("expected ErrInvalidUsername for single char, got %v", err)
	}

	// 2. Reserved username
	_, err = svc.UpdateUsername(ctx, "u1", "admin")
	if err != ErrUsernameReserved {
		t.Fatalf("expected ErrUsernameReserved for 'admin', got %v", err)
	}

	// 3. Already taken username
	_, err = svc.UpdateUsername(ctx, "u1", "playerTwo")
	if err != ErrUserAlreadyExists {
		t.Fatalf("expected ErrUserAlreadyExists for taken name, got %v", err)
	}

	// 4. Same username returns profile successfully
	prof, err := svc.UpdateUsername(ctx, "u1", "playerOne")
	if err != nil || prof.Username != "playerOne" {
		t.Fatalf("expected success on identical username, got %v", err)
	}

	// 5. Successful username change
	prof, err = svc.UpdateUsername(ctx, "u1", "playerRenamed")
	if err != nil {
		t.Fatalf("expected success, got %v", err)
	}
	if prof.Username != "playerRenamed" {
		t.Fatalf("expected profile username to be 'playerRenamed', got %s", prof.Username)
	}

	// Verify persistence in repo
	u1, _ := userRepo.FindByID(ctx, "u1")
	if u1.Username != "playerRenamed" {
		t.Fatalf("expected repo username to be 'playerRenamed', got %s", u1.Username)
	}
}

func TestUserService_DeleteAccount(t *testing.T) {
	hash, _ := bcrypt.GenerateFromPassword([]byte("secret123"), bcrypt.DefaultCost)
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "playerOne", PasswordHash: string(hash), Rating: 1200},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)
	ctx := context.Background()

	// 1. Delete with wrong password
	err := svc.DeleteAccount(ctx, "u1", "wrongpass")
	if err != ErrWrongPassword {
		t.Fatalf("expected ErrWrongPassword, got %v", err)
	}

	// 2. Delete non-existent account
	err = svc.DeleteAccount(ctx, "nonexistent", "secret123")
	if err == nil {
		t.Fatalf("expected error for non-existent user, got nil")
	}

	// 3. Delete existing account with correct password
	err = svc.DeleteAccount(ctx, "u1", "secret123")
	if err != nil {
		t.Fatalf("expected delete to succeed, got %v", err)
	}

	// Verify user is deleted
	u, _ := userRepo.FindByID(ctx, "u1")
	if u != nil {
		t.Fatalf("expected user to be nil after deletion")
	}
}

func TestUserService_SearchUsers(t *testing.T) {
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "Alice", Rating: 1500, Wins: 10, Losses: 5},
			{ID: "u2", Username: "Bob", Rating: 1600, Wins: 20, Losses: 10},
			{ID: "u3", Username: "Charlie", Rating: 1400, Wins: 5, Losses: 2},
		},
	}
	friendRepo := &mockFriendRepoForUserService{
		friends: []domain.Friendship{
			{ID: "f1", RequesterID: "u1", AddresseeID: "u2", Status: domain.FriendshipStatusAccepted},
		},
	}
	svc := NewUserService(userRepo, friendRepo)
	ctx := context.Background()

	// 1. Search with empty query -> returns empty
	emptyResults, err := svc.SearchUsers(ctx, "", "u1", 10)
	if err != nil || len(emptyResults) != 0 {
		t.Fatalf("expected empty results for empty query, got %d, err: %v", len(emptyResults), err)
	}

	// 2. Search excluding self ("u1") with query "li" -> finds Alice ("u1", excluded) and Charlie ("u3")
	results, err := svc.SearchUsers(ctx, "li", "u1", 10)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result (Charlie), got %d", len(results))
	}
	if results[0].Username != "Charlie" {
		t.Errorf("expected Charlie, got %s", results[0].Username)
	}
	if results[0].FriendshipStatus != "none" {
		t.Errorf("expected friendship status none, got %s", results[0].FriendshipStatus)
	}

	// 3. Search query "ob" as u1 -> Bob is found, should have status "friend"
	bobResults, err := svc.SearchUsers(ctx, "ob", "u1", 10)
	if err != nil || len(bobResults) != 1 {
		t.Fatalf("expected Bob to be found, got %d results, err: %v", len(bobResults), err)
	}
	if bobResults[0].FriendshipStatus != "friend" {
		t.Errorf("expected Bob to have status 'friend', got %s", bobResults[0].FriendshipStatus)
	}
	if bobResults[0].FriendshipID != "f1" {
		t.Errorf("expected Bob to have friendship_id 'f1', got %s", bobResults[0].FriendshipID)
	}
}

func TestUserService_UpdateRoles(t *testing.T) {
	ctx := context.Background()
	userRepo := &mockUserRepoForUserService{
		users: []domain.User{
			{ID: "u1", Username: "player1", Roles: []string{}},
		},
	}
	friendRepo := &mockFriendRepoForUserService{}
	svc := NewUserService(userRepo, friendRepo)

	// Update with admin and premium (with duplicates and mixed casing)
	profile, err := svc.UpdateRoles(ctx, "u1", []string{"Admin", "premium", "ADMIN", "  vip  "})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(profile.Roles) != 3 {
		t.Fatalf("expected 3 roles, got %d: %v", len(profile.Roles), profile.Roles)
	}
	if !profile.IsAdmin() {
		t.Errorf("expected IsAdmin to be true")
	}
	if !profile.IsPremium() {
		t.Errorf("expected IsPremium to be true")
	}
	if !profile.HasRole("vip") {
		t.Errorf("expected HasRole('vip') to be true")
	}

	// Verify not found user
	_, err = svc.UpdateRoles(ctx, "unknown", []string{"admin"})
	if err == nil {
		t.Errorf("expected error for unknown user, got nil")
	}
}





