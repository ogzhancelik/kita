"""
Immutable game-state snapshot used for threefold-repetition detection.

A GameState captures everything that makes two moments in the game
"identical" for the purpose of the repetition rule:

    * Where every living piece is on the board.
    * Whose turn it is.
    * The last move each team made (determines the undo restriction
      on the very next move — two positions that differ only in undo
      restriction are genuinely different states).
    * Whether one team's king has been eaten and the other is in
      last-stand mode (and who ate first, for the draw scenario).
"""

from __future__ import annotations
from typing import NamedTuple, Optional
from .pieces import Move


class GameState(NamedTuple):
    """
    Fully hashable, immutable snapshot of a game position.
    Used as a key in the state-history counter inside Game.

    Fields
    ------
    positions : frozenset of (piece_id, col, row)
        One entry per living piece.  Captured pieces are absent.
    turn : str
        "white" or "black" — who is about to move.
    last_move_white : Move | None
        The last Move made by the White team, or None at game start.
    last_move_black : Move | None
        The last Move made by the Black team, or None at game start.
    king_eaten_by : str | None
        None  → normal game, both kings alive.
        "white" → White ate Black's king; Black is in last-stand mode.
        "black" → Black ate White's king; White is in last-stand mode.
        "both"  → both kings gone → draw (terminal state).
    """
    positions:       frozenset              # frozenset[(piece_id, col, row)]
    turn:            str                    # "white" | "black"
    last_move_white: Optional[Move]
    last_move_black: Optional[Move]
    king_eaten_by:   Optional[str]          # None | "white" | "black" | "both"
