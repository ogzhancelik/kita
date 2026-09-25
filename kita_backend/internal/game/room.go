package game

import (
	"context"
	"errors"
	"log"
	"math/rand"
	"sync"
	"time"

	"github.com/oguzhancelik/kita/internal/core/domain"
	"github.com/oguzhancelik/kita/internal/core/ports"
	kitagame "github.com/oguzhancelik/kita/pkg/game"
)

var (
	ErrGameFinished = errors.New("game is already finished")
	ErrNotYourTurn  = errors.New("it is not your turn")
	ErrIllegalMove  = errors.New("illegal move")
	ErrNotInMatch   = errors.New("player is not part of this match")
)

type Room struct {
	ID           string
	RoomCode     string
	IsPrivate    bool
	Host         *Client
	Status       string // "waiting", "in_game", "finished"
	WhitePlayer  *Client
	BlackPlayer  *Client
	Spectators   map[string]*Client

	// Mevcut Oyun Motoru (pkg/game - dokunulmadan kullanılıyor)
	Game         *kitagame.Game

	// Bellekte biriken tüm hamleler (Deferred Persistence Buffer - JSONB)
	MovesBuffer  []domain.MoveRecord
	lastMoveTime time.Time

	// Chess Clock
	TimeControl      int64 // ms per player, 0 = unlimited
	WhiteRemainingMs int64
	BlackRemainingMs int64
	turnStartedAt    time.Time   // When the current player's clock started ticking
	timeoutTimer     *time.Timer // Fires when current player runs out of time

	// Last move tracking for UI highlighting
	LastMoveDTO  *MoveDTO

	// Rematch tracking
	RematchRequester string // UserID of who requested rematch

	// Disconnect / Reconnect grace period
	disconnectPlayerID string
	disconnectTimer    *time.Timer

	StartedAt    time.Time
	mu           sync.RWMutex
	matchService ports.MatchService
	isFinished   bool
	hub          *Hub
}

func NewRoom(id string, white, black *Client, matchService ports.MatchService, hub *Hub) *Room {
	return NewRoomWithTimeControl(id, white, black, TimeControlNone, matchService, hub)
}

func NewRoomWithTimeControl(id string, white, black *Client, timeControl int64, matchService ports.MatchService, hub *Hub) *Room {
	now := time.Now()
	r := &Room{
		ID:               id,
		Status:           "in_game",
		WhitePlayer:      white,
		BlackPlayer:      black,
		Spectators:       make(map[string]*Client),
		Game:             kitagame.NewGame(),
		MovesBuffer:      make([]domain.MoveRecord, 0, 64),
		lastMoveTime:     now,
		TimeControl:      timeControl,
		WhiteRemainingMs: timeControl,
		BlackRemainingMs: timeControl,
		turnStartedAt:    now,
		StartedAt:        now,
		matchService:     matchService,
		hub:              hub,
	}

	white.CurrentMatchID = id
	black.CurrentMatchID = id

	return r
}

func NewCustomRoom(id, roomCode string, host *Client, isPrivate bool, timeControl int64, matchService ports.MatchService, hub *Hub) *Room {
	now := time.Now()
	r := &Room{
		ID:               id,
		RoomCode:         roomCode,
		IsPrivate:        isPrivate,
		Host:             host,
		Status:           "waiting",
		Spectators:       make(map[string]*Client),
		Game:             kitagame.NewGame(),
		MovesBuffer:      make([]domain.MoveRecord, 0, 64),
		lastMoveTime:     now,
		TimeControl:      timeControl,
		WhiteRemainingMs: timeControl,
		BlackRemainingMs: timeControl,
		StartedAt:        now,
		matchService:     matchService,
		hub:              hub,
	}

	host.CurrentMatchID = id
	return r
}

func (r *Room) Join(client *Client) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.Status != "waiting" {
		return errors.New("room is not waiting for players")
	}

	client.CurrentMatchID = r.ID

	if rand.Intn(2) == 0 {
		r.WhitePlayer = r.Host
		r.BlackPlayer = client
	} else {
		r.WhitePlayer = client
		r.BlackPlayer = r.Host
	}

	r.Status = "in_game"
	now := time.Now()
	r.lastMoveTime = now
	r.StartedAt = now
	r.turnStartedAt = now
	r.startLocked()
	return nil
}

func (r *Room) Start() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.startLocked()
}

