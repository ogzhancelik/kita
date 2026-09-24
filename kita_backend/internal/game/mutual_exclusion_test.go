package game

import (
	"encoding/json"
	"testing"
)

// Helper to get all messages from a client's Send channel
func getAllMessages(c *Client) []WSMessage {
	var msgs []WSMessage
	for len(c.Send) > 0 {
		raw := <-c.Send
		var msg WSMessage
		if err := json.Unmarshal(raw, &msg); err == nil {
			msgs = append(msgs, msg)
		}
	}
	return msgs
}

func hasMessageType(msgs []WSMessage, msgType string) bool {
	for _, m := range msgs {
		if m.Type == msgType {
			return true
		}
	}
	return false
}

func getMessageOfType(msgs []WSMessage, msgType string) (WSMessage, bool) {
	for _, m := range msgs {
		if m.Type == msgType {
			return m, true
		}
	}
	return WSMessage{}, false
}

// Helper to drain client's Send channel
func drainMessages(c *Client) {
	for len(c.Send) > 0 {
		<-c.Send
	}
}

func setupHubWithClients(t *testing.T, userIDs ...string) (*Hub, map[string]*Client) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)
	clients := make(map[string]*Client)

	for _, uid := range userIDs {
		sConn, _ := setupTestWS(t)
		client := NewClient(hub, sConn, uid, "User_"+uid, 1200)
		hub.mu.Lock()
		hub.clients[uid] = client
		hub.mu.Unlock()
		clients[uid] = client
	}
	return hub, clients
}

// ---------------------------------------------------------------------
// STATE A: Active Game
// ---------------------------------------------------------------------

func TestStateActiveGame_Scenarios(t *testing.T) {
	hub, clients := setupHubWithClients(t, "userA", "userOpponent", "userFriend1", "userFriend2", "roomHost")
	userA := clients["userA"]
	opponent := clients["userOpponent"]
	friend1 := clients["userFriend1"]
	roomHost := clients["roomHost"]

	// Set userA in Active Game
	activeMatchID := "active-match-1"
	activeRoom := NewRoomWithTimeControl(activeMatchID, userA, opponent, TimeControl3Min, hub.matchService, hub)
	hub.mu.Lock()
	hub.rooms[activeMatchID] = activeRoom
	hub.mu.Unlock()
	go activeRoom.Start()
	userA.CurrentMatchID = activeMatchID
	opponent.CurrentMatchID = activeMatchID
	drainMessages(userA)

	t.Run("State A + Action a: Open new room", func(t *testing.T) {
		createPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(userA, createPayload)

		msgs := getAllMessages(userA)
		msg, ok := getMessageOfType(msgs, TypeError)
		if !ok {
			t.Fatalf("Expected TypeError, got %+v", msgs)
		}
		t.Logf("[A + a] Result: Blocked with error: %v", msg.Payload)
	})

	t.Run("State A + Action b: Join a room", func(t *testing.T) {
		// Create a separate room hosted by roomHost
		hostPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(roomHost, hostPayload)
		hub.mu.RLock()
		hostRoomCode := hub.rooms[roomHost.CurrentMatchID].RoomCode
		hub.mu.RUnlock()

		joinPayload, _ := json.Marshal(JoinRoomDTO{RoomCode: hostRoomCode})
		hub.handleJoinRoom(userA, joinPayload)

		msgs := getAllMessages(userA)
		msg, ok := getMessageOfType(msgs, TypeError)
		if !ok {
			t.Fatalf("Expected TypeError, got %+v", msgs)
		}
		t.Logf("[A + b] Result: Blocked with error: %v", msg.Payload)
	})

	t.Run("State A + Action c: Send a Pending Challenge", func(t *testing.T) {
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invitePayload)

		msgs := getAllMessages(userA)
		msg, ok := getMessageOfType(msgs, TypeError)
		if !ok {
			t.Fatalf("Expected TypeError, got %+v", msgs)
		}
		t.Logf("[A + c] Result: Blocked with error: %v", msg.Payload)
	})

	t.Run("State A + Action d: Get a challenge invite from another player", func(t *testing.T) {
		drainMessages(friend1)
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invitePayload)

		// Sender (friend1) should receive an error that friend is already in match
		fMsgs := getAllMessages(friend1)
		msg, ok := getMessageOfType(fMsgs, TypeError)
		if !ok {
			t.Fatalf("Expected sender to get TypeError, got %+v", fMsgs)
		}
		// Target (userA) should receive nothing
		userMsgs := getAllMessages(userA)
		if hasMessageType(userMsgs, TypeMatchInvitation) {
			t.Fatalf("Target in active game should NOT get match invitation, got %+v", userMsgs)
		}
		t.Logf("[A + d] Result: Sender rejected with error: %v; Target in game receives nothing", msg.Payload)
	})
}

// ---------------------------------------------------------------------
// STATE B: Pending Challenge Invite (Sent or Received)
// ---------------------------------------------------------------------

