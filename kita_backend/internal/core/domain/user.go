package domain

import (
	"math"
	"strings"
	"time"
)

const (
	ProvisionalGamesThreshold = 5
	ProvisionalRDThreshold    = 180.0
)

type User struct {
	ID              string        `json:"id" gorm:"primaryKey;type:uuid"`
	Username        string        `json:"username" gorm:"uniqueIndex;not null"`
	Email           string        `json:"email" gorm:"uniqueIndex;not null"`
	PasswordHash    string        `json:"-" gorm:"not null"`
	AvatarIndex     int           `json:"avatar_index" gorm:"default:0"`
	AvatarCustom    string        `json:"avatar_custom" gorm:"default:''"`
	Rating          float64       `json:"rating" gorm:"default:1500;index"`
	RatingDeviation float64       `json:"rating_deviation" gorm:"default:350"`
	Volatility      float64       `json:"volatility" gorm:"default:0.06"`
	Wins            int           `json:"wins" gorm:"default:0"`
	Losses          int           `json:"losses" gorm:"default:0"`
	Draws           int           `json:"draws" gorm:"default:0"`
	Roles           []string      `json:"roles" gorm:"type:jsonb;serializer:json;default:'[]'"`
	CreatedAt       time.Time     `json:"created_at"`
	UpdatedAt       time.Time     `json:"updated_at"`
	Settings        *UserSettings `json:"settings,omitempty" gorm:"foreignKey:UserID;references:ID;constraint:OnDelete:CASCADE"`
}

const (
	RoleAdmin   = "admin"
	RolePremium = "premium"
	RoleSystem  = "system"
)

func (u *User) HasRole(role string) bool {
	for _, r := range u.Roles {
		if strings.EqualFold(r, role) {
			return true
		}
	}
	return false
}

func (u *User) IsAdmin() bool {
	return u.HasRole(RoleAdmin)
}

func (u *User) IsPremium() bool {
	return u.HasRole(RolePremium)
}

func (u *User) IsSystem() bool {
	return u.HasRole(RoleSystem) || strings.EqualFold(u.Username, "report")
}

func (u *User) AddRole(role string) {
	trimmed := strings.ToLower(strings.TrimSpace(role))
	if trimmed == "" {
		return
	}
	if !u.HasRole(trimmed) {
		u.Roles = append(u.Roles, trimmed)
	}
}

func (u *User) RemoveRole(role string) {
	trimmed := strings.ToLower(strings.TrimSpace(role))
	newRoles := make([]string, 0, len(u.Roles))
	for _, r := range u.Roles {
		if !strings.EqualFold(r, trimmed) {
			newRoles = append(newRoles, r)
		}
	}
	u.Roles = newRoles
}

func (u *User) IsProvisional() bool {
	total := u.Wins + u.Losses + u.Draws
	if total < ProvisionalGamesThreshold {
		return true
	}
	if u.RatingDeviation <= 0 {
		return false
	}
	return u.RatingDeviation > ProvisionalRDThreshold
}

type UserProfile struct {
	ID            string    `json:"id"`
	Username      string    `json:"username"`
	AvatarIndex   int       `json:"avatar_index"`
	AvatarCustom  string    `json:"avatar_custom"`
	Rating        int       `json:"rating"`
	IsProvisional bool      `json:"is_provisional"`
	Wins          int       `json:"wins"`
	Losses        int       `json:"losses"`
	Draws         int       `json:"draws"`
	Total         int       `json:"total_games"`
	WinRate       float64   `json:"win_rate"`
	Roles         []string  `json:"roles"`
	CreatedAt     time.Time `json:"created_at"`
}

func (p *UserProfile) HasRole(role string) bool {
	for _, r := range p.Roles {
		if strings.EqualFold(r, role) {
			return true
		}
	}
	return false
}

func (p *UserProfile) IsAdmin() bool {
	return p.HasRole(RoleAdmin)
}

func (p *UserProfile) IsPremium() bool {
	return p.HasRole(RolePremium)
}

func (p *UserProfile) IsSystem() bool {
	return p.HasRole(RoleSystem) || strings.EqualFold(p.Username, "report")
}

func (u *User) ToProfile() UserProfile {
	total := u.Wins + u.Losses + u.Draws
	winRate := 0.0
	if total > 0 {
		winRate = float64(u.Wins) / float64(total) * 100
	}
	roles := u.Roles
	if roles == nil {
		roles = []string{}
	}
	return UserProfile{
		ID:            u.ID,
		Username:      u.Username,
		AvatarIndex:   u.AvatarIndex,
		AvatarCustom:  u.AvatarCustom,
		Rating:        int(math.Round(u.Rating)),
		IsProvisional: u.IsProvisional(),
		Wins:          u.Wins,
		Losses:        u.Losses,
		Draws:         u.Draws,
		Total:         total,
		WinRate:       winRate,
		Roles:         roles,
		CreatedAt:     u.CreatedAt,
	}
}

type UserSearchResult struct {
	ID               string   `json:"id"`
	Username         string   `json:"username"`
	AvatarIndex      int      `json:"avatar_index"`
	AvatarCustom     string   `json:"avatar_custom"`
	Rating           int      `json:"rating"`
	IsProvisional    bool     `json:"is_provisional"`
	Wins             int      `json:"wins"`
	Losses           int      `json:"losses"`
	Draws            int      `json:"draws"`
	WinRate          float64  `json:"win_rate"`
	Roles            []string `json:"roles"`
	FriendshipStatus string   `json:"friendship_status"` // "none", "friend", "outgoing", "incoming"
	FriendshipID     string   `json:"friendship_id,omitempty"`
}