func (r *Room) startLocked() {

	// 1. Oyunculara maç bulundu ve takımları bildirilir
	r.WhitePlayer.SendJSON(TypeMatchFound, MatchFoundDTO{
		MatchID:             r.ID,
		YourTeam:            "white",
		OpponentID:          r.BlackPlayer.UserID,
		OpponentName:        r.BlackPlayer.Username,
		OpponentRating:      r.BlackPlayer.Rating,
		OpponentAvatarIndex: r.BlackPlayer.AvatarIndex,
		TimeControl:         r.TimeControl,
	})

	r.BlackPlayer.SendJSON(TypeMatchFound, MatchFoundDTO{
		MatchID:             r.ID,
		YourTeam:            "black",
		OpponentID:          r.WhitePlayer.UserID,
		OpponentName:        r.WhitePlayer.Username,
		OpponentRating:      r.WhitePlayer.Rating,
		OpponentAvatarIndex: r.WhitePlayer.AvatarIndex,
		TimeControl:         r.TimeControl,
	})

	// 2. İlk chess clock timeout'u başlatılır (beyazın sırası)
	r.startTimeoutTimerLocked()

	// 3. Tahtanın ilk hali gönderilir
	r.broadcastStateLocked()
}

// ─── Chess Clock ──────────────────────────────────────────────────────

// deductCurrentPlayerTimeLocked deducts elapsed time from current player's clock.
// Must be called with lock held. Returns remaining time for the current player.
func (r *Room) deductCurrentPlayerTimeLocked() int64 {
	if r.TimeControl == 0 {
		return 0 // Unlimited — no deduction
	}

	elapsed := time.Since(r.turnStartedAt).Milliseconds()
	r.turnStartedAt = time.Now() // Reset reference immediately so elapsed does not leak into next player's broadcast

	if r.Game.Turn == "white" {
		r.WhiteRemainingMs -= elapsed
		if r.WhiteRemainingMs < 0 {
			r.WhiteRemainingMs = 0
		}
		return r.WhiteRemainingMs
	}

	r.BlackRemainingMs -= elapsed
	if r.BlackRemainingMs < 0 {
		r.BlackRemainingMs = 0
	}
	return r.BlackRemainingMs
}

// startTimeoutTimerLocked starts a timer that fires when the current player runs out of time.
// Must be called with lock held.
func (r *Room) startTimeoutTimerLocked() {
	if r.TimeControl == 0 {
		return // Unlimited — no timeout
	}

	// Cancel previous timer
	if r.timeoutTimer != nil {
		r.timeoutTimer.Stop()
	}

	var remaining int64
	if r.Game.Turn == "white" {
		remaining = r.WhiteRemainingMs
	} else {
		remaining = r.BlackRemainingMs
	}

	if remaining <= 0 {
		go r.handleTimeout()
		return
	}

	r.turnStartedAt = time.Now()
	r.timeoutTimer = time.AfterFunc(time.Duration(remaining)*time.Millisecond, func() {
		r.handleTimeout()
	})
}

// handleTimeout is called when a player's clock reaches zero.
func (r *Room) handleTimeout() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.isFinished || r.Status != "in_game" {
		return
	}

	// Deduct remaining time
	r.deductCurrentPlayerTimeLocked()

	// Current turn player loses
	var winnerID *string
	var winnerTeam string
	var result string
	if r.Game.Turn == "white" {
		r.WhiteRemainingMs = 0
		winnerID = &r.BlackPlayer.UserID
		winnerTeam = "black"
		result = string(domain.ResultBlackWins)
	} else {
		r.BlackRemainingMs = 0
		winnerID = &r.WhitePlayer.UserID
		winnerTeam = "white"
		result = string(domain.ResultWhiteWins)
	}

	log.Printf("[Room %s] Player %s timed out, winner: %s", r.ID, r.Game.Turn, winnerTeam)
	r.finishWithExplicitWinnerLocked(winnerID, winnerTeam, result, "timeout")
}

// ─── Move Handling ────────────────────────────────────────────────────

