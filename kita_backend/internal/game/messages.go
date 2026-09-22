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

	// Client -> Server (New)
	TypeGetOnlineCount  = "get_online_count"
	TypeListRooms       = "list_rooms"
	TypeRematchRequest  = "rematch_request"
	TypeRematchAccept   = "rematch_accept"
	TypeRematchDecline  = "rematch_decline"
	TypeInviteToMatch   = "invite_to_match"
	TypeAcceptInvite    = "accept_invitation"
	TypeDeclineInvite   = "decline_invitation"
	TypeLeaveRoom       = "leave_room"

	// Server -> Client
	TypeConnected        = "connected"
	TypeQueueJoined      = "queue_joined"
	TypeMatchFound       = "match_found"
	TypeRoomCreated      = "room_created"
	TypeRoomJoined       = "room_joined"
	TypeRoomLeft         = "room_left"
	TypeGameState        = "game_state"
	TypeOpponentMoved    = "opponent_moved"
	TypeGameOver         = "game_over"
	TypeChatBroadcast    = "chat_broadcast"
	TypeError            = "error"

	// Server -> Client (New)
	TypeOnlineCount       = "online_count"
	TypeRoomsList         = "rooms_list"
	TypeRematchOffered    = "rematch_offered"
	TypeRematchAccepted   = "rematch_accepted"
	TypeRematchDeclined   = "rematch_declined"
	TypeMatchInvitation   = "match_invitation"
	TypeInvitationDeclined = "invitation_declined"
	TypeTimeoutLoss       = "timeout_loss"
)

// Time control presets (in milliseconds)
const (
	TimeControl1Min    = 60_000
	TimeControl3Min    = 180_000
	TimeControl5Min    = 300_000
	TimeControlNone    = 0 // Unlimited
)

type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// ─── Move DTO ─────────────────────────────────────────────────────────

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

// ─── Game State DTO ───────────────────────────────────────────────────

type GameStateDTO struct {
	MatchID          string                   `json:"match_id"`
	Turn             string                   `json:"turn"`
	Status           string                   `json:"status"`
	MoveCount        int                      `json:"move_count"`
	KingEatenBy      string                   `json:"king_eaten_by,omitempty"`
	Positions        map[string]*kitagame.Pos `json:"positions"`
	LegalMoves       []MoveDTO                `json:"legal_moves"`
	Display          string                   `json:"display_board,omitempty"`
	// Chess clock fields
	WhiteRemainingMs int64                    `json:"white_remaining_ms"`
	BlackRemainingMs int64                    `json:"black_remaining_ms"`
	TimeControl      int64                    `json:"time_control"`
	// Last move for highlighting
	LastMove         *MoveDTO                 `json:"last_move,omitempty"`
}

// ─── Match Found DTO ──────────────────────────────────────────────────

type MatchFoundDTO struct {
	MatchID        string `json:"match_id"`
	YourTeam       string `json:"your_team"` // "white" or "black"
	OpponentID     string `json:"opponent_id"`
	OpponentName   string `json:"opponent_name"`
	OpponentRating int    `json:"opponent_rating"`
	TimeControl    int64  `json:"time_control"`
}

// ─── Game Over DTO ────────────────────────────────────────────────────

type GameOverDTO struct {
	MatchID       string                 `json:"match_id"`
	WinnerID      *string                `json:"winner_id"`
	WinnerTeam    string                 `json:"winner_team"` // "white", "black", or "draw"
	Result        string                 `json:"result"`
	Reason        string                 `json:"reason"`
	RatingChanges map[string]interface{} `json:"rating_changes,omitempty"`
}

// ─── Chat DTO ─────────────────────────────────────────────────────────

type ChatBroadcastDTO struct {
	MatchID   string    `json:"match_id"`
	SenderID  string    `json:"sender_id"`
	Username  string    `json:"username"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

// ─── Error DTO ────────────────────────────────────────────────────────

type ErrorDTO struct {
	Code    errors.ErrorCode `json:"code"`
	Message string           `json:"message"`
}

// ─── Room Management DTOs ─────────────────────────────────────────────

type CreateRoomDTO struct {
	IsPrivate   bool  `json:"is_private"`
	TimeControl int64 `json:"time_control"` // ms: 60000, 180000, 300000, 0=unlimited
}

type JoinRoomDTO struct {
	RoomCode string `json:"room_code"`
}

type RoomCreatedDTO struct {
	RoomCode    string `json:"room_code"`
	TimeControl int64  `json:"time_control"`
}

// ─── Online Count DTO ─────────────────────────────────────────────────

type OnlineCountDTO struct {
	Count     int `json:"count"`
	InQueue   int `json:"in_queue"`
}

// ─── Room Listing DTOs ────────────────────────────────────────────────

type ListRoomsDTO struct {
	Page  int `json:"page"`
	Limit int `json:"limit"`
}

type RoomInfoDTO struct {
	RoomCode     string `json:"room_code"`
	HostName     string `json:"host_name"`
	HostRating   int    `json:"host_rating"`
	TimeControl  int64  `json:"time_control"`
	IsPrivate    bool   `json:"is_private"`
}

type RoomsListDTO struct {
	Rooms      []RoomInfoDTO `json:"rooms"`
	Page       int           `json:"page"`
	TotalPages int           `json:"total_pages"`
	Total      int           `json:"total"`
}

// ─── Rematch DTOs ─────────────────────────────────────────────────────

type RematchRequestDTO struct {
	MatchID string `json:"match_id"`
}

type RematchOfferedDTO struct {
	MatchID       string `json:"match_id"`
	RequesterID   string `json:"requester_id"`
	RequesterName string `json:"requester_name"`
	TimeControl   int64  `json:"time_control"`
}

// ─── Friend Invite DTOs ───────────────────────────────────────────────

type InviteToMatchDTO struct {
	FriendID    string `json:"friend_id"`
	TimeControl int64  `json:"time_control"`
}

type MatchInvitationDTO struct {
	InviteID      string `json:"invite_id"`
	InviterID     string `json:"inviter_id"`
	InviterName   string `json:"inviter_name"`
	InviterRating int    `json:"inviter_rating"`
	TimeControl   int64  `json:"time_control"`
}

type AcceptInviteDTO struct {
	InviteID string `json:"invite_id"`
}
