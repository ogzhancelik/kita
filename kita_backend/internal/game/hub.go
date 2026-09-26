package game

import (
	"context"
	"encoding/json"
	"log"
	"math/rand"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/oguzhancelik/kita/internal/core/domain"
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

	matchService        ports.MatchService
	messageService      ports.MessageService
	notificationService ports.NotificationService
	friendService       ports.FriendService

	mu sync.RWMutex
}

func NewHub(matchService ports.MatchService, messageService ports.MessageService, notificationService ports.NotificationService, friendService ...ports.FriendService) *Hub {
	var fs ports.FriendService
	if len(friendService) > 0 {
		fs = friendService[0]
	}
	return &Hub{
		clients:             make(map[string]*Client),
		rooms:               make(map[string]*Room),
		roomCodes:           make(map[string]string),
		matchmakingQueue:    make([]*Client, 0),
		Register:            make(chan *Client),
		Unregister:          make(chan *Client),
		matchService:        matchService,
		messageService:      messageService,
		notificationService: notificationService,
		friendService:       fs,
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

			// Check if client has an active match or waiting room to reconnect
			var matchedRoom *Room
			for _, r := range h.rooms {
				r.mu.RLock()
				if !r.isFinished && r.Status == "in_game" {
					if (r.WhitePlayer != nil && r.WhitePlayer.UserID == client.UserID) ||
						(r.BlackPlayer != nil && r.BlackPlayer.UserID == client.UserID) {
						matchedRoom = r
					}
				} else if r.Status == "waiting" && r.Host != nil && r.Host.UserID == client.UserID {
					matchedRoom = r
				}
				r.mu.RUnlock()
				if matchedRoom != nil {
					break
				}
			}
			activeMatchID := ""
			activeRoomCode := ""
			if matchedRoom != nil {
				matchedRoom.mu.RLock()
				if matchedRoom.Status == "in_game" {
					activeMatchID = matchedRoom.ID
				} else if matchedRoom.Status == "waiting" {
					activeRoomCode = matchedRoom.RoomCode
				}
				matchedRoom.mu.RUnlock()
			}
			h.mu.Unlock()

			client.SendJSON(TypeConnected, map[string]any{
				"user_id":          client.UserID,
				"username":         client.Username,
				"rating":           client.Rating,
				"avatar_index":     client.AvatarIndex,
				"active_match_id":  activeMatchID,
				"active_room_code": activeRoomCode,
			})
			log.Printf("[Hub] Client connected: %s (%s, avatar: %d, activeMatch: %s)", client.Username, client.UserID, client.AvatarIndex, activeMatchID)

			if matchedRoom != nil {
				if matchedRoom.Status == "in_game" {
					matchedRoom.HandleReconnect(client)
				} else if matchedRoom.Status == "waiting" {
					matchedRoom.mu.Lock()
					matchedRoom.Host = client
					client.CurrentMatchID = matchedRoom.ID
					roomCode := matchedRoom.RoomCode
					tc := matchedRoom.TimeControl
					matchedRoom.mu.Unlock()
					client.SendJSON(TypeRoomCreated, RoomCreatedDTO{
						RoomCode:    roomCode,
						TimeControl: tc,
					})
				}
			}

			h.BroadcastOnlineCount()
			h.BroadcastRoomsList()
			go h.notifyFriendsPresence(client.UserID, true)

		case client := <-h.Unregister:
			h.handleDisconnect(client)

		case <-ticker.C:
			h.BroadcastOnlineCount()
			h.BroadcastRoomsList()
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

	// Clean up any unstarted waiting room & pending outgoing invites hosted by this client
	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)

	// Eğer oyuncu aktif bir maçtaysa, odanın disconnect mantığını çalıştır
	if client.CurrentMatchID != "" {
		if room, exists := h.rooms[client.CurrentMatchID]; exists {
			go room.HandleDisconnect(client.UserID)
		}
	}

	client.Close()
	log.Printf("[Hub] Client disconnected: %s (%s)", client.Username, client.UserID)
	h.broadcastOnlineCountLocked()
	go h.notifyFriendsPresence(client.UserID, false)
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

	case TypeDrawOffer:
		h.handleDrawOffer(client)

	case TypeDrawAccept:
		h.handleDrawAccept(client)

	case TypeDrawDecline:
		h.handleDrawDecline(client)

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

	case TypeRematchCancel:
		h.handleRematchCancel(client, msg.Payload)

	case TypeInviteToMatch:
		h.handleInviteToMatch(client, msg.Payload)

	case TypeAcceptInvite:
		h.handleAcceptInvite(client, msg.Payload)

	case TypeDeclineInvite:
		h.handleDeclineInvite(client, msg.Payload)

	case TypeCancelInvite:
		h.handleCancelInvite(client, msg.Payload)

	case TypeLeaveRoom:
		h.handleLeaveRoom(client)

	case TypeUpdateAvatar:
		h.handleUpdateAvatar(client, msg.Payload)

	default:
		client.SendError(errors.ErrUnknownMessage, "Unknown message type: "+msg.Type)
	}
}

