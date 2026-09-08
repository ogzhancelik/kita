# Kita Board Game - Core Backend Engine

Pure Python implementation of the **Kita** board game rules, state management, and move generator.

This repository contains the standalone game engine. It has **zero external dependencies** (runs on standard Python 3.10+) and is ready to be integrated into any frontend or web framework (FastAPI, Flask, Django, React, Vue, Electron, etc.).

---

## 🚀 Quick Start

No installation or `pip install` required!

### View Board & Engine Info
```bash
python main.py
```

### Play 2-Player Match in Terminal
Test the rules and moves directly in your console:
```bash
python main.py play
```

---

## 💻 How to Use in Code (Frontend Integration)

The frontend can interact with the game engine via the `Game` class:

```python
from game import Game, Move

# 1. Start a new game
game = Game.new_game()

# 2. Inspect game state
print("Current turn :", game.turn)             # 'white' or 'black'
print("Game status  :", game.get_status())       # 'ongoing', 'white_wins', 'black_wins', 'draw'
print("Move count   :", game.move_count)

# 3. Piece positions on the board
# Maps piece_id to (col, row) tuple, or None if captured
for piece_id, pos in game.positions.items():
    print(f"{piece_id}: {pos}")

# 4. Get all legal moves for the current player
legal_moves = game.get_legal_moves()
for m in legal_moves:
    print(f"Move {m.piece_id} from {m.from_pos} to {m.to_pos}")

# 5. Apply a move (returns a brand new immutable Game instance)
if legal_moves:
    next_game = game.apply_move(legal_moves[0])
    print(next_game.display())               # Detailed mode (default: turn, ply, pieces, steps)
    print(next_game.display(mode="simple"))  # Simple mode (board grid only)
```

---

## 🧩 Game Overview & Pieces

* **Board**: 4 rows × 7 columns grid.
* **Pieces**:
  * **White**: King (`WK`), Pawn 1 (`WP1`), Pawn 2 (`WP2`)
  * **Black**: King (`BK`), Pawn 1 (`BP1`), Pawn 2 (`BP2`)
* **Movement**: Step-count is dynamically determined by tile distances and rules.
* **Winning / Terminal Conditions**:
  * Capturing the opponent's king (with last-stand defense mechanic).
  * Threefold repetition results in a draw.

---

## 🧪 Tests

To run the unit test suite:
```bash
pytest tests/test_board.py tests/test_game.py tests/test_rules.py
```
*(Or using Python's built-in test runner without pytest)*:
```bash
python -m unittest discover tests
```

---

## 📁 Repository Structure

```text
├── game/                    # Core Kita game engine package
│   ├── __init__.py          # Public exports (Game, Move, GameState)
│   ├── board.py             # Board grid representation & symmetries
│   ├── pieces.py            # Pieces, colors, move data structures
│   ├── rules.py             # Kita rule-set and legal move generator
│   ├── state.py             # State encoding & hashing
│   └── game.py              # Main Game class & turn management
├── tests/                   # Engine unit tests
│   ├── test_board.py
│   ├── test_game.py
│   └── test_rules.py
├── main.py                  # Entry point & terminal 2-player game
├── .gitignore               # Ignores databases, solver, and caches
└── README.md                # Documentation & API reference
```
