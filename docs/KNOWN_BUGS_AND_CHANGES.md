# Known Bugs & Changes

This document tracks identified bugs, UX glitches, and quick changes across the client and engine.

---

## 🐛 Known Bugs

- [ ] **Form Focus & Tab Navigation**: `Tab` key in Login and Sign-In forms cycles to prefix/suffix icons and password toggle buttons instead of jumping strictly between text inputs.
- [ ] **Mobile Keyboard Action & Layout Overflow**: Mobile keyboard shows enter button instead of `next`/`done` actions, and fixed-height form layout on login clips the bottom action/play button when keyboard is visible.
- [ ] **Top Players Podium Layout Distortion**: Long nicknames in the top players leaderboard cause text truncation and distort podium alignment.
- [ ] **Replay Navigation Double-Click Glitch**: When scrubbing back to the latest move in the move ribbon using arrows, two clicks are required to regain interactive move control.
- [ ] **Settings Tutorial Dialog Padding**: Excessive outer padding when opening the Tutorial modal directly from the in-game / main Settings menu.
- [ ] **Tutorial Movement Step Coverage**: The onboarding tutorial scenario does not demonstrate basic single-tile movement (1-tile step).
- [ ] **Notification Read State Synchronization**: When an in-app message notification is dismissed or ignored, or when a message is read directly, the unread badge is not reliably cleared across the top bar and chat tiles.
- [ ] **Active Match Turn Indicator Refresh**: The turn indicator on the Home Dashboard active/ongoing match card does not update in real time when the opponent makes a move.

---

## 🔄 Changes & Adjustments

- [ ] 90 degrees piece orientation in local coop setting is the wrong way clockwise
- [ ] improve tutorial
- [x] There are too many explanations everywhere, prune them ("play" hamburger menu, "play vs computer" choice menu etc.)
- [x] It says easy/medium/hard in Replay Mode for AI's instead of their correct names. Instead, remove the ELO from bots and put correct beginner/intermediate/grandmaster names there, just like it is in play mode.
- [ ] No time etc. choice in Local 2P Coop mode. Should be?
- [ ] Rearrange settings menu
- [x] Remove names of time modes (bullet, blitz, rapid)
- [x] Nickname convention (min 2, max 15, allowed chars [a-zA-Z0-9_-], no whitespace, case-insensitive uniqueness, reserved names list)