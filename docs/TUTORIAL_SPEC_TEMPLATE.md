# Tutorial Specification Template

Use this template to define lessons, steps, screen tap behaviors, text cards, and board states for the revamped Kita Tutorial.
Antigravity will parse your finalized document to implement the screens, interactions, and translation keys.

---

## 📐 Mechanics & Screen Tap Flow

In the improved tutorial:
1. **Screen Tap to Advance (`tap_to_reveal` / `tap_to_next`)**:
   - Instead of requiring users to find and tap a small "Next" button at the bottom, **tapping anywhere on the screen** (outside interactive board tiles) will advance the tutorial.
   - For steps with multiple text cards, **each screen tap reveals the next text card** sequentially with a smooth entrance animation. Once all cards for the step are revealed, the next tap advances to the next step.
   - A subtle image/animation appears at the bottom to show "tap".
2. **Interactive Steps (`interactive_action`)**:
   - In interactive steps, screen taps do not skip the exercise. The user interacts directly with the board (selecting pieces, deselecting on re-tap, or dragging & dropping).
   - Once the winning or required move is completed, the success card appears and tapping anywhere continues to the next step.
   - Doing an "incorrect step" wouldn't commit the move, do the move anyways (it will have restart button as it has right now).
3. **Previous Boards**:
   - If we go "back" to previous page where it has interactive board, keep the last move in memory and load it. Do not have the player do the same thing again.
4. **Reduce the padding**: There is an unnecesarily huge gap from left and right (this also is in KNOWN_BUGS_AND_CHANGES.md). Fix it.
---

## 📝 Syntax Reference

### Text Formatting
- Use `<mint>your text</mint>` to highlight keywords in the soft mint accent color (e.g. `<mint>Şah</mint>`, `<mint>3 adım</mint>`).
- The text is a bit grayish, make it white to more pop. Right now it looks a bit "subtle".
- I won't write everything, like there will be "Great Move!" "Success!" etc. cards and "Try it yourself!"/"Reset Step" texts etc. You figure out the best way to put these texts.
---

## 📋 Lessons

My template will be:
## Page X
- Opponent plays (optional). "First text card"
  - The board shows alongside the text card
- "Second text card" (tap to reveal)
  - The board shows alongsinde the new text card

There won't be "multiple lessons". It will be just pages.

----

### Page 1
- "This is the Kita board shape":
  - Only the board shows up with no pieces.
- "Each side has: \n 1 King" (with king icon):
  - The white and black king on the board
- "\n And 2 Pawns" (with pawn icon) (it will added to the same text card, not new card):
  - The white and black pawns on the board along with the kings.
- "You are positioned at bottom-right"
  - White pieces on the board are highlighted in the mint accent color.

### Page 2
- "1-Value Tiles" (in yellow, like it is an explanation under the board) + "Each tile has a value of 1, 2, or 3."
  - Highlight all 1-value tiles with mint. Pieces exist.
- "2-Value Tiles" (replace the previous "explanation" card)
  - Highlight all 2-value tiles with mint. Pieces exist.
- "3-Value Tiles" (replace the previous "explanation" card)
  - Highlight all 3-value tiles with mint. Pieces exist.

### Page 3
- "Your step count you can move equals the value of the opponent's King's tile." (write it in a better way i just made the text up)
  - Highlight opponent (black) king tile with mint.
- "<red>Notice that black king sits on a <mint>2-value</mint> tile.</red>" + "<yellow>Make a move!</yellow> You <red>cannot</red> <yellow>pass through</yellow> other pieces or <yellow>capture</yellow>."
  - Interactive board. Any move is legal.
- On board, opponent will play. If player played A7A5, play D1D2. In other cases, play D1D3 (king moves). Change "2-value" on previous card to "1-value" or "3-value" depending on the move.
  - Interactive board. Any move is legal. It succeeds.

### Page 4
- Opponent plays one of these in this order, depending of which one is possible: C1D2, C1D1, C1A2, D4D7. "You cannot undo your previous move by moving the same piece back to where it came from." + "Your last move was <red>{Player's last move}</red>. Notice you cannot do <red>{Player's last move reversed (like A7A5 to A5A7)}</red> now. \n <yellow>Make another move</yellow>"
  - Interactive board. Any move is legal. It succeeds.

### Page 5
- "However, if that reversal is your ONLY legal move, it is allowed". 
  - Completely new board. Interactive. D3C4 succeeds (it is only legal move anyways, so any move succeeds). WK:D2, WP:D3, WP:D6, BK:D1, BP:D5, BP:D7, Last Moves: C4D3, A7D7.

### Page 6
- "You<mint>win</mint> when:" + "* <yellow>If you capture opponent's king.</yellow>"
  - Completely new board. Interactive. D3D1 succeeds. Autoselect D3. WK:A7, WP:D3, WP:B7, BK:D1, BP:B1, BP:D5, Last Moves:C4D3, A2B1.
- "*<yellow>If your opponent has no legal moves lef.</yellow>"
  - Completely new board. Interactive. A7C7 succeeds. Autoselect A7. WK:A7, WP:A4, WP:D7, BK:D1, BP:A1, BP:D4, Last Moves:C1A1, B7D7.

### Page 7
- "When a king is captured..." (the text already exists. put color if needed for necessary parts)
  - Completely new board. Interactive. D3D1 succeeds. Autoselect D3. WK:A7, WP:D3, WP:A4, BK:D1, BP:B1, BP:C7, Last Moves:D5D3, D6C7. 
- C7A7 plays.

### Page 8
- "A <mint>draw</mint> also accurs if exact same board..." (text already exists.)
  - Completely new board. It autoplays these moves in loop as long as this page is open: A4D4, A1A4, D4D1, A4D4, D1A1, D4D1, A1A4, D1A1. WK:A6, WP:B7, WP:A4, BK:C7, BP:D5, BP:A1, Last Moves:A1A4, D1A1.
  
Then we will somehow say "Now play a game with a bot to practice!" and make the player play againts novice ai. After they finish the game, it should automatically navigate them to the home page. 