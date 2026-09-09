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
	GetLeaderboard(ctx context.Context, limit int) ([]domain.User, error)
}

type MatchRepository interface {
	SaveFinishedMatchWithMoves(ctx context.Context, match *domain.Match, whiteRatingChange, blackRatingChange int) error
	FindByID(ctx context.Context, id string) (*domain.Match, error)
	FindUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error)
	GetMovesByMatchID(ctx context.Context, matchID string) ([]domain.MatchMove, error)
}

type MessageRepository interface {
	Save(ctx context.Context, msg *domain.Message) error
	GetMatchMessages(ctx context.Context, matchID string, limit int) ([]domain.Message, error)
}
