"""
main.py - Entry point and quick-start guide for the Kita Game Backend.

This file provides a minimal demonstration of the game engine and allows
two players to test moves locally in the terminal.

Frontend developers can import the engine directly:
    from game import Game, Move

    game = Game.new_game()
    legal_moves = game.get_legal_moves()
    next_game = game.apply_move(legal_moves[0])
"""

from __future__ import annotations
import sys
from game.game import Game
from game.pieces import Move


def print_board(game: Game, mode: str = "detailed") -> None:
    """Print the current board state to stdout in simple or detailed mode."""
    print("\n" + game.display(mode=mode))


def print_moves(moves: list[Move]) -> None:
    """Print available moves with numeric indices."""
    for idx, move in enumerate(moves):
        print(f"  [{idx:>2d}] {move}")


def play_terminal(display_mode: str = "detailed") -> None:
    """2-Player local hotseat game directly in terminal."""
    print("=" * 50)
    print("  KITA - 2-PLAYER TERMINAL MODE")
    print("  White moves first. Players take turns.")
    print(f"  Current display mode: {display_mode.upper()}")
    print("=" * 50)

    game = Game.new_game()
    print_board(game, mode=display_mode)

    while True:
        status = game.get_status()
        if status != "ongoing":
            print("\n" + "=" * 50)
            print(f"  GAME OVER: {status.upper()}")
            print(f"  Total moves played: {game.move_count}")
            print("=" * 50)
            break

        moves = game.get_legal_moves()
        if not moves:
            print(f"\n  {game.turn.upper()} has no legal moves left!")
            break

        print(f"\n{game.turn.upper()}'s Turn - {len(moves)} legal move(s):")
        print_moves(moves)

        while True:
            try:
                cmd = input("\nEnter move index ('d'=detailed, 's'=simple, 'q'=quit): ").strip().lower()
            except (KeyboardInterrupt, EOFError):
                print("\nQuit.")
                return

            if cmd == "q":
                print("Exiting.")
                return
            if cmd == "d":
                display_mode = "detailed"
                print_board(game, mode=display_mode)
                continue
            if cmd == "s":
                display_mode = "simple"
                print_board(game, mode=display_mode)
                continue

            try:
                choice = int(cmd)
                if 0 <= choice < len(moves):
                    chosen = moves[choice]
                    break
                print(f"Invalid index. Enter a number between 0 and {len(moves) - 1}.")
            except ValueError:
                print("Invalid input. Enter a move index number, 'd', 's', or 'q'.")

        game = game.apply_move(chosen)
        print_board(game, mode=display_mode)


def show_info() -> None:
    """Display engine overview and usage example."""
    game = Game.new_game()
    moves = game.get_legal_moves()

    print("=" * 55)
    print("  KITA GAME ENGINE - BACKEND")
    print("=" * 55)
    print(f"  Initial Turn     : {game.turn.upper()}")
    print(f"  Legal Moves      : {len(moves)} opening moves available")
    print(f"  Game Status      : {game.get_status()}")
    print("-" * 55)
    print("  Quick-start in Python:")
    print("    from game import Game")
    print("    game = Game.new_game()")
    print("    moves = game.get_legal_moves()")
    print("    game = game.apply_move(moves[0])")
    print("    # Display options:")
    print("    game.display(mode='detailed')  # full details")
    print("    game.display(mode='simple')    # board only")
    print("=" * 55)
    print_board(game)
    print("\nCommands:")
    print("  python main.py play          -> Play 2-player game (detailed mode)")
    print("  python main.py play simple   -> Play 2-player game (simple mode)")
    print("  python main.py info          -> Show this overview")


if __name__ == "__main__":
    mode = sys.argv[1].lower() if len(sys.argv) > 1 else "info"

    if mode == "play":
        display_mode = (
            "simple"
            if len(sys.argv) > 2 and sys.argv[2].lower() in ("simple", "--simple", "-s")
            else "detailed"
        )
        play_terminal(display_mode=display_mode)
    else:
        show_info()
