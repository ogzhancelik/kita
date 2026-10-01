## General Critisism

There are a lot of texts. Also there are many parts/lessons for a game with this simple rules. The tutorial should be easy, welcoming, and on to point, not long and boring/scary. These are the changes I suggest. Implement them. 

# General Changes

- Remove titles from text cards, there will be just text. I will refer to titles in this document for you to follow, but they will not be there in the UI (or even backend if not necessary).
- Can you put a transition between pages? Like maybe fade in/out or bounce the board when new page is opened or something. Do something to make it more alive.
- The interactive boards sometimes can be too limiting. I will address this in below specifically. Generally, let users choose any piece and any legal move. If the move is the correct one approve it and if the move is not correct let them retry.
- Completely remove lesson 5

## Lesson 1 and Lesson 2

- Lesson 1 and 2 will be merged.
- Merge "board layout" and "your army". Put one board (with pieces) and 2 text cards:
    - "This is the Kita board shape."
    - "Each side has 1 king and 2 pawns. You are positioned at bottom-right."
- In "tile values" page, put 3 boards. In each board highlight the 1s 2s and 3s.
- Put a "goal" page. Write a short text about goal of the game: "your goal is to capture opponent's king or leave them with no moves" etc.
- In this "goal" page, put a second text card saying "Kings can be captured, pawns cannot". With this added to goal page, remove "King" and "Pawn" steps.

## Lesson 3 and Lesson 4

- In "Dynamic Steps" put 2 boards, one with opponent's king on 2 and one with opponent's king on 3 (D1 and D2 for black king is a good option). Highlight the A4 piece on board.
- Merge "walking step-by-step" and "try a move". Do not mention "step by step" (what does it mean?), just say "you cannot pass through other pieces". And say "make a move yourself. Tap the piece to select it and move" etc. Let them choose any piece and any move you are restricting currently.
- Lesson 4 will be added to lesson 3. In "no immediate undos" part, put an interactive board saying "make a move and after opponent plays, try to move the same piece.". So in this interactive board you will make a move, the opponent will make a move automatically (it will do D4D2), and you will make a move again to succeed.
- In "forced exception" step the board should show a setup where white only have 1 legal move and that piece is selected.

## Lesson 6, Lesson 7 and Lesson 8
- In "king elimination" step, make the board interactive, just use the same board setup as lesson 5 step 2. In text you say "you win if you capture opponent's king". Do not mention retaliation here. If possible write "win" in mint.
- In "no legal moves" step, idk why you wrote stalemate, it is a clear win. Make an interactive board with BK:D1, BP:D4, BP:A1, WK:A7, WP:A4, WP:D7 and the correct move is A7C7. The try it test will say "make one move to win"
- Lesson 7 will be added to lesson 6. The 2 steps of lesson 7 will be merged. Simply add "this retaliation move triggers automatically if exists" to text. Put an interactive board where a retaliation is happening. Player will move king-capturing move and it will be retaliated automatically. The game will end in DRAW.
- Lesson 8 "mutual king fall" is already handled in previous step. Keep the repetition&agreement step.