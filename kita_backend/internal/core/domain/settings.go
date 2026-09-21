package domain

import (
	"fmt"
	"time"
)

// Allowed settings values
var (
	ValidBoardThemes = map[string]bool{
		"emerald":          true,
		"amber_sunset":     true,
		"ocean_azure":      true,
		"cyber_purple":     true,
		"slate_monochrome": true,
	}

	ValidBoardOrientations = map[string]bool{
		"horizontal": true,
		"vertical":   true,
		"auto":       true,
	}

	ValidThemeModes = map[string]bool{
		"system": true,
		"dark":   true,
		"light":  true,
	}

	ValidLanguages = map[string]bool{
		"en": true,
		"tr": true,
	}
)

type UserSettings struct {
	UserID            string    `json:"-" gorm:"primaryKey;type:uuid"`
	BoardTheme        string    `json:"board_theme" gorm:"type:varchar(32);default:'emerald'"`
	BoardOrientation  string    `json:"board_orientation" gorm:"type:varchar(32);default:'horizontal'"`
	SoundEnabled      bool      `json:"sound_enabled" gorm:"default:true"`
	HapticsEnabled    bool      `json:"haptics_enabled" gorm:"default:true"`
	HighlightLastMove bool      `json:"highlight_last_move" gorm:"default:true"`
	ThemeMode         string    `json:"theme_mode" gorm:"type:varchar(16);default:'dark'"`
	Language          string    `json:"language" gorm:"type:varchar(8);default:'en'"`
	CreatedAt         time.Time `json:"-"`
	UpdatedAt         time.Time `json:"-"`
}

// DefaultSettings returns a new UserSettings struct populated with system defaults.
func DefaultSettings(userID string) UserSettings {
	now := time.Now().UTC()
	return UserSettings{
		UserID:            userID,
		BoardTheme:        "emerald",
		BoardOrientation:  "horizontal",
		SoundEnabled:      true,
		HapticsEnabled:    true,
		HighlightLastMove: true,
		ThemeMode:         "dark",
		Language:          "en",
		CreatedAt:         now,
		UpdatedAt:         now,
	}
}

// UpdateSettingsDTO represents payload for partial or full settings update.
type UpdateSettingsDTO struct {
	BoardTheme        *string `json:"board_theme"`
	BoardOrientation  *string `json:"board_orientation"`
	SoundEnabled      *bool   `json:"sound_enabled"`
	HapticsEnabled    *bool   `json:"haptics_enabled"`
	HighlightLastMove *bool   `json:"highlight_last_move"`
	ThemeMode         *string `json:"theme_mode"`
	Language          *string `json:"language"`
}

// Validate checks whether the values in DTO are within permitted ranges and formats.
func (dto *UpdateSettingsDTO) Validate() error {
	if dto.BoardTheme != nil && !ValidBoardThemes[*dto.BoardTheme] {
		return fmt.Errorf("invalid board_theme: '%s'", *dto.BoardTheme)
	}
	if dto.BoardOrientation != nil && !ValidBoardOrientations[*dto.BoardOrientation] {
		return fmt.Errorf("invalid board_orientation: '%s'", *dto.BoardOrientation)
	}
	if dto.ThemeMode != nil && !ValidThemeModes[*dto.ThemeMode] {
		return fmt.Errorf("invalid theme_mode: '%s'", *dto.ThemeMode)
	}
	if dto.Language != nil && !ValidLanguages[*dto.Language] {
		return fmt.Errorf("invalid language: '%s'", *dto.Language)
	}
	return nil
}

// ApplyTo updates the target UserSettings with non-nil fields from dto.
func (dto *UpdateSettingsDTO) ApplyTo(s *UserSettings) {
	if dto.BoardTheme != nil {
		s.BoardTheme = *dto.BoardTheme
	}
	if dto.BoardOrientation != nil {
		s.BoardOrientation = *dto.BoardOrientation
	}
	if dto.SoundEnabled != nil {
		s.SoundEnabled = *dto.SoundEnabled
	}
	if dto.HapticsEnabled != nil {
		s.HapticsEnabled = *dto.HapticsEnabled
	}
	if dto.HighlightLastMove != nil {
		s.HighlightLastMove = *dto.HighlightLastMove
	}
	if dto.ThemeMode != nil {
		s.ThemeMode = *dto.ThemeMode
	}
	if dto.Language != nil {
		s.Language = *dto.Language
	}
	s.UpdatedAt = time.Now().UTC()
}
