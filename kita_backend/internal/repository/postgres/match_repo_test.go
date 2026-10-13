package postgres

import (
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

func TestPopulatePlayers_IndependentRatingsPerMatch(t *testing.T) {
	// Verify that resolvePlayer returns independent copies so mutating
	// WhitePlayer.Rating or BlackPlayer.Rating on one match does not overwrite
	// other matches of the same user.
	repo := &matchRepo{}

	sharedUserID := "00000000-0000-0000-0000-000000000001"
	otherUserID := "00000000-0000-0000-0000-000000000002"
	usersMap := map[string]*domain.User{
		sharedUserID: {
			ID:       sharedUserID,
			Username: "IrozWh",
			Rating:   1360,
		},
		otherUserID: {
			ID:       otherUserID,
			Username: "OtherPlayer",
			Rating:   1200,
		},
	}

	r1 := 1353
	r2 := 1358
	r3 := 1362

	matches := []*domain.Match{
		{
			ID:            "m3",
			WhitePlayerID: sharedUserID,
			BlackPlayerID: otherUserID,
			WhiteRating:   &r3,
		},
		{
			ID:            "m2",
			WhitePlayerID: sharedUserID,
			BlackPlayerID: otherUserID,
			WhiteRating:   &r2,
		},
		{
			ID:            "m1",
			WhitePlayerID: sharedUserID,
			BlackPlayerID: otherUserID,
			WhiteRating:   &r1,
		},
	}

	for _, m := range matches {
		m.WhitePlayer = repo.resolvePlayer(m.WhitePlayerID, usersMap)
		m.BlackPlayer = repo.resolvePlayer(m.BlackPlayerID, usersMap)
		if m.WhiteRating != nil && m.WhitePlayer != nil {
			m.WhitePlayer.Rating = float64(*m.WhiteRating)
		}
		if m.BlackRating != nil && m.BlackPlayer != nil {
			m.BlackPlayer.Rating = float64(*m.BlackRating)
		}
	}

	if matches[0].WhitePlayer.Rating != 1362 {
		t.Errorf("m3 WhitePlayer rating expected 1362, got %v", matches[0].WhitePlayer.Rating)
	}
	if matches[1].WhitePlayer.Rating != 1358 {
		t.Errorf("m2 WhitePlayer rating expected 1358, got %v", matches[1].WhitePlayer.Rating)
	}
	if matches[2].WhitePlayer.Rating != 1353 {
		t.Errorf("m1 WhitePlayer rating expected 1353, got %v", matches[2].WhitePlayer.Rating)
	}
}
