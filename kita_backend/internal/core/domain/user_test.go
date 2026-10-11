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