func (r *Room) MakeMove(playerID string, moveDTO MoveDTO) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.isFinished {
		return ErrGameFinished
	}
	if r.Status != "in_game" {
		return errors.New("game has not started yet")
	}

	// 1. Sıranın bu oyuncuda olduğunu doğrula
	currentTurn := r.Game.Turn // "white" veya "black"
	if (currentTurn == "white" && playerID != r.WhitePlayer.UserID) ||
		(currentTurn == "black" && playerID != r.BlackPlayer.UserID) {
		return ErrNotYourTurn
	}

	// 2. Hamlenin kurallara uygunluğunu kontrol et (legal moves)
	candidateMove := moveDTO.ToGameMove()
	legalMoves := r.Game.GetLegalMoves()

	isLegal := false
	for _, m := range legalMoves {
		if m.PieceID == candidateMove.PieceID &&
			m.FromPos == candidateMove.FromPos &&
			m.ToPos == candidateMove.ToPos {
			isLegal = true
			candidateMove = m
			break
		}
	}

	if !isLegal {
		return ErrIllegalMove
	}

	// 3. Chess clock: Deduct time for the player who just moved
	r.deductCurrentPlayerTimeLocked()

	// 4. Hamleyi oyuna uygula (Mevcut engine metodu: pure transition)
	r.Game = r.Game.ApplyMove(candidateMove)

	// 5. Last move tracking
	r.LastMoveDTO = &MoveDTO{
		PieceID: candidateMove.PieceID,
		FromCol: candidateMove.FromPos.Col,
		FromRow: candidateMove.FromPos.Row,
		ToCol:   candidateMove.ToPos.Col,
		ToRow:   candidateMove.ToPos.Row,
	}

	// 6. Hamleyi veritabanına değil, bellekteki buffer'a ekle (JSONB MoveRecord)
	now := time.Now()
	durationMs := int(now.Sub(r.lastMoveTime).Milliseconds())
	r.lastMoveTime = now

	matchMove := domain.MoveRecord{
		PlyIndex:  r.Game.MoveCount,
		PlayerID:  playerID,
		PieceID:   candidateMove.PieceID,
		FromCol:   candidateMove.FromPos.Col,
		FromRow:   candidateMove.FromPos.Row,
		ToCol:     candidateMove.ToPos.Col,
		ToRow:     candidateMove.ToPos.Row,
		TimeMs:    durationMs,
		CreatedAt: now,
	}
	r.MovesBuffer = append(r.MovesBuffer, matchMove)

	// 7. Oyun bitti mi kontrol et (Karşı kral avlanamadıysa anında win/loss)
	status := r.Game.GetStatus()
	if status != "ongoing" {
		r.broadcastStateLocked()
		r.finishGameLocked(status, domain.ReasonNormal)
		return nil
	}

	// 8. Otomatik karşı misilleme kontrolü (Last-Stand Defense Auto Retaliation)
	retaliationMove := r.Game.GetKingRetaliationMove()
	if retaliationMove != nil {
		if r.timeoutTimer != nil {
			r.timeoutTimer.Stop()
			r.timeoutTimer = nil
		}
		r.turnStartedAt = time.Now()
		r.broadcastStateLocked()

		go func(rm *Room, autoMove kitagame.Move) {
			time.Sleep(400 * time.Millisecond)
			rm.mu.Lock()
			defer rm.mu.Unlock()
			if rm.isFinished || rm.Status != "in_game" {
				return
			}

			// Deduct time for auto-retaliation turn
			rm.deductCurrentPlayerTimeLocked()

			rm.Game = rm.Game.ApplyMove(autoMove)

			// Last move tracking for retaliation
			rm.LastMoveDTO = &MoveDTO{
				PieceID: autoMove.PieceID,
				FromCol: autoMove.FromPos.Col,
				FromRow: autoMove.FromPos.Row,
				ToCol:   autoMove.ToPos.Col,
				ToRow:   autoMove.ToPos.Row,
			}

			var retaliatorID string
			if rm.Game.Turn == "white" { // Turn flipped after applyMove
				retaliatorID = rm.BlackPlayer.UserID
			} else {
				retaliatorID = rm.WhitePlayer.UserID
			}

			retaliationTime := time.Now()
			rm.lastMoveTime = retaliationTime
			rm.MovesBuffer = append(rm.MovesBuffer, domain.MoveRecord{
				PlyIndex:  rm.Game.MoveCount,
				PlayerID:  retaliatorID,
				PieceID:   autoMove.PieceID,
				FromCol:   autoMove.FromPos.Col,
				FromRow:   autoMove.FromPos.Row,
				ToCol:     autoMove.ToPos.Col,
				ToRow:     autoMove.ToPos.Row,
				TimeMs:    400,
				CreatedAt: retaliationTime,
			})

			retaliationStatus := rm.Game.GetStatus()
			if retaliationStatus != "ongoing" {
				rm.broadcastStateLocked()
				rm.finishGameLocked(retaliationStatus, domain.ReasonNormal)
			} else {
				rm.startTimeoutTimerLocked()
				rm.broadcastStateLocked()
			}
		}(r, *retaliationMove)
		return nil
	}

	// 9. Sıradaki oyuncu için timer'ı başlat, ardından tahtanın yeni halini bildir
	r.startTimeoutTimerLocked()
	r.broadcastStateLocked()

	return nil
}

