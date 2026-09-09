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
	GetLeaderboard(ctx context.Context, limit int) ([]domain.UserProfile, error)
}

type MatchService interface {
	SaveFinishedMatch(ctx context.Context, match *domain.Match) error
	GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error)
	GetMatchMoves(ctx context.Context, matchID string) ([]domain.MatchMove, error)
	GetUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error)
}

type MessageService interface {
	SaveMessage(ctx context.Context, matchID, senderID, content string) (*domain.Message, error)
	GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error)
}
