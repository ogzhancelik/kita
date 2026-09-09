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
	Moves         []MatchMove  `json:"moves,omitempty" gorm:"foreignKey:MatchID;references:ID"`
}

type MatchMove struct {
	ID        uint      `json:"id" gorm:"primaryKey;autoIncrement"`
	MatchID   string    `json:"match_id" gorm:"type:uuid;index;not null"`
	PlyIndex  int       `json:"ply_index" gorm:"not null"`
	PlayerID  string    `json:"player_id" gorm:"type:uuid;not null"`
	PieceID   string    `json:"piece_id" gorm:"type:varchar(10);not null"`
	FromCol   int       `json:"from_col" gorm:"not null"`
	FromRow   int       `json:"from_row" gorm:"not null"`
	ToCol     int       `json:"to_col" gorm:"not null"`
	ToRow     int       `json:"to_row" gorm:"not null"`
	CreatedAt time.Time `json:"created_at"`
}
