package game

import (
	"encoding/json"
	"testing"
	"time"
)

func readNextWSMessage(ch chan []byte, timeout time.Duration) (*WSMessage, error) {
	select {
	case data := <-ch:
		var msg WSMessage
		if err := json.Unmarshal(data, &msg); err != nil {
			return nil, err
		}
		return &msg, nil
	case <-time.After(timeout):
		return nil, nil
	}
}

func findNextRoomsList(ch chan []byte, timeout time.Duration) (*RoomsListDTO, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		rem := time.Until(deadline)
		if rem <= 0 {
			break
		}
		msg, err := readNextWSMessage(ch, rem)
		if err != nil {
			return nil, err
		}
		if msg == nil {
			break
		}
		if msg.Type == TypeRoomsList {
			var dto RoomsListDTO
			if err := json.Unmarshal(msg.Payload, &dto); err != nil {
				return nil, err
			}
			return &dto, nil
		}
	}
	return nil, nil
}

func TestRoomsListRealTimeBroadcasting(t *testing.T) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)
	sConn3, _ := setupTestWS(t)

	c1 := NewClient(hub, sConn1, "user-1", "HostUser", 1200)
	c2 := NewClient(hub, sConn2, "user-2", "JoinerUser", 1300)
	c3 := NewClient(hub, sConn3, "user-3", "SpectatorUser", 1400)

	hub.mu.Lock()
	hub.clients[c1.UserID] = c1
	hub.clients[c2.UserID] = c2
	hub.clients[c3.UserID] = c3
	hub.mu.Unlock()

	// Step 1: c1 creates a public room
	createPayload, _ := json.Marshal(CreateRoomDTO{
		IsPrivate:   false,
		TimeControl: 180000,
	})
	hub.handleCreateRoom(c1, createPayload)

	// c3 (another client on main menu) should receive TypeRoomsList with 1 room
	roomsForC3, err := findNextRoomsList(c3.Send, 500*time.Millisecond)
	if err != nil {
		t.Fatalf("Failed to read rooms list for c3: %v", err)
	}
	if roomsForC3 == nil {
		t.Fatalf("Expected c3 to receive rooms_list after c1 created room, but got nil")
	}
	if len(roomsForC3.Rooms) != 1 {
		t.Fatalf("Expected 1 open room, got %d", len(roomsForC3.Rooms))
	}
	if roomsForC3.Rooms[0].HostName != "HostUser" {
		t.Errorf("Expected host to be HostUser, got %s", roomsForC3.Rooms[0].HostName)
	}
	roomCode := roomsForC3.Rooms[0].RoomCode

	// Step 2: c2 joins the room
	joinPayload, _ := json.Marshal(JoinRoomDTO{
		RoomCode: roomCode,
	})
	hub.handleJoinRoom(c2, joinPayload)

	// c3 should immediately receive TypeRoomsList with 0 rooms (since it became in_game)
	roomsForC3AfterJoin, err := findNextRoomsList(c3.Send, 500*time.Millisecond)
	if err != nil {
		t.Fatalf("Failed to read rooms list for c3 after join: %v", err)
	}
	if roomsForC3AfterJoin == nil {
		t.Fatalf("Expected c3 to receive rooms_list after c2 joined room, but got nil")
	}
	if len(roomsForC3AfterJoin.Rooms) != 0 {
		t.Fatalf("Expected 0 open rooms after match started, got %d", len(roomsForC3AfterJoin.Rooms))
	}
}

func TestRoomsListCancellationBroadcasting(t *testing.T) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)

	c1 := NewClient(hub, sConn1, "user-c1", "Host1", 1200)
	c2 := NewClient(hub, sConn2, "user-c2", "Watcher", 1250)

	hub.mu.Lock()
	hub.clients[c1.UserID] = c1
	hub.clients[c2.UserID] = c2
	hub.mu.Unlock()

	// 1. Host creates room
	createPayload, _ := json.Marshal(CreateRoomDTO{
		IsPrivate:   false,
		TimeControl: 60000,
	})
	hub.handleCreateRoom(c1, createPayload)

	roomsForWatcher, _ := findNextRoomsList(c2.Send, 500*time.Millisecond)
	if roomsForWatcher == nil || len(roomsForWatcher.Rooms) != 1 {
		t.Fatalf("Watcher expected 1 room, got %+v", roomsForWatcher)
	}

	// 2. Host cancels room
	hub.handleLeaveRoom(c1)

	roomsAfterCancel, _ := findNextRoomsList(c2.Send, 500*time.Millisecond)
	if roomsAfterCancel == nil || len(roomsAfterCancel.Rooms) != 0 {
		t.Fatalf("Watcher expected 0 rooms after cancel, got %+v", roomsAfterCancel)
	}
}
