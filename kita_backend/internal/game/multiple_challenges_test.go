package game

import (
	"encoding/json"
	"testing"
)

func TestMultipleChallenges_CanInviteMultipleAndAcceptCancelsOthers(t *testing.T) {
	hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2", "userFriend3")
	userA := clients["userA"]
	friend1 := clients["userFriend1"]
	friend2 := clients["userFriend2"]
	friend3 := clients["userFriend3"]

	// 1. userA sends challenge to friend1
	invite1Payload, _ := json.Marshal(InviteToMatchDTO{
		FriendID:        friend1.UserID,
		TimeControl:     TimeControl3Min,
		ColorPreference: "white",
	})
	hub.handleInviteToMatch(userA, invite1Payload)
	inv1 := userA.GetPendingInvite(userA.PendingInviteID)
	if inv1 == nil || inv1.FriendID != friend1.UserID {
		t.Fatalf("Expected pending invite to friend1")
	}

	// 2. userA sends challenge to friend2
	invite2Payload, _ := json.Marshal(InviteToMatchDTO{
		FriendID:        friend2.UserID,
		TimeControl:     TimeControl5Min,
		ColorPreference: "black",
	})
	hub.handleInviteToMatch(userA, invite2Payload)

	// 3. userA sends challenge to friend3
	invite3Payload, _ := json.Marshal(InviteToMatchDTO{
		FriendID:        friend3.UserID,
		TimeControl:     TimeControl1Min,
		ColorPreference: "random",
	})
	hub.handleInviteToMatch(userA, invite3Payload)

	// Verify userA has 3 pending outgoing invites
	allInvites := userA.GetAllPendingInvites()
	if len(allInvites) != 3 {
		t.Fatalf("Expected userA to have 3 pending invites, got %d", len(allInvites))
	}

	// Verify friend1 and friend2 did NOT receive cancellation
	f1Msgs := getAllMessages(friend1)
	if hasMessageType(f1Msgs, TypeInvitationCancelled) {
		t.Fatalf("friend1 should NOT have received cancellation when inviting others")
	}
	f2Msgs := getAllMessages(friend2)
	if hasMessageType(f2Msgs, TypeInvitationCancelled) {
		t.Fatalf("friend2 should NOT have received cancellation when inviting others")
	}

	// Find invite ID for friend2
	var friend2InviteID string
	for _, inv := range allInvites {
		if inv.FriendID == friend2.UserID {
			friend2InviteID = inv.InviteID
		}
	}
	if friend2InviteID == "" {
		t.Fatalf("Missing invite ID for friend2")
	}

	// 4. Friend2 accepts the challenge
	drainMessages(userA)
	drainMessages(friend1)
	drainMessages(friend2)
	drainMessages(friend3)

	acceptPayload, _ := json.Marshal(AcceptInviteDTO{
		InviteID: friend2InviteID,
	})
	hub.handleAcceptInvite(friend2, acceptPayload)

	// Verify friend1 and friend3 got cancellation messages
	f1MsgsAfter := getAllMessages(friend1)
	if !hasMessageType(f1MsgsAfter, TypeInvitationCancelled) {
		t.Errorf("friend1 SHOULD receive cancellation after friend2 accepts")
	}

	f3MsgsAfter := getAllMessages(friend3)
	if !hasMessageType(f3MsgsAfter, TypeInvitationCancelled) {
		t.Errorf("friend3 SHOULD receive cancellation after friend2 accepts")
	}

	// Verify userA's pending invites are cleared
	if len(userA.GetAllPendingInvites()) != 0 {
		t.Errorf("userA should have 0 pending invites after match start, got %d", len(userA.GetAllPendingInvites()))
	}

	// Verify userA and friend2 are in match
	if userA.Activity != ActivityInMatch {
		t.Errorf("userA activity should be InMatch, got %v", userA.Activity)
	}
	if friend2.Activity != ActivityInMatch {
		t.Errorf("friend2 activity should be InMatch, got %v", friend2.Activity)
	}
}

func TestMultipleChallenges_JoinQueueOrRoomCancelsAllInvites(t *testing.T) {
	hub, clients := setupHubWithClients(t, "userA", "userFriend1", "userFriend2")
	userA := clients["userA"]
	friend1 := clients["userFriend1"]
	friend2 := clients["userFriend2"]

	// 1. userA sends challenge to friend1 and friend2
	inv1Payload, _ := json.Marshal(InviteToMatchDTO{
		FriendID:    friend1.UserID,
		TimeControl: TimeControl3Min,
	})
	hub.handleInviteToMatch(userA, inv1Payload)

	inv2Payload, _ := json.Marshal(InviteToMatchDTO{
		FriendID:    friend2.UserID,
		TimeControl: TimeControl3Min,
	})
	hub.handleInviteToMatch(userA, inv2Payload)

	if len(userA.GetAllPendingInvites()) != 2 {
		t.Fatalf("Expected 2 pending invites, got %d", len(userA.GetAllPendingInvites()))
	}

	drainMessages(userA)
	drainMessages(friend1)
	drainMessages(friend2)

	// 2. userA creates a waiting room
	createRoomPayload, _ := json.Marshal(CreateRoomDTO{
		TimeControl: TimeControl3Min,
		IsPrivate:   false,
	})
	hub.handleCreateRoom(userA, createRoomPayload)

	// Verify userA has 0 pending invites
	if len(userA.GetAllPendingInvites()) != 0 {
		t.Errorf("userA should have 0 pending invites after creating room, got %d", len(userA.GetAllPendingInvites()))
	}

	// Verify both friends received cancellation
	f1Msgs := getAllMessages(friend1)
	if !hasMessageType(f1Msgs, TypeInvitationCancelled) {
		t.Errorf("friend1 should receive cancellation when inviter creates room")
	}
	f2Msgs := getAllMessages(friend2)
	if !hasMessageType(f2Msgs, TypeInvitationCancelled) {
		t.Errorf("friend2 should receive cancellation when inviter creates room")
	}

	// Clean up room for next check
	hub.handleLeaveRoom(userA)
	drainMessages(userA)
	drainMessages(friend1)
	drainMessages(friend2)

	// 3. userA sends challenges again
	hub.handleInviteToMatch(userA, inv1Payload)
	hub.handleInviteToMatch(userA, inv2Payload)
	if len(userA.GetAllPendingInvites()) != 2 {
		t.Fatalf("Expected 2 pending invites, got %d", len(userA.GetAllPendingInvites()))
	}

	drainMessages(userA)
	drainMessages(friend1)
	drainMessages(friend2)

	// 4. userA joins matchmaking queue
	hub.handleJoinQueue(userA)

	if len(userA.GetAllPendingInvites()) != 0 {
		t.Errorf("userA should have 0 pending invites after joining queue, got %d", len(userA.GetAllPendingInvites()))
	}
	f1QueueMsgs := getAllMessages(friend1)
	if !hasMessageType(f1QueueMsgs, TypeInvitationCancelled) {
		t.Errorf("friend1 should receive cancellation when inviter joins queue")
	}
	f2QueueMsgs := getAllMessages(friend2)
	if !hasMessageType(f2QueueMsgs, TypeInvitationCancelled) {
		t.Errorf("friend2 should receive cancellation when inviter joins queue")
	}
}

