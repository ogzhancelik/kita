package game

import (
	"fmt"
	"strings"
)

var Symbols = map[string]string{
	"BK": "BK", "BP1": "Bp", "BP2": "Bp",
	"WK": "WK", "WP1": "Wp", "WP2": "Wp",
}

type Game struct {
	Positions     map[string]*Pos
	Turn          string
	LastMoveWhite *Move
	LastMoveBlack *Move
	KingEatenBy   string
	StateHistory  map[GameState]int
	MoveCount     int
}

func NewGame() *Game {
	positions := make(map[string]*Pos)
	for pid, pos := range InitialPositions {
		p := pos
		positions[pid] = &p
	}

	g := &Game{
		Positions:     positions,
		Turn:          "white",
		LastMoveWhite: nil,
		LastMoveBlack: nil,
		KingEatenBy:   "",
		StateHistory:  make(map[GameState]int),
		MoveCount:     0,
	}
	g.StateHistory[g.ToGameState()] = 1
	return g
}

func (g *Game) ToGameState() GameState {
	lmw, lmb := NormalizeLastMoves(g.Positions, g.Turn, g.LastMoveWhite, g.LastMoveBlack)
	return GameState{
		Positions:     GetPositionsHash(g.Positions),
		Turn:          g.Turn,
		LastMoveWhite: ToNullableMove(lmw),
		LastMoveBlack: ToNullableMove(lmb),
		KingEatenBy:   g.KingEatenBy,
	}
}

func (g *Game) kingEndStatus() string {
	if g.KingEatenBy == "both" {
		return "draw"
	}
	if g.KingEatenBy == "white" && g.Turn == "white" {
		return "white_wins"
	}
	if g.KingEatenBy == "black" && g.Turn == "black" {
		return "black_wins"
	}
	return ""
}

func (g *Game) GetStatus() string {
	if status := g.kingEndStatus(); status != "" {
		return status
	}
	if g.StateHistory[g.ToGameState()] >= 3 {
		return "draw"
	}
	rawMoves := GetLegalMoves(g.Positions, g.Turn, g.LastMoveBlack, g.LastMoveWhite)
	if len(rawMoves) == 0 {
		if g.Turn == "black" {
			return "white_wins"
		}
		return "black_wins"
	}
	return "ongoing"
}

func (g *Game) GetLegalMoves() []Move {
	if g.GetStatus() != "ongoing" {
		return []Move{}
	}
	return GetLegalMoves(g.Positions, g.Turn, g.LastMoveBlack, g.LastMoveWhite)
}

func (g *Game) ApplyMove(move Move) *Game {
	newPos := make(map[string]*Pos)
	for k, v := range g.Positions {
		if v != nil {
			p := *v
			newPos[k] = &p
		} else {
			newPos[k] = nil
		}
	}

	var newLmw, newLmb *Move
	if g.LastMoveWhite != nil {
		m := *g.LastMoveWhite
		newLmw = &m
	}
	if g.LastMoveBlack != nil {
		m := *g.LastMoveBlack
		newLmb = &m
	}
	newKeb := g.KingEatenBy

	toPos := move.ToPos
	newPos[move.PieceID] = &toPos

	if g.Turn == "white" {
		m := move
		newLmw = &m
	} else {
		m := move
		newLmb = &m
	}

	oppKingId := WhiteKing
	if g.Turn == "black" {
		oppKingId = BlackKing
	}

	oppKingPos := g.Positions[oppKingId]
	if oppKingPos != nil && move.ToPos == *oppKingPos {
		newPos[oppKingId] = nil
		if newKeb == "" {
			newKeb = g.Turn
		} else {
			newKeb = "both"
		}
	}

	newTurn := "black"
	if g.Turn == "white" {
		newTurn = "white" // Wait, this should flip the turn. I see a bug here!
	}
	if g.Turn == "black" {
		newTurn = "white"
	} else {
		newTurn = "black"
	}

	newLmw, newLmb = NormalizeLastMoves(newPos, newTurn, newLmw, newLmb)

	newHistory := make(map[GameState]int)
	for k, v := range g.StateHistory {
		newHistory[k] = v
	}

	newGame := &Game{
		Positions:     newPos,
		Turn:          newTurn,
		LastMoveWhite: newLmw,
		LastMoveBlack: newLmb,
		KingEatenBy:   newKeb,
		StateHistory:  newHistory,
		MoveCount:     g.MoveCount + 1,
	}
	newGame.StateHistory[newGame.ToGameState()]++
	return newGame
}

