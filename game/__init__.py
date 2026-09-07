"""
Kita board-game backend package.

Primary public interface:
    from game.game import Game
    from game.pieces import Move

Typical solver usage:
    game = Game.new_game()
    while game.get_status() == "ongoing":
        for move in game.get_legal_moves():
            next_game = game.apply_move(move)
            # … explore next_game …
"""
from .game import Game
from .pieces import Move
from .state import GameState

__all__ = ["Game", "Move", "GameState"]
