package postgres

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
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
	if match.TotalMoves <= 1 || len(match.Moves) <= 1 {
		return nil
	}

	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// 1. Maç ve ilişkili tüm hamleleri kaydet (GORM match.Moves'u otomatik topluca insert eder)
		if err := tx.Create(match).Error; err != nil {
			return err
		}

		// 2. Beyaz oyuncunun istatistiklerini güncelle (kayıtlı kullanıcıysa)
		if _, err := uuid.Parse(strings.TrimSpace(match.WhitePlayerID)); err == nil {
			var whiteUser domain.User
			if err := tx.First(&whiteUser, "id = ?", strings.TrimSpace(match.WhitePlayerID)).Error; err == nil {
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

				_ = tx.Model(&domain.User{}).Where("id = ?", strings.TrimSpace(match.WhitePlayerID)).Updates(map[string]interface{}{
					"rating":           newRating,
					"rating_deviation": newRD,
					"volatility":       newVol,
					"wins":             wins,
					"losses":           losses,
					"draws":            draws,
				}).Error
			}
		}

		// 3. Siyah oyuncunun istatistiklerini güncelle (kayıtlı kullanıcıysa)
		if _, err := uuid.Parse(strings.TrimSpace(match.BlackPlayerID)); err == nil {
			var blackUser domain.User
			if err := tx.First(&blackUser, "id = ?", strings.TrimSpace(match.BlackPlayerID)).Error; err == nil {
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

				_ = tx.Model(&domain.User{}).Where("id = ?", strings.TrimSpace(match.BlackPlayerID)).Updates(map[string]interface{}{
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

// SaveReplay: Saves a match replay record without modifying ratings or competitive stats.
func (r *matchRepo) SaveReplay(ctx context.Context, match *domain.Match) error {
	var existing domain.Match
	if err := r.db.WithContext(ctx).First(&existing, "id = ?", match.ID).Error; err == nil {
		return nil
	}
	return r.db.WithContext(ctx).Create(match).Error
}

func (r *matchRepo) populatePlayers(ctx context.Context, matches []*domain.Match) {
	if len(matches) == 0 {
		return
	}

	userIDsMap := make(map[string]bool)
	for _, m := range matches {
		if wID := strings.TrimSpace(m.WhitePlayerID); wID != "" {
			if parsed, err := uuid.Parse(wID); err == nil {
				userIDsMap[parsed.String()] = true
			}
		}
		if bID := strings.TrimSpace(m.BlackPlayerID); bID != "" {
			if parsed, err := uuid.Parse(bID); err == nil {
				userIDsMap[parsed.String()] = true
			}
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
		m.WhitePlayer = r.resolvePlayer(m.WhitePlayerID, usersMap)
		m.BlackPlayer = r.resolvePlayer(m.BlackPlayerID, usersMap)
		if m.WhiteRating != nil && m.WhitePlayer != nil {
			m.WhitePlayer.Rating = float64(*m.WhiteRating)
		}
		if m.BlackRating != nil && m.BlackPlayer != nil {
			m.BlackPlayer.Rating = float64(*m.BlackRating)
		}
	}
}

func (r *matchRepo) resolvePlayer(playerID string, usersMap map[string]*domain.User) *domain.User {
	trimmedID := strings.TrimSpace(playerID)
	lowerID := strings.ToLower(trimmedID)

	if strings.HasPrefix(lowerID, "guest-") || lowerID == "guest" {
		return &domain.User{ID: trimmedID, Username: "Guest", Rating: 1200, AvatarIndex: 0}
	}
	if strings.Contains(lowerID, "bot") {
		return &domain.User{ID: trimmedID, Username: "AI Bot", Rating: 1200, AvatarIndex: 7}
	}
	if lowerID == "local_white" {
		return &domain.User{ID: trimmedID, Username: "White", Rating: 1200, AvatarIndex: 0}
	}
	if lowerID == "local_black" {
		return &domain.User{ID: trimmedID, Username: "Black", Rating: 1200, AvatarIndex: 1}
	}
	if lowerID == "local_player" {
		return &domain.User{ID: trimmedID, Username: "Player", Rating: 1200, AvatarIndex: 1}
	}

	if parsed, err := uuid.Parse(trimmedID); err == nil {
		if u, ok := usersMap[parsed.String()]; ok {
			userCopy := *u
			return &userCopy
		}
		return &domain.User{ID: trimmedID, Username: "[Deleted]", Rating: 1200, AvatarIndex: 0}
	}

	return &domain.User{ID: trimmedID, Username: trimmedID, Rating: 1200, AvatarIndex: 0}
}

func (r *matchRepo) FindByID(ctx context.Context, id string) (*domain.Match, error) {
	var match domain.Match
	err := r.db.WithContext(ctx).First(&match, "id = ?", id).Error

	if err != nil && errors.Is(err, gorm.ErrRecordNotFound) && len(id) >= 6 {
		err = r.db.WithContext(ctx).First(&match, "id ILIKE ?", id+"%").Error
	}

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
		Where("(white_player_id = ? OR black_player_id = ?) AND total_moves > 1", userID, userID).
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

func (r *matchRepo) CountUserMatches(ctx context.Context, userID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&domain.Match{}).
		Where("(white_player_id = ? OR black_player_id = ?) AND total_moves > 1", userID, userID).
		Count(&count).Error
	return count, err
}

func (r *matchRepo) GetMovesByMatchID(ctx context.Context, matchID string) ([]domain.MoveRecord, error) {
	var match domain.Match
	err := r.db.WithContext(ctx).
		Select("id", "moves").
		First(&match, "id = ?", matchID).Error

	if err != nil && errors.Is(err, gorm.ErrRecordNotFound) && len(matchID) >= 6 {
		err = r.db.WithContext(ctx).
			Select("id", "moves").
			First(&match, "id ILIKE ?", matchID+"%").Error
	}

	if err != nil {
		return nil, err
	}
	return match.Moves, nil
}
