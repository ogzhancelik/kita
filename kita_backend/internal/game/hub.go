package game

import (
	"context"
	"encoding/json"
	"log"
	"math/rand"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/errors"
	"github.com/oguzhancelik/kita/internal/core/ports"
)

type Hub struct {
	clients          map[string]*Client
	rooms            map[string]*Room
	roomCodes        map[string]string
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
		roomCodes:        make(map[string]string),
		matchmakingQueue: make([]*Client, 0),
		Register:         make(chan *Client),
		Unregister:       make(chan *Client),
		matchService:     matchService,
		messageService:   messageService,
	}
}

func (h *Hub) Run() {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

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
			h.BroadcastOnlineCount()

		case client := <-h.Unregister:
			h.handleDisconnect(client)

		case <-ticker.C:
			h.BroadcastOnlineCount()
		}
	}
}

func (h *Hub) handleDisconnect(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, exists := h.clients[client.UserID]; !exists {
		client.Close()
		return
	}

	delete(h.clients, client.UserID)
	h.removeFromQueueLocked(client)

	// Eğer oyuncu aktif bir maçtaysa, odanın disconnect mantığını çalıştır
	if client.CurrentMatchID != "" {
		if room, exists := h.rooms[client.CurrentMatchID]; exists {
			go room.HandleDisconnect(client.UserID)
		}
	}

	client.Close()
	log.Printf("[Hub] Client disconnected: %s (%s)", client.Username, client.UserID)
	h.broadcastOnlineCountLocked()
}

func (h *Hub) broadcastOnlineCountLocked() {
	count := len(h.clients)
	inQueue := len(h.matchmakingQueue)
	dto := OnlineCountDTO{
		Count:   count,
		InQueue: inQueue,
	}
	for _, c := range h.clients {
		c.SendJSON(TypeOnlineCount, dto)
	}
}

func (h *Hub) BroadcastOnlineCount() {
	h.mu.RLock()
	defer h.mu.RUnlock()
	h.broadcastOnlineCountLocked()
}

func (h *Hub) GetOnlineStats() (int, int) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients), len(h.matchmakingQueue)
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

	case TypeCreateRoom:
		h.handleCreateRoom(client, msg.Payload)

	case TypeJoinRoom:
		h.handleJoinRoom(client, msg.Payload)

	case TypeGetOnlineCount:
		h.handleOnlineCount(client)

	case TypeListRooms:
		h.handleListRooms(client, msg.Payload)

	case TypeRematchRequest:
		h.handleRematchRequest(client, msg.Payload)

	case TypeRematchAccept:
		h.handleRematchAccept(client, msg.Payload)

	case TypeRematchDecline:
		h.handleRematchDecline(client, msg.Payload)

	case TypeInviteToMatch:
		h.handleInviteToMatch(client, msg.Payload)

	case TypeAcceptInvite:
		h.handleAcceptInvite(client, msg.Payload)

	case TypeDeclineInvite:
		h.handleDeclineInvite(client, msg.Payload)

	case TypeLeaveRoom:
		h.handleLeaveRoom(client)

	default:
		client.SendError(errors.ErrUnknownMessage, "Unknown message type: "+msg.Type)
	}
}

// ─── Matchmaking Queue ────────────────────────────────────────────────

func (h *Hub) handleJoinQueue(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		// Clean up unstarted waiting room if user was hosting one
		if oldRoom, exists := h.rooms[client.CurrentMatchID]; exists && oldRoom.Status == "waiting" && oldRoom.Host != nil && oldRoom.Host.UserID == client.UserID {
			log.Printf("[Hub] Host %s replacing unstarted waiting room %s to join queue", client.Username, oldRoom.ID)
			delete(h.roomCodes, oldRoom.RoomCode)
			delete(h.rooms, client.CurrentMatchID)
			client.CurrentMatchID = ""
		} else {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
	}

	for _, queued := range h.matchmakingQueue {
		if queued.UserID == client.UserID {
			client.SendError(errors.ErrAlreadyInQueue, "You are already in queue")
			return
		}
	}

	h.matchmakingQueue = append(h.matchmakingQueue, client)
	client.SendJSON(TypeQueueJoined, map[string]string{"status": "waiting"})
	log.Printf("[Hub] User %s entered queue. Queue size: %d", client.Username, len(h.matchmakingQueue))
	h.broadcastOnlineCountLocked()

	// Kuyrukta en az 2 oyuncu varsa eşleştir
	if len(h.matchmakingQueue) >= 2 {
		p1 := h.matchmakingQueue[0]
		p2 := h.matchmakingQueue[1]
		h.matchmakingQueue = h.matchmakingQueue[2:]
		h.broadcastOnlineCountLocked()

		matchID := uuid.New().String()
		// 50/50 toss for white and black
		white, black := p1, p2
		if rand.Intn(2) == 1 {
			white, black = p2, p1
		}

		// Default matchmaking uses 3-minute time control
		room := NewRoomWithTimeControl(matchID, white, black, TimeControl3Min, h.matchService, h)
		h.rooms[matchID] = room

		log.Printf("[Hub] Match created: %s between %s (white) and %s (black)", matchID, white.Username, black.Username)
		go room.Start()
	}
}

