package game

import (
	"encoding/json"
	"testing"
	"time"
)

func TestTimedRoom_MutualReadyConfirmation(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

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
	if !room.HostOnline {
		t.Fatalf("Expected HostOnline to be true on room creation")
	}

	// 2. Host closes app / disconnects (HostOnline = false)
	room.HostOnline = false

	// Guest joins room while host is away -> enters ready_phase
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if room.Status != "ready_phase" {
		t.Fatalf("Expected Status to be ready_phase, got %s", room.Status)
	}
	if room.IsClockStarted {
		t.Fatalf("Clock should not start upon join for timed room")
	}
	if room.timeoutTimer != nil {
		t.Fatalf("Timeout timer should not be running in ready_phase")
	}

	// Read ready_phase_started message from clientGuest (since host is offline)
	_, rawMsg, err := c2.ReadMessage()
	if err != nil {
		t.Fatalf("Failed to read ready_phase_started: %v", err)
	}
	var rps WSMessage
	if err := json.Unmarshal(rawMsg, &rps); err != nil {
		t.Fatalf("Unmarshal WSMessage failed: %v", err)
	}
	if rps.Type != TypeReadyPhaseStarted {
		t.Fatalf("Expected ready_phase_started, got %s", rps.Type)
	}

	// Host returns and reconnects into ready phase
	room.HandleReadyPhaseReconnect(clientHost)

	// 3. One player confirms ready
	room.SetPlayerReady(room.WhitePlayer.UserID)
	if !room.WhiteReady {
		t.Fatalf("Expected WhiteReady to be true")
	}
	if room.BlackReady {
		t.Fatalf("Expected BlackReady to remain false")
	}
	if room.Status != "ready_phase" {
		t.Fatalf("Status should still be ready_phase with only 1 player ready")
	}
	if room.IsClockStarted {
		t.Fatalf("Clock should not start with only 1 player ready")
	}

	// 4. Second player confirms ready -> transitions to in_game after delay
	room.readyStartDelay = 20 * time.Millisecond
	room.SetPlayerReady(room.BlackPlayer.UserID)
	if !room.BlackReady {
		t.Fatalf("Expected BlackReady to be true")
	}

	for i := 0; i < 20; i++ {
		time.Sleep(10 * time.Millisecond)
		room.mu.RLock()
		status := room.Status
		timer := room.timeoutTimer
		room.mu.RUnlock()
		if status == "in_game" && timer != nil {
			break
		}
	}

	if room.Status != "in_game" {
		t.Fatalf("Expected Status to be in_game after both ready, got %s", room.Status)
	}
	if !room.IsClockStarted {
		t.Fatalf("Expected IsClockStarted to be true after both players ready")
	}
	if room.timeoutTimer == nil {
		t.Fatalf("Expected timeoutTimer to be running now")
	}
}

