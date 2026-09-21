package domain

import (
	"testing"
)

func TestDefaultSettings(t *testing.T) {
	s := DefaultSettings("user-123")
	if s.UserID != "user-123" {
		t.Errorf("expected user ID 'user-123', got '%s'", s.UserID)
	}
	if s.BoardTheme != "emerald" {
		t.Errorf("expected default theme emerald, got %s", s.BoardTheme)
	}
	if !s.SoundEnabled {
		t.Errorf("expected soundEnabled true by default")
	}
	if !s.HapticsEnabled {
		t.Errorf("expected hapticsEnabled true by default")
	}
	if !s.HighlightLastMove {
		t.Errorf("expected highlightLastMove true by default")
	}
	if s.BoardOrientation != "horizontal" {
		t.Errorf("expected boardOrientation horizontal, got %s", s.BoardOrientation)
	}
	if s.ThemeMode != "dark" {
		t.Errorf("expected themeMode dark, got %s", s.ThemeMode)
	}
	if s.Language != "en" {
		t.Errorf("expected language en, got %s", s.Language)
	}
}

func TestUpdateSettingsDTO_Validate(t *testing.T) {
	// Valid DTO
	emerald := "emerald"
	soundOff := false
	dto := UpdateSettingsDTO{
		BoardTheme:   &emerald,
		SoundEnabled: &soundOff,
	}
	if err := dto.Validate(); err != nil {
		t.Fatalf("expected valid DTO, got error: %v", err)
	}

	// Invalid board theme
	invalidTheme := "unknown_theme"
	badDto := UpdateSettingsDTO{BoardTheme: &invalidTheme}
	if err := badDto.Validate(); err == nil {
		t.Fatalf("expected error for unknown board theme, got nil")
	}

	// Invalid board orientation
	badOrientation := "diagonal"
	badOrientDto := UpdateSettingsDTO{BoardOrientation: &badOrientation}
	if err := badOrientDto.Validate(); err == nil {
		t.Fatalf("expected error for invalid board orientation, got nil")
	}

	// Invalid theme mode
	badThemeMode := "neon"
	badThemeDto := UpdateSettingsDTO{ThemeMode: &badThemeMode}
	if err := badThemeDto.Validate(); err == nil {
		t.Fatalf("expected error for invalid theme mode, got nil")
	}

	// Invalid language
	badLang := "fr"
	badLangDto := UpdateSettingsDTO{Language: &badLang}
	if err := badLangDto.Validate(); err == nil {
		t.Fatalf("expected error for unsupported language, got nil")
	}
}

func TestUpdateSettingsDTO_ApplyTo(t *testing.T) {
	s := DefaultSettings("user-456")
	amber := "amber_sunset"
	soundOff := false
	hapticsOff := false
	vertical := "vertical"
	tr := "tr"

	dto := UpdateSettingsDTO{
		BoardTheme:       &amber,
		SoundEnabled:     &soundOff,
		HapticsEnabled:   &hapticsOff,
		BoardOrientation: &vertical,
		Language:         &tr,
	}

	dto.ApplyTo(&s)

	if s.BoardTheme != "amber_sunset" {
		t.Errorf("expected amber_sunset, got %s", s.BoardTheme)
	}
	if s.SoundEnabled != false {
		t.Errorf("expected soundEnabled false, got %v", s.SoundEnabled)
	}
	if s.HapticsEnabled != false {
		t.Errorf("expected hapticsEnabled false, got %v", s.HapticsEnabled)
	}
	if s.BoardOrientation != "vertical" {
		t.Errorf("expected vertical, got %s", s.BoardOrientation)
	}
	if s.Language != "tr" {
		t.Errorf("expected language tr, got %s", s.Language)
	}
	// Untouched fields remain intact
	if s.ThemeMode != "dark" {
		t.Errorf("expected themeMode dark to remain unchanged, got %s", s.ThemeMode)
	}
}
