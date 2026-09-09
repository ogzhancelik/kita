package game

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type Hub struct {
	clients          map[string]*Client
	rooms            map[string]*Room
	matchmakingQueue []*Client

	Register   chan *Client
	Unregister chan *Client

	matchService   ports.MatchService
	messageService ports.MessageService

	mu sync.RWMutex
}

func NewHub(matchService ports.MatchService, messageService ports.MessageService) *Hub {
	return &Hub{
		clients:          make(map[string]*Client),
		rooms:            make(map[string]*Room),
		matchmakingQueue: make([]*Client, 0),
		Register:         make(chan *Client),
		Unregister:       make(chan *Client),
		matchService:     matchService,
		messageService:   messageService,
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.mu.Lock()
			h.clients[client.UserID] = client
			h.mu.Unlock()
			client.SendJSON(TypeConnected, map[string]any{
				"user_id":  client.UserID,
				"username": client.Username,
				"rating":   client.Rating,
			})
			log.Printf("[Hub] Client connected: %s (%s)", client.Username, client.UserID)

		case client := <-h.Unregister:
			h.handleDisconnect(client)
		}
	}
}

func (h *Hub) handleDisconnect(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	delete(h.clients, client.UserID)
	h.removeFromQueueLocked(client)

	// Eğer oyuncu aktif bir maçtaysa, odanın disconnect mantığını çalıştır
	if client.CurrentMatchID != "" {
		if room, exists := h.rooms[client.CurrentMatchID]; exists {
			go room.HandleDisconnect(client.UserID)
		}
	}

	close(client.Send)
	log.Printf("[Hub] Client disconnected: %s (%s)", client.Username, client.UserID)
}

func (h *Hub) RouteClientMessage(client *Client, msg WSMessage) {
	switch msg.Type {
	case TypeJoinQueue:
		h.handleJoinQueue(client)

	case TypeLeaveQueue:
		h.handleLeaveQueue(client)

	case TypeMakeMove:
		h.handleMakeMove(client, msg.Payload)

	case TypeChatMessage:
		h.handleChatMessage(client, msg.Payload)

	case TypeResign:
		h.handleResign(client)

	default:
		client.SendError("Unknown message type: " + msg.Type)
	}
}

func (h *Hub) handleJoinQueue(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		client.SendError("You are already in an active match")
		return
	}

	for _, queued := range h.matchmakingQueue {
		if queued.UserID == client.UserID {
			client.SendError("You are already in queue")
			return
		}
	}

	h.matchmakingQueue = append(h.matchmakingQueue, client)
	client.SendJSON(TypeQueueJoined, map[string]string{"status": "waiting"})
	log.Printf("[Hub] User %s entered queue. Queue size: %d", client.Username, len(h.matchmakingQueue))

	// Kuyrukta en az 2 oyuncu varsa eşleştir
	if len(h.matchmakingQueue) >= 2 {
		p1 := h.matchmakingQueue[0]
		p2 := h.matchmakingQueue[1]
		h.matchmakingQueue = h.matchmakingQueue[2:]

		matchID := uuid.New().String()
		room := NewRoom(matchID, p1, p2, h.matchService, h)
		h.rooms[matchID] = room

		log.Printf("[Hub] Match created: %s between %s (white) and %s (black)", matchID, p1.Username, p2.Username)
		go room.Start()
	}
}

func (h *Hub) handleLeaveQueue(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.removeFromQueueLocked(client)
	client.SendJSON("queue_left", map[string]string{"status": "idle"})
}

func (h *Hub) removeFromQueueLocked(client *Client) {
	for i, c := range h.matchmakingQueue {
		if c.UserID == client.UserID {
			h.matchmakingQueue = append(h.matchmakingQueue[:i], h.matchmakingQueue[i+1:]...)
			break
		}
	}
}

func (h *Hub) handleMakeMove(client *Client, rawPayload json.RawMessage) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError("No active match found")
		return
	}

	var moveDTO MoveDTO
	if err := json.Unmarshal(rawPayload, &moveDTO); err != nil {
		client.SendError("Invalid move payload")
		return
	}

	if err := room.MakeMove(client.UserID, moveDTO); err != nil {
		client.SendError(err.Error())
	}
}

func (h *Hub) handleChatMessage(client *Client, rawPayload json.RawMessage) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError("No active match found")
		return
	}

	var payload struct {
		Content string `json:"content"`
	}
	if err := json.Unmarshal(rawPayload, &payload); err != nil || payload.Content == "" {
		client.SendError("Invalid chat message content")
		return
	}

	room.BroadcastChat(client.UserID, client.Username, payload.Content)

	if h.messageService != nil {
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			_, _ = h.messageService.SaveMessage(ctx, matchID, client.UserID, payload.Content)
		}()
	}
}

func (h *Hub) handleResign(client *Client) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError("No active match found")
		return
	}

	if err := room.Resign(client.UserID); err != nil {
		client.SendError(err.Error())
	}
}

func (h *Hub) CloseRoom(matchID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if room, exists := h.rooms[matchID]; exists {
		if room.WhitePlayer != nil {
			room.WhitePlayer.CurrentMatchID = ""
		}
		if room.BlackPlayer != nil {
			room.BlackPlayer.CurrentMatchID = ""
		}
		delete(h.rooms, matchID)
		log.Printf("[Hub] Room %s closed and removed from memory", matchID)
	}
}
