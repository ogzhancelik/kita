package game

import (
	"fmt"
	"sort"
	"strings"
)

type NullableMove struct {
	Valid bool
	Move  Move
}

func ToNullableMove(m *Move) NullableMove {
	if m == nil {
		return NullableMove{Valid: false}
	}
	return NullableMove{Valid: true, Move: *m}
}

type GameState struct {
	Positions     string
	Turn          string
	LastMoveWhite NullableMove
	LastMoveBlack NullableMove
	KingEatenBy   string // "" | "white" | "black" | "both"
}

func GetPositionsHash(positions map[string]*Pos) string {
	var parts []string
	for pid, pos := range positions {
		if pos != nil {
			parts = append(parts, fmt.Sprintf("%s:%d,%d", pid, pos.Col, pos.Row))
		}
	}
	sort.Strings(parts)
	return strings.Join(parts, ";")
}
