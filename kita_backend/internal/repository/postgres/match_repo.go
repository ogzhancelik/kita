package postgres

import (
	"context"
	"errors"
	"strings"

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
	whiteRating, whiteRD, whiteVol, blackRating, blackRD, blackVol float64,
) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 1. Maç ve ilişkili tüm hamleleri kaydet (GORM match.Moves'u otomatik topluca insert eder)
		if err := tx.Create(match).Error; err != nil {
			return err
		}

		// 2. Beyaz oyuncunun istatistiklerini güncelle (misafir değilse)
		if !strings.HasPrefix(match.WhitePlayerID, "guest-") {
			var whiteUser domain.User
			if err := tx.First(&whiteUser, "id = ?", match.WhitePlayerID).Error; err == nil {
				newRating := whiteRating
				if newRating < 100 {
					newRating = 100
				}
				newRD := whiteRD
				newVol := whiteVol

				wins := whiteUser.Wins
				losses := whiteUser.Losses
				draws := whiteUser.Draws

				if match.WinnerID != nil {
					if *match.WinnerID == match.WhitePlayerID {
						wins++
					} else {
						losses++
					}
				} else {
					draws++
				}

				_ = tx.Model(&domain.User{}).Where("id = ?", match.WhitePlayerID).Updates(map[string]interface{}{
					"rating":           newRating,
					"rating_deviation": newRD,
					"volatility":       newVol,
					"wins":             wins,
					"losses":           losses,
					"draws":            draws,
				}).Error
			}
		}

		// 3. Siyah oyuncunun istatistiklerini güncelle (misafir değilse)
		if !strings.HasPrefix(match.BlackPlayerID, "guest-") {
			var blackUser domain.User
			if err := tx.First(&blackUser, "id = ?", match.BlackPlayerID).Error; err == nil {
				newRating := blackRating
				if newRating < 100 {
					newRating = 100
				}
				newRD := blackRD
				newVol := blackVol

				wins := blackUser.Wins
				losses := blackUser.Losses
				draws := blackUser.Draws

				if match.WinnerID != nil {
					if *match.WinnerID == match.BlackPlayerID {
						wins++
					} else {
						losses++
					}
				} else {
					draws++
				}

				_ = tx.Model(&domain.User{}).Where("id = ?", match.BlackPlayerID).Updates(map[string]interface{}{
					"rating":           newRating,
					"rating_deviation": newRD,
					"volatility":       newVol,
					"wins":             wins,
					"losses":           losses,
					"draws":            draws,
				}).Error
			}
		}

		return nil
	})
}

func (r *matchRepo) populatePlayers(ctx context.Context, matches []*domain.Match) {
	if len(matches) == 0 {
		return
	}

	userIDsMap := make(map[string]bool)
	for _, m := range matches {
		if m.WhitePlayerID != "" && !strings.HasPrefix(m.WhitePlayerID, "guest-") {
			userIDsMap[m.WhitePlayerID] = true
		}
		if m.BlackPlayerID != "" && !strings.HasPrefix(m.BlackPlayerID, "guest-") {
			userIDsMap[m.BlackPlayerID] = true
		}
	}

	usersMap := make(map[string]*domain.User)
	if len(userIDsMap) > 0 {
		ids := make([]string, 0, len(userIDsMap))
		for id := range userIDsMap {
			ids = append(ids, id)
		}
		var users []domain.User
		if err := r.db.WithContext(ctx).Where("id IN ?", ids).Find(&users).Error; err == nil {
			for i := range users {
				usersMap[users[i].ID] = &users[i]
			}
		}
	}

	for _, m := range matches {
		if strings.HasPrefix(m.WhitePlayerID, "guest-") {
			m.WhitePlayer = &domain.User{ID: m.WhitePlayerID, Username: "Guest", Rating: 1200}
		} else if u, ok := usersMap[m.WhitePlayerID]; ok {
			m.WhitePlayer = u
		}

		if strings.HasPrefix(m.BlackPlayerID, "guest-") {
			m.BlackPlayer = &domain.User{ID: m.BlackPlayerID, Username: "Guest", Rating: 1200}
		} else if u, ok := usersMap[m.BlackPlayerID]; ok {
			m.BlackPlayer = u
		}
	}
}

func (r *matchRepo) FindByID(ctx context.Context, id string) (*domain.Match, error) {
	var match domain.Match
	err := r.db.WithContext(ctx).First(&match, "id = ?", id).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	r.populatePlayers(ctx, []*domain.Match{&match})
	return &match, nil
}

func (r *matchRepo) FindUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error) {
	var matches []domain.Match
	err := r.db.WithContext(ctx).
		Omit("moves").
		Where("white_player_id = ? OR black_player_id = ?", userID, userID).
		Order("started_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&matches).Error

	if err != nil {
		return nil, err
	}

	matchPtrs := make([]*domain.Match, len(matches))
	for i := range matches {
		matchPtrs[i] = &matches[i]
	}
	r.populatePlayers(ctx, matchPtrs)

	return matches, nil
}

func (r *matchRepo) GetMovesByMatchID(ctx context.Context, matchID string) ([]domain.MoveRecord, error) {
	var match domain.Match
	err := r.db.WithContext(ctx).
		Select("id", "moves").
		First(&match, "id = ?", matchID).Error

	if err != nil {
		return nil, err
	}
	return match.Moves, nil
}
