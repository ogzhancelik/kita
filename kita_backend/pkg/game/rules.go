package game

import "sort"

func getOpponentKingID(turn string) string {
	if turn == "black" {
		return WhiteKing
	}
	return BlackKing
}

func getTeamPieces(turn string) []string {
	if turn == "black" {
		return BlackPieces
	}
	return WhitePieces
}

func getOpponentPieces(turn string) []string {
	if turn == "black" {
		return WhitePieces
	}
	return BlackPieces
}

func GetStepCount(turn string, positions map[string]*Pos) int {
	oppKingID := getOpponentKingID(turn)
	oppKingPos := positions[oppKingID]
	if oppKingPos == nil {
		panic("Opponent king is not on the board")
	}
	return TileValue(*oppKingPos)
}

func GetLegalMoves(positions map[string]*Pos, turn string, lastMoveBlack *Move, lastMoveWhite *Move) []Move {
	steps := GetStepCount(turn, positions)

	allOccupied := make(map[Pos]bool)
	for _, pos := range positions {
		if pos != nil {
			allOccupied[*pos] = true
		}
	}

	ownIds := getTeamPieces(turn)
	ownOccupied := make(map[Pos]bool)
	for _, pid := range ownIds {
		if pos := positions[pid]; pos != nil {
			ownOccupied[*pos] = true
		}
	}

	oppIds := getOpponentPieces(turn)
	oppPawnTiles := make(map[Pos]bool)
	for _, pid := range oppIds {
		if PieceKind[pid] == "pawn" {
			if pos := positions[pid]; pos != nil {
				oppPawnTiles[*pos] = true
			}
		}
	}

	oppKingID := getOpponentKingID(turn)
	var landable = make(map[Pos]bool)
	if pos := positions[oppKingID]; pos != nil {
		landable[*pos] = true
	}

	var lastMove *Move
	if turn == "black" {
		lastMove = lastMoveBlack
	} else {
		lastMove = lastMoveWhite
	}

	var normalMoves []Move
	var undoMoves []Move

	for _, pid := range ownIds {
		pos := positions[pid]
		if pos == nil {
			continue
		}

		occupiedExclSelf := make(map[Pos]bool)
		for k, v := range allOccupied {
			occupiedExclSelf[k] = v
		}
		delete(occupiedExclSelf, *pos)

		dests := FindReachable(*pos, steps, occupiedExclSelf, landable)

		for _, dest := range dests {
			if ownOccupied[dest] || oppPawnTiles[dest] {
				continue
			}
			move := Move{PieceID: pid, FromPos: *pos, ToPos: dest}

			if lastMove != nil && move.IsReverseOf(*lastMove) {
				undoMoves = append(undoMoves, move)
			} else {
				normalMoves = append(normalMoves, move)
			}
		}
	}

	var result []Move
	if len(normalMoves) > 0 {
		result = normalMoves
	} else {
		result = undoMoves
	}

	sort.Slice(result, func(i, j int) bool {
		m1 := result[i]
		m2 := result[j]
		if m1.PieceID != m2.PieceID {
			return m1.PieceID < m2.PieceID
		}
		if m1.FromPos.Col != m2.FromPos.Col {
			return m1.FromPos.Col < m2.FromPos.Col
		}
		if m1.FromPos.Row != m2.FromPos.Row {
			return m1.FromPos.Row < m2.FromPos.Row
		}
		if m1.ToPos.Col != m2.ToPos.Col {
			return m1.ToPos.Col < m2.ToPos.Col
		}
		return m1.ToPos.Row < m2.ToPos.Row
	})

	return result
}

func isReversalPossible(positions map[string]*Pos, turn string, lastMove *Move) bool {
	if lastMove == nil {
		return false
	}
	currentPos := positions[lastMove.PieceID]
	if currentPos == nil || *currentPos != lastMove.ToPos {
		return false
	}

	oppKingID := getOpponentKingID(turn)
	oppKingPos := positions[oppKingID]
	if oppKingPos == nil {
		return false
	}

	steps := TileValue(*oppKingPos)
	target := lastMove.FromPos

	ownIds := getTeamPieces(turn)
	for _, pid := range ownIds {
		if pos := positions[pid]; pos != nil && *pos == target {
			return false
		}
	}

	var oppPawnIds []string
	for _, pid := range getOpponentPieces(turn) {
		if PieceKind[pid] == "pawn" {
			oppPawnIds = append(oppPawnIds, pid)
		}
	}
	for _, pid := range oppPawnIds {
		if pos := positions[pid]; pos != nil && *pos == target {
			return false
		}
	}

	allOccupied := make(map[Pos]bool)
	for _, pos := range positions {
		if pos != nil {
			allOccupied[*pos] = true
		}
	}

	occupiedExclSelf := make(map[Pos]bool)
	for k, v := range allOccupied {
		occupiedExclSelf[k] = v
	}
	delete(occupiedExclSelf, *currentPos)

	landable := make(map[Pos]bool)
	landable[*oppKingPos] = true

	dests := FindReachable(*currentPos, steps, occupiedExclSelf, landable)
	for _, d := range dests {
		if d == target {
			return true
		}
	}
	return false
}

func NormalizeLastMoves(positions map[string]*Pos, turn string, lastMoveWhite *Move, lastMoveBlack *Move) (*Move, *Move) {
	lmw := lastMoveWhite
	lmb := lastMoveBlack

	if turn == "white" {
		if !isReversalPossible(positions, "white", lmw) {
			lmw = nil
		}
	} else if turn == "black" {
		if !isReversalPossible(positions, "black", lmb) {
			lmb = nil
		}
	}
	return lmw, lmb
}
