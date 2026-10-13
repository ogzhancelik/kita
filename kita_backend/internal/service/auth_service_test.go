package service

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockUserRepoForAuthService struct {
	users []*domain.User
}

func (m *mockUserRepoForAuthService) Create(ctx context.Context, user *domain.User) error {
	m.users = append(m.users, user)
	return nil
}

func (m *mockUserRepoForAuthService) FindByID(ctx context.Context, id string) (*domain.User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return u, nil
		}
	}
	return nil, nil
}

func (m *mockUserRepoForAuthService) FindByUsername(ctx context.Context, username string) (*domain.User, error) {
	for _, u := range m.users {
		if strings.EqualFold(u.Username, username) {
			return u, nil
		}
	}
	return nil, nil
}

func (m *mockUserRepoForAuthService) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	for _, u := range m.users {
		if strings.EqualFold(u.Email, email) {
			return u, nil
		}
	}
	return nil, nil
}

func (m *mockUserRepoForAuthService) Update(ctx context.Context, user *domain.User) error {
	for i, u := range m.users {
		if u.ID == user.ID {
			m.users[i] = user
			return nil
		}
	}
	return nil
}

func (m *mockUserRepoForAuthService) Delete(ctx context.Context, id string) error {
	for i, u := range m.users {
		if u.ID == id {
			m.users = append(m.users[:i], m.users[i+1:]...)
			return nil
		}
	}
	return nil
}

func (m *mockUserRepoForAuthService) GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error) {
	return nil, nil
}

func TestValidateUsername(t *testing.T) {
	tests := []struct {
		name     string
		username string
		wantErr  error
	}{
		// Valid usernames (2 to 15 chars, alphanumeric + _ + -)
		{"valid min length 2", "ab", nil},
		{"valid max length 15", "abcdefghijklmno", nil},
		{"valid with hyphen and underscore", "user_1-test", nil},
		{"valid numbers and letters", "Player99", nil},

		// Length boundaries
		{"too short (1 char)", "a", ErrInvalidUsername},
		{"too long (16 chars)", "abcdefghijklmnop", ErrInvalidUsername},
		{"empty string", "", ErrInvalidUsername},

		// Disallowed characters & whitespace
		{"contains space", "user name", ErrInvalidUsername},
		{"leading space", " user", ErrInvalidUsername},
		{"trailing space", "user ", ErrInvalidUsername},
		{"tab character", "user\tname", ErrInvalidUsername},
		{"special character @", "user@kita", ErrInvalidUsername},
		{"special character !", "user!name", ErrInvalidUsername},
		{"special character dot", "user.name", ErrInvalidUsername},
		{"unicode emoji", "user🔥", ErrInvalidUsername},

		// Reserved usernames (case-insensitive)
		{"reserved admin", "admin", ErrUsernameReserved},
		{"reserved Admin uppercase", "Admin", ErrUsernameReserved},
		{"reserved ADMIN all caps", "ADMIN", ErrUsernameReserved},
		{"reserved guest", "guest", ErrUsernameReserved},
		{"reserved Guest", "Guest", ErrUsernameReserved},
		{"reserved system", "system", ErrUsernameReserved},
		{"reserved System", "System", ErrUsernameReserved},
		{"reserved kita", "kita", ErrUsernameReserved},
		{"reserved Kita", "Kita", ErrUsernameReserved},
		{"reserved bot", "bot", ErrUsernameReserved},
		{"reserved moderator", "moderator", ErrUsernameReserved},
		{"reserved support", "support", ErrUsernameReserved},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateUsername(tt.username)
			if err != tt.wantErr {
				t.Errorf("ValidateUsername(%q) = %v, want %v", tt.username, err, tt.wantErr)
			}
		})
	}
}

