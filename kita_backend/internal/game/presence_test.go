package game

import (
	"encoding/json"
	"testing"
)

func TestHub_PresenceUpdateAndQueueEviction(t *testing.T) {
	hub := NewHub(nil, nil, nil, nil, nil, nil)
	client := NewClient(hub, nil, "user-presence-1", "Alice", 1300)

	hub.mu.Lock()
	hub.clients[client.UserID] = client
	hub.mu.Unlock()

	// 1. Initial presence must be online
	isOnline, status := hub.GetUserPresence(client.UserID)
	if !isOnline || status != "online" {
		t.Fatalf("Expected client to be initially online, got isOnline=%v, status=%s", isOnline, status)
	}

	// 2. Put client into matchmaking queue
	hub.mu.Lock()
	hub.enterActivityLocked(client, ActivityInQueue)
	hub.matchmakingQueue = append(hub.matchmakingQueue, client)
	hub.mu.Unlock()

	if len(hub.matchmakingQueue) != 1 {
		t.Fatalf("Expected 1 player in queue, got %d", len(hub.matchmakingQueue))
	}

	// 3. Send presence_update: afk
	afkPayload, _ := json.Marshal(PresenceUpdateDTO{Status: "afk"})
	hub.RouteClientMessage(client, WSMessage{
		Type:    TypePresenceUpdate,
		Payload: afkPayload,
	})

	// 4. Verify client presence is afk
	isOnline, status = hub.GetUserPresence(client.UserID)
	if !isOnline || status != "afk" {
		t.Fatalf("Expected client status to be afk, got %s", status)
	}

	// 5. Verify client was automatically removed from matchmaking queue
	hub.mu.RLock()
	queueLen := len(hub.matchmakingQueue)
	hub.mu.RUnlock()
	if queueLen != 0 {
		t.Fatalf("Expected client to be removed from queue on becoming AFK, but queue length is %d", queueLen)
	}

	// 6. Send presence_update: online
	onlinePayload, _ := json.Marshal(PresenceUpdateDTO{Status: "online"})
	hub.RouteClientMessage(client, WSMessage{
		Type:    TypePresenceUpdate,
		Payload: onlinePayload,
	})

	isOnline, status = hub.GetUserPresence(client.UserID)
	if !isOnline || status != "online" {
		t.Fatalf("Expected client status to return to online, got %s", status)
	}
}