func TestTimedRoom_CannotMoveInReadyPhase(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-ready-2", "ROOM88", clientHost, false, TimeControl1Min, mockService, hub)
	room.HostOnline = false
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if room.Status != "ready_phase" {
		t.Fatalf("Expected room in ready_phase")
	}

	moves := room.Game.GetLegalMoves()
	if len(moves) == 0 {
		t.Fatalf("No legal moves found")
	}

	// Attempting to move during ready_phase must fail
	err := room.MakeMove(room.WhitePlayer.UserID, FromGameMove(moves[0]))
	if err == nil {
		t.Fatalf("Expected MakeMove to fail during ready_phase, but it succeeded")
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

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

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

	// Unlimited room transitions directly to in_game
	if room.Status != "in_game" {
		t.Fatalf("Expected in_game status for untimed room, got %s", room.Status)
	}
	if !room.IsClockStarted {
		t.Fatalf("IsClockStarted should remain true")
	}
}

func TestWaitingRoom_PersistsOnDisconnect(t *testing.T) {
	s1, c1 := setupTestWS(t)
	_ = c1

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	hub.clients[clientHost.UserID] = clientHost

	go clientHost.WritePump()

	room := NewCustomRoom("match-ready-4", "ROOM66", clientHost, false, TimeControl3Min, mockService, hub)
	hub.rooms[room.ID] = room
	hub.roomCodes[room.RoomCode] = room.ID

	// Host disconnects
	room.HandleDisconnect(clientHost.UserID)

	// Room should still exist and remain in waiting status
	if room.Status != "waiting" {
		t.Fatalf("Expected room status to remain waiting, got %s", room.Status)
	}
	if room.HostOnline {
		t.Fatalf("Expected HostOnline to be false after disconnect")
	}
	if _, exists := hub.rooms[room.ID]; !exists {
		t.Fatalf("Expected room to still exist in hub.rooms")
	}
}

func TestReadyPhase_HostTimeout_RoomStaysOpenInWaitingState(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-ready-5", "ROOM55", clientHost, false, TimeControl3Min, mockService, hub)
	hub.rooms[room.ID] = room
	hub.roomCodes[room.RoomCode] = room.ID
	room.HostOnline = false

	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	// Guest readies, but Host does not show up
	guestUserID := clientGuest.UserID
	room.SetPlayerReady(guestUserID)

	// Trigger timeout
	room.handleReadyPhaseTimeout()

	// Guest should be returned to idle
	if clientGuest.Activity != ActivityIdle {
		t.Fatalf("Expected guest Activity to be ActivityIdle, got %v", clientGuest.Activity)
	}
	if clientGuest.CurrentMatchID != "" {
		t.Fatalf("Expected guest CurrentMatchID to be cleared, got %s", clientGuest.CurrentMatchID)
	}

	// Room should NOT be closed! It should return to waiting state under 24h TTL
	if room.isFinished {
		t.Fatalf("Room should NOT be finished/closed after host timeout; it should persist for other challengers")
	}
	if room.Status != "waiting" {
		t.Fatalf("Expected room to return to waiting status, got %s", room.Status)
	}
	if room.WhitePlayer != nil || room.BlackPlayer != nil {
		t.Fatalf("Expected WhitePlayer and BlackPlayer to be reset to nil")
	}
	if _, exists := hub.rooms[room.ID]; !exists {
		t.Fatalf("Expected room to remain registered in hub.rooms")
	}
}

func TestReadyPhase_GuestTimeoutReturnsToWaiting(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-ready-6", "ROOM44", clientHost, false, TimeControl3Min, mockService, hub)
	hub.rooms[room.ID] = room
	hub.roomCodes[room.RoomCode] = room.ID
	room.HostOnline = false

	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	// Host readies, but Guest does not
	room.SetPlayerReady(clientHost.UserID)

	// Trigger timeout
	room.handleReadyPhaseTimeout()

	// Room should return to waiting state with host
	if room.Status != "waiting" {
		t.Fatalf("Expected room to return to waiting status, got %s", room.Status)
	}
	if room.WhitePlayer != nil || room.BlackPlayer != nil {
		t.Fatalf("Expected WhitePlayer and BlackPlayer to be reset to nil")
	}
	if clientGuest.CurrentMatchID != "" {
		t.Fatalf("Expected guest CurrentMatchID to be cleared, got %s", clientGuest.CurrentMatchID)
	}
	if clientGuest.Activity != ActivityIdle {
		t.Fatalf("Expected guest Activity to be ActivityIdle, got %v", clientGuest.Activity)
	}
}

func TestHub_HandleJoinRoom_EntersReadyPhaseWithoutDeadlock(t *testing.T) {
	s1, _ := setupTestWS(t)
	s2, _ := setupTestWS(t)

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host-h", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest-g", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-ready-7", "JOIN99", clientHost, false, TimeControl3Min, mockService, hub)
	hub.rooms[room.ID] = room
	hub.roomCodes[room.RoomCode] = room.ID
	room.HostOnline = false

	payload, _ := json.Marshal(JoinRoomDTO{RoomCode: "JOIN99"})
	// This invokes hub.handleJoinRoom which acquires h.mu.Lock() before calling room.Join
	hub.handleJoinRoom(clientGuest, payload)

	if room.Status != "ready_phase" {
		t.Fatalf("Expected room status to be ready_phase, got %s", room.Status)
	}
	if clientGuest.Activity != ActivityInReadyPhase {
		t.Fatalf("Expected guest activity to be ActivityInReadyPhase, got %v", clientGuest.Activity)
	}
}

func TestTimedRoom_BothOnline_DirectToGame(t *testing.T) {
	s1, c1 := setupTestWS(t)
	s2, c2 := setupTestWS(t)
	_ = c1
	_ = c2

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, s1, "user-host-online", "HostPlayer", 1200)
	clientGuest := NewClient(hub, s2, "user-guest-online", "GuestPlayer", 1200)

	hub.clients[clientHost.UserID] = clientHost
	hub.clients[clientGuest.UserID] = clientGuest

	go clientHost.WritePump()
	go clientGuest.WritePump()

	room := NewCustomRoom("match-both-online", "ONLINE1", clientHost, false, TimeControl3Min, mockService, hub)
	if !room.HostOnline {
		t.Fatalf("Expected HostOnline to be true on room creation")
	}

	// Guest joins while host is online in app -> bypasses ready confirmation!
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if room.Status != "in_game" {
		t.Fatalf("Expected room status to be in_game, got %s", room.Status)
	}
	if !room.IsClockStarted {
		t.Fatalf("Expected IsClockStarted to be true")
	}
	if room.RequiresReadyConfirmation {
		t.Fatalf("Expected RequiresReadyConfirmation to be false")
	}
	if clientHost.Activity != ActivityInMatch {
		t.Fatalf("Expected host Activity to be ActivityInMatch, got %v", clientHost.Activity)
	}
	if clientGuest.Activity != ActivityInMatch {
		t.Fatalf("Expected guest Activity to be ActivityInMatch, got %v", clientGuest.Activity)
	}
}