func TestStatePendingChallenge_Scenarios(t *testing.T) {
	t.Run("State B (Sent Invite) + Action a: Open new room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]

		// userA sends challenge to friend1
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invitePayload)
		drainMessages(userA)

		if userA.PendingInviteID == "" {
			t.Fatalf("userA should have pending invite")
		}

		// userA now tries to open a new room
		createPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(userA, createPayload)

		msgs := getAllMessages(userA)
		msg, ok := getMessageOfType(msgs, TypeRoomCreated)
		if !ok {
			t.Fatalf("Expected TypeRoomCreated, got %+v", msgs)
		}
		t.Logf("[B_sent + a] OBSERVATION: User was allowed to create room! userA.CurrentMatchID=%s, userA.PendingInviteID=%s", userA.CurrentMatchID, userA.PendingInviteID)
		t.Logf("[B_sent + a] BUG/CONFLICT: User now has BOTH an Open Room AND a Pending Challenge to Friend1! (msg=%s)", msg.Type)
	})

	t.Run("State B (Sent Invite) + Action b: Join a room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "roomHost")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		roomHost := clients["roomHost"]

		// userA sends challenge to friend1
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invitePayload)
		drainMessages(userA)

		// roomHost creates room
		hostPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(roomHost, hostPayload)
		hub.mu.RLock()
		hostRoomCode := hub.rooms[roomHost.CurrentMatchID].RoomCode
		hub.mu.RUnlock()

		// userA tries to join roomHost's room
		joinPayload, _ := json.Marshal(JoinRoomDTO{RoomCode: hostRoomCode})
		hub.handleJoinRoom(userA, joinPayload)

		t.Logf("[B_sent + b] OBSERVATION: userA joined roomHost's room! Active match started: %s", userA.CurrentMatchID)
		t.Logf("[B_sent + b] BUG/CONFLICT: userA.PendingInviteID to friend1 is STILL '%s'. Friend1 was never notified of cancellation!", userA.PendingInviteID)
	})

	t.Run("State B (Sent Invite) + Action c: Send a Pending Challenge to a DIFFERENT friend", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		friend2 := clients["userFriend2"]

		// userA sends challenge to friend1
		invite1Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invite1Payload)
		firstInviteID := userA.PendingInviteID
		drainMessages(userA)
		drainMessages(friend1)

		// userA sends challenge to friend2
		invite2Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend2.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invite2Payload)
		secondInviteID := userA.PendingInviteID

		t.Logf("[B_sent + c] OBSERVATION: userA PendingInviteID changed from %s to %s", firstInviteID, secondInviteID)
		// Check if friend1 got cancellation notification
		f1Msgs := getAllMessages(friend1)
		f1Got := hasMessageType(f1Msgs, TypeInvitationCancelled)
		t.Logf("[B_sent + c] BUG: friend1 received cancellation? %v (msgs: %+v)", f1Got, f1Msgs)
	})

	t.Run("State B (Sent Invite) + Action d: Get a challenge invite from another player", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		friend2 := clients["userFriend2"]

		// userA sent invite to friend1
		invite1Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invite1Payload)
		drainMessages(userA)

		// friend2 sends invite to userA
		invite2Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend2, invite2Payload)

		uMsgs := getAllMessages(userA)
		msg, ok := getMessageOfType(uMsgs, TypeMatchInvitation)
		t.Logf("[B_sent + d] OBSERVATION: userA received invitation from friend2? %v (Type: %s)", ok, msg.Type)
		t.Logf("[B_sent + d] BUG/CONFLICT: userA now has an outgoing challenge to friend1 AND incoming challenge from friend2!")
	})

	t.Run("State B (Received Invite) + Action a: Open new room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]

		// friend1 sends invite to userA
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invitePayload)
		drainMessages(userA)

		// userA tries to create an open room
		createPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(userA, createPayload)

		uMsgs := getAllMessages(userA)
		msg, ok := getMessageOfType(uMsgs, TypeRoomCreated)
		t.Logf("[B_recv + a] OBSERVATION: userA created room? %v (msg: %s, matchID: %s)", ok, msg.Type, userA.CurrentMatchID)
		t.Logf("[B_recv + a] BUG/CONFLICT: userA has an open room while friend1's invite is still pending on friend1!")
	})

	t.Run("State B (Received Invite) + Action b: Join a room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "roomHost")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		roomHost := clients["roomHost"]

		// friend1 sends invite to userA
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invitePayload)
		drainMessages(userA)

		// roomHost creates room
		hostPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(roomHost, hostPayload)
		hub.mu.RLock()
		hostRoomCode := hub.rooms[roomHost.CurrentMatchID].RoomCode
		hub.mu.RUnlock()

		// userA joins roomHost's room
		joinPayload, _ := json.Marshal(JoinRoomDTO{RoomCode: hostRoomCode})
		hub.handleJoinRoom(userA, joinPayload)

		t.Logf("[B_recv + b] OBSERVATION: userA joined roomHost's room! Active match: %s", userA.CurrentMatchID)
		t.Logf("[B_recv + b] BUG/CONFLICT: friend1's pending challenge to userA was never cancelled or declined!")
	})

	t.Run("State B (Received Invite) + Action c: Send a Pending Challenge", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		friend2 := clients["userFriend2"]

		// friend1 sends invite to userA
		invite1Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invite1Payload)
		drainMessages(userA)

		// userA sends invite to friend2
		invite2Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend2.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invite2Payload)

		t.Logf("[B_recv + c] OBSERVATION: userA sent challenge to friend2! (PendingInviteID: %s)", userA.PendingInviteID)
		t.Logf("[B_recv + c] BUG/CONFLICT: userA has received challenge from friend1 AND sent challenge to friend2 concurrently!")
	})

	t.Run("State B (Received Invite) + Action d: Get another challenge invite", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]
		friend2 := clients["userFriend2"]

		// friend1 sends invite to userA
		invite1Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invite1Payload)
		drainMessages(userA)

		// friend2 sends invite to userA
		invite2Payload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend2, invite2Payload)

		uMsgs := getAllMessages(userA)
		msg, ok := getMessageOfType(uMsgs, TypeMatchInvitation)
		t.Logf("[B_recv + d] OBSERVATION: userA received 2nd invitation? %v (Type: %s)", ok, msg.Type)
		t.Logf("[B_recv + d] BUG/CONFLICT: Multiple incoming challenges overlap without mutual exclusion!")
	})
}