func (h *Hub) handleUpdateAvatar(client *Client, rawPayload json.RawMessage) {
	var dto struct {
		AvatarIndex int `json:"avatar_index"`
	}
	if err := json.Unmarshal(rawPayload, &dto); err == nil {
		client.AvatarIndex = dto.AvatarIndex
		log.Printf("[Hub] User %s (%s) updated avatar index to %d", client.Username, client.UserID, client.AvatarIndex)
	}
}

func (h *Hub) UpdateClientAvatar(userID string, avatarIndex int) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if client, ok := h.clients[userID]; ok {
		client.AvatarIndex = avatarIndex
		log.Printf("[Hub] Updated client %s avatar index to %d", userID, avatarIndex)
	}
}

// ─── Matchmaking Queue ────────────────────────────────────────────────

func (h *Hub) handleJoinQueue(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		if activeRoom, exists := h.rooms[client.CurrentMatchID]; exists && activeRoom.Status != "waiting" && !activeRoom.isFinished {
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

	// Clean up any unstarted waiting room hosted by this client and pending outgoing challenges
	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)

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

func (h *Hub) cleanupWaitingRoomLocked(client *Client) {
	if client == nil {
		return
	}
	cleanedUp := false
	if client.CurrentMatchID != "" {
		if r, exists := h.rooms[client.CurrentMatchID]; exists && r.Status == "waiting" && r.Host != nil && r.Host.UserID == client.UserID {
			delete(h.roomCodes, r.RoomCode)
			delete(h.rooms, client.CurrentMatchID)
			client.CurrentMatchID = ""
			cleanedUp = true
		}
	}
	for id, r := range h.rooms {
		if r.Status == "waiting" && r.Host != nil && r.Host.UserID == client.UserID {
			delete(h.roomCodes, r.RoomCode)
			delete(h.rooms, id)
			cleanedUp = true
			if client.CurrentMatchID == id {
				client.CurrentMatchID = ""
			}
		}
	}
	if cleanedUp {
		h.broadcastRoomsListLocked()
	}
}

func (h *Hub) cleanupPendingInviteLocked(client *Client) {
	if client == nil {
		return
	}
	client.mu.Lock()
	oldInviteID := client.PendingInviteID
	oldFriendID := client.PendingInviteFriendID
	client.PendingInviteID = ""
	client.PendingInviteFriendID = ""
	client.PendingInviteTimeControl = 0
	client.PendingInviteColor = ""
	client.mu.Unlock()

	if oldInviteID != "" || oldFriendID != "" {
		if oldFriend, exists := h.clients[oldFriendID]; exists && oldFriend != nil {
			oldFriend.SendJSON(TypeInvitationCancelled, map[string]string{
				"invite_id":  oldInviteID,
				"inviter_id": client.UserID,
			})
		}
		if h.notificationService != nil {
			go func(invID, fID, uID string) {
				if invID != "" && fID != "" {
					_ = h.notificationService.DeleteNotification(context.Background(), "challenge_"+invID, fID)
				}
				if uID != "" && fID != "" {
					_ = h.notificationService.DeletePendingChallenge(context.Background(), uID, fID)
				}
			}(oldInviteID, oldFriendID, client.UserID)
		}
	}
}

// ─── Room Creation & Joining ──────────────────────────────────────────

func (h *Hub) handleCreateRoom(client *Client, rawPayload json.RawMessage) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// If client is already in an active playing match, reject
	if client.CurrentMatchID != "" {
		if activeRoom, exists := h.rooms[client.CurrentMatchID]; exists && activeRoom.Status != "waiting" && !activeRoom.isFinished {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
	}

	// Clean up ANY prior waiting room hosted by this client and pending outgoing challenges
	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)

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
	client.CurrentMatchID = matchID

	client.SendJSON(TypeRoomCreated, RoomCreatedDTO{
		RoomCode:    roomCode,
		TimeControl: timeControl,
		IsPrivate:   dto.IsPrivate,
	})
	log.Printf("[Hub] Custom room created: %s (Code: %s, TC: %dms) by %s", matchID, roomCode, timeControl, client.Username)
	h.broadcastRoomsListLocked()
}