func TestFriendChallenge_OfflineInviter_EntersReadyPhase(t *testing.T) {
	sAccepting, cAccepting := setupTestWS(t)
	_ = cAccepting

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientAccepting := NewClient(hub, sAccepting, "user-accepting", "AcceptingUser", 1300)

	hub.clients[clientAccepting.UserID] = clientAccepting
	go clientAccepting.WritePump()

	// Inviter is offline (not in hub.clients)
	acceptPayload, _ := json.Marshal(AcceptInviteDTO{
		InviteID:      "inv-1234",
		InviterID:     "user-offline-inviter",
		InviterName:   "OfflineInviter",
		InviterRating: 1400,
		TimeControl:   TimeControl3Min,
		ColorPref:     "white",
	})

	hub.handleAcceptInvite(clientAccepting, acceptPayload)

	if clientAccepting.Activity != ActivityInReadyPhase {
		t.Fatalf("Expected accepting client activity to be ActivityInReadyPhase, got %v", clientAccepting.Activity)
	}

	matchID := clientAccepting.CurrentMatchID
	if matchID == "" {
		t.Fatalf("Expected accepting client to have a CurrentMatchID")
	}

	room := hub.rooms[matchID]
	if room == nil {
		t.Fatalf("Expected room to exist in hub.rooms")
	}

	if room.Status != "ready_phase" {
		t.Fatalf("Expected room status to be ready_phase, got %s", room.Status)
	}
	if room.HostOnline {
		t.Fatalf("Expected HostOnline to be false for offline inviter")
	}
	if room.RoomCode != "" {
		t.Fatalf("Expected RoomCode to be empty for friend challenge, got %s", room.RoomCode)
	}

	// Read ready_phase_started message sent to accepting client
	_, rawMsg, err := cAccepting.ReadMessage()
	if err != nil {
		t.Fatalf("Failed to read ready_phase_started: %v", err)
	}
	var msg struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(rawMsg, &msg); err != nil || msg.Type != TypeReadyPhaseStarted {
		t.Fatalf("Expected TypeReadyPhaseStarted, got %v", string(rawMsg))
	}

	// Inviter comes online
	sInviter, cInviter := setupTestWS(t)
	_ = cInviter
	clientInviter := NewClient(hub, sInviter, "user-offline-inviter", "OfflineInviter", 1400)
	go clientInviter.WritePump()

	// Simulate inviter reconnecting into ready phase
	room.HandleReadyPhaseReconnect(clientInviter)

	if !room.HostOnline {
		t.Fatalf("Expected HostOnline to be true after inviter connected")
	}
	if clientInviter.Activity != ActivityInReadyPhase {
		t.Fatalf("Expected inviter activity to be ActivityInReadyPhase, got %v", clientInviter.Activity)
	}

	// Both ready up
	room.readyStartDelay = 10 * time.Millisecond
	room.SetPlayerReady(clientAccepting.UserID)
	room.SetPlayerReady(clientInviter.UserID)

	time.Sleep(50 * time.Millisecond)

	if room.Status != "in_game" {
		t.Fatalf("Expected room to transition to in_game, got %s", room.Status)
	}
}

