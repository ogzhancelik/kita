package game

import (
	"encoding/json"
	"testing"
)

func TestTimedRoom_MutualReadyConfirmation(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	go clientHost.WritePump()
	go clientGuest.WritePump()

	// 1. Create custom timed room (3 min)
	room := NewCustomRoom("match-ready-1", "ROOM99", clientHost, false, TimeControl3Min, mockService, hub)
	if !room.RequiresReadyConfirmation {
		t.Fatalf("Expected RequiresReadyConfirmation to be true for timed custom room")
	}
	if room.IsClockStarted {
		t.Fatalf("Expected IsClockStarted to be false before ready confirmation")
	}

	// 2. Guest joins room
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	// Clock should not be started yet
	if room.IsClockStarted {
		t.Fatalf("Clock should not start immediately upon join for timed room")
	}
	if room.timeoutTimer != nil {
		t.Fatalf("Timeout timer should not be running yet")
	}

	// Read match_found message from clientHost
	_, rawMsg, err := c1.ReadMessage()
	if err != nil {
		t.Fatalf("Failed to read match_found: %v", err)
	}
	var mf WSMessage
	if err := json.Unmarshal(rawMsg, &mf); err != nil {
		t.Fatalf("Unmarshal WSMessage failed: %v", err)
	}
	if mf.Type != TypeMatchFound {
		t.Fatalf("Expected match_found, got %s", mf.Type)
	}

	// 3. One player confirms ready
	room.SetPlayerReady(room.WhitePlayer.UserID)
	if !room.WhiteReady {
		t.Fatalf("Expected WhiteReady to be true")
	}
	if room.BlackReady {
		t.Fatalf("Expected BlackReady to remain false")
	}
	if room.IsClockStarted {
		t.Fatalf("Clock should not start with only 1 player ready")
	}

	// 4. Second player confirms ready
	room.SetPlayerReady(room.BlackPlayer.UserID)
	if !room.BlackReady {
		t.Fatalf("Expected BlackReady to be true")
	}
	if !room.IsClockStarted {
		t.Fatalf("Expected IsClockStarted to be true after both players ready")
	}
	if room.timeoutTimer == nil {
		t.Fatalf("Expected timeoutTimer to be running now")
	}
}

func TestTimedRoom_MoveAutoStartsClock(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-ready-2", "ROOM88", clientHost, false, TimeControl1Min, mockService, hub)
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if room.IsClockStarted {
		t.Fatalf("Clock should be paused waiting for ready")
	}

	// White player makes move without explicit ready click
	moves := room.Game.GetLegalMoves()
	if len(moves) == 0 {
		t.Fatalf("No legal moves found")
	}

	if err := room.MakeMove(room.WhitePlayer.UserID, FromGameMove(moves[0])); err != nil {
		t.Fatalf("MakeMove failed: %v", err)
	}

	if !room.IsClockStarted {
		t.Fatalf("Expected making a move to auto-start clock")
	}
	if room.timeoutTimer == nil {
		t.Fatalf("Expected timeout timer to be active after move")
	}
}

func TestUntimedRoom_NoReadyConfirmationNeeded(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	go clientHost.WritePump()
	go clientGuest.WritePump()

	// Untimed room (0ms)
	room := NewCustomRoom("match-ready-3", "ROOM77", clientHost, false, TimeControlNone, mockService, hub)
	if room.RequiresReadyConfirmation {
		t.Fatalf("Untimed room should not require ready confirmation")
	}
	if !room.IsClockStarted {
		t.Fatalf("Untimed room should have IsClockStarted = true")
	}

	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if !room.IsClockStarted {
		t.Fatalf("IsClockStarted should remain true")
	}
}
