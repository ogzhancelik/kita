"""
Legal-move generation for Kita.

All game rules about movement are implemented here, keeping Game free
of rule logic and making it easy to unit-test rules in isolation.

Movement rules summary
----------------------
1.  Step count = tile_value(opponent_king.pos).
    The piece must move **exactly** that many steps.
2.  A piece may not pass through or land on a tile occupied by any piece,
    with one exception: a piece may land on the **opponent's king** (eating it).
3.  Pawns are immortal — no piece may land on a pawn (own or enemy).
4.  Undo restriction: the last piece moved by a team may not reverse its
    own previous move (go back to where it just came from), UNLESS that
    reversal is the team's **only** legal option.
5.  The undo restriction is per-piece / per-move: only the specific
    (piece_id, from→to) pair is forbidden, not all reversals by other pieces.
"""

from __future__ import annotations
from typing import Optional

from .board import tile_value, find_reachable
from .pieces import (
    Move,
    BLACK_PIECES, WHITE_PIECES,
    BLACK_KING,   WHITE_KING,
    PIECE_KIND,
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _team_pieces(team: str) -> tuple[str, ...]:
    return BLACK_PIECES if team == "black" else WHITE_PIECES


def _opponent_king_id(team: str) -> str:
    return WHITE_KING if team == "black" else BLACK_KING


def _opponent_pieces(team: str) -> tuple[str, ...]:
    return WHITE_PIECES if team == "black" else BLACK_PIECES


# ---------------------------------------------------------------------------
# Step-count resolver
# ---------------------------------------------------------------------------

def get_step_count(
    turn: str,
    positions: dict[str, Optional[tuple[int, int]]],
) -> int:
    """
    Return the number of steps that pieces of *turn* must take this move.

    Equals tile_value(opponent_king_pos).

    Raises RuntimeError if the opponent king is not on the board, which
    should never occur during a valid active turn (last-stand end conditions
    are checked before move generation).
    """
    opp_king_id  = _opponent_king_id(turn)
    opp_king_pos = positions.get(opp_king_id)
    if opp_king_pos is None:
        raise RuntimeError(
            f"Opponent king '{opp_king_id}' is not on the board. "
            "get_step_count should only be called during an active turn."
        )
    return tile_value(opp_king_pos)


# ---------------------------------------------------------------------------
# Core move generator
# ---------------------------------------------------------------------------

def get_legal_moves(
    positions: dict[str, Optional[tuple[int, int]]],
    turn: str,
    last_move_black: Optional[Move],
    last_move_white: Optional[Move],
) -> list[Move]:
    """
    Return all legal moves for the current player (*turn*).

    Returns an empty list when the player has no legal moves (they lose).

    Undo restriction is enforced with the forced-undo exception:
    *  Normally, a piece may not reverse its own immediately-previous move.
    *  Exception: if every candidate move is a forbidden reversal,
       those reversal moves are returned (the player is forced to undo).

    Args:
        positions       : dict[piece_id → (col, row) | None]
        turn            : "white" | "black"
        last_move_black : last Move made by Black (or None)
        last_move_white : last Move made by White (or None)

    Returns:
        Sorted list of Move objects (sorted for determinism in solvers).
    """
    steps = get_step_count(turn, positions)

    # ---- Build occupation sets ----------------------------------------- #

    # All tiles occupied by any piece (used for blocking traversal)
    all_occupied: frozenset[tuple[int, int]] = frozenset(
        pos for pos in positions.values() if pos is not None
    )

    # Tiles of own pieces (cannot land on own piece)
    own_ids = _team_pieces(turn)
    own_occupied: frozenset[tuple[int, int]] = frozenset(
        positions[pid] for pid in own_ids if positions.get(pid) is not None
    )

    # Opponent pawn tiles (immortal — cannot land on them)
    opp_ids = _opponent_pieces(turn)
    opp_pawn_ids  = [pid for pid in opp_ids if PIECE_KIND[pid] == "pawn"]
    opp_pawn_tiles: frozenset[tuple[int, int]] = frozenset(
        positions[pid] for pid in opp_pawn_ids if positions.get(pid) is not None
    )

    # Opponent king tile — the ONE occupied tile we may land on (eating it)
    opp_king_id  = _opponent_king_id(turn)
    opp_king_pos = positions.get(opp_king_id)
    landable: frozenset[tuple[int, int]] = (
        frozenset({opp_king_pos}) if opp_king_pos is not None else frozenset()
    )

    # The last move THIS team made (for undo restriction)
    last_move = last_move_black if turn == "black" else last_move_white

    # ---- Generate moves ------------------------------------------------- #

    normal_moves: list[Move] = []   # moves that satisfy all restrictions
    undo_moves:   list[Move] = []   # moves that would be normally forbidden (reversal)

    for pid in own_ids:
        pos = positions.get(pid)
        if pos is None:
            continue  # piece has been captured

        # Remove self from occupied so we don't block our own path
        occupied_excl_self = all_occupied - {pos}

        # Find all tiles reachable in exactly `steps` steps
        dests = find_reachable(pos, steps, occupied_excl_self, landable)

        for dest in dests:
            # Double-check: cannot land on own piece or enemy pawn
            # (find_reachable already blocks these, but we guard explicitly)
            if dest in own_occupied or dest in opp_pawn_tiles:
                continue

            move = Move(piece_id=pid, from_pos=pos, to_pos=dest)

            # Undo restriction check (per-piece, per-move)
            if last_move is not None and move.is_reverse_of(last_move):
                undo_moves.append(move)
            else:
                normal_moves.append(move)

    # Forced-undo exception: if only reversals are available, allow them
    result = normal_moves if normal_moves else undo_moves

    # Sort for determinism (solvers can rely on ordering)
    return sorted(result, key=lambda m: (m.piece_id, m.from_pos, m.to_pos))


# ---------------------------------------------------------------------------
# Reversal reachability & normalization
# ---------------------------------------------------------------------------

def is_reversal_possible(
    positions: dict[str, Optional[tuple[int, int]]],
    turn: str,
    last_move: Optional[Move],
) -> bool:
    """
    Check if player *turn* could physically execute the reversal of *last_move*
    in the current board state.

    Returns False if:
    - last_move is None
    - The moving piece is not on the board at last_move.to_pos
    - Opponent's king is missing (terminal state)
    - The reversal target tile (last_move.from_pos) is blocked by an own piece or opponent pawn
    - The reversal target tile cannot be reached in exactly tile_value(opponent_king) steps
    """
    if last_move is None:
        return False

    current_pos = positions.get(last_move.piece_id)
    if current_pos != last_move.to_pos:
        return False

    opp_king_id = _opponent_king_id(turn)
    opp_king_pos = positions.get(opp_king_id)
    if opp_king_pos is None:
        return False

    steps = tile_value(opp_king_pos)
    target = last_move.from_pos

    # Target cannot be occupied by own piece or opponent pawn
    own_ids = _team_pieces(turn)
    if any(positions.get(pid) == target for pid in own_ids):
        return False

    opp_pawn_ids = [pid for pid in _opponent_pieces(turn) if PIECE_KIND[pid] == "pawn"]
    if any(positions.get(pid) == target for pid in opp_pawn_ids):
        return False

    all_occupied = frozenset(pos for pos in positions.values() if pos is not None)
    occupied_excl_self = all_occupied - {current_pos}
    landable = frozenset({opp_king_pos})

    dests = find_reachable(current_pos, steps, occupied_excl_self, landable)
    return target in dests


def normalize_last_moves(
    positions: dict[str, Optional[tuple[int, int]]],
    turn: str,
    last_move_white: Optional[Move],
    last_move_black: Optional[Move],
) -> tuple[Optional[Move], Optional[Move]]:
    """
    Normalize last moves by setting the current player's last move to None
    if it cannot physically be reversed in the current board state.
    """
    lmw = last_move_white
    lmb = last_move_black
    if turn == "white":
        if not is_reversal_possible(positions, "white", lmw):
            lmw = None
    elif turn == "black":
        if not is_reversal_possible(positions, "black", lmb):
            lmb = None
    return lmw, lmb