func TestRoom_BothOnline_HostAfk_EntersReadyPhase(t *testing.T) {
	sHost, _ := setupTestWS(t)
	sGuest, _ := setupTestWS(t)

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clientHost := NewClient(hub, sHost, "user-host-afk", "HostUser", 1200)
	clientHost.PresenceStatus = "afk"
	clientGuest := NewClient(hub, sGuest, "user-guest", "GuestUser", 1200)

	room := NewCustomRoom("room-afk-test", "AFK001", clientHost, false, 180000, mockService, hub)

	// Guest joins while host is online but AFK -> MUST enter ready confirmation!
	if err := room.Join(clientGuest); err != nil {
		t.Fatalf("Join failed: %v", err)
	}

	if room.Status != "ready_phase" {
		t.Fatalf("Expected room status to be ready_phase when host is AFK, got %s", room.Status)
	}
	if room.IsClockStarted {
		t.Fatalf("Expected IsClockStarted to be false when in ready_phase")
	}
	if !room.RequiresReadyConfirmation {
		t.Fatalf("Expected RequiresReadyConfirmation to be true")
	}
}

func TestFriendChallenge_InviterOnlineAfk_EntersReadyPhase(t *testing.T) {
	sAccepting, _ := setupTestWS(t)
	sInviter, _ := setupTestWS(t)

	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	clientAccepting := NewClient(hub, sAccepting, "user-accepting-2", "AcceptingUser", 1300)
	clientInviter := NewClient(hub, sInviter, "user-inviter-afk", "AfkInviter", 1400)
	clientInviter.PresenceStatus = "afk"

	hub.clients[clientAccepting.UserID] = clientAccepting
	hub.clients[clientInviter.UserID] = clientInviter
	go clientAccepting.WritePump()
	go clientInviter.WritePump()

	acceptPayload, _ := json.Marshal(AcceptInviteDTO{
		InviteID:      "inv-afk-test",
		InviterID:     clientInviter.UserID,
		InviterName:   clientInviter.Username,
		InviterRating: clientInviter.Rating,
		TimeControl:   TimeControl3Min,
		ColorPref:     "white",
	})

	hub.handleAcceptInvite(clientAccepting, acceptPayload)

	if clientAccepting.Activity != ActivityInReadyPhase {
		t.Fatalf("Expected accepting client activity to be ActivityInReadyPhase, got %v", clientAccepting.Activity)
	}
	if clientInviter.Activity != ActivityInReadyPhase {
		t.Fatalf("Expected AFK inviter client activity to be ActivityInReadyPhase, got %v", clientInviter.Activity)
	}

	matchID := clientAccepting.CurrentMatchID
	room, ok := hub.rooms[matchID]
	if !ok || room == nil {
		t.Fatalf("Expected room %s to exist in hub", matchID)
	}
	if room.Status != "ready_phase" {
		t.Fatalf("Expected room status to be ready_phase when inviter is AFK, got %s", room.Status)
	}
}

