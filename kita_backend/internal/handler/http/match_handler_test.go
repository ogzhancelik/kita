package http

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/oguzhancelik/kita/internal/core/domain"
)

type mockMatchServiceForHandler struct {
	savedMatch *domain.Match
}

func (m *mockMatchServiceForHandler) SaveFinishedMatch(ctx context.Context, match *domain.Match) (map[string]interface{}, error) {
	return nil, nil
}

func (m *mockMatchServiceForHandler) SaveReplay(ctx context.Context, match *domain.Match) (string, error) {
	m.savedMatch = match
	return "KITA-12345678", nil
}

func (m *mockMatchServiceForHandler) GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error) {
	return m.savedMatch, nil
}

func (m *mockMatchServiceForHandler) GetMatchMoves(ctx context.Context, matchID string) ([]domain.MoveRecord, error) {
	return nil, nil
}

func (m *mockMatchServiceForHandler) GetUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error) {
	return nil, nil
}

func (m *mockMatchServiceForHandler) CountUserMatches(ctx context.Context, userID string) (int64, error) {
	return 0, nil
}

func TestShareReplayHandler(t *testing.T) {
	gin.SetMode(gin.TestMode)
	mockSvc := &mockMatchServiceForHandler{}
	handler := NewMatchHandler(mockSvc)

	r := gin.New()
	r.POST("/matches/share", handler.ShareReplay)

	// Sample JSON from frontend offline game
	payload := map[string]interface{}{
		"match": map[string]interface{}{
			"id":              "offline_1728765432",
			"white_player_id": "player_white",
			"black_player_id": "bot",
			"white_player": map[string]interface{}{
				"id":           "player_white",
				"username":     "Player",
				"avatar_index": 0,
				"rating":       1200,
				"created_at":   nil,
			},
			"black_player": map[string]interface{}{
				"id":           "bot",
				"username":     "AI Bot",
				"avatar_index": 0,
				"rating":       1200,
			},
			"winner_id":   nil,
			"result":      "white_wins",
			"reason":      "king_captured",
			"total_moves": 2,
			"started_at":  "2026-10-12T22:00:00.123456",
			"ended_at":    "2026-10-12T22:05:00.654321",
			"moves": []map[string]interface{}{
				{
					"ply":        0,
					"player_id":  "player_white",
					"piece":      "W1",
					"from_col":   0,
					"from_row":   3,
					"to_col":     0,
					"to_row":     2,
					"time_ms":    0,
					"created_at": "2026-10-12T22:00:05.999",
				},
			},
			"is_offline": true,
		},
	}

	bodyBytes, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/matches/share", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected 200 OK, got %d. Body: %s", w.Code, w.Body.String())
	}
}
