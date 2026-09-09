package game

import (
	"encoding/json"
	"time"

	"github.com/oguzhancelik/kita/internal/core/errors"
	kitagame "github.com/oguzhancelik/kita/pkg/game"
)

// WebSocket Message Types
const (
	// Client -> Server
	TypeJoinQueue   = "join_queue"
	TypeLeaveQueue  = "leave_queue"
	TypeMakeMove    = "make_move"
	TypeChatMessage = "chat_message"
	TypeResign      = "resign"
	TypeCreateRoom  = "create_room"
	TypeJoinRoom    = "join_room"

	// Server -> Client
	TypeConnected     = "connected"
	TypeQueueJoined   = "queue_joined"
	TypeMatchFound    = "match_found"
	TypeRoomCreated   = "room_created"
	TypeRoomJoined    = "room_joined"
	TypeGameState     = "game_state"
	TypeOpponentMoved = "opponent_moved"
	TypeGameOver      = "game_over"
	TypeChatBroadcast = "chat_broadcast"
	TypeError         = "error"
)

type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type MoveDTO struct {
	PieceID string `json:"piece_id"`
	FromCol int    `json:"from_col"`
	FromRow int    `json:"from_row"`
	ToCol   int    `json:"to_col"`
	ToRow   int    `json:"to_row"`
}

func (m MoveDTO) ToGameMove() kitagame.Move {
	return kitagame.Move{
		PieceID: m.PieceID,
		FromPos: kitagame.Pos{Col: m.FromCol, Row: m.FromRow},
		ToPos:   kitagame.Pos{Col: m.ToCol, Row: m.ToRow},
	}
}

func FromGameMove(m kitagame.Move) MoveDTO {
	return MoveDTO{
		PieceID: m.PieceID,
		FromCol: m.FromPos.Col,
		FromRow: m.FromPos.Row,
		ToCol:   m.ToPos.Col,
		ToRow:   m.ToPos.Row,
	}
}

type PiecePositionDTO struct {
	PieceID string `json:"piece_id"`
	Col     int    `json:"col"`
	Row     int    `json:"row"`
	Status  string `json:"status"` // "active" or "captured"
}

type GameStateDTO struct {
	MatchID     string                      `json:"match_id"`
	Turn        string                      `json:"turn"`
	Status      string                      `json:"status"`
	MoveCount   int                         `json:"move_count"`
	KingEatenBy string                      `json:"king_eaten_by,omitempty"`
	Positions   map[string]*kitagame.Pos    `json:"positions"`
	LegalMoves  []MoveDTO                   `json:"legal_moves"`
	Display     string                      `json:"display_board,omitempty"`
}

type MatchFoundDTO struct {
	MatchID     string `json:"match_id"`
	YourTeam    string `json:"your_team"` // "white" or "black"
	OpponentID  string `json:"opponent_id"`
	OpponentName string `json:"opponent_name"`
	OpponentRating int  `json:"opponent_rating"`
}

type GameOverDTO struct {
	MatchID  string  `json:"match_id"`
	WinnerID *string `json:"winner_id"`
	Result   string  `json:"result"`
	Reason   string  `json:"reason"`
}

type ChatBroadcastDTO struct {
	MatchID   string    `json:"match_id"`
	SenderID  string    `json:"sender_id"`
	Username  string    `json:"username"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type ErrorDTO struct {
	Code    errors.ErrorCode `json:"code"`
	Message string           `json:"message"`
}

type CreateRoomDTO struct {
	IsPrivate bool `json:"is_private"`
}

type JoinRoomDTO struct {
	RoomCode string `json:"room_code"`
}

type RoomCreatedDTO struct {
	RoomCode string `json:"room_code"`
}