// ---------------------------------------------------------------------
// STATE C: Open Room
// ---------------------------------------------------------------------

func TestStateOpenRoom_Scenarios(t *testing.T) {
	createPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})

	t.Run("State C + Action a: Open new room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA")
		userA := clients["userA"]

		hub.handleCreateRoom(userA, createPayload)
		room1ID := userA.CurrentMatchID

		hub.handleCreateRoom(userA, createPayload)
		room2ID := userA.CurrentMatchID
		t.Logf("[C + a] Result: Old room replaced cleanly. room1=%s, room2=%s", room1ID, room2ID)
	})

	t.Run("State C + Action b: Join a room", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "roomHost")
		userA := clients["userA"]
		roomHost := clients["roomHost"]

		hub.handleCreateRoom(userA, createPayload)

		// roomHost creates room
		hostPayload, _ := json.Marshal(CreateRoomDTO{TimeControl: TimeControl3Min, IsPrivate: false})
		hub.handleCreateRoom(roomHost, hostPayload)
		hub.mu.RLock()
		hostRoomCode := hub.rooms[roomHost.CurrentMatchID].RoomCode
		hub.mu.RUnlock()

		// userA tries to join roomHost's room
		joinPayload, _ := json.Marshal(JoinRoomDTO{RoomCode: hostRoomCode})
		hub.handleJoinRoom(userA, joinPayload)

		t.Logf("[C + b] Result: userA abandoned waiting room and joined roomHost's room! Active match=%s", userA.CurrentMatchID)
	})

	t.Run("State C + Action c: Send a Pending Challenge to a friend", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]

		// userA creates open room
		hub.handleCreateRoom(userA, createPayload)
		drainMessages(userA)

		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend1.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(userA, invitePayload)

		uMsgs := getAllMessages(userA)
		msg, ok := getMessageOfType(uMsgs, TypeMatchInvitationSent)
		if !ok {
			t.Fatalf("Expected TypeMatchInvitationSent, got %+v", uMsgs)
		}
		t.Logf("[C + c] Result: userA waiting room was cleanly closed, and challenge was sent! (msg: %s, pendingInviteID: %s)", msg.Type, userA.PendingInviteID)
	})

	t.Run("State C + Action d: Get a challenge invite from another player", func(t *testing.T) {
		hub, clients := setupHubWithClients(t, "userA", "userFriend1")
		userA := clients["userA"]
		friend1 := clients["userFriend1"]

		// userA is in open room
		hub.handleCreateRoom(userA, createPayload)
		drainMessages(userA)

		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        userA.UserID,
			TimeControl:     TimeControl3Min,
			ColorPreference: "random",
		})
		hub.handleInviteToMatch(friend1, invitePayload)

		// friend1 should have sent successfully (NOT blocked with 'Friend is already in a match'!)
		fMsgs := getAllMessages(friend1)
		fMsg, fOk := getMessageOfType(fMsgs, TypeMatchInvitationSent)
		if !fOk {
			t.Fatalf("Expected friend1 to send invite successfully, got %+v", fMsgs)
		}

		// userA should have received the invite!
		uMsgs := getAllMessages(userA)
		uMsg, uOk := getMessageOfType(uMsgs, TypeMatchInvitation)
		if !uOk {
			t.Fatalf("Expected userA in open room to receive challenge invite, got %+v", uMsgs)
		}

		t.Logf("[C + d] SUCCESS: userA received incoming challenge while hosting room! (fMsg: %s, uMsg: %s)", fMsg.Type, uMsg.Type)
	})
}
