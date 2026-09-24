package domain

import (
	"time"
)

const (
	NotificationTypeFriendRequest         = "friend_request"
	NotificationTypeFriendRequestAccepted = "friend_request_accepted"
	NotificationTypeFriendRequestDeclined = "friend_request_declined"
	NotificationTypeChallenge             = "challenge"
	NotificationTypeChallengeDeclined     = "challenge_declined"
	NotificationTypeRematchDeclined       = "rematch_declined"
	NotificationTypeInfo                  = "info"
)

const (
	NotificationStatusPending  = "pending"
	NotificationStatusUnread   = "unread"
	NotificationStatusRead     = "read"
	NotificationStatusAccepted = "accepted"
	NotificationStatusDeclined = "declined"
	NotificationStatusIgnored  = "ignored"
)

type Notification struct {
	ID        string    `json:"id" gorm:"primaryKey;type:varchar(64)"`
	UserID    string    `json:"user_id" gorm:"index;type:varchar(64);not null"`
	ActorID   string    `json:"actor_id" gorm:"index;type:varchar(64)"`
	ActorName string    `json:"actor_name" gorm:"type:varchar(64)"`
	Type      string    `json:"type" gorm:"index;type:varchar(32);not null"`
	Status    string    `json:"status" gorm:"index;type:varchar(32);default:'pending'"`
	Title     string    `json:"title" gorm:"type:varchar(255)"`
	Subtitle  string    `json:"subtitle" gorm:"type:text"`
	Payload   string    `json:"payload" gorm:"type:text"` // JSON-encoded extra data
	CreatedAt time.Time `json:"created_at" gorm:"index"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpdateNotificationStatusDTO struct {
	Status string `json:"status" binding:"required"`
}