func (h *Hub) handleJoinRoom(client *Client, rawPayload json.RawMessage) {
	h.mu.Lock()
	defer h.mu.Unlock()

	// If client was hosting a waiting room or had a pending invite, clean it up
	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)

	if client.CurrentMatchID != "" {
		if activeRoom, exists := h.rooms[client.CurrentMatchID]; exists && activeRoom.Status != "waiting" && !activeRoom.isFinished {
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

	// A player cannot join their own room
	if room.Host != nil && room.Host.UserID == client.UserID {
		client.SendError(errors.ErrValidationFailed, "You cannot join your own room")
		return
	}

	if err := room.Join(client); err != nil {
		client.SendError(errors.ErrValidationFailed, err.Error())
		return
	}
	// Note: room.Join(client) already executes r.startLocked() which sends TypeMatchFound
	// and initial game_state to both players!
	log.Printf("[Hub] Client %s joined custom room %s and match started", client.Username, dto.RoomCode)
	h.broadcastRoomsListLocked()
}

func (h *Hub) handleLeaveRoom(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)
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

func (h *Hub) handleDrawOffer(client *Client) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	if err := room.OfferDraw(client.UserID); err != nil {
		client.SendError(errors.ErrValidationFailed, err.Error())
	}
}

func (h *Hub) handleDrawAccept(client *Client) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	if err := room.AcceptDraw(client.UserID); err != nil {
		client.SendError(errors.ErrValidationFailed, err.Error())
	}
}

