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

	// Bellekte biriken tüm hamleler (Deferred Persistence Buffer)
	MovesBuffer  []domain.MatchMove

	StartedAt    time.Time
	mu           sync.RWMutex
	matchService ports.MatchService
	isFinished   bool
	hub          *Hub
}

func NewRoom(id string, white, black *Client, matchService ports.MatchService, hub *Hub) *Room {
	r := &Room{
		ID:           id,
		Status:       "in_game",
		WhitePlayer:  white,
		BlackPlayer:  black,
		Spectators:   make(map[string]*Client),
		Game:         kitagame.NewGame(),
		MovesBuffer:  make([]domain.MatchMove, 0, 64),
		StartedAt:    time.Now(),
		matchService: matchService,
		hub:          hub,
	}

	white.CurrentMatchID = id
	black.CurrentMatchID = id

	return r
}

func NewCustomRoom(id, roomCode string, host *Client, isPrivate bool, matchService ports.MatchService, hub *Hub) *Room {
	r := &Room{
		ID:           id,
		RoomCode:     roomCode,
		IsPrivate:    isPrivate,
		Host:         host,
		Status:       "waiting",
		Spectators:   make(map[string]*Client),
		Game:         kitagame.NewGame(),
		MovesBuffer:  make([]domain.MatchMove, 0, 64),
		StartedAt:    time.Now(),
		matchService: matchService,
		hub:          hub,
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
		MatchID:        r.ID,
		YourTeam:       "white",
		OpponentID:     r.BlackPlayer.UserID,
		OpponentName:   r.BlackPlayer.Username,
		OpponentRating: r.BlackPlayer.Rating,
	})

	r.BlackPlayer.SendJSON(TypeMatchFound, MatchFoundDTO{
		MatchID:        r.ID,
		YourTeam:       "black",
		OpponentID:     r.WhitePlayer.UserID,
		OpponentName:   r.WhitePlayer.Username,
		OpponentRating: r.WhitePlayer.Rating,
	})

	// 2. Tahtanın ilk hali gönderilir
	r.broadcastStateLocked()
}

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

	// 3. Hamleyi oyuna uygula (Mevcut engine metodu: pure transition)
	r.Game = r.Game.ApplyMove(candidateMove)

	// 4. Hamleyi veritabanına değil, bellekteki buffer'a ekle
	matchMove := domain.MatchMove{
		MatchID:   r.ID,
		PlyIndex:  r.Game.MoveCount,
		PlayerID:  playerID,
		PieceID:   candidateMove.PieceID,
		FromCol:   candidateMove.FromPos.Col,
		FromRow:   candidateMove.FromPos.Row,
		ToCol:     candidateMove.ToPos.Col,
		ToRow:     candidateMove.ToPos.Row,
		CreatedAt: time.Now(),
	}
	r.MovesBuffer = append(r.MovesBuffer, matchMove)

	// 5. Durumu oyunculara bildir
	r.broadcastStateLocked()

	// 6. Oyun bitti mi kontrol et
	status := r.Game.GetStatus()
	if status != "ongoing" {
		r.finishGameLocked(status, domain.ReasonNormal)
	}

	return nil
}

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
	result := domain.ResultResigned

	if playerID == r.WhitePlayer.UserID {
		winnerID = &r.BlackPlayer.UserID
	} else {
		winnerID = &r.WhitePlayer.UserID
	}

	r.finishWithExplicitWinnerLocked(winnerID, string(result), domain.ReasonResigned)
	return nil
}

func (r *Room) HandleDisconnect(playerID string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.isFinished {
		return
	}

	if r.Status == "waiting" {
		r.hub.CloseRoom(r.ID)
		return
	}

	var winnerID *string
	if playerID == r.WhitePlayer.UserID {
		winnerID = &r.BlackPlayer.UserID
	} else if playerID == r.BlackPlayer.UserID {
		winnerID = &r.WhitePlayer.UserID
	} else {
		return
	}

	r.finishWithExplicitWinnerLocked(winnerID, string(domain.ResultAbandoned), domain.ReasonDisconnected)
}

func (r *Room) finishGameLocked(status, reason string) {
	var winnerID *string
	if status == "white_wins" {
		winnerID = &r.WhitePlayer.UserID
	} else if status == "black_wins" {
		winnerID = &r.BlackPlayer.UserID
	}

	r.finishWithExplicitWinnerLocked(winnerID, status, reason)
}

func (r *Room) finishWithExplicitWinnerLocked(winnerID *string, result, reason string) {
	if r.isFinished {
		return
	}
	r.isFinished = true
	now := time.Now()

	gameOverData := GameOverDTO{
		MatchID:  r.ID,
		WinnerID: winnerID,
		Result:   result,
		Reason:   reason,
	}

	// 1. Oyunculara oyun bittiği haber verilir
	r.WhitePlayer.SendJSON(TypeGameOver, gameOverData)
	r.BlackPlayer.SendJSON(TypeGameOver, gameOverData)
	for _, spec := range r.Spectators {
		spec.SendJSON(TypeGameOver, gameOverData)
	}

	// 2. Veritabanına tek bir transaction ile toplu kayıt (Deferred Persistence)
	matchRecord := &domain.Match{
		ID:            r.ID,
		WhitePlayerID: r.WhitePlayer.UserID,
		BlackPlayerID: r.BlackPlayer.UserID,
		WinnerID:      winnerID,
		Result:        domain.MatchResult(result),
		TotalMoves:    len(r.MovesBuffer),
		StartedAt:     r.StartedAt,
		EndedAt:       &now,
		Moves:         r.MovesBuffer, // Tüm hamle listesi tek seferde aktarılır
	}

	go func(m *domain.Match) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := r.matchService.SaveFinishedMatch(ctx, m); err != nil {
			log.Printf("[Room %s] Error saving finished match to database: %v", r.ID, err)
		} else {
			log.Printf("[Room %s] Match successfully saved with %d moves", r.ID, len(m.Moves))
		}
	}(matchRecord)

	// 3. Hub üzerinden odayı temizle
	go func() {
		r.hub.CloseRoom(r.ID)
	}()
}

func (r *Room) broadcastStateLocked() {
	legalGameMoves := r.Game.GetLegalMoves()
	legalDTOs := make([]MoveDTO, 0, len(legalGameMoves))
	for _, m := range legalGameMoves {
		legalDTOs = append(legalDTOs, FromGameMove(m))
	}

	stateDTO := GameStateDTO{
		MatchID:     r.ID,
		Turn:        r.Game.Turn,
		Status:      r.Game.GetStatus(),
		MoveCount:   r.Game.MoveCount,
		KingEatenBy: r.Game.KingEatenBy,
		Positions:   r.Game.Positions,
		LegalMoves:  legalDTOs,
		Display:     r.Game.Display("simple"),
	}

	r.WhitePlayer.SendJSON(TypeGameState, stateDTO)
	r.BlackPlayer.SendJSON(TypeGameState, stateDTO)
	for _, spec := range r.Spectators {
		spec.SendJSON(TypeGameState, stateDTO)
	}
}

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