// ─── Resign ───────────────────────────────────────────────────────────

func (r *Room) Resign(playerID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.isFinished {
		return ErrGameFinished
	}

	if playerID != r.WhitePlayer.UserID && playerID != r.BlackPlayer.UserID {
		return ErrNotInMatch
	}

	var winnerID *string
	var winnerTeam string
	var result string

	if playerID == r.WhitePlayer.UserID {
		// White resigned -> Black wins
		winnerID = &r.BlackPlayer.UserID
		winnerTeam = "black"
		result = string(domain.ResultBlackWins)
	} else {
		// Black resigned -> White wins
		winnerID = &r.WhitePlayer.UserID
		winnerTeam = "white"
		result = string(domain.ResultWhiteWins)
	}

	log.Printf("[Room %s] Player %s resigned. Winner: %s (%s)", r.ID, playerID, winnerTeam, *winnerID)
	r.finishWithExplicitWinnerLocked(winnerID, winnerTeam, result, domain.ReasonResigned)
	return nil
}

// ─── Disconnect & Reconnect ──────────────────────────────────────────

func (r *Room) HandleDisconnect(playerID string) {
	r.mu.Lock()

	if r.isFinished {
		r.mu.Unlock()
		return
	}

	if r.Status == "waiting" {
		r.mu.Unlock()
		r.hub.CloseRoom(r.ID)
		return
	}

	// Active match: Give a grace period for reconnection (45s or remaining time if lower)
	if r.disconnectTimer != nil {
		r.disconnectTimer.Stop()
	}
	r.disconnectPlayerID = playerID

	graceDuration := 45 * time.Second
	if r.TimeControl > 0 {
		var remMs int64
		if r.WhitePlayer != nil && playerID == r.WhitePlayer.UserID {
			remMs = r.WhiteRemainingMs
		} else if r.BlackPlayer != nil && playerID == r.BlackPlayer.UserID {
			remMs = r.BlackRemainingMs
		}
		if remMs > 0 && time.Duration(remMs)*time.Millisecond < graceDuration {
			graceDuration = time.Duration(remMs) * time.Millisecond
		}
	}

	log.Printf("[Room %s] Player %s disconnected. Grace period %v started.", r.ID, playerID, graceDuration)

	var opp *Client
	if r.WhitePlayer != nil && playerID == r.WhitePlayer.UserID {
		opp = r.BlackPlayer
	} else if r.BlackPlayer != nil && playerID == r.BlackPlayer.UserID {
		opp = r.WhitePlayer
	}
	if opp != nil {
		opp.SendJSON("opponent_disconnected", map[string]any{
			"player_id":     playerID,
			"grace_seconds": int(graceDuration.Seconds()),
		})
	}

	r.disconnectTimer = time.AfterFunc(graceDuration, func() {
		r.mu.Lock()
		defer r.mu.Unlock()

		if r.isFinished || r.disconnectPlayerID != playerID {
			return
		}

		log.Printf("[Room %s] Disconnect grace period expired for %s. Forfeiting.", r.ID, playerID)
		var winnerID *string
		var winnerTeam string
		var result string

		if r.WhitePlayer != nil && playerID == r.WhitePlayer.UserID {
			if r.BlackPlayer != nil {
				winnerID = &r.BlackPlayer.UserID
			}
			winnerTeam = "black"
			result = string(domain.ResultBlackWins)
		} else if r.BlackPlayer != nil && playerID == r.BlackPlayer.UserID {
			if r.WhitePlayer != nil {
				winnerID = &r.WhitePlayer.UserID
			}
			winnerTeam = "white"
			result = string(domain.ResultWhiteWins)
		} else {
			return
		}

		r.finishWithExplicitWinnerLocked(winnerID, winnerTeam, result, domain.ReasonDisconnected)
	})
	r.mu.Unlock()
}

