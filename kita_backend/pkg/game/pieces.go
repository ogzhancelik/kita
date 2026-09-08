package game

import "fmt"

var AllPieceIDs = []string{"BK", "BP1", "BP2", "WK", "WP1", "WP2"}
var BlackPieces = []string{"BK", "BP1", "BP2"}
var WhitePieces = []string{"WK", "WP1", "WP2"}

const (
	BlackKing = "BK"
	WhiteKing = "WK"
)

var PieceTeam = map[string]string{
	"BK": "black", "BP1": "black", "BP2": "black",
	"WK": "white", "WP1": "white", "WP2": "white",
}

var PieceKind = map[string]string{
	"BK": "king", "BP1": "pawn", "BP2": "pawn",
	"WK": "king", "WP1": "pawn", "WP2": "pawn",
}

var InitialPositions = map[string]Pos{
	"BK":  {0, 0},
	"BP1": {3, 0},
	"BP2": {0, 1},
	"WK":  {6, 3},
	"WP1": {3, 3},
	"WP2": {6, 2},
}

type Move struct {
	PieceID string
	FromPos Pos
	ToPos   Pos
}

func (m Move) IsReverseOf(other Move) bool {
	return m.PieceID == other.PieceID && m.FromPos == other.ToPos && m.ToPos == other.FromPos
}

func (m Move) String() string {
	return fmt.Sprintf("%s: (%d,%d) -> (%d,%d)", m.PieceID, m.FromPos.Col, m.FromPos.Row, m.ToPos.Col, m.ToPos.Row)
}