func (h *Hub) handleLeaveQueue(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.removeFromQueueLocked(client)
	client.SendJSON("queue_left", map[string]string{"status": "idle"})
	h.broadcastOnlineCountLocked()
}

func (h *Hub) removeFromQueueLocked(client *Client) {
	for i, c := range h.matchmakingQueue {
		if c.UserID == client.UserID {
			h.matchmakingQueue = append(h.matchmakingQueue[:i], h.matchmakingQueue[i+1:]...)
			break
		}
	}
}

// ─── Room Creation & Joining ──────────────────────────────────────────

func (h *Hub) handleCreateRoom(client *Client, rawPayload json.RawMessage) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		// If client is already the host of an unstarted waiting room, clean it up and recreate
		if oldRoom, exists := h.rooms[client.CurrentMatchID]; exists && oldRoom.Status == "waiting" && oldRoom.Host != nil && oldRoom.Host.UserID == client.UserID {
			log.Printf("[Hub] Host %s replacing unstarted waiting room %s (Code: %s)", client.Username, oldRoom.ID, oldRoom.RoomCode)
			delete(h.roomCodes, oldRoom.RoomCode)
			delete(h.rooms, client.CurrentMatchID)
			client.CurrentMatchID = ""
		} else {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
	}

	var dto CreateRoomDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid payload")
		return
	}

	// Validate time control
	timeControl := dto.TimeControl
	if timeControl != TimeControlNone &&
		timeControl != TimeControl1Min &&
		timeControl != TimeControl3Min &&
		timeControl != TimeControl5Min {
		timeControl = TimeControl3Min // Default fallback
	}

	const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, 6)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	roomCode := string(b)
	matchID := uuid.New().String()

	room := NewCustomRoom(matchID, roomCode, client, dto.IsPrivate, timeControl, h.matchService, h)
	h.rooms[matchID] = room
	h.roomCodes[roomCode] = matchID

	client.SendJSON(TypeRoomCreated, RoomCreatedDTO{
		RoomCode:    roomCode,
		TimeControl: timeControl,
	})
	log.Printf("[Hub] Custom room created: %s (Code: %s, TC: %dms) by %s", matchID, roomCode, timeControl, client.Username)
}

func (h *Hub) handleJoinRoom(client *Client, rawPayload json.RawMessage) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		// If client was hosting an unstarted waiting room, clean it up so they can join another room
		if oldRoom, exists := h.rooms[client.CurrentMatchID]; exists && oldRoom.Status == "waiting" && oldRoom.Host != nil && oldRoom.Host.UserID == client.UserID {
			log.Printf("[Hub] Host %s abandoning unstarted room %s (Code: %s) to join another room", client.Username, oldRoom.ID, oldRoom.RoomCode)
			delete(h.roomCodes, oldRoom.RoomCode)
			delete(h.rooms, client.CurrentMatchID)
			client.CurrentMatchID = ""
		} else {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
	}

	var dto JoinRoomDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid payload")
		return
	}

	matchID, exists := h.roomCodes[dto.RoomCode]
	if !exists {
		client.SendError(errors.ErrMatchNotFound, "Invalid room code")
		return
	}

	room, rExists := h.rooms[matchID]
	if !rExists || room.Status != "waiting" {
		client.SendError(errors.ErrMatchNotFound, "Room is not available")
		return
	}

	if err := room.Join(client); err != nil {
		client.SendError(errors.ErrValidationFailed, err.Error())
		return
	}
	// Note: room.Join(client) already executes r.startLocked() which sends TypeMatchFound
	// and initial game_state to both players!
	log.Printf("[Hub] Client %s joined custom room %s and match started", client.Username, dto.RoomCode)
}

