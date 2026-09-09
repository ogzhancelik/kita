package game

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/oguzhancelik/kita/internal/core/domain"
)

// MockMatchService for testing
type mockMatchService struct {
	savedMatch *domain.Match
	saveChan   chan *domain.Match
}

func (m *mockMatchService) SaveFinishedMatch(ctx context.Context, match *domain.Match) error {
	m.savedMatch = match
	if m.saveChan != nil {
		m.saveChan <- match
	}
	return nil
}

func (m *mockMatchService) GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error) {
	return m.savedMatch, nil
}

func (m *mockMatchService) GetMatchMoves(ctx context.Context, matchID string) ([]domain.MatchMove, error) {
	if m.savedMatch != nil {
		return m.savedMatch.Moves, nil
	}
	return nil, nil
}

func (m *mockMatchService) GetUserMatches(ctx context.Context, userID string, limit, offset int) ([]domain.Match, error) {
	return nil, nil
}

func setupTestWS(t *testing.T) (*websocket.Conn, *websocket.Conn) {
	upgrader := websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	var serverConn *websocket.Conn
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var err error
		serverConn, err = upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Fatalf("Failed to upgrade: %v", err)
		}
	}))
	t.Cleanup(server.Close)

	url := "ws" + strings.TrimPrefix(server.URL, "http")
	clientConn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("Failed to dial: %v", err)
	}
	t.Cleanup(func() {
		clientConn.Close()
		if serverConn != nil {
			serverConn.Close()
		}
	})

	return serverConn, clientConn
}

func TestRoomMoveBufferingAndExecution(t *testing.T) {
	mockService := &mockMatchService{
		saveChan: make(chan *domain.Match, 1),
	}
	hub := NewHub(mockService, nil)

	sConn1, cConn1 := setupTestWS(t)
	sConn2, cConn2 := setupTestWS(t)
	_ = cConn1
	_ = cConn2

	clientWhite := NewClient(hub, sConn1, "user-white", "WhitePlayer", 1200)
	clientBlack := NewClient(hub, sConn2, "user-black", "BlackPlayer", 1200)

	room := NewRoom("test-match-1", clientWhite, clientBlack, mockService, hub)
	room.Start()

	// Initial turn should be white
	if room.Game.Turn != "white" {
		t.Fatalf("Expected initial turn white, got %s", room.Game.Turn)
	}

	// 1. Black cannot move first
	legalMoves := room.Game.GetLegalMoves()
	if len(legalMoves) == 0 {
		t.Fatal("Expected opening legal moves for White, got none")
	}

	firstMove := legalMoves[0]
	moveDTO := FromGameMove(firstMove)

	err := room.MakeMove("user-black", moveDTO)
	if err != ErrNotYourTurn {
		t.Fatalf("Expected ErrNotYourTurn for black playing on white's turn, got %v", err)
	}

	// 2. White makes a legal move
	err = room.MakeMove("user-white", moveDTO)
	if err != nil {
		t.Fatalf("Expected successful move by white, got %v", err)
	}

	// 3. Move must be buffered in memory
	if len(room.MovesBuffer) != 1 {
		t.Fatalf("Expected MovesBuffer length 1, got %d", len(room.MovesBuffer))
	}
	bufferedMove := room.MovesBuffer[0]
	if bufferedMove.PlayerID != "user-white" || bufferedMove.PieceID != firstMove.PieceID {
		t.Fatalf("Unexpected buffered move: %+v", bufferedMove)
	}

	// 4. Turn should now be black
	if room.Game.Turn != "black" {
		t.Fatalf("Expected turn black, got %s", room.Game.Turn)
	}

	// 5. Test Resign and deferred persistence
	err = room.Resign("user-white")
	if err != nil {
		t.Fatalf("Resign failed: %v", err)
	}

	select {
	case savedMatch := <-mockService.saveChan:
		if savedMatch.ID != "test-match-1" {
			t.Errorf("Expected match ID test-match-1, got %s", savedMatch.ID)
		}
		if savedMatch.WinnerID == nil || *savedMatch.WinnerID != "user-black" {
			t.Errorf("Expected black to win by white's resignation, got %+v", savedMatch.WinnerID)
		}
		if len(savedMatch.Moves) != 1 {
			t.Errorf("Expected exactly 1 move saved, got %d", len(savedMatch.Moves))
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for match to be saved via MatchService")
	}
}