func (r *Room) HandleReconnect(client *Client) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.isFinished || r.Status != "in_game" {
		return false
	}

	var team string
	var opp *Client
	if r.WhitePlayer != nil && r.WhitePlayer.UserID == client.UserID {
		team = "white"
		r.WhitePlayer = client
		opp = r.BlackPlayer
	} else if r.BlackPlayer != nil && r.BlackPlayer.UserID == client.UserID {
		team = "black"
		r.BlackPlayer = client
		opp = r.WhitePlayer
	} else {
		return false
	}

	client.CurrentMatchID = r.ID

	if r.disconnectPlayerID == client.UserID {
		if r.disconnectTimer != nil {
			r.disconnectTimer.Stop()
			r.disconnectTimer = nil
		}
		r.disconnectPlayerID = ""
	}

	log.Printf("[Room %s] Player %s reconnected as %s", r.ID, client.Username, team)

	oppID := ""
	oppName := ""
	oppRating := 1200
	oppAvatar := 0
	if opp != nil {
		oppID = opp.UserID
		oppName = opp.Username
		oppRating = opp.Rating
		oppAvatar = opp.AvatarIndex
	}

	client.SendJSON(TypeMatchFound, MatchFoundDTO{
		MatchID:             r.ID,
		YourTeam:            team,
		OpponentID:          oppID,
		OpponentName:        oppName,
		OpponentRating:      oppRating,
		OpponentAvatarIndex: oppAvatar,
		TimeControl:         r.TimeControl,
		IsReconnect:         true,
	})

	// Send authoritative current game state
	r.sendStateToClientLocked(client)

	if opp != nil {
		opp.SendJSON("opponent_reconnected", map[string]any{
			"player_id": client.UserID,
		})
	}

	return true
}

// ─── Finish Game ──────────────────────────────────────────────────────

func (r *Room) finishGameLocked(status, reason string) {
	var winnerID *string
	var winnerTeam string

	if status == "white_wins" {
		winnerID = &r.WhitePlayer.UserID
		winnerTeam = "white"
	} else if status == "black_wins" {
		winnerID = &r.BlackPlayer.UserID
		winnerTeam = "black"
	} else {
		winnerTeam = "draw"
	}

	r.finishWithExplicitWinnerLocked(winnerID, winnerTeam, status, reason)
}

func (r *Room) finishWithExplicitWinnerLocked(winnerID *string, winnerTeam, result, reason string) {
	if r.isFinished {
		return
	}
	r.isFinished = true
	r.Status = "finished"
	now := time.Now()

	// Stop chess clock timer
	if r.timeoutTimer != nil {
		r.timeoutTimer.Stop()
		r.timeoutTimer = nil
	}

	// Stop disconnect grace timer
	if r.disconnectTimer != nil {
		r.disconnectTimer.Stop()
		r.disconnectTimer = nil
	}
	r.disconnectPlayerID = ""

	// Free players from active match lock so they can queue/join/invite without waiting 5 min
	if r.WhitePlayer != nil {
		r.WhitePlayer.mu.Lock()
		r.WhitePlayer.LastFinishedMatchID = r.ID
		if r.WhitePlayer.CurrentMatchID == r.ID {
			r.WhitePlayer.CurrentMatchID = ""
		}
		r.WhitePlayer.mu.Unlock()
	}
	if r.BlackPlayer != nil {
		r.BlackPlayer.mu.Lock()
		r.BlackPlayer.LastFinishedMatchID = r.ID
		if r.BlackPlayer.CurrentMatchID == r.ID {
			r.BlackPlayer.CurrentMatchID = ""
		}
		r.BlackPlayer.mu.Unlock()
	}

	// Final time deduction
	if r.TimeControl > 0 {
		r.deductCurrentPlayerTimeLocked()
	}

	// 1. Veritabanına tek bir transaction ile toplu kayıt (Deferred Persistence)
	totalMoves := len(r.MovesBuffer)
	matchRecord := &domain.Match{
		ID:            r.ID,
		WhitePlayerID: r.WhitePlayer.UserID,
		BlackPlayerID: r.BlackPlayer.UserID,
		WinnerID:      winnerID,
		Result:        domain.MatchResult(result),
		Reason:        reason,
		TotalMoves:    totalMoves,
		StartedAt:     r.StartedAt,
		EndedAt:       &now,
		Moves:         r.MovesBuffer, // Tüm hamle listesi tek seferde aktarılır
	}

	var ratingChanges map[string]interface{}
	if r.matchService != nil {
		if totalMoves > 1 {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			var err error
			ratingChanges, err = r.matchService.SaveFinishedMatch(ctx, matchRecord)
			cancel()
			if err != nil {
				log.Printf("[Room %s] Error saving finished match to database: %v", r.ID, err)
			} else {
				log.Printf("[Room %s] Match successfully saved with %d moves", r.ID, len(matchRecord.Moves))
			}
		} else {
			log.Printf("[Room %s] Match finished with %d moves (<= 1); skipped recording to match history", r.ID, totalMoves)
		}
	}

	// In-memory oyuncu rating'lerini güncelle
	if ratingChanges != nil {
		if whiteChange, ok := ratingChanges[r.WhitePlayer.UserID].(map[string]interface{}); ok {
			if newR, ok := whiteChange["new"].(int); ok {
				r.WhitePlayer.Rating = newR
			}
		}
		if blackChange, ok := ratingChanges[r.BlackPlayer.UserID].(map[string]interface{}); ok {
			if newR, ok := blackChange["new"].(int); ok {
				r.BlackPlayer.Rating = newR
			}
		}
	}

	gameOverData := GameOverDTO{
		MatchID:       r.ID,
		WinnerID:      winnerID,
		WinnerTeam:    winnerTeam,
		Result:        result,
		Reason:        reason,
		RatingChanges: ratingChanges,
	}

	// 2. Oyunculara oyun bittiği haber verilir (DB işlemi tamamlandıktan sonra)
	r.WhitePlayer.SendJSON(TypeGameOver, gameOverData)
	r.BlackPlayer.SendJSON(TypeGameOver, gameOverData)
	for _, spec := range r.Spectators {
		spec.SendJSON(TypeGameOver, gameOverData)
	}

	// 3. Hub üzerinden odayı belirli bir süre sonra temizle (oyuncuların inceleme, sohbet ve rövanş yapabilmesi için)
	go func() {
		time.Sleep(5 * time.Minute)
		r.hub.CloseRoom(r.ID)
	}()
}

