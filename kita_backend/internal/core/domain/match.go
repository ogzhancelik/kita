package domain

import "time"

type MatchResult string

const (
	ResultOngoing   MatchResult = "ongoing"
	ResultWhiteWins MatchResult = "white_wins"
	ResultBlackWins MatchResult = "black_wins"
	ResultDraw      MatchResult = "draw"
	ResultResigned  MatchResult = "resigned"
	ResultAbandoned MatchResult = "abandoned"

	ReasonNormal       = "reason_normal"
	ReasonResigned     = "reason_resigned"
	ReasonDisconnected = "reason_disconnected"
)

type Match struct {
	ID            string       `json:"id" gorm:"primaryKey;type:uuid"`
	WhitePlayerID string       `json:"white_player_id" gorm:"type:uuid;index;not null"`
	BlackPlayerID string       `json:"black_player_id" gorm:"type:uuid;index;not null"`
	WhitePlayer   *User        `json:"white_player,omitempty" gorm:"foreignKey:WhitePlayerID;references:ID"`
	BlackPlayer   *User        `json:"black_player,omitempty" gorm:"foreignKey:BlackPlayerID;references:ID"`
	WinnerID      *string      `json:"winner_id" gorm:"type:uuid;index"`
	Result        MatchResult  `json:"result" gorm:"type:varchar(32);not null"`
	TotalMoves    int          `json:"total_moves" gorm:"default:0"`
	StartedAt     time.Time    `json:"started_at"`
	EndedAt       *time.Time   `json:"ended_at"`
	Moves         []MoveRecord `json:"moves" gorm:"type:jsonb;serializer:json"`
}

type MoveRecord struct {
	PlyIndex int       `json:"ply"`
	PlayerID string    `json:"player_id"`
	PieceID  string    `json:"piece"`
	FromCol  int       `json:"from_col"`
	FromRow  int       `json:"from_row"`
	ToCol    int       `json:"to_col"`
	ToRow    int       `json:"to_row"`
	TimeMs   int       `json:"time_ms,omitempty"`
	CreatedAt time.Time `json:"created_at,omitempty"`
}