func (h *Hub) handleDrawDecline(client *Client) {
	h.mu.RLock()
	matchID := client.CurrentMatchID
	room, exists := h.rooms[matchID]
	h.mu.RUnlock()

	if !exists || room == nil {
		client.SendError(errors.ErrMatchNotFound, "No active match found")
		return
	}

	if err := room.DeclineDraw(client.UserID); err != nil {
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

func (h *Hub) getPublicRoomsDTOLocked(page, limit int) RoomsListDTO {
	type roomItem struct {
		dto       RoomInfoDTO
		startedAt time.Time
	}
	var items []roomItem
	for _, room := range h.rooms {
		if room.Status == "waiting" && !room.IsPrivate && room.RoomCode != "" {
			hostID := ""
			hostName := "Unknown"
			hostRating := 1200
			hostAvatarIndex := 0
			if room.Host != nil {
				hostID = room.Host.UserID
				hostName = room.Host.Username
				hostRating = room.Host.Rating
				hostAvatarIndex = room.Host.AvatarIndex
			}
			items = append(items, roomItem{
				dto: RoomInfoDTO{
					RoomCode:        room.RoomCode,
					HostID:          hostID,
					HostName:        hostName,
					HostRating:      hostRating,
					HostAvatarIndex: hostAvatarIndex,
					TimeControl:     room.TimeControl,
					IsPrivate:       room.IsPrivate,
				},
				startedAt: room.StartedAt,
			})
		}
	}

	// Sort newest first
	sort.Slice(items, func(i, j int) bool {
		return items[i].startedAt.After(items[j].startedAt)
	})

	total := len(items)
	if limit <= 0 {
		limit = 20
	}
	totalPages := (total + limit - 1) / limit
	if totalPages < 1 {
		totalPages = 1
	}
	if page < 1 {
		page = 1
	}

	start := (page - 1) * limit
	end := start + limit
	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	pagedRooms := make([]RoomInfoDTO, 0, end-start)
	for _, item := range items[start:end] {
		pagedRooms = append(pagedRooms, item.dto)
	}

	return RoomsListDTO{
		Rooms:      pagedRooms,
		Page:       page,
		TotalPages: totalPages,
		Total:      total,
	}
}

func (h *Hub) broadcastRoomsListLocked() {
	dto := h.getPublicRoomsDTOLocked(1, 20)
	for _, c := range h.clients {
		c.SendJSON(TypeRoomsList, dto)
	}
}

func (h *Hub) BroadcastRoomsList() {
	h.mu.RLock()
	defer h.mu.RUnlock()
	h.broadcastRoomsListLocked()
}

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
	resp := h.getPublicRoomsDTOLocked(dto.Page, dto.Limit)
	h.mu.RUnlock()

	client.SendJSON(TypeRoomsList, resp)
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

	var tc int64 = TimeControl3Min
	if room, exists := h.rooms[dto.MatchID]; exists && room.TimeControl > 0 {
		tc = room.TimeControl
	}

	// Store rematch request on client for opponent to accept
	client.mu.Lock()
	client.PendingRematchID = dto.MatchID
	client.PendingRematchTimeControl = tc
	client.mu.Unlock()

	if opponentClient == nil {
		client.SendError(errors.ErrMatchNotFound, "Opponent is no longer online")
		return
	}

	opponentClient.SendJSON(TypeRematchOffered, RematchOfferedDTO{
		MatchID:              dto.MatchID,
		RequesterID:          client.UserID,
		RequesterName:        client.Username,
		RequesterAvatarIndex: client.AvatarIndex,
		TimeControl:          tc,
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

	tc := requester.PendingRematchTimeControl
	if tc <= 0 {
		tc = TimeControl3Min
	}

	// Clear pending rematch
	requester.mu.Lock()
	requester.PendingRematchID = ""
	requester.PendingRematchTimeControl = 0
	requester.mu.Unlock()

	// Clean up any unstarted waiting room hosted by either client
	for _, p := range []*Client{requester, client} {
		for id, r := range h.rooms {
			if r.Status == "waiting" && r.Host != nil && r.Host.UserID == p.UserID {
				delete(h.roomCodes, r.RoomCode)
				delete(h.rooms, id)
				p.CurrentMatchID = ""
				h.broadcastRoomsListLocked()
				break
			}
		}
	}

	// Create new match with swapped colors
	matchID := uuid.New().String()
	room := NewRoomWithTimeControl(matchID, client, requester, tc, h.matchService, h)
	h.rooms[matchID] = room

	log.Printf("[Hub] Rematch created: %s between %s and %s", matchID, client.Username, requester.Username)
	go room.Start()
}

func (h *Hub) handleRematchCancel(client *Client, rawPayload json.RawMessage) {
	var dto RematchRequestDTO
	if len(rawPayload) > 0 {
		_ = json.Unmarshal(rawPayload, &dto)
	}

	client.mu.Lock()
	matchID := client.PendingRematchID
	if matchID == "" && dto.MatchID != "" {
		matchID = dto.MatchID
	}
	client.PendingRematchID = ""
	client.PendingRematchTimeControl = 0
	client.mu.Unlock()

	if matchID == "" {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, c := range h.clients {
		if c.UserID != client.UserID {
			c.mu.RLock()
			lastMatch := c.LastFinishedMatchID
			currentMatch := c.CurrentMatchID
			c.mu.RUnlock()
			if lastMatch == matchID || currentMatch == matchID {
				c.SendJSON(TypeRematchDeclined, map[string]string{
					"match_id":      matchID,
					"decliner_name": client.Username,
					"reason":        "cancelled",
				})
				break
			}
		}
	}
	log.Printf("[Hub] Rematch cancelled by %s for match %s", client.Username, matchID)
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
				c.SendJSON(TypeRematchDeclined, map[string]string{
					"match_id":      dto.MatchID,
					"decliner_name": client.Username,
				})
				if h.notificationService != nil {
					go func(targetUserID string, declinerName string) {
						payloadBytes, _ := json.Marshal(map[string]any{
							"match_id":      dto.MatchID,
							"decliner_name": declinerName,
						})
						notif := &domain.Notification{
							UserID:    targetUserID,
							ActorID:   client.UserID,
							ActorName: declinerName,
							Type:      domain.NotificationTypeRematchDeclined,
							Status:    domain.NotificationStatusUnread,
							Title:     "notifications.rematchDeclinedTitle",
							Subtitle:  "notifications.rematchDeclinedSubtitle",
							Payload:   string(payloadBytes),
						}
						_, _ = h.notificationService.CreateNotification(context.Background(), notif)
					}(c.UserID, client.Username)
				}
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

	h.mu.Lock()
	defer h.mu.Unlock()

	if client.CurrentMatchID != "" {
		if r, exists := h.rooms[client.CurrentMatchID]; exists && r.Status != "waiting" && !r.isFinished {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
	}

	timeControl := dto.TimeControl
	if timeControl != TimeControlNone &&
		timeControl != TimeControl1Min &&
		timeControl != TimeControl3Min &&
		timeControl != TimeControl5Min {
		timeControl = TimeControl3Min
	}

	friend, exists := h.clients[dto.FriendID]
	if !exists || friend == nil {
		client.SendError(errors.ErrPlayerOffline, "Friend is not online")
		return
	}

	if friend.CurrentMatchID != "" {
		if fRoom, fExists := h.rooms[friend.CurrentMatchID]; fExists && fRoom.Status != "waiting" && !fRoom.isFinished {
			client.SendError(errors.ErrAlreadyInMatch, "Friend is already in a match")
			return
		}
	}

	// Clean up inviter's waiting room and previous pending outgoing challenge
	h.cleanupWaitingRoomLocked(client)
	h.cleanupPendingInviteLocked(client)

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

	client.SendJSON(TypeMatchInvitationSent, MatchInvitationSentDTO{
		InviteID: inviteID,
		FriendID: dto.FriendID,
	})

	friend.SendJSON(TypeMatchInvitation, MatchInvitationDTO{
		InviteID:           inviteID,
		InviterID:          client.UserID,
		InviterName:        client.Username,
		InviterRating:      client.Rating,
		InviterAvatarIndex: client.AvatarIndex,
		TimeControl:        timeControl,
		ColorPreference:    colorPref,
	})

	if h.notificationService != nil {
		go func(friendID string, inviterID string, inviterName string, rating int, avatarIdx int, tc int64, pref string, invID string) {
			payloadBytes, _ := json.Marshal(map[string]any{
				"invite_id":            invID,
				"inviter_id":           inviterID,
				"sender_name":          inviterName,
				"sender_rating":        rating,
				"sender_avatar_index":  avatarIdx,
				"time_control":         tc,
				"color_preference":     pref,
			})
			notif := &domain.Notification{
				ID:        "challenge_" + invID,
				UserID:    friendID,
				ActorID:   inviterID,
				ActorName: inviterName,
				Type:      domain.NotificationTypeChallenge,
				Status:    domain.NotificationStatusPending,
				Title:     "notifications.challengeTitle",
				Subtitle:  inviterName,
				Payload:   string(payloadBytes),
			}
			_, _ = h.notificationService.CreateNotification(context.Background(), notif)
		}(dto.FriendID, client.UserID, client.Username, client.Rating, client.AvatarIndex, timeControl, colorPref, inviteID)
	}

	// Ephemeral auto-expiration timer (60s) for live match invitation
	go func(invID string, inviterID string, friendID string) {
		time.Sleep(60 * time.Second)
		h.mu.Lock()
		defer h.mu.Unlock()

		if inviter, exists := h.clients[inviterID]; exists && inviter != nil {
			inviter.mu.Lock()
			isStillPending := (inviter.PendingInviteID == invID)
			if isStillPending {
				inviter.PendingInviteID = ""
				inviter.PendingInviteFriendID = ""
				inviter.PendingInviteTimeControl = 0
				inviter.PendingInviteColor = ""
			}
			inviter.mu.Unlock()

			if isStillPending {
				inviter.SendJSON(TypeInvitationCancelled, map[string]string{
					"invite_id":  invID,
					"inviter_id": inviterID,
					"reason":     "timeout",
				})

				if f, fExists := h.clients[friendID]; fExists && f != nil {
					f.SendJSON(TypeInvitationCancelled, map[string]string{
						"invite_id":  invID,
						"inviter_id": inviterID,
						"reason":     "timeout",
					})
				}

				if h.notificationService != nil {
					_ = h.notificationService.DeleteNotification(context.Background(), "challenge_"+invID, friendID)
					_ = h.notificationService.DeletePendingChallenge(context.Background(), inviterID, friendID)
				}
				log.Printf("[Hub] Match invite %s expired after 60s timeout", invID)
			}
		}
	}(inviteID, client.UserID, dto.FriendID)

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
		if r, exists := h.rooms[client.CurrentMatchID]; exists && r.Status != "waiting" && !r.isFinished {
			client.SendError(errors.ErrAlreadyInMatch, "You are already in an active match")
			return
		}
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

	if inviter == nil {
		client.SendError(errors.ErrMatchNotFound, "Invite no longer valid")
		if h.notificationService != nil && dto.InviteID != "" {
			go func(invID string, uID string) {
				_ = h.notificationService.DeleteNotification(context.Background(), "challenge_"+invID, uID)
			}(dto.InviteID, client.UserID)
		}
		return
	}

	if inviter.CurrentMatchID != "" {
		if r, exists := h.rooms[inviter.CurrentMatchID]; exists && r.Status != "waiting" {
			client.SendError(errors.ErrMatchNotFound, "Invite no longer valid")
			if h.notificationService != nil && dto.InviteID != "" {
				go func(invID string, uID string) {
					_ = h.notificationService.DeleteNotification(context.Background(), "challenge_"+invID, uID)
				}(dto.InviteID, client.UserID)
			}
			return
		}
	}

	// Clear invite
	inviter.mu.Lock()
	inviter.PendingInviteID = ""
	inviter.PendingInviteFriendID = ""
	inviter.PendingInviteTimeControl = 0
	inviter.PendingInviteColor = ""
	inviter.mu.Unlock()

	if h.notificationService != nil {
		go func(invID string, uID string) {
			_ = h.notificationService.UpdateStatus(context.Background(), "challenge_"+invID, uID, domain.NotificationStatusAccepted)
		}(dto.InviteID, client.UserID)
	}

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

	// Clean up any unstarted waiting room & pending invites hosted by either client
	for _, p := range []*Client{inviter, client} {
		h.cleanupWaitingRoomLocked(p)
		h.cleanupPendingInviteLocked(p)
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
				"invite_id":     dto.InviteID,
				"friend_id":     client.UserID,
				"decliner_name": client.Username,
			})

			if h.notificationService != nil {
				go func(inviterID string, declinerID string, declinerName string, invID string) {
					_ = h.notificationService.UpdateStatus(context.Background(), "challenge_"+invID, declinerID, domain.NotificationStatusDeclined)
					payloadBytes, _ := json.Marshal(map[string]any{
						"invite_id":     invID,
						"decliner_name": declinerName,
					})
					notif := &domain.Notification{
						UserID:    inviterID,
						ActorID:   declinerID,
						ActorName: declinerName,
						Type:      domain.NotificationTypeChallengeDeclined,
						Status:    domain.NotificationStatusUnread,
						Title:     "notifications.challengeDeclinedTitle",
						Subtitle:  "notifications.challengeDeclinedSubtitle",
						Payload:   string(payloadBytes),
					}
					_, _ = h.notificationService.CreateNotification(context.Background(), notif)
				}(c.UserID, client.UserID, client.Username, dto.InviteID)
			}
			break
		}
	}
}

func (h *Hub) handleCancelInvite(client *Client, rawPayload json.RawMessage) {
	var dto CancelInviteDTO
	if len(rawPayload) > 0 {
		_ = json.Unmarshal(rawPayload, &dto)
	}

	client.mu.Lock()
	inviteID := client.PendingInviteID
	friendID := client.PendingInviteFriendID
	client.PendingInviteID = ""
	client.PendingInviteFriendID = ""
	client.PendingInviteTimeControl = 0
	client.PendingInviteColor = ""
	client.mu.Unlock()

	if inviteID == "" && dto.InviteID != "" {
		inviteID = dto.InviteID
	}
	if friendID == "" && dto.FriendID != "" {
		friendID = dto.FriendID
	}

	if inviteID == "" && friendID == "" {
		return
	}

	h.mu.RLock()
	var friend *Client
	if friendID != "" {
		friend = h.clients[friendID]
	}
	h.mu.RUnlock()

	if friend != nil {
		friend.SendJSON(TypeInvitationCancelled, map[string]string{
			"invite_id":  inviteID,
			"inviter_id": client.UserID,
		})
	}

	if h.notificationService != nil {
		go func(invID string, fID string, uID string) {
			if invID != "" && fID != "" {
				_ = h.notificationService.DeleteNotification(context.Background(), "challenge_"+invID, fID)
			}
			if uID != "" && fID != "" {
				_ = h.notificationService.DeletePendingChallenge(context.Background(), uID, fID)
			}
		}(inviteID, friendID, client.UserID)
	}
}

// ─── Room Cleanup ─────────────────────────────────────────────────────

func (h *Hub) CloseRoom(matchID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if room, exists := h.rooms[matchID]; exists {
		if !room.isFinished {
			if room.WhitePlayer != nil {
				room.WhitePlayer.mu.Lock()
				if room.WhitePlayer.CurrentMatchID == matchID {
					room.WhitePlayer.CurrentMatchID = ""
				}
				room.WhitePlayer.mu.Unlock()
				room.WhitePlayer.SendJSON(TypeMatchClosed, map[string]string{
					"match_id": matchID,
					"reason":   "closed",
				})
			}
			if room.BlackPlayer != nil {
				room.BlackPlayer.mu.Lock()
				if room.BlackPlayer.CurrentMatchID == matchID {
					room.BlackPlayer.CurrentMatchID = ""
				}
				room.BlackPlayer.mu.Unlock()
				room.BlackPlayer.SendJSON(TypeMatchClosed, map[string]string{
					"match_id": matchID,
					"reason":   "closed",
				})
			}
		} else {
			if room.WhitePlayer != nil {
				room.WhitePlayer.mu.Lock()
				room.WhitePlayer.LastFinishedMatchID = matchID
				if room.WhitePlayer.CurrentMatchID == matchID {
					room.WhitePlayer.CurrentMatchID = ""
				}
				room.WhitePlayer.mu.Unlock()
			}
			if room.BlackPlayer != nil {
				room.BlackPlayer.mu.Lock()
				room.BlackPlayer.LastFinishedMatchID = matchID
				if room.BlackPlayer.CurrentMatchID == matchID {
					room.BlackPlayer.CurrentMatchID = ""
				}
				room.BlackPlayer.mu.Unlock()
			}
		}
		if room.Host != nil && room.Status == "waiting" {
			room.Host.mu.Lock()
			if room.Host.CurrentMatchID == matchID {
				room.Host.CurrentMatchID = ""
			}
			room.Host.mu.Unlock()
			room.Host.SendJSON(TypeRoomLeft, map[string]string{"status": "idle"})
		}
		if room.RoomCode != "" {
			delete(h.roomCodes, room.RoomCode)
		}
		delete(h.rooms, matchID)
		log.Printf("[Hub] Room %s closed and removed from memory", matchID)
		h.broadcastRoomsListLocked()
	}
}

// SendToUser dispatches a message to an online user connected to the Hub.
func (h *Hub) SendToUser(userID string, msgType string, payload any) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if client, exists := h.clients[userID]; exists {
		client.SendJSON(msgType, payload)
		log.Printf("[Hub] Dispatched %s to user %s (%s)", msgType, client.Username, userID)
	}
}

// IsUserOnline returns whether a user is currently connected to the Hub.
func (h *Hub) IsUserOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, exists := h.clients[userID]
	return exists
}

func (h *Hub) notifyFriendsPresence(userID string, isOnline bool) {
	if h.friendService == nil || strings.HasPrefix(userID, "guest-") {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	friends, err := h.friendService.GetFriends(ctx, userID)
	if err != nil {
		return
	}

	dto := FriendPresenceDTO{
		UserID:   userID,
		IsOnline: isOnline,
	}

	for _, f := range friends {
		h.SendToUser(f.UserID, TypeFriendPresence, dto)
	}
}



