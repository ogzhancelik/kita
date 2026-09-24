package ports

import (
	"context"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	FindByID(ctx context.Context, id string) (*domain.User, error)
	FindByUsername(ctx context.Context, username string) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*domain.User, error)
	Update(ctx context.Context, user *domain.User) error
	GetLeaderboard(ctx context.Context, limit int, userIDs []string) ([]domain.User, error)
}

type MatchRepository interface {
	SaveFinishedMatchWithMoves(ctx context.Context, match *domain.Match, whiteRating, whiteRD, whiteVol, blackRating, blackRD, blackVol float64) error
	FindByID(ctx context.Context, id string) (*domain.Match, error)
	FindUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error)
	GetMovesByMatchID(ctx context.Context, matchID string) ([]domain.MoveRecord, error)
}

type MessageRepository interface {
	Save(ctx context.Context, msg *domain.Message) error
	GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error)
}

type SettingsRepository interface {
	GetByUserID(ctx context.Context, userID string) (*domain.UserSettings, error)
	Upsert(ctx context.Context, settings *domain.UserSettings) error
	ResetToDefaults(ctx context.Context, userID string) (*domain.UserSettings, error)
}

type FriendRepository interface {
	Create(ctx context.Context, friendship *domain.Friendship) error
	FindByID(ctx context.Context, id string) (*domain.Friendship, error)
	FindByUsers(ctx context.Context, user1, user2 string) (*domain.Friendship, error)
	UpdateStatus(ctx context.Context, id string, status string) error
	Delete(ctx context.Context, id string) error
	ListFriends(ctx context.Context, userID string) ([]domain.Friendship, error)
	ListPendingRequests(ctx context.Context, userID string) ([]domain.Friendship, error)
}

type NotificationRepository interface {
	Create(ctx context.Context, notif *domain.Notification) error
	FindByID(ctx context.Context, id string) (*domain.Notification, error)
	ListByUserID(ctx context.Context, userID string, limit, offset int) ([]domain.Notification, error)
	GetUnreadCount(ctx context.Context, userID string) (int64, error)
	UpdateStatus(ctx context.Context, id string, userID string, status string) error
	MarkAllAsRead(ctx context.Context, userID string) error
	Delete(ctx context.Context, id string, userID string) error
	DeletePendingChallenge(ctx context.Context, actorID string, friendID string) error
}

