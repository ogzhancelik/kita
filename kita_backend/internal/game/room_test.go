package game

import (
	"context"
	"encoding/json"
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

func (m *mockMatchService) SaveFinishedMatch(ctx context.Context, match *domain.Match) (map[string]interface{}, error) {
	m.savedMatch = match
	if m.saveChan != nil {
		m.saveChan <- match
	}
	return nil, nil
}

func (m *mockMatchService) GetMatchDetails(ctx context.Context, matchID string) (*domain.Match, error) {
	return m.savedMatch, nil
}

func (m *mockMatchService) GetMatchMoves(ctx context.Context, matchID string) ([]domain.MoveRecord, error) {
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
	hub := NewHub(mockService, nil, nil)

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
		} else if savedMatch.Moves[0].TimeMs < 0 {
			t.Errorf("Expected non-negative TimeMs, got %d", savedMatch.Moves[0].TimeMs)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Timeout waiting for match to be saved via MatchService")
	}
}

func TestRoomClockNoElapsedLeakToOpponent(t *testing.T) {
	mockService := &mockMatchService{
		saveChan: make(chan *domain.Match, 1),
	}
	hub := NewHub(mockService, nil, nil)

	sConn1, cConn1 := setupTestWS(t)
	sConn2, cConn2 := setupTestWS(t)
	_ = cConn1
	_ = cConn2

	clientWhite := NewClient(hub, sConn1, "user-white", "WhitePlayer", 1200)
	clientBlack := NewClient(hub, sConn2, "user-black", "BlackPlayer", 1200)

	tc := int64(180_000)
	room := NewRoomWithTimeControl("test-clock-room", clientWhite, clientBlack, tc, mockService, hub)
	room.Start()

	// Drain initial MatchFound and GameState messages from clientBlack.Send
	<-clientBlack.Send // match_found
	<-clientBlack.Send // initial game_state

	// White waits 60ms before making a move
	time.Sleep(60 * time.Millisecond)

	legalMoves := room.Game.GetLegalMoves()
	if len(legalMoves) == 0 {
		t.Fatal("No legal moves for White")
	}
	moveDTO := FromGameMove(legalMoves[0])

	err := room.MakeMove("user-white", moveDTO)
	if err != nil {
		t.Fatalf("MakeMove failed: %v", err)
	}

	// White's remaining time should have decreased
	if room.WhiteRemainingMs >= tc {
		t.Errorf("Expected White's time to decrease from %d, got %d", tc, room.WhiteRemainingMs)
	}

	// Black's remaining time in memory MUST NOT be affected by White's elapsed time
	if room.BlackRemainingMs != tc {
		t.Errorf("Expected Black's remaining time to be %d, got %d", tc, room.BlackRemainingMs)
	}

	// Read next game_state sent to Black after White's move
	select {
	case msgBytes := <-clientBlack.Send:
		var wsMsg struct {
			Type    string       `json:"type"`
			Payload GameStateDTO `json:"payload"`
		}
		if err := json.Unmarshal(msgBytes, &wsMsg); err != nil {
			t.Fatalf("Failed to unmarshal game_state: %v", err)
		}
		if wsMsg.Payload.Turn != "black" {
			t.Errorf("Expected turn 'black', got %s", wsMsg.Payload.Turn)
		}
		// Black's remaining time in the broadcast payload MUST be equal to tc (or within 20ms), NEVER tc - 60ms
		if wsMsg.Payload.BlackRemainingMs < tc-20 {
			t.Errorf("Elapsed leaked! Black remaining time in payload was %d (expected >= %d)", wsMsg.Payload.BlackRemainingMs, tc-20)
		}
	case <-time.After(1 * time.Second):
		t.Fatal("Timed out waiting for game_state on clientBlack.Send")
	}
}

func TestMatchFoundIncludesOpponentAvatarIndex(t *testing.T) {
	mockService := &mockMatchService{
		saveChan: make(chan *domain.Match, 1),
	}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)

	// White has avatar index 3, Black has avatar index 6
	clientWhite := NewClient(hub, sConn1, "user-white", "WhitePlayer", 1200, 3)
	clientBlack := NewClient(hub, sConn2, "user-black", "BlackPlayer", 1400, 6)

	room := NewRoom("test-avatar-match", clientWhite, clientBlack, mockService, hub)
	room.Start()

	// 1. Verify White receives Black's avatar index (6)
	select {
	case msgBytes := <-clientWhite.Send:
		var wsMsg struct {
			Type    string        `json:"type"`
			Payload MatchFoundDTO `json:"payload"`
		}
		if err := json.Unmarshal(msgBytes, &wsMsg); err != nil {
			t.Fatalf("Failed to unmarshal match_found: %v", err)
		}
		if wsMsg.Payload.OpponentAvatarIndex != 6 {
			t.Errorf("Expected White to receive OpponentAvatarIndex 6, got %d", wsMsg.Payload.OpponentAvatarIndex)
		}
		if wsMsg.Payload.OpponentName != "BlackPlayer" {
			t.Errorf("Expected OpponentName 'BlackPlayer', got %s", wsMsg.Payload.OpponentName)
		}
	case <-time.After(1 * time.Second):
		t.Fatal("Timed out waiting for match_found on clientWhite.Send")
	}

	// 2. Verify Black receives White's avatar index (3)
	select {
	case msgBytes := <-clientBlack.Send:
		var wsMsg struct {
			Type    string        `json:"type"`
			Payload MatchFoundDTO `json:"payload"`
		}
		if err := json.Unmarshal(msgBytes, &wsMsg); err != nil {
			t.Fatalf("Failed to unmarshal match_found: %v", err)
		}
		if wsMsg.Payload.OpponentAvatarIndex != 3 {
			t.Errorf("Expected Black to receive OpponentAvatarIndex 3, got %d", wsMsg.Payload.OpponentAvatarIndex)
		}
		if wsMsg.Payload.OpponentName != "WhitePlayer" {
			t.Errorf("Expected OpponentName 'WhitePlayer', got %s", wsMsg.Payload.OpponentName)
		}
	case <-time.After(1 * time.Second):
		t.Fatal("Timed out waiting for match_found on clientBlack.Send")
	}
}

