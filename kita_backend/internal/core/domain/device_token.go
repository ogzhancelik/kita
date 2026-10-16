package domain

import "time"

// DeviceToken represents a user's registered mobile or web push notification token.
type DeviceToken struct {
	ID        string    `json:"id" gorm:"primaryKey;type:varchar(128)"`
	UserID    string    `json:"user_id" gorm:"index;type:varchar(64);not null"`
	Token     string    `json:"token" gorm:"uniqueIndex;type:text;not null"`
	Platform  string    `json:"platform" gorm:"type:varchar(20);not null"` // 'android', 'ios', 'web'
	CreatedAt time.Time `json:"created_at" gorm:"index"`
	UpdatedAt time.Time `json:"updated_at"`
}

// RegisterDeviceTokenDTO defines payload for registering a push token.
type RegisterDeviceTokenDTO struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required"`
}

// RemoveDeviceTokenDTO defines payload for unregistering a push token.
type RemoveDeviceTokenDTO struct {
	Token string `json:"token" binding:"required"`
}