func (h *Hub) handleLeaveRoom(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID == "" {
		client.SendJSON(TypeRoomLeft, map[string]string{"status": "idle"})
		return
	}

	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	if exists && room.Status == "waiting" && room.Host != nil && room.Host.UserID == client.UserID {
		delete(h.roomCodes, room.RoomCode)
		delete(h.rooms, matchID)
		log.Printf("[Hub] Host %s cancelled waiting room %s (Code: %s)", client.Username, matchID, room.RoomCode)
	}
	client.CurrentMatchID = ""
	client.SendJSON(TypeRoomLeft, map[string]string{"status": "idle"})
}

// ─── Move, Chat, Resign ──────────────────────────────────────────────

func (h *Hub) handleMakeMove(client *Client, rawPayload json.RawMessage) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	var moveDTO MoveDTO
	if err := json.Unmarshal(rawPayload, &moveDTO); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid move payload")
		return
	}

	if err := room.MakeMove(client.UserID, moveDTO); err != nil {
		client.SendError(errors.ErrInvalidMove, err.Error())
	}
}

func (h *Hub) handleChatMessage(client *Client, rawPayload json.RawMessage) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	var payload struct {
		Content string `json:"content"`
	}
	if err := json.Unmarshal(rawPayload, &payload); err != nil || payload.Content == "" {
		client.SendError(errors.ErrInvalidMessage, "Invalid chat message content")
		return
	}

	// Rate limiting: max 200 chars
	if len(payload.Content) > 200 {
		client.SendError(errors.ErrValidationFailed, "Message too long (max 200 chars)")
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
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	if err := room.Resign(client.UserID); err != nil {
		client.SendError(errors.ErrValidationFailed, err.Error())
	}
}

// ─── Online Count ─────────────────────────────────────────────────────

func (h *Hub) handleOnlineCount(client *Client) {
	h.mu.RLock()
	count := len(h.clients)
	inQueue := len(h.matchmakingQueue)
	h.mu.RUnlock()

	client.SendJSON(TypeOnlineCount, OnlineCountDTO{
		Count:   count,
		InQueue: inQueue,
	})
}

// ─── Room Listing ─────────────────────────────────────────────────────

func (h *Hub) handleListRooms(client *Client, rawPayload json.RawMessage) {
	var dto ListRoomsDTO
	if rawPayload != nil {
		_ = json.Unmarshal(rawPayload, &dto)
	}
	if dto.Page < 1 {
		dto.Page = 1
	}
	if dto.Limit < 1 || dto.Limit > 50 {
		dto.Limit = 20
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	// Collect public, waiting rooms
	var publicRooms []RoomInfoDTO
	for _, room := range h.rooms {
		if room.Status == "waiting" && !room.IsPrivate && room.RoomCode != "" {
			hostName := "Unknown"
			hostRating := 1200
			if room.Host != nil {
				hostName = room.Host.Username
				hostRating = room.Host.Rating
			}
			publicRooms = append(publicRooms, RoomInfoDTO{
				RoomCode:    room.RoomCode,
				HostName:    hostName,
				HostRating:  hostRating,
				TimeControl: room.TimeControl,
				IsPrivate:   room.IsPrivate,
			})
		}
	}

	total := len(publicRooms)
	totalPages := (total + dto.Limit - 1) / dto.Limit
	if totalPages < 1 {
		totalPages = 1
	}

	start := (dto.Page - 1) * dto.Limit
	end := start + dto.Limit
	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	client.SendJSON(TypeRoomsList, RoomsListDTO{
		Rooms:      publicRooms[start:end],
		Page:       dto.Page,
		TotalPages: totalPages,
		Total:      total,
	})
}

// ─── Rematch ──────────────────────────────────────────────────────────

// pendingRematches tracks matchID → Room (finished room with rematch request)
// We re-use the finished room's data to create a new match with same settings.

func (h *Hub) handleRematchRequest(client *Client, rawPayload json.RawMessage) {
	var dto RematchRequestDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid rematch payload")
		return
	}

	h.mu.RLock()
	// Find the opponent from the finished match
	var opponentClient *Client

	// 1. Check if room still exists in memory
	if room, exists := h.rooms[dto.MatchID]; exists {
		if room.WhitePlayer != nil && room.WhitePlayer.UserID != client.UserID {
			opponentClient = room.WhitePlayer
		} else if room.BlackPlayer != nil && room.BlackPlayer.UserID != client.UserID {
			opponentClient = room.BlackPlayer
		}
	}

	// 2. If room was already closed or cleaned up, search connected clients
	if opponentClient == nil {
		for _, c := range h.clients {
			if c.UserID != client.UserID {
				c.mu.RLock()
				lastMatch := c.LastFinishedMatchID
				currentMatch := c.CurrentMatchID
				c.mu.RUnlock()
				if lastMatch == dto.MatchID || currentMatch == dto.MatchID {
					opponentClient = c
					break
				}
			}
		}
	}
	h.mu.RUnlock()

	// Store rematch request on client for opponent to accept
	client.mu.Lock()
	client.PendingRematchID = dto.MatchID
	client.mu.Unlock()

	if opponentClient == nil {
		client.SendError(errors.ErrMatchNotFound, "Opponent is no longer online")
		return
	}

	opponentClient.SendJSON(TypeRematchOffered, RematchOfferedDTO{
		MatchID:       dto.MatchID,
		RequesterID:   client.UserID,
		RequesterName: client.Username,
		TimeControl:   TimeControl3Min, // Default for rematch
	})

	log.Printf("[Hub] Rematch requested by %s for match %s", client.Username, dto.MatchID)
}

