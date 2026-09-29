package domain

import "time"

// DirectMessage represents a DM between two friends.
// conversation_id is deterministically derived from sorted (user1_id, user2_id)
// so that both participants always reference the same conversation row.
type DirectMessage struct {
	ID             uint      `json:"id"              gorm:"primaryKey;autoIncrement"`
	ConversationID string    `json:"conversation_id" gorm:"type:varchar(128);index;not null"`
	SenderID       string    `json:"sender_id"       gorm:"type:uuid;not null;index"`
	RecipientID    string    `json:"recipient_id"    gorm:"type:uuid;not null;index"`
	Content        string    `json:"content"         gorm:"type:text;not null"`
	CreatedAt      time.Time `json:"created_at"`
}
