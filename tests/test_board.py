"""
Unit tests for board geometry: tile values, adjacency, and path finding.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from game.board import TILES, ADJACENCY, tile_value, find_reachable, ALL_TILES


class TestTiles:
    def test_total_tile_count(self):
        assert len(TILES) == 20

    def test_tile_values(self):
        # Value 2 tiles
        for pos in [(0,0),(3,0),(6,0),(0,3),(3,3),(6,3)]:
            assert tile_value(pos) == 2, f"{pos} should be value 2"
        # Value 3 tiles
        for pos in [(1,0),(5,0),(0,1),(6,1),(0,2),(6,2),(1,3),(5,3)]:
            assert tile_value(pos) == 3, f"{pos} should be value 3"
        # Value 1 tiles
        for pos in [(2,0),(4,0),(3,1),(3,2),(2,3),(4,3)]:
            assert tile_value(pos) == 1, f"{pos} should be value 1"

    def test_no_middle_tiles(self):
        """Middle cells that are not on the board."""
        for pos in [(1,1),(2,1),(4,1),(5,1),(1,2),(2,2),(4,2),(5,2)]:
            assert pos not in TILES


class TestAdjacency:
    def test_corner_adjacency(self):
        # (0,0) connects to (1,0) and (0,1) only
        assert set(ADJACENCY[(0, 0)]) == {(1, 0), (0, 1)}
        assert set(ADJACENCY[(6, 0)]) == {(5, 0), (6, 1)}
        assert set(ADJACENCY[(0, 3)]) == {(1, 3), (0, 2)}
        assert set(ADJACENCY[(6, 3)]) == {(5, 3), (6, 2)}

    def test_center_crossings(self):
        # (3,0) connects to (2,0), (4,0), and (3,1)
        assert set(ADJACENCY[(3, 0)]) == {(2, 0), (4, 0), (3, 1)}
        assert set(ADJACENCY[(3, 3)]) == {(2, 3), (4, 3), (3, 2)}

    def test_stem_tiles(self):
        # (0,1) connects only up and down
        assert set(ADJACENCY[(0, 1)]) == {(0, 0), (0, 2)}
        assert set(ADJACENCY[(3, 1)]) == {(3, 0), (3, 2)}
        assert set(ADJACENCY[(6, 1)]) == {(6, 0), (6, 2)}

    def test_symmetry(self):
        """Adjacency must be symmetric."""
        for tile, nbrs in ADJACENCY.items():
            for nb in nbrs:
                assert tile in ADJACENCY[nb], f"{tile} -> {nb} but not reverse"

    def test_total_edges(self):
        total_directed = sum(len(v) for v in ADJACENCY.values())
        # Each undirected edge counted twice
        assert total_directed % 2 == 0


class TestFindReachable:
    """Tests for find_reachable() path-finding function."""

    def test_zero_steps_returns_start(self):
        result = find_reachable((0, 0), 0, frozenset(), frozenset())
        assert result == {(0, 0)}

    def test_one_step_from_corner(self):
        # (0,0) has neighbors (1,0) and (0,1) — both reachable in 1 step
        result = find_reachable((0, 0), 1, frozenset(), frozenset())
        assert result == {(1, 0), (0, 1)}

    def test_blocked_neighbor(self):
        # If (1,0) is occupied, only (0,1) is reachable from (0,0)
        result = find_reachable((0, 0), 1, frozenset({(1, 0)}), frozenset())
        assert result == {(0, 1)}

    def test_cannot_land_on_occupied(self):
        # Both neighbors blocked → no destinations
        result = find_reachable((0, 0), 1, frozenset({(1, 0), (0, 1)}), frozenset())
        assert result == set()

    def test_landable_override(self):
        # (1,0) is occupied but also landable → can land there
        result = find_reachable((0, 0), 1,
                                frozenset({(1, 0)}),
                                frozenset({(1, 0)}))
        assert (1, 0) in result

    def test_two_steps_no_block(self):
        # From (0,0), 2 steps, no blockers
        # Path 1: (0,0)→(1,0)→(2,0)
        # Path 2: (0,0)→(0,1)→(0,2)
        # Path 3: (0,0)→(1,0)→(0,0)? NO — (0,0) is in visited
        # So destinations: {(2,0), (0,2)}
        result = find_reachable((0, 0), 2, frozenset(), frozenset())
        assert (2, 0) in result
        assert (0, 2) in result
        # Cannot revisit start
        assert (0, 0) not in result

    def test_no_revisit_within_path(self):
        # Piece at (0,1) — neighbors are (0,0) and (0,2)
        # 2 steps: can go (0,0)→... but NOT back to (0,1)
        result = find_reachable((0, 1), 2, frozenset(), frozenset())
        assert (0, 1) not in result  # no revisiting start

    def test_intermediate_blocked(self):
        # From (0,0), 2 steps, (0,1) blocked as intermediate
        # Path (0,0)→(0,1)→(0,2) blocked at step 1
        # Path (0,0)→(1,0)→(2,0) still works
        result = find_reachable((0, 0), 2, frozenset({(0, 1)}), frozenset())
        assert (0, 2) not in result   # (0,1) blocks this path
        assert (2, 0) in result       # this path is clear

    def test_three_steps_from_corner(self):
        result = find_reachable((0, 0), 3, frozenset(), frozenset())
        # (0,0)→(0,1)→(0,2)→(0,3)
        assert (0, 3) in result
        # (0,0)→(1,0)→(2,0)→(3,0)
        assert (3, 0) in result
