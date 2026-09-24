package ports

import (
	"context"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type AuthService interface {
	Register(ctx context.Context, username, email, password string) (*domain.User, string, error)
	Login(ctx context.Context, usernameOrEmail, password string) (*domain.User, string, error)
	ValidateToken(tokenString string) (string, error)
}

type UserService interface {
	GetProfile(ctx context.Context, userID string) (*domain.UserProfile, error)
	GetLeaderboard(ctx context.Context, limit int, filter string, currentUserID string) ([]domain.UserProfile, error)
	UpdateAvatar(ctx context.Context, userID string, avatarIndex int) (*domain.UserProfile, error)
}

type MatchService interface {
	SaveFinishedMatch(ctx context.Context, match *domain.Match) (map[string]interface{}, error)
	GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error)
	GetMatchMoves(ctx context.Context, matchID string) ([]domain.MoveRecord, error)
	GetUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error)
}

type MessageService interface {
	SaveMessage(ctx context.Context, matchID, senderID, content string) (*domain.Message, error)
	GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error)
}

type SettingsService interface {
	GetSettings(ctx context.Context, userID string) (*domain.UserSettings, error)
	UpdateSettings(ctx context.Context, userID string, dto *domain.UpdateSettingsDTO) (*domain.UserSettings, error)
	ResetSettings(ctx context.Context, userID string) (*domain.UserSettings, error)
	GetDefaultSettings() domain.UserSettings
}

type FriendService interface {
	SendRequest(ctx context.Context, requesterID, targetUsername string) (*domain.Friendship, error)
	AcceptRequest(ctx context.Context, userID, friendshipID string) error
	DeclineRequest(ctx context.Context, userID, friendshipID string) error
	RemoveFriend(ctx context.Context, userID, friendID string) error
	GetFriends(ctx context.Context, userID string) ([]domain.FriendItem, error)
	GetPendingRequests(ctx context.Context, userID string) ([]domain.FriendItem, error)
}

type NotificationService interface {
	CreateNotification(ctx context.Context, notif *domain.Notification) (*domain.Notification, error)
	GetUserNotifications(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, int64, error)
	UpdateStatus(ctx context.Context, id string, userID string, status string) error
	MarkAllAsRead(ctx context.Context, userID string) error
	DeleteNotification(ctx context.Context, id string, userID string) error
	DeletePendingChallenge(ctx context.Context, actorID string, friendID string) error
}