// ─── Broadcast State ──────────────────────────────────────────────────

func (r *Room) sendStateToClientLocked(client *Client) {
	if client == nil {
		return
	}
	legalGameMoves := r.Game.GetLegalMoves()
	legalDTOs := make([]MoveDTO, 0, len(legalGameMoves))
	for _, m := range legalGameMoves {
		legalDTOs = append(legalDTOs, FromGameMove(m))
	}

	// Calculate remaining times with current elapsed
	whiteRemaining := r.WhiteRemainingMs
	blackRemaining := r.BlackRemainingMs

	if r.TimeControl > 0 {
		elapsed := time.Since(r.turnStartedAt).Milliseconds()
		if r.Game.Turn == "white" {
			whiteRemaining -= elapsed
			if whiteRemaining < 0 {
				whiteRemaining = 0
			}
		} else {
			blackRemaining -= elapsed
			if blackRemaining < 0 {
				blackRemaining = 0
			}
		}
	}

	stateDTO := GameStateDTO{
		MatchID:          r.ID,
		Turn:             r.Game.Turn,
		Status:           r.Game.GetStatus(),
		MoveCount:        r.Game.MoveCount,
		KingEatenBy:      r.Game.KingEatenBy,
		Positions:        r.Game.Positions,
		LegalMoves:       legalDTOs,
		Display:          r.Game.Display("simple"),
		WhiteRemainingMs: whiteRemaining,
		BlackRemainingMs: blackRemaining,
		TimeControl:      r.TimeControl,
		LastMove:         r.LastMoveDTO,
	}

	client.SendJSON(TypeGameState, stateDTO)
}

func (r *Room) broadcastStateLocked() {
	r.sendStateToClientLocked(r.WhitePlayer)
	r.sendStateToClientLocked(r.BlackPlayer)
	for _, spec := range r.Spectators {
		r.sendStateToClientLocked(spec)
	}
}

// ─── Chat ─────────────────────────────────────────────────────────────

func (r *Room) BroadcastChat(senderID, senderName, content string) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if r.Status == "waiting" {
		return
	}

	chatDTO := ChatBroadcastDTO{
		MatchID:   r.ID,
		SenderID:  senderID,
		Username:  senderName,
		Content:   content,
		CreatedAt: time.Now(),
	}

	r.WhitePlayer.SendJSON(TypeChatBroadcast, chatDTO)
	r.BlackPlayer.SendJSON(TypeChatBroadcast, chatDTO)
	for _, spec := range r.Spectators {
		spec.SendJSON(TypeChatBroadcast, chatDTO)
	}
}
