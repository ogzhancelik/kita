package service

import (
	"context"
	"math"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type matchService struct {
	matchRepo ports.MatchRepository
	userRepo  ports.UserRepository
}

func NewMatchService(matchRepo ports.MatchRepository, userRepo ports.UserRepository) ports.MatchService {
	return &matchService{
		matchRepo: matchRepo,
		userRepo:  userRepo,
	}
}

func (s *matchService) SaveFinishedMatch(ctx context.Context, match *domain.Match) error {
	// Oyuncuların mevcut puanlarını al
	whiteUser, _ := s.userRepo.FindByID(ctx, match.WhitePlayerID)
	blackUser, _ := s.userRepo.FindByID(ctx, match.BlackPlayerID)

	whiteRating := 1200
	blackRating := 1200
	if whiteUser != nil {
		whiteRating = whiteUser.Rating
	}
	if blackUser != nil {
		blackRating = blackUser.Rating
	}

	// ELO hesaplaması
	deltaWhite, deltaBlack := calculateElo(whiteRating, blackRating, match.Result, match.WinnerID, match.WhitePlayerID)

	// Maçı ve tüm hamleleri tek transaction ile veritabanına kaydet
	return s.matchRepo.SaveFinishedMatchWithMoves(ctx, match, deltaWhite, deltaBlack)
}

func (s *matchService) GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error) {
	return s.matchRepo.FindByID(ctx, matchID)
}

func (s *matchService) GetMatchMoves(ctx context.Context, matchID string) ([]domain.MatchMove, error) {
	return s.matchRepo.GetMovesByMatchID(ctx, matchID)
}

func (s *matchService) GetUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	return s.matchRepo.FindUserMatches(ctx, userID, limit, offset)
}

// calculateElo calculates standard Elo rating changes
func calculateElo(rWhite, rBlack int, result domain.MatchResult, winnerID *string, whitePlayerID string) (int, int) {
	const k = 32.0

	// Expected scores
	expWhite := 1.0 / (1.0 + math.Pow(10.0, float64(rBlack-rWhite)/400.0))
	expBlack := 1.0 - expWhite

	var scoreWhite float64
	var scoreBlack float64

	if result == domain.ResultWhiteWins {
		scoreWhite, scoreBlack = 1.0, 0.0
	} else if result == domain.ResultBlackWins {
		scoreWhite, scoreBlack = 0.0, 1.0
	} else if result == domain.ResultDraw {
		scoreWhite, scoreBlack = 0.5, 0.5
	} else if winnerID != nil {
		if *winnerID == whitePlayerID {
			scoreWhite, scoreBlack = 1.0, 0.0
		} else {
			scoreWhite, scoreBlack = 0.0, 1.0
		}
	} else {
		scoreWhite, scoreBlack = 0.5, 0.5
	}

	deltaWhite := int(math.Round(k * (scoreWhite - expWhite)))
	deltaBlack := int(math.Round(k * (scoreBlack - expBlack)))

	return deltaWhite, deltaBlack
}
