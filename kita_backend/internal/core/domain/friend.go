package domain

import (
	"time"
)

const (
	FriendshipStatusPending  = "pending"
	FriendshipStatusAccepted = "accepted"
	FriendshipStatusRejected = "rejected"
)

type Friendship struct {
	ID          string    `json:"id" gorm:"primaryKey;type:uuid"`
	RequesterID string    `json:"requester_id" gorm:"index;not null"`
	AddresseeID string    `json:"addressee_id" gorm:"index;not null"`
	Status      string    `json:"status" gorm:"default:'pending';index"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	Requester *User `json:"requester,omitempty" gorm:"foreignKey:RequesterID"`
	Addressee *User `json:"addressee,omitempty" gorm:"foreignKey:AddresseeID"`
}

type FriendItem struct {
	FriendshipID string    `json:"friendship_id"`
	UserID       string    `json:"user_id"`
	Username     string    `json:"username"`
	Rating       int       `json:"rating"`
	Status       string    `json:"status"`
	Direction    string    `json:"direction"` // "friend", "incoming", "outgoing"
	IsOnline     bool      `json:"is_online"`
	CreatedAt    time.Time `json:"created_at"`
}

type SendFriendRequestDTO struct {
	TargetUsername string `json:"target_username" binding:"required"`
}
