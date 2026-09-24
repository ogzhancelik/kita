package game

import (
	"encoding/json"
	"testing"
)

func TestMatchmakingQueueToss(t *testing.T) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)

	c1 := NewClient(hub, sConn1, "user-1", "Player1", 1200)
	c2 := NewClient(hub, sConn2, "user-2", "Player2", 1200)

	// Test multiple pairings to verify both assignments occur (50/50 toss)
	seenP1White := false
	seenP1Black := false

	// We can directly test handleJoinQueue
	for i := 0; i < 60; i++ {
		c1.CurrentMatchID = ""
		c2.CurrentMatchID = ""

		hub.mu.Lock()
		hub.matchmakingQueue = []*Client{}
		hub.mu.Unlock()

		hub.handleJoinQueue(c1)
		hub.handleJoinQueue(c2)

		hub.mu.RLock()
		matchID := c1.CurrentMatchID
		room := hub.rooms[matchID]
		hub.mu.RUnlock()

		if room != nil {
			if room.WhitePlayer.UserID == c1.UserID {
				seenP1White = true
			} else if room.BlackPlayer.UserID == c1.UserID {
				seenP1Black = true
			}
			hub.mu.Lock()
			delete(hub.rooms, matchID)
			hub.mu.Unlock()
		}

		if seenP1White && seenP1Black {
			break
		}
	}

	if !seenP1White || !seenP1Black {
		t.Errorf("Expected 50/50 toss to yield both White and Black assignments for Player 1, got White: %v, Black: %v", seenP1White, seenP1Black)
	}
}

func TestDirectInviteColorPreference(t *testing.T) {
	mockService := &mockMatchService{}
	hub := NewHub(mockService, nil, nil)

	sConn1, _ := setupTestWS(t)
	sConn2, _ := setupTestWS(t)

	inviter := NewClient(hub, sConn1, "inviter-id", "Inviter", 1200)
	friend := NewClient(hub, sConn2, "friend-id", "Friend", 1200)

	hub.mu.Lock()
	hub.clients[inviter.UserID] = inviter
	hub.clients[friend.UserID] = friend
	hub.mu.Unlock()

	// 1. Inviter chooses "white"
	{
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend.UserID,
			TimeControl:     180000,
			ColorPreference: "white",
		})
		hub.handleInviteToMatch(inviter, invitePayload)

		if inviter.PendingInviteColor != "white" {
			t.Fatalf("Expected PendingInviteColor to be 'white', got %s", inviter.PendingInviteColor)
		}

		acceptPayload, _ := json.Marshal(AcceptInviteDTO{
			InviteID: inviter.PendingInviteID,
		})
		hub.handleAcceptInvite(friend, acceptPayload)

		hub.mu.RLock()
		room := hub.rooms[inviter.CurrentMatchID]
		hub.mu.RUnlock()

		if room == nil {
			t.Fatalf("Room not found after accept")
		}
		if room.WhitePlayer.UserID != inviter.UserID || room.BlackPlayer.UserID != friend.UserID {
			t.Errorf("Expected inviter to be White and friend to be Black, got White=%s, Black=%s", room.WhitePlayer.UserID, room.BlackPlayer.UserID)
		}

		// Reset
		inviter.CurrentMatchID = ""
		friend.CurrentMatchID = ""
	}

	// 2. Inviter chooses "black"
	{
		invitePayload, _ := json.Marshal(InviteToMatchDTO{
			FriendID:        friend.UserID,
			TimeControl:     180000,
			ColorPreference: "black",
		})
		hub.handleInviteToMatch(inviter, invitePayload)

		if inviter.PendingInviteColor != "black" {
			t.Fatalf("Expected PendingInviteColor to be 'black', got %s", inviter.PendingInviteColor)
		}

		acceptPayload, _ := json.Marshal(AcceptInviteDTO{
			InviteID: inviter.PendingInviteID,
		})
		hub.handleAcceptInvite(friend, acceptPayload)

		hub.mu.RLock()
		room := hub.rooms[inviter.CurrentMatchID]
		hub.mu.RUnlock()

		if room == nil {
			t.Fatalf("Room not found after accept")
		}
		if room.WhitePlayer.UserID != friend.UserID || room.BlackPlayer.UserID != inviter.UserID {
			t.Errorf("Expected friend to be White and inviter to be Black, got White=%s, Black=%s", room.WhitePlayer.UserID, room.BlackPlayer.UserID)
		}

		// Reset
		inviter.CurrentMatchID = ""
		friend.CurrentMatchID = ""
	}

	// 3. Inviter chooses "random" (or omitted)
	{
		seenInviterWhite := false
		seenInviterBlack := false

		for i := 0; i < 50; i++ {
			inviter.CurrentMatchID = ""
			friend.CurrentMatchID = ""

			invitePayload, _ := json.Marshal(InviteToMatchDTO{
				FriendID:        friend.UserID,
				TimeControl:     180000,
				ColorPreference: "random",
			})
			hub.handleInviteToMatch(inviter, invitePayload)

			acceptPayload, _ := json.Marshal(AcceptInviteDTO{
				InviteID: inviter.PendingInviteID,
			})
			hub.handleAcceptInvite(friend, acceptPayload)

			hub.mu.RLock()
			room := hub.rooms[inviter.CurrentMatchID]
			hub.mu.RUnlock()

			if room != nil {
				if room.WhitePlayer.UserID == inviter.UserID {
					seenInviterWhite = true
				} else if room.BlackPlayer.UserID == inviter.UserID {
					seenInviterBlack = true
				}
			}

			if seenInviterWhite && seenInviterBlack {
				break
			}
		}

		if !seenInviterWhite || !seenInviterBlack {
			t.Errorf("Expected 'random' color preference to yield both White and Black assignments for inviter, got White: %v, Black: %v", seenInviterWhite, seenInviterBlack)
		}
	}
}
