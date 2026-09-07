"""
Board geometry for the Kita board game.

The board is a 7x4 grid shaped like a sideways figure-8 (20 tiles total).
Each tile has a (col, row) coordinate and an integer value (1, 2, or 3):

    Tile values: 1, 2, or 3.

Board layout (values 1, 2, 3; . = no tile):

    Col:   0  1  2  3  4  5  6
    Row 0: 2  3  1  2  1  3  2
    Row 1: 3  .  .  1  .  .  3
    Row 2: 3  .  .  1  .  .  3
    Row 3: 2  3  1  2  1  3  2

Adjacency graph (tiles connected by a shared edge):

    (0,0)-(1,0)-(2,0)-(3,0)-(4,0)-(5,0)-(6,0)
      |                  |                  |
    (0,1)              (3,1)              (6,1)
      |                  |                  |
    (0,2)              (3,2)              (6,2)
      |                  |                  |
    (0,3)-(1,3)-(2,3)-(3,3)-(4,3)-(5,3)-(6,3)
"""

from __future__ import annotations
from typing import FrozenSet

# ---------------------------------------------------------------------------
# Tile data: (col, row) → tile value  (1, 2, or 3)
# ---------------------------------------------------------------------------

TILES: dict[tuple[int, int], int] = {
    (0, 0): 2, (1, 0): 3, (2, 0): 1, (3, 0): 2, (4, 0): 1, (5, 0): 3, (6, 0): 2,
    (0, 1): 3,                        (3, 1): 1,                        (6, 1): 3,
    (0, 2): 3,                        (3, 2): 1,                        (6, 2): 3,
    (0, 3): 2, (1, 3): 3, (2, 3): 1, (3, 3): 2, (4, 3): 1, (5, 3): 3, (6, 3): 2,
}

ALL_TILES: frozenset[tuple[int, int]] = frozenset(TILES.keys())

# ---------------------------------------------------------------------------
# Adjacency list (precomputed at import time)
# ---------------------------------------------------------------------------

_DIRECTIONS: tuple[tuple[int, int], ...] = ((1, 0), (-1, 0), (0, 1), (0, -1))

ADJACENCY: dict[tuple[int, int], tuple[tuple[int, int], ...]] = {}
for _col, _row in TILES:
    ADJACENCY[(_col, _row)] = tuple(
        (_col + dc, _row + dr)
        for dc, dr in _DIRECTIONS
        if (_col + dc, _row + dr) in TILES
    )


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def tile_value(pos: tuple[int, int]) -> int:
    """Return the value (1, 2, or 3) of the tile at *pos*."""
    return TILES[pos]


def find_reachable(
    start: tuple[int, int],
    steps: int,
    occupied: FrozenSet[tuple[int, int]],
    landable: FrozenSet[tuple[int, int]],
) -> set[tuple[int, int]]:
    """
    Find every tile reachable from *start* in **exactly** *steps* steps.

    Movement rules encoded here:
    * No tile may be revisited within the same path (includes *start*).
    * **Intermediate** tiles (not the final step) cannot be in *occupied*.
    * The **landing** tile (final step) is blocked if it is in *occupied*,
      **unless** it is also in *landable* (e.g., the opponent's king).

    The moving piece is expected to have been removed from *occupied*
    by the caller before this function is invoked.

    Args:
        start:    The moving piece's current tile.
        steps:    Exact number of edge-steps to take (≥ 1).
        occupied: Tiles blocked for traversal (all other pieces on board).
        landable: Subset of *occupied* tiles that are valid landing spots.

    Returns:
        Set of valid destination tiles.
    """
    if steps == 0:
        return {start}

    destinations: set[tuple[int, int]] = set()

    # Stack entry: (current_tile, remaining_steps, path_visited_set)
    # path_visited_set includes start so we never backtrack through it.
    stack: list[tuple[tuple[int, int], int, frozenset[tuple[int, int]]]] = [
        (start, steps, frozenset({start}))
    ]

    while stack:
        pos, rem, visited = stack.pop()
        for nb in ADJACENCY[pos]:
            if nb in visited:
                continue  # no revisiting within this path
            if rem == 1:
                # Landing step — allowed unless blocked (and not landable)
                if nb not in occupied or nb in landable:
                    destinations.add(nb)
            else:
                # Intermediate step — cannot pass through any piece
                if nb in occupied:
                    continue
                stack.append((nb, rem - 1, visited | {nb}))

    return destinations
