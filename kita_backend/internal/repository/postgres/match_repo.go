package postgres

import (
	"context"
	"errors"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	"gorm.io/gorm"
)

type matchRepo struct {
	db *gorm.DB
}

func NewMatchRepository(db *gorm.DB) ports.MatchRepository {
	return &matchRepo{db: db}
}

// SaveFinishedMatchWithMoves: Tek bir PostgreSQL transaction'ı ile hem maçı,
// hem tüm hamleleri (batch insert) hem de oyuncu istatistiklerini/rating'lerini atomik olarak günceller.
func (r *matchRepo) SaveFinishedMatchWithMoves(
	ctx context.Context,
	match *domain.Match,
	whiteRatingChange, blackRatingChange int,
) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 1. Maç ve ilişkili tüm hamleleri kaydet (GORM match.Moves'u otomatik topluca insert eder)
		if err := tx.Create(match).Error; err != nil {
			return err
		}

		// 2. Beyaz oyuncunun istatistiklerini güncelle
		var whiteUser domain.User
		if err := tx.First(&whiteUser, "id = ?", match.WhitePlayerID).Error; err == nil {
			whiteUser.Rating += whiteRatingChange
			if whiteUser.Rating < 100 {
				whiteUser.Rating = 100 // Taban puan sınırı
			}
			if match.Result == domain.ResultWhiteWins {
				whiteUser.Wins++
			} else if match.Result == domain.ResultBlackWins || match.Result == domain.ResultResigned || match.Result == domain.ResultAbandoned {
				if match.WinnerID != nil && *match.WinnerID == match.WhitePlayerID {
					whiteUser.Wins++
				} else {
					whiteUser.Losses++
				}
			} else if match.Result == domain.ResultDraw {
				whiteUser.Draws++
			}
			_ = tx.Save(&whiteUser).Error
		}

		// 3. Siyah oyuncunun istatistiklerini güncelle
		var blackUser domain.User
		if err := tx.First(&blackUser, "id = ?", match.BlackPlayerID).Error; err == nil {
			blackUser.Rating += blackRatingChange
			if blackUser.Rating < 100 {
				blackUser.Rating = 100
			}
			if match.Result == domain.ResultBlackWins {
				blackUser.Wins++
			} else if match.Result == domain.ResultWhiteWins || match.Result == domain.ResultResigned || match.Result == domain.ResultAbandoned {
				if match.WinnerID != nil && *match.WinnerID == match.BlackPlayerID {
					blackUser.Wins++
				} else {
					blackUser.Losses++
				}
			} else if match.Result == domain.ResultDraw {
				blackUser.Draws++
			}
			_ = tx.Save(&blackUser).Error
		}

		return nil
	})
}

func (r *matchRepo) FindByID(ctx context.Context, id string) (*domain.Match, error) {
	var match domain.Match
	err := r.db.WithContext(ctx).
		Preload("WhitePlayer").
		Preload("BlackPlayer").
		Preload("Moves", func(db *gorm.DB) *gorm.DB {
			return db.Order("match_moves.ply_index ASC")
		}).
		First(&match, "id = ?", id).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &match, nil
}

func (r *matchRepo) FindUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error) {
	var matches []domain.Match
	err := r.db.WithContext(ctx).
		Preload("WhitePlayer").
		Preload("BlackPlayer").
		Where("white_player_id = ? OR black_player_id = ?", userID, userID).
		Order("started_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&matches).Error

	if err != nil {
		return nil, err
	}
	return matches, nil
}

func (r *matchRepo) GetMovesByMatchID(ctx context.Context, matchID string) ([]domain.MatchMove, error) {
	var moves []domain.MatchMove
	err := r.db.WithContext(ctx).
		Where("match_id = ?", matchID).
		Order("ply_index ASC").
		Find(&moves).Error

	if err != nil {
		return nil, err
	}
	return moves, nil
}