func (h *Hub) handleRematchAccept(client *Client, rawPayload json.RawMessage) {
	var dto RematchRequestDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid rematch accept payload")
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" && client.CurrentMatchID != dto.MatchID {
		client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
		return
	}

	// Find the requester
	var requester *Client
	for _, c := range h.clients {
		if c.UserID != client.UserID {
			c.mu.RLock()
			pending := c.PendingRematchID
			c.mu.RUnlock()
			if pending == dto.MatchID {
				requester = c
				break
			}
		}
	}

	if requester == nil || (requester.CurrentMatchID != "" && requester.CurrentMatchID != dto.MatchID) {
		client.SendError(errors.ErrMatchNotFound, "Rematch requester not available")
		return
	}

	// Clear pending rematch
	requester.mu.Lock()
	requester.PendingRematchID = ""
	requester.mu.Unlock()

	// Create new match with swapped colors
	matchID := uuid.New().String()
	room := NewRoomWithTimeControl(matchID, client, requester, TimeControl3Min, h.matchService, h)
	h.rooms[matchID] = room

	log.Printf("[Hub] Rematch created: %s between %s and %s", matchID, client.Username, requester.Username)
	go room.Start()
}

func (h *Hub) handleRematchDecline(client *Client, rawPayload json.RawMessage) {
	var dto RematchRequestDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, c := range h.clients {
		if c.UserID != client.UserID {
			c.mu.RLock()
			pending := c.PendingRematchID
			c.mu.RUnlock()
			if pending == dto.MatchID {
				c.mu.Lock()
				c.PendingRematchID = ""
				c.mu.Unlock()
				c.SendJSON(TypeRematchDeclined, map[string]string{"match_id": dto.MatchID})
				break
			}
		}
	}
}

// ─── Friend Match Invites ─────────────────────────────────────────────

func (h *Hub) handleInviteToMatch(client *Client, rawPayload json.RawMessage) {
	var dto InviteToMatchDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid invite payload")
		return
	}

	if client.CurrentMatchID != "" {
		client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
		return
	}

	timeControl := dto.TimeControl
	if timeControl != TimeControlNone &&
		timeControl != TimeControl1Min &&
		timeControl != TimeControl3Min &&
		timeControl != TimeControl5Min {
		timeControl = TimeControl3Min
	}

	h.mu.RLock()
	friend, exists := h.clients[dto.FriendID]
	h.mu.RUnlock()

	if !exists || friend == nil {
		client.SendError(errors.ErrNotFound, "Friend is not online")
		return
	}

	if friend.CurrentMatchID != "" {
		client.SendError(errors.ErrAlreadyInMatch, "Friend is already in a match")
		return
	}

	colorPref := dto.ColorPreference
	if colorPref != "white" && colorPref != "black" {
		colorPref = "random"
	}

	inviteID := uuid.New().String()

	// Store invite info on the inviter
	client.mu.Lock()
	client.PendingInviteID = inviteID
	client.PendingInviteFriendID = dto.FriendID
	client.PendingInviteTimeControl = timeControl
	client.PendingInviteColor = colorPref
	client.mu.Unlock()

	friend.SendJSON(TypeMatchInvitation, MatchInvitationDTO{
		InviteID:        inviteID,
		InviterID:       client.UserID,
		InviterName:     client.Username,
		InviterRating:   client.Rating,
		TimeControl:     timeControl,
		ColorPreference: colorPref,
	})

	log.Printf("[Hub] Match invite sent from %s to %s (pref: %s)", client.Username, friend.Username, colorPref)
}

