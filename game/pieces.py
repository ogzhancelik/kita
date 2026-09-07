"""
Piece identifiers, kinds, and starting positions for Kita.

Piece ID convention:
    First char  : team   — 'B' (Black) or 'W' (White)
    Second char : kind   — 'K' (King) or 'P' (Pawn, followed by '1' or '2')

IDs:  BK  BP1  BP2   WK  WP1  WP2

Starting layout:

    Black:
        BK  -> (0, 0)  Tile value 2 — very edge corner
        BP1 -> (3, 0)  Tile value 2 — top center
        BP2 -> (0, 1)  Tile value 3 — below BK

    White (mirror of Black):
        WK  -> (6, 3)  Tile value 2 — very edge corner
        WP1 -> (3, 3)  Tile value 2 — bottom center
        WP2 -> (6, 2)  Tile value 3 — above WK
"""

from __future__ import annotations
from typing import NamedTuple, Optional

# ---------------------------------------------------------------------------
# Piece ID sets
# ---------------------------------------------------------------------------

ALL_PIECE_IDS: tuple[str, ...] = ("BK", "BP1", "BP2", "WK", "WP1", "WP2")
BLACK_PIECES:  tuple[str, ...] = ("BK", "BP1", "BP2")
WHITE_PIECES:  tuple[str, ...] = ("WK", "WP1", "WP2")

BLACK_KING = "BK"
WHITE_KING = "WK"

# ---------------------------------------------------------------------------
# Piece attribute lookups
# ---------------------------------------------------------------------------

PIECE_TEAM: dict[str, str] = {
    "BK": "black", "BP1": "black", "BP2": "black",
    "WK": "white", "WP1": "white", "WP2": "white",
}

PIECE_KIND: dict[str, str] = {
    "BK": "king",  "BP1": "pawn",  "BP2": "pawn",
    "WK": "king",  "WP1": "pawn",  "WP2": "pawn",
}

# ---------------------------------------------------------------------------
# Starting positions
# ---------------------------------------------------------------------------

INITIAL_POSITIONS: dict[str, tuple[int, int]] = {
    "BK":  (0, 0),
    "BP1": (3, 0),
    "BP2": (0, 1),
    "WK":  (6, 3),
    "WP1": (3, 3),
    "WP2": (6, 2),
}

# ---------------------------------------------------------------------------
# Move data type
# ---------------------------------------------------------------------------

class Move(NamedTuple):
    """
    Represents a single piece movement.

    Attributes:
        piece_id : e.g. "BP1"
        from_pos : (col, row) before the move
        to_pos   : (col, row) after the move
    """
    piece_id: str
    from_pos: tuple[int, int]
    to_pos:   tuple[int, int]

    def is_reverse_of(self, other: "Move") -> bool:
        """
        Return True if this move is the exact inverse of *other*.

        Used to enforce the undo restriction: a piece cannot reverse
        its own previous move (unless it has no other legal options).
        """
        return (
            self.piece_id == other.piece_id
            and self.from_pos == other.to_pos
            and self.to_pos   == other.from_pos
        )

    def __str__(self) -> str:
        return (
            f"{self.piece_id}: "
            f"({self.from_pos[0]},{self.from_pos[1]}) -> "
            f"({self.to_pos[0]},{self.to_pos[1]})"
        )
