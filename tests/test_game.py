"""
Integration tests for the Game class: apply_move, status detection,
threefold repetition, king-eating flow, and last-stand equalization.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from game.game import Game
from game.pieces import Move, INITIAL_POSITIONS


class TestNewGame:
    def test_initial_turn(self):
        g = Game.new_game()
        assert g.turn == "white"

    def test_initial_positions(self):
        g = Game.new_game()
        assert g.positions["BK"]  == (0, 0)
        assert g.positions["BP1"] == (3, 0)
        assert g.positions["BP2"] == (0, 1)
        assert g.positions["WK"]  == (6, 3)
        assert g.positions["WP1"] == (3, 3)
        assert g.positions["WP2"] == (6, 2)

    def test_initial_status_ongoing(self):
        g = Game.new_game()
        assert g.get_status() == "ongoing"

    def test_initial_has_legal_moves(self):
        g = Game.new_game()
        assert g.get_legal_moves()

    def test_initial_state_recorded_once(self):
        g = Game.new_game()
        assert g.state_history[g.to_game_state()] == 1


class TestApplyMove:
    def test_piece_moves_to_new_position(self):
        g = Game.new_game()
        moves = g.get_legal_moves()
        m = moves[0]
        g2 = g.apply_move(m)
        assert g2.positions[m.piece_id] == m.to_pos

    def test_turn_alternates(self):
        g = Game.new_game()
        m = g.get_legal_moves()[0]
        g2 = g.apply_move(m)
        assert g2.turn == "black"
        m2 = g2.get_legal_moves()[0]
        g3 = g2.apply_move(m2)
        assert g3.turn == "white"

    def test_original_game_unchanged(self):
        """apply_move must not mutate the original Game."""
        g = Game.new_game()
        orig_positions = dict(g.positions)
        orig_turn = g.turn
        m = g.get_legal_moves()[0]
        _ = g.apply_move(m)
        assert g.positions == orig_positions
        assert g.turn == orig_turn

    def test_last_move_recorded(self):
        g = Game.new_game()
        m = g.get_legal_moves()[0]
        g2 = g.apply_move(m)
        assert g2.last_move_white == m
        assert g2.last_move_black is None  # Black hasn't moved yet

    def test_move_count_increments(self):
        g = Game.new_game()
        m = g.get_legal_moves()[0]
        g2 = g.apply_move(m)
        assert g2.move_count == 1

    def test_state_history_grows(self):
        g = Game.new_game()
        m = g.get_legal_moves()[0]
        g2 = g.apply_move(m)
        # After one move there are 2 distinct states in history
        assert sum(g2.state_history.values()) == 2


class TestGameStatus:
    def test_no_moves_loss(self):
        """Construct a position where White has absolutely no legal moves."""
        # All White pieces on Green tiles (step=1), but no reachable destination.
        # It's very hard to construct analytically; instead verify that the status
        # method returns the right losing side when get_legal_moves would return [].
        # We use monkey-patching via a subclass.
        from game.rules import get_legal_moves as _gen
        import game.game as gg

        original = gg._gen_moves

        def fake_gen(positions, turn, lmb, lmw):
            if turn == "white":
                return []
            return original(positions, turn, lmb, lmw)

        gg._gen_moves = fake_gen
        try:
            g = Game.new_game()
            assert g.get_status() == "black_wins"
        finally:
            gg._gen_moves = original

    def test_king_eaten_white_wins(self):
        """White eats Black king → after Black's last-stand, White wins."""
        g = Game.new_game()
        # Directly build the post-last-stand state
        from collections import Counter
        from game.state import GameState
        pos = dict(g.positions)
        pos["BK"] = None  # BK is captured
        last_move_white = Move("WP1", (5, 3), (0, 0))
        # Simulate: White ate BK (king_eaten_by="white"), Black took last-stand,
        # now it's White's turn again.
        h: Counter = Counter()
        g2 = Game(
            positions       = pos,
            turn            = "white",  # back to White's turn after Black's last stand
            last_move_white = last_move_white,
            last_move_black = None,
            king_eaten_by   = "white",  # White ate the king
            state_history   = h,
            move_count      = 2,
        )
        h[g2.to_game_state()] += 1
        assert g2.get_status() == "white_wins"

    def test_both_kings_eaten_draw(self):
        """Both kings captured → draw."""
        from collections import Counter
        pos = {pid: None for pid in ["BK", "WK",
                                      "BP1", "BP2", "WP1", "WP2"]}
        pos["BP1"] = (1, 0)
        pos["BP2"] = (0, 1)
        pos["WP1"] = (5, 3)
        pos["WP2"] = (6, 2)
        h: Counter = Counter()
        g = Game(
            positions       = pos,
            turn            = "white",
            last_move_white = None,
            last_move_black = None,
            king_eaten_by   = "both",
            state_history   = h,
            move_count      = 4,
        )
        h[g.to_game_state()] += 1
        assert g.get_status() == "draw"


class TestThreefoldRepetition:
    def test_repeated_state_detected(self):
        """
        Force the same GameState to appear three times by going back and forth.
        We need a round-trip sequence that returns to the same
        (positions, turn, last_moves) triple.

        Sequence:
          White: WP1 A→B  (state S1)
          Black: BP1 X→Y  (state S2)
          White: WP1 B→A  (state S3, but undo restriction may apply!)
          ...
        
        Because of undo restriction, a perfect 4-ply loop is tricky.
        Instead we test the Counter directly.
        """
        g = Game.new_game()
        initial_state = g.to_game_state()
        assert g.state_history[initial_state] == 1

        # Manually inflate the counter to simulate repetition
        from collections import Counter
        import copy
        g2 = Game(
            positions       = dict(g.positions),
            turn            = g.turn,
            last_move_white = g.last_move_white,
            last_move_black = g.last_move_black,
            king_eaten_by   = g.king_eaten_by,
            state_history   = Counter({initial_state: 3}),
            move_count      = g.move_count,
        )
        assert g2.get_status() == "draw"

    def test_repetition_not_triggered_at_two(self):
        g = Game.new_game()
        initial_state = g.to_game_state()
        from collections import Counter
        g2 = Game(
            positions       = dict(g.positions),
            turn            = g.turn,
            last_move_white = g.last_move_white,
            last_move_black = g.last_move_black,
            king_eaten_by   = g.king_eaten_by,
            state_history   = Counter({initial_state: 2}),
            move_count      = g.move_count,
        )
        assert g2.get_status() == "ongoing"


class TestClone:
    def test_clone_is_independent(self):
        g = Game.new_game()
        g2 = g.clone()
        m = g.get_legal_moves()[0]
        g3 = g.apply_move(m)
        # g2 should not be affected
        assert g2.positions == g.positions
        assert g2.move_count == 0


class TestDisplay:
    def test_display_returns_string(self):
        g = Game.new_game()
        out = g.display()
        assert isinstance(out, str)
        assert "BK" in out
        assert "WK" in out

    def test_display_no_rgb_labels(self):
        """Empty squares must not show R, B, G color letters."""
        g = Game.new_game()
        out = g.display()
        # Board rows must use dots for empty squares, not R/G/B
        assert " . " in out
        # Check board grid lines specifically don't have R, G, B as standalone tile letters
        for line in out.splitlines():
            if line.strip().startswith("r"):
                # Tile row — should contain piece tokens or dots/spaces, not color labels
                assert " R " not in line
                assert " G " not in line
                assert " B " not in line

    def test_repr(self):
        g = Game.new_game()
        r = repr(g)
        assert "Game(" in r
        assert "ongoing" in r
