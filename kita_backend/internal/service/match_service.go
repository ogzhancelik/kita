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
	whiteUser, _ := s.userRepo.FindByID(ctx, match.WhitePlayerID)
	blackUser, _ := s.userRepo.FindByID(ctx, match.BlackPlayerID)

	whiteRating, whiteRD, whiteVol := 1500.0, 350.0, 0.06
	blackRating, blackRD, blackVol := 1500.0, 350.0, 0.06

	if whiteUser != nil {
		whiteRating = whiteUser.Rating
		whiteRD = whiteUser.RatingDeviation
		if whiteRD == 0 { whiteRD = 350.0 }
		whiteVol = whiteUser.Volatility
		if whiteVol == 0 { whiteVol = 0.06 }
	}
	if blackUser != nil {
		blackRating = blackUser.Rating
		blackRD = blackUser.RatingDeviation
		if blackRD == 0 { blackRD = 350.0 }
		blackVol = blackUser.Volatility
		if blackVol == 0 { blackVol = 0.06 }
	}

	wR, wRD, wVol, bR, bRD, bVol := calculateGlicko2(whiteRating, whiteRD, whiteVol, blackRating, blackRD, blackVol, match.Result, match.WinnerID, match.WhitePlayerID)

	return s.matchRepo.SaveFinishedMatchWithMoves(ctx, match, wR, wRD, wVol, bR, bRD, bVol)
}

func (s *matchService) GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error) {
	return s.matchRepo.FindByID(ctx, matchID)
}

func (s *matchService) GetMatchMoves(ctx context.Context, matchID string) ([]domain.MoveRecord, error) {
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

const (
	glickoTau   = 0.5
	glickoScale = 173.7178
)

func glickoG(phi float64) float64 {
	return 1.0 / math.Sqrt(1.0+3.0*phi*phi/(math.Pi*math.Pi))
}

func glickoE(mu, muOpp, phiOpp float64) float64 {
	return 1.0 / (1.0 + math.Exp(-glickoG(phiOpp)*(mu-muOpp)))
}

func calculateGlicko2Single(r, rd, vol, rOpp, rdOpp, score float64) (float64, float64, float64) {
	mu := (r - 1500.0) / glickoScale
	phi := rd / glickoScale
	sigma := vol

	muOpp := (rOpp - 1500.0) / glickoScale
	phiOpp := rdOpp / glickoScale

	gOpp := glickoG(phiOpp)
	e := glickoE(mu, muOpp, phiOpp)

	v := 1.0 / (gOpp * gOpp * e * (1.0 - e))
	delta := v * gOpp * (score - e)

	a := math.Log(sigma * sigma)

	f := func(x float64) float64 {
		ex := math.Exp(x)
		num1 := ex * (delta*delta - phi*phi - v - ex)
		den1 := 2.0 * math.Pow(phi*phi+v+ex, 2)
		return (num1 / den1) - ((x - a) / (glickoTau * glickoTau))
	}

	epsilon := 0.000001
	A := a
	var B float64
	if (delta * delta) > (phi*phi + v) {
		B = math.Log(delta*delta - phi*phi - v)
	} else {
		k := 1.0
		for f(a-k*glickoTau) < 0 {
			k++
		}
		B = a - k*glickoTau
	}

	fA := f(A)
	fB := f(B)

	for math.Abs(B-A) > epsilon {
		C := A + (A-B)*fA/(fB-fA)
		fC := f(C)
		if fC*fB <= 0 {
			A = B
			fA = fB
		} else {
			fA = fA / 2.0
		}
		B = C
		fB = fC
	}

	sigmaPrime := math.Exp(A / 2.0)
	phiStar := math.Sqrt(phi*phi + sigmaPrime*sigmaPrime)
	phiPrime := 1.0 / math.Sqrt((1.0/(phiStar*phiStar))+(1.0/v))
	muPrime := mu + phiPrime*phiPrime*gOpp*(score-e)

	rPrime := glickoScale*muPrime + 1500.0
	rdPrime := glickoScale * phiPrime

	return rPrime, rdPrime, sigmaPrime
}

func calculateGlicko2(whiteR, whiteRD, whiteVol, blackR, blackRD, blackVol float64, result domain.MatchResult, winnerID *string, whitePlayerID string) (float64, float64, float64, float64, float64, float64) {
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

	wR, wRD, wVol := calculateGlicko2Single(whiteR, whiteRD, whiteVol, blackR, blackRD, scoreWhite)
	bR, bRD, bVol := calculateGlicko2Single(blackR, blackRD, blackVol, whiteR, whiteRD, scoreBlack)

	return wR, wRD, wVol, bR, bRD, bVol
}