func TestAuthService_Register_CaseInsensitiveUniqueness(t *testing.T) {
	repo := &mockUserRepoForAuthService{
		users: []*domain.User{
			{ID: "1", Username: "PlayerOne", Email: "p1@kita.gg", PasswordHash: "hash"},
		},
	}
	svc := NewAuthService(repo)
	ctx := context.Background()

	// Attempt exact same username
	_, _, err := svc.Register(ctx, "PlayerOne", "new@kita.gg", "password123")
	if err != ErrUserAlreadyExists {
		t.Fatalf("expected ErrUserAlreadyExists for exact match, got %v", err)
	}

	// Attempt lowercase match (case-insensitive duplicate)
	_, _, err = svc.Register(ctx, "playerone", "new2@kita.gg", "password123")
	if err != ErrUserAlreadyExists {
		t.Fatalf("expected ErrUserAlreadyExists for case-insensitive duplicate 'playerone', got %v", err)
	}

	// Attempt uppercase match
	_, _, err = svc.Register(ctx, "PLAYERONE", "new3@kita.gg", "password123")
	if err != ErrUserAlreadyExists {
		t.Fatalf("expected ErrUserAlreadyExists for uppercase duplicate 'PLAYERONE', got %v", err)
	}

	// Successful registration with a distinct name
	newUser, token, err := svc.Register(ctx, "PlayerTwo", "p2@kita.gg", "password123")
	if err != nil {
		t.Fatalf("expected success for unique username, got %v", err)
	}
	if newUser.Username != "PlayerTwo" || token == "" {
		t.Fatalf("unexpected user or empty token: %+v", newUser)
	}
}

func TestIsReservedUsername_HotReloading(t *testing.T) {
	// Initially 'customvip' is not reserved
	if IsReservedUsername("customvip") {
		t.Fatalf("expected 'customvip' not to be reserved initially")
	}

	// Find the active config path
	path, _, err := findConfigFilePath()
	if err != nil {
		t.Skip("config file not found in test path, skipping file-mutation test")
	}

	// Read original content
	original, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read config file: %v", err)
	}
	defer func() {
		// Restore original content
		_ = os.WriteFile(path, original, 0644)
		// Touch file so modTime updates back
		time.Sleep(10 * time.Millisecond)
		reloadIfNeeded()
	}()

	// Append 'customvip' to the file
	time.Sleep(50 * time.Millisecond) // Ensure modTime changes
	appended := string(original) + "\ncustomvip\n"
	if err := os.WriteFile(path, []byte(appended), 0644); err != nil {
		t.Fatalf("failed to append to config file: %v", err)
	}

	// Should now automatically be recognized as reserved without restarting!
	if !IsReservedUsername("customvip") {
		t.Fatalf("expected 'customvip' to automatically be reserved after file edit")
	}
	if !IsReservedUsername("CustomVIP") {
		t.Fatalf("expected 'CustomVIP' (case-insensitive) to be reserved after file edit")
	}
}

func TestChangePassword(t *testing.T) {
	mockRepo := &mockUserRepoForAuthService{users: []*domain.User{}}
	svc := NewAuthService(mockRepo)
	ctx := context.Background()

	// Register a test user
	user, _, err := svc.Register(ctx, "passwordTester", "pass@test.com", "oldPassword123")
	if err != nil {
		t.Fatalf("failed to register user: %v", err)
	}

	// 1. Password too short (<6)
	err = svc.ChangePassword(ctx, user.ID, "oldPassword123", "123")
	if err != ErrPasswordTooShort {
		t.Fatalf("expected ErrPasswordTooShort, got %v", err)
	}

	// 2. Same password
	err = svc.ChangePassword(ctx, user.ID, "oldPassword123", "oldPassword123")
	if err != ErrSamePassword {
		t.Fatalf("expected ErrSamePassword, got %v", err)
	}

	// 3. Wrong current password
	err = svc.ChangePassword(ctx, user.ID, "wrongCurrent", "newPassword123")
	if err != ErrWrongPassword {
		t.Fatalf("expected ErrWrongPassword, got %v", err)
	}

	// 4. Successful password change
	err = svc.ChangePassword(ctx, user.ID, "oldPassword123", "newPassword123")
	if err != nil {
		t.Fatalf("expected successful change, got %v", err)
	}

	// 5. Verify login with new password works
	loginUser, _, err := svc.Login(ctx, "passwordTester", "newPassword123")
	if err != nil || loginUser == nil {
		t.Fatalf("failed to login with new password: %v", err)
	}

	// 6. Verify old password no longer works
	_, _, err = svc.Login(ctx, "passwordTester", "oldPassword123")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected old password to fail with ErrInvalidCredentials, got %v", err)
	}
}

