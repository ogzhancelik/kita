package service

import (
	"testing"

	"github.com/oguzhancelik/kita/internal/core/domain"
)

func TestGlickoScenario(t *testing.T) {
	// Scenario: 2 newly created accounts.
	// In auth_service.go, starting rating is 1200, RD is 350 (default fallback in match_service), Vol is 0.06.
	// If domain default 1500 was used, we also test that.

	// Scenario 1: Starting Rating = 1200
	wR, wRD, wVol, bR, bRD, bVol := calculateGlicko2(1200, 350, 0.06, 1200, 350, 0.06, domain.ResultWhiteWins, nil, "white")
	if int(wR) != 1362 || int(bR) != 1037 {
		t.Errorf("expected 1362 and 1037, got %v and %v", wR, bR)
	}
	if int(wRD) != 290 || int(bRD) != 290 {
		t.Errorf("expected RD 290, got %v and %v", wRD, bRD)
	}
	if wVol <= 0 || bVol <= 0 {
		t.Errorf("expected positive volatility")
	}

	// Scenario 2: Standard Glicko-2 1500 baseline
	wR2, wRD2, _, bR2, bRD2, _ := calculateGlicko2(1500, 350, 0.06, 1500, 350, 0.06, domain.ResultWhiteWins, nil, "white")
	if int(wR2) != 1662 || int(bR2) != 1337 {
		t.Errorf("expected 1662 and 1337, got %v and %v", wR2, bR2)
	}
	if int(wRD2) != 290 || int(bRD2) != 290 {
		t.Errorf("expected RD 290, got %v and %v", wRD2, bRD2)
	}
}

func TestSaveFinishedMatch_ZeroOrOneMoveIgnored(t *testing.T) {
	svc := NewMatchService(nil, nil)

	// Case 1: 0 moves
	match0 := &domain.Match{
		ID:         "m-0",
		TotalMoves: 0,
		Moves:      []domain.MoveRecord{},
	}
	res0, err0 := svc.SaveFinishedMatch(nil, match0)
	if err0 != nil {
		t.Fatalf("expected nil error, got %v", err0)
	}
	if res0 != nil {
		t.Fatalf("expected nil rating changes for 0-move game, got %v", res0)
	}

	// Case 2: 1 move
	match1 := &domain.Match{
		ID:         "m-1",
		TotalMoves: 1,
		Moves:      []domain.MoveRecord{{PlyIndex: 0}},
	}
	res1, err1 := svc.SaveFinishedMatch(nil, match1)
	if err1 != nil {
		t.Fatalf("expected nil error, got %v", err1)
	}
	if res1 != nil {
		t.Fatalf("expected nil rating changes for 1-move game, got %v", res1)
	}
}
