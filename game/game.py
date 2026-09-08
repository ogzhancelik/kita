"""
Game class — the central interface for the Kita engine.

Design goals
------------
* **Immutable-friendly**: `apply_move` returns a *new* Game instance.
  The caller's reference is never mutated.  This is essential for
  tree-search / traversal solvers that branch from the same state.
* **Self-contained history**: each Game carries a Counter of GameState
  occurrences so that threefold-repetition can be detected anywhere
  in the tree without external bookkeeping.
* **Zero external I/O**: display() returns a string; nothing is printed
  inside this module.

King-eaten flow (last-stand rule)
----------------------------------
When team A eats team B's king:
  king_eaten_by = "A"
  Turn passes to B (last-stand move).

On B's last-stand move:
  • If B eats A's king  → king_eaten_by = "both"  → Draw
  • Otherwise           → turn passes back to A.
    get_status() sees king_eaten_by == "A" and turn == "A"  → A wins.

Step-count when in last-stand
------------------------------
The eating team's king is still alive, so the last-stand player's step
count (based on opponent's king tile) remains well-defined.  The dead
king (belonging to the last-stand player) is no longer on the board and
is never used for step-count resolution.
"""

from __future__ import annotations
from collections import Counter
from typing import Optional

from .board import TILES, tile_value
from .pieces import (
    Move, ALL_PIECE_IDS,
    BLACK_PIECES, WHITE_PIECES,
    BLACK_KING,   WHITE_KING,
    PIECE_KIND,   INITIAL_POSITIONS,
)
from .rules import get_legal_moves as _gen_moves, get_step_count, normalize_last_moves
from .state import GameState


# Terminal symbols used by display()
_SYMBOLS: dict[str, str] = {
    "BK": "BK", "BP1": "Bp", "BP2": "Bp",
    "WK": "WK", "WP1": "Wp", "WP2": "Wp",
}

# Grid dimensions
_COLS = 7
_ROWS = 4
_ALL_GRID = {(c, r) for c in range(_COLS) for r in range(_ROWS)}
_EMPTY_CELLS = _ALL_GRID - set(TILES.keys())


