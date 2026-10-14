package domain

import (
	"testing"
)

func TestUser_IsProvisional(t *testing.T) {
	tests := []struct {
		name            string
		wins            int
		losses          int
		draws           int
		ratingDeviation float64
		expected        bool
	}{
		{
			name:            "brand new user 0 games default RD 350",
			wins:            0,
			losses:          0,
			draws:           0,
			ratingDeviation: 350.0,
			expected:        true,
		},
		{
			name:            "4 games played (under threshold 5)",
			wins:            3,
			losses:          1,
			draws:           0,
			ratingDeviation: 150.0,
			expected:        true,
		},
		{
			name:            "5 games played but high deviation > 180",
			wins:            3,
			losses:          2,
			draws:           0,
			ratingDeviation: 195.0,
			expected:        true,
		},
		{
			name:            "5 games played with established deviation <= 180",
			wins:            3,
			losses:          2,
			draws:           0,
			ratingDeviation: 175.0,
			expected:        false,
		},
		{
			name:            "6 games played with low deviation",
			wins:            4,
			losses:          1,
			draws:           1,
			ratingDeviation: 140.0,
			expected:        false,
		},
		{
			name:            "5 games played with uninitialized 0 deviation (test/legacy fallback)",
			wins:            5,
			losses:          0,
			draws:           0,
			ratingDeviation: 0.0,
			expected:        false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			u := &User{
				Wins:            tc.wins,
				Losses:          tc.losses,
				Draws:           tc.draws,
				RatingDeviation: tc.ratingDeviation,
			}
			actual := u.IsProvisional()
			if actual != tc.expected {
				t.Errorf("expected %v, got %v", tc.expected, actual)
			}

			profile := u.ToProfile()
			if profile.IsProvisional != tc.expected {
				t.Errorf("expected profile.IsProvisional %v, got %v", tc.expected, profile.IsProvisional)
			}
		})
	}
}

func TestUser_Roles(t *testing.T) {
	u := &User{
		Username: "admin_user",
		Roles:    []string{"admin"},
	}

	if !u.HasRole("admin") {
		t.Errorf("expected HasRole('admin') to be true")
	}
	if !u.HasRole("ADMIN") {
		t.Errorf("expected case-insensitive HasRole('ADMIN') to be true")
	}
	if !u.IsAdmin() {
		t.Errorf("expected IsAdmin() to be true")
	}
	if u.IsPremium() {
		t.Errorf("expected IsPremium() to be false initially")
	}

	// Add role
	u.AddRole("premium")
	u.AddRole("PREMIUM") // Duplicate shouldn't be added
	if !u.IsPremium() {
		t.Errorf("expected IsPremium() to be true after AddRole")
	}
	if len(u.Roles) != 2 {
		t.Errorf("expected 2 roles without duplicates, got %d: %v", len(u.Roles), u.Roles)
	}

	// Convert to profile
	p := u.ToProfile()
	if !p.IsAdmin() || !p.IsPremium() {
		t.Errorf("expected profile to inherit admin and premium roles")
	}

	// Remove role
	u.RemoveRole("admin")
	if u.IsAdmin() {
		t.Errorf("expected IsAdmin() to be false after RemoveRole")
	}
	if len(u.Roles) != 1 {
		t.Errorf("expected 1 role after removal, got %d", len(u.Roles))
	}
}