func (h *Hub) handleAcceptInvite(client *Client, rawPayload json.RawMessage) {
	var dto AcceptInviteDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		client.SendError(errors.ErrInvalidMessage, "Invalid accept invite payload")
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
		return
	}

	// Find the inviter by invite ID
	var inviter *Client
	var timeControl int64
	var colorPref string
	for _, c := range h.clients {
		c.mu.RLock()
		if c.PendingInviteID == dto.InviteID && c.PendingInviteFriendID == client.UserID {
			inviter = c
			timeControl = c.PendingInviteTimeControl
			colorPref = c.PendingInviteColor
		}
		c.mu.RUnlock()
		if inviter != nil {
			break
		}
	}

	if inviter == nil || inviter.CurrentMatchID != "" {
		client.SendError(errors.ErrMatchNotFound, "Invite no longer valid")
		return
	}

	// Clear invite
	inviter.mu.Lock()
	inviter.PendingInviteID = ""
	inviter.PendingInviteFriendID = ""
	inviter.PendingInviteTimeControl = 0
	inviter.PendingInviteColor = ""
	inviter.mu.Unlock()

	// Assign sides based on inviter's preference
	var white, black *Client
	switch colorPref {
	case "white":
		white, black = inviter, client
	case "black":
		white, black = client, inviter
	default: // "random"
		if rand.Intn(2) == 0 {
			white, black = inviter, client
		} else {
			white, black = client, inviter
		}
	}

	// Create match
	matchID := uuid.New().String()
	room := NewRoomWithTimeControl(matchID, white, black, timeControl, h.matchService, h)
	h.rooms[matchID] = room

	log.Printf("[Hub] Friend match created: %s between %s (white) and %s (black) (TC: %dms, pref: %s)", matchID, white.Username, black.Username, timeControl, colorPref)
	go room.Start()
}

func (h *Hub) handleDeclineInvite(client *Client, rawPayload json.RawMessage) {
	var dto AcceptInviteDTO
	if err := json.Unmarshal(rawPayload, &dto); err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, c := range h.clients {
		c.mu.RLock()
		inviteID := c.PendingInviteID
		friendID := c.PendingInviteFriendID
		c.mu.RUnlock()

		if inviteID == dto.InviteID && friendID == client.UserID {
			c.mu.Lock()
			c.PendingInviteID = ""
			c.PendingInviteFriendID = ""
			c.PendingInviteTimeControl = 0
			c.PendingInviteColor = ""
			c.mu.Unlock()
			c.SendJSON(TypeInvitationDeclined, map[string]string{
				"invite_id": dto.InviteID,
				"friend_id": client.UserID,
			})
			break
		}
	}
}

// ─── Room Cleanup ─────────────────────────────────────────────────────

func (h *Hub) CloseRoom(matchID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if room, exists := h.rooms[matchID]; exists {
		if room.WhitePlayer != nil {
			room.WhitePlayer.mu.Lock()
			room.WhitePlayer.LastFinishedMatchID = matchID
			room.WhitePlayer.CurrentMatchID = ""
			room.WhitePlayer.mu.Unlock()
		}
		if room.BlackPlayer != nil {
			room.BlackPlayer.mu.Lock()
			room.BlackPlayer.LastFinishedMatchID = matchID
			room.BlackPlayer.CurrentMatchID = ""
			room.BlackPlayer.mu.Unlock()
		}
		if room.RoomCode != "" {
			delete(h.roomCodes, room.RoomCode)
		}
		delete(h.rooms, matchID)
		log.Printf("[Hub] Room %s closed and removed from memory", matchID)
	}
}