class Game:
    """
    Full game state including move history for repetition detection.

    Attributes
    ----------
    positions : dict[str, tuple[int,int] | None]
        Maps piece_id to board position, or None if captured.
    turn : str
        "white" or "black" — who moves next.
    last_move_white : Move | None
        Most recent White move (drives undo restriction).
    last_move_black : Move | None
        Most recent Black move (drives undo restriction).
    king_eaten_by : str | None
        None       → both kings alive, normal play.
        "white"    → White ate BK; Black gets last-stand turn.
        "black"    → Black ate WK; White gets last-stand turn.
        "both"     → both kings gone (draw, terminal).
    state_history : Counter[GameState]
        How many times each GameState has appeared in this game.
    move_count : int
        Total half-moves (plies) played so far.
    """

    __slots__ = (
        "positions",
        "turn",
        "last_move_white",
        "last_move_black",
        "king_eaten_by",
        "state_history",
        "move_count",
    )

    def __init__(
        self,
        positions:        dict[str, Optional[tuple[int, int]]],
        turn:             str,
        last_move_white:  Optional[Move],
        last_move_black:  Optional[Move],
        king_eaten_by:    Optional[str],
        state_history:    Counter,
        move_count:       int,
    ) -> None:
        self.positions       = positions
        self.turn            = turn
        self.last_move_white = last_move_white
        self.last_move_black = last_move_black
        self.king_eaten_by   = king_eaten_by
        self.state_history   = state_history
        self.move_count      = move_count

    # ------------------------------------------------------------------ #
    # Construction
    # ------------------------------------------------------------------ #

    @classmethod
    def new_game(cls) -> "Game":
        """Return a fresh Game in the initial starting position."""
        positions = dict(INITIAL_POSITIONS)
        history: Counter = Counter()
        game = cls(
            positions       = positions,
            turn            = "white",
            last_move_white = None,
            last_move_black = None,
            king_eaten_by   = None,
            state_history   = history,
            move_count      = 0,
        )
        history[game.to_game_state()] += 1
        return game

    # ------------------------------------------------------------------ #
    # Immutable snapshot
    # ------------------------------------------------------------------ #

    def to_game_state(self) -> GameState:
        """
        Return a hashable, immutable snapshot of the current position.
        Used as the key for threefold-repetition detection.
        """
        pos_frozen = frozenset(
            (pid, col, row)
            for pid, pos in self.positions.items()
            if pos is not None
            for col, row in (pos,)
        )
        lmw, lmb = normalize_last_moves(
            self.positions, self.turn, self.last_move_white, self.last_move_black
        )
        return GameState(
            positions       = pos_frozen,
            turn            = self.turn,
            last_move_white = lmw,
            last_move_black = lmb,
            king_eaten_by   = self.king_eaten_by,
        )

    # ------------------------------------------------------------------ #
    # Status
    # ------------------------------------------------------------------ #

    def _king_end_status(self) -> Optional[str]:
        """
        Check king-eating end conditions.

        Returns a terminal status string or None if still ongoing by this rule.
        """
        if self.king_eaten_by == "both":
            return "draw"
        # After the last-stand turn, it is the eating team's turn again.
        if self.king_eaten_by == "white" and self.turn == "white":
            return "white_wins"   # Black's last stand is over; White wins
        if self.king_eaten_by == "black" and self.turn == "black":
            return "black_wins"   # White's last stand is over; Black wins
        return None

    def get_status(self) -> str:
        """
        Return the current game outcome:

        ``"ongoing"``    — game is still in progress.
        ``"white_wins"`` — White has won.
        ``"black_wins"`` — Black has won.
        ``"draw"``       — game ended in a draw (threefold repetition or
                           mutual king-eating).
        """
        # 1. King-eating terminal conditions
        king_result = self._king_end_status()
        if king_result is not None:
            return king_result

        # 2. Threefold repetition
        if self.state_history.get(self.to_game_state(), 0) >= 3:
            return "draw"

        # 3. No legal moves → current player loses
        raw_moves = _gen_moves(
            self.positions,
            self.turn,
            self.last_move_black,
            self.last_move_white,
        )
        if not raw_moves:
            return "white_wins" if self.turn == "black" else "black_wins"

        return "ongoing"

    # ------------------------------------------------------------------ #
    # Legal-move interface
    # ------------------------------------------------------------------ #

    def get_legal_moves(self) -> list[Move]:
        """
        Return all legal moves for the current player.
        Returns an empty list when the game is already over.

        This is the primary interface for solvers:
            for move in game.get_legal_moves():
                next_state = game.apply_move(move)
        """
        if self.get_status() != "ongoing":
            return []
        return _gen_moves(
            self.positions,
            self.turn,
            self.last_move_black,
            self.last_move_white,
        )

    # ------------------------------------------------------------------ #
    # Move application
    # ------------------------------------------------------------------ #

    def apply_move(self, move: Move) -> "Game":
        """
        Apply *move* and return a **new** Game representing the next state.

        This method does **not** validate legality — the caller should
        ensure *move* comes from get_legal_moves().

        King-capture handling
        ---------------------
        If the moving piece lands on the opponent king's tile:
          * The opponent king is removed from the board (pos → None).
          * king_eaten_by is set (or updated to "both" for last-stand equalize).
        """
        new_pos  = dict(self.positions)
        new_lmw  = self.last_move_white
        new_lmb  = self.last_move_black
        new_keb  = self.king_eaten_by

        # Move the piece to its new tile
        new_pos[move.piece_id] = move.to_pos

        # Record last move for this team
        if self.turn == "white":
            new_lmw = move
        else:
            new_lmb = move

        # Check for king capture
        opp_king_id  = WHITE_KING if self.turn == "black" else BLACK_KING
        opp_king_pos = self.positions.get(opp_king_id)

        if opp_king_pos is not None and move.to_pos == opp_king_pos:
            new_pos[opp_king_id] = None   # king is captured
            if new_keb is None:
                # First king eaten — grant last-stand to the captured team
                new_keb = self.turn        # "white" or "black"
            else:
                # Last-stand equalizer — both kings eaten
                new_keb = "both"

        # Advance turn
        new_turn = "black" if self.turn == "white" else "white"

        # Normalize last moves for the new game state
        new_lmw, new_lmb = normalize_last_moves(new_pos, new_turn, new_lmw, new_lmb)

        # Build history (shallow copy Counter, then increment new state)
        new_history = Counter(self.state_history)
        new_game = Game(
            positions       = new_pos,
            turn            = new_turn,
            last_move_white = new_lmw,
            last_move_black = new_lmb,
            king_eaten_by   = new_keb,
            state_history   = new_history,
            move_count      = self.move_count + 1,
        )
        new_history[new_game.to_game_state()] += 1
        return new_game

    # ------------------------------------------------------------------ #
    # Terminal display
    # ------------------------------------------------------------------ #

    def display(self, mode: str = "detailed", *, simple: Optional[bool] = None) -> str:
        """
        Return a human-readable board string for terminal output.

        Parameters
        ----------
        mode : str
            - ``"detailed"`` (default): includes turn, ply count, pieces list,
              move distances, state repetition counter, and status.
            - ``"simple"``: renders ONLY the board grid (coordinates and pieces).
        simple : bool | None, optional
            Shortcut flag. If True, forces simple mode. If False, forces detailed mode.

        Each cell shows:
          - The piece symbol (e.g. "BK", "Wp") if occupied
          - " .  " for an empty board square
          - "    " if there is no tile (empty cell in the grid)
        """
        if simple is not None:
            is_simple = bool(simple)
        else:
            m = mode.strip().lower()
            if m in ("simple", "s"):
                is_simple = True
            elif m in ("detailed", "detail", "d"):
                is_simple = False
            else:
                raise ValueError(
                    f"Unknown display mode: {mode!r}. Expected 'detailed' or 'simple'."
                )

        # Build pos->symbol map
        pos_map: dict[tuple[int, int], str] = {}
        for pid, pos in self.positions.items():
            if pos is not None:
                pos_map[pos] = _SYMBOLS[pid]

        # Board grid lines
        board_lines: list[str] = []
        board_lines.append("        " + "  ".join(f"c{c}" for c in range(_COLS)))
        board_lines.append("       +" + "-" * (_COLS * 4 + 1))

        for row in range(_ROWS):
            row_str = f"  r{row}  |"
            for col in range(_COLS):
                p = (col, row)
                if p in _EMPTY_CELLS:
                    row_str += "    "
                elif p in pos_map:
                    row_str += f" {pos_map[p]} "
                else:
                    row_str += " .  "
            board_lines.append(row_str)

        if is_simple:
            return "\n".join(board_lines)

        lines: list[str] = []

        # Header
        lines.append("=" * 46)
        lines.append(f"  Ply #{self.move_count:>3d}  |  Turn: {self.turn.upper()}")

        status = self.get_status()
        if status != "ongoing":
            lines.append(f"  *** GAME OVER — {status.upper()} ***")
        elif self.king_eaten_by is not None:
            ls_team = ("black" if self.king_eaten_by == "white" else "white").upper()
            lines.append(
                f"  *** LAST STAND — {self.king_eaten_by.upper()} ate opponent king "
                f"| {ls_team} has 1 more move ***"
            )

        lines.append("")
        lines.extend(board_lines)
        lines.append("")

        # Piece positions
        lines.append("  Pieces:")
        for pid in ALL_PIECE_IDS:
            pos = self.positions.get(pid)
            loc = f"({pos[0]},{pos[1]})" if pos else "CAPTURED"
            lines.append(f"    {pid:<4s} -> {loc}")

        lines.append("")

        # Step counts (informational)
        bk_pos = self.positions.get(BLACK_KING)
        wk_pos = self.positions.get(WHITE_KING)
        w_steps = tile_value(bk_pos) if bk_pos else "?"
        b_steps = tile_value(wk_pos) if wk_pos else "?"
        lines.append(f"  Move distance: White must take {w_steps} step(s), Black must take {b_steps} step(s)")

        # State repetition count
        cur_state = self.to_game_state()
        rep = self.state_history.get(cur_state, 0)
        lines.append(f"  State seen: {rep}x  (draw at 3x)")

        lines.append("=" * 46)
        return "\n".join(lines)

    def display_simple(self) -> str:
        """Convenience alias for self.display(mode='simple')."""
        return self.display(mode="simple")

    # ------------------------------------------------------------------ #
    # Utility
    # ------------------------------------------------------------------ #

    def __repr__(self) -> str:
        bk = self.positions.get(BLACK_KING)
        wk = self.positions.get(WHITE_KING)
        return (
            f"Game(ply={self.move_count}, turn={self.turn!r}, "
            f"status={self.get_status()!r}, "
            f"BK={bk}, WK={wk})"
        )

    def clone(self) -> "Game":
        """
        Return a deep-enough copy for independent branching.
        (Positions dict and Counter are copied; the rest are immutable values.)
        """
        return Game(
            positions       = dict(self.positions),
            turn            = self.turn,
            last_move_white = self.last_move_white,
            last_move_black = self.last_move_black,
            king_eaten_by   = self.king_eaten_by,
            state_history   = Counter(self.state_history),
            move_count      = self.move_count,
        )
