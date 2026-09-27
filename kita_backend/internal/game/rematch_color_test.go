package game

import (
	"encoding/json"
	"testing"
)

func TestRematchColorSwapping(t *testing.T) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)

	userA := NewClient(hub, sConn1, "user-a", "PlayerA", 1200)
	userB := NewClient(hub, sConn2, "user-b", "PlayerB", 1200)

	hub.mu.Lock()
	hub.clients[userA.UserID] = userA
	hub.clients[userB.UserID] = userB
	hub.mu.Unlock()

	// 1. Initial Match: userA is White, userB is Black
	matchID1 := "match-1"
	room1 := NewRoomWithTimeControl(matchID1, userA, userB, TimeControl3Min, mockService, hub)
	hub.mu.Lock()
	hub.rooms[matchID1] = room1
	hub.mu.Unlock()

	// Finish match 1
	room1.finishWithExplicitWinnerLocked(nil, "draw", "draw", "draw_agreement")

	if userA.LastFinishedTeam != "white" {
		t.Fatalf("Expected userA LastFinishedTeam to be 'white', got %s", userA.LastFinishedTeam)
	}
	if userB.LastFinishedTeam != "black" {
		t.Fatalf("Expected userB LastFinishedTeam to be 'black', got %s", userB.LastFinishedTeam)
	}

	// 2. User A requests rematch
	rematchReqPayload, _ := json.Marshal(RematchRequestDTO{MatchID: matchID1})
	hub.handleRematchRequest(userA, rematchReqPayload)

	// User B accepts rematch
	rematchAcceptPayload, _ := json.Marshal(RematchRequestDTO{MatchID: matchID1})
	hub.handleRematchAccept(userB, rematchAcceptPayload)

	hub.mu.RLock()
	matchID2 := userA.CurrentMatchID
	room2 := hub.rooms[matchID2]
	hub.mu.RUnlock()

	if room2 == nil {
		t.Fatalf("Room 2 not created on rematch accept")
	}

	// Verify colors are swapped: userB must be White, userA must be Black
	if room2.WhitePlayer.UserID != userB.UserID {
		t.Errorf("Expected userB to be White in rematch 1, got %s", room2.WhitePlayer.UserID)
	}
	if room2.BlackPlayer.UserID != userA.UserID {
		t.Errorf("Expected userA to be Black in rematch 1, got %s", room2.BlackPlayer.UserID)
	}

	// 3. Second Rematch: Finish match 2 and rematch again
	room2.finishWithExplicitWinnerLocked(nil, "draw", "draw", "draw_agreement")

	if userB.LastFinishedTeam != "white" {
		t.Fatalf("Expected userB LastFinishedTeam to be 'white', got %s", userB.LastFinishedTeam)
	}
	if userA.LastFinishedTeam != "black" {
		t.Fatalf("Expected userA LastFinishedTeam to be 'black', got %s", userA.LastFinishedTeam)
	}

	// User B requests rematch this time
	rematchReqPayload2, _ := json.Marshal(RematchRequestDTO{MatchID: matchID2})
	hub.handleRematchRequest(userB, rematchReqPayload2)

	// User A accepts rematch
	rematchAcceptPayload2, _ := json.Marshal(RematchRequestDTO{MatchID: matchID2})
	hub.handleRematchAccept(userA, rematchAcceptPayload2)

	hub.mu.RLock()
	matchID3 := userA.CurrentMatchID
	room3 := hub.rooms[matchID3]
	hub.mu.RUnlock()

	if room3 == nil {
		t.Fatalf("Room 3 not created on rematch accept")
	}

	// Verify colors swapped back: userA must be White, userB must be Black
	if room3.WhitePlayer.UserID != userA.UserID {
		t.Errorf("Expected userA to be White in rematch 2, got %s", room3.WhitePlayer.UserID)
	}
	if room3.BlackPlayer.UserID != userB.UserID {
		t.Errorf("Expected userB to be Black in rematch 2, got %s", room3.BlackPlayer.UserID)
	}

	// 4. Mutual Rematch Check
	room3.finishWithExplicitWinnerLocked(nil, "draw", "draw", "draw_agreement")
	rematchReqPayload3, _ := json.Marshal(RematchRequestDTO{MatchID: matchID3})

	// User A requests rematch
	hub.handleRematchRequest(userA, rematchReqPayload3)
	// User B also requests rematch -> mutual rematch auto-starts!
	hub.handleRematchRequest(userB, rematchReqPayload3)

	hub.mu.RLock()
	matchID4 := userA.CurrentMatchID
	room4 := hub.rooms[matchID4]
	hub.mu.RUnlock()

	if room4 == nil {
		t.Fatalf("Room 4 not created on mutual rematch")
	}

	// In room3 userA was White, so in room4 userB must be White and userA must be Black
	if room4.WhitePlayer.UserID != userB.UserID {
		t.Errorf("Expected userB to be White in mutual rematch, got %s", room4.WhitePlayer.UserID)
	}
	if room4.BlackPlayer.UserID != userA.UserID {
		t.Errorf("Expected userA to be Black in mutual rematch, got %s", room4.BlackPlayer.UserID)
	}
}