func (g *Game) Display(mode string) string {
	isSimple := false
	m := strings.ToLower(strings.TrimSpace(mode))
	if m == "simple" || m == "s" {
		isSimple = true
	} else if m == "detailed" || m == "detail" || m == "d" {
		isSimple = false
	} else {
		panic(fmt.Sprintf("Unknown display mode: %s", mode))
	}

	posMap := make(map[Pos]string)
	for pid, pos := range g.Positions {
		if pos != nil {
			posMap[*pos] = Symbols[pid]
		}
	}

	var boardLines []string
	colsLine := "        "
	for c := 0; c < 7; c++ {
		colsLine += fmt.Sprintf("c%d  ", c)
	}
	boardLines = append(boardLines, strings.TrimRight(colsLine, " "))

	sepLine := "       +"
	for i := 0; i < 7*4+1; i++ {
		sepLine += "-"
	}
	boardLines = append(boardLines, sepLine)

	for r := 0; r < 4; r++ {
		rowStr := fmt.Sprintf("  r%d  |", r)
		for c := 0; c < 7; c++ {
			p := Pos{c, r}
			if _, exists := Tiles[p]; !exists {
				rowStr += "    "
			} else if sym, ok := posMap[p]; ok {
				rowStr += fmt.Sprintf(" %s ", sym)
			} else {
				rowStr += " .  "
			}
		}
		boardLines = append(boardLines, rowStr)
	}

	if isSimple {
		return strings.Join(boardLines, "\n")
	}

	var lines []string
	lines = append(lines, strings.Repeat("=", 46))
	lines = append(lines, fmt.Sprintf("  Ply #%3d  |  Turn: %s", g.MoveCount, strings.ToUpper(g.Turn)))

	status := g.GetStatus()
	if status != "ongoing" {
		lines = append(lines, fmt.Sprintf("  *** GAME OVER — %s ***", strings.ToUpper(status)))
	} else if g.KingEatenBy != "" {
		lsTeam := "BLACK"
		if g.KingEatenBy == "black" {
			lsTeam = "WHITE"
		}
		lines = append(lines, fmt.Sprintf("  *** LAST STAND — %s ate opponent king | %s has 1 more move ***", strings.ToUpper(g.KingEatenBy), lsTeam))
	}

	lines = append(lines, "")
	lines = append(lines, boardLines...)
	lines = append(lines, "")

	lines = append(lines, "  Pieces:")
	for _, pid := range AllPieceIDs {
		pos := g.Positions[pid]
		loc := "CAPTURED"
		if pos != nil {
			loc = fmt.Sprintf("(%d,%d)", pos.Col, pos.Row)
		}
		lines = append(lines, fmt.Sprintf("    %-4s -> %s", pid, loc))
	}

	lines = append(lines, "")

	wSteps := "?"
	bkPos := g.Positions[BlackKing]
	if bkPos != nil {
		wSteps = fmt.Sprintf("%d", TileValue(*bkPos))
	}
	bSteps := "?"
	wkPos := g.Positions[WhiteKing]
	if wkPos != nil {
		bSteps = fmt.Sprintf("%d", TileValue(*wkPos))
	}
	lines = append(lines, fmt.Sprintf("  Move distance: White must take %s step(s), Black must take %s step(s)", wSteps, bSteps))

	rep := g.StateHistory[g.ToGameState()]
	lines = append(lines, fmt.Sprintf("  State seen: %dx  (draw at 3x)", rep))

	lines = append(lines, strings.Repeat("=", 46))
	return strings.Join(lines, "\n")
}
