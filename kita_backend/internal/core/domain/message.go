package domain

import "time"

type Message struct {
	ID        uint      `json:"id" gorm:"primaryKey;autoIncrement"`
	MatchID   string    `json:"match_id" gorm:"type:uuid;index;not null"`
	SenderID  string    `json:"sender_id" gorm:"type:uuid;not null"`
	Sender    *User     `json:"sender,omitempty" gorm:"foreignKey:SenderID;references:ID"`
	Content   string    `json:"content" gorm:"type:text;not null"`
	CreatedAt time.Time `json:"created_at"`
}
