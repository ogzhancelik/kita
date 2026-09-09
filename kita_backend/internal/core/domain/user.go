package domain

import "time"

type User struct {
	ID           string    `json:"id" gorm:"primaryKey;type:uuid"`
	Username     string    `json:"username" gorm:"uniqueIndex;not null"`
	Email        string    `json:"email" gorm:"uniqueIndex;not null"`
	PasswordHash string    `json:"-" gorm:"not null"`
	Rating       int       `json:"rating" gorm:"default:1200;index"`
	Wins         int       `json:"wins" gorm:"default:0"`
	Losses       int       `json:"losses" gorm:"default:0"`
	Draws        int       `json:"draws" gorm:"default:0"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type UserProfile struct {
	ID        string    `json:"id"`
	Username  string    `json:"username"`
	Rating    int       `json:"rating"`
	Wins      int       `json:"wins"`
	Losses    int       `json:"losses"`
	Draws     int       `json:"draws"`
	Total     int       `json:"total_games"`
	WinRate   float64   `json:"win_rate"`
	CreatedAt time.Time `json:"created_at"`
}

func (u *User) ToProfile() UserProfile {
	total := u.Wins + u.Losses + u.Draws
	winRate := 0.0
	if total > 0 {
		winRate = float64(u.Wins) / float64(total) * 100
	}
	return UserProfile{
		ID:        u.ID,
		Username:  u.Username,
		Rating:    u.Rating,
		Wins:      u.Wins,
		Losses:    u.Losses,
		Draws:     u.Draws,
		Total:     total,
		WinRate:   winRate,
		CreatedAt: u.CreatedAt,
	}
}
