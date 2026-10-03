# Kita Fullstack — Roadmap & To-Do List

This document tracks planned features, active backlog items, and completed milestones for **Kita Fullstack**.

---

## 📋 Backlog & In Progress

### 🎨 UI & Design Systems
- [ ] Splash / loading screen
- [ ] App logo, branding, and icon design
- [ ] In-match hamburger menu and settings recoloring.
- [ ] There are too many explanations everywhere, prune them ("play" hamburger menu, "play vs computer" choice menu etc.)

### 🛡️ Moderation & Support
- [ ] In-game player reporting system
- [ ] In-app bug report submission system

### 💡 Under Review / Exploratory (To Be Decided)
- [ ] Spectator mode (live match viewing)
- [ ] Deep linking for match record (universal links/app links) that open the app directly.
- [ ] Achievements & progression badges (for milestones like "First Win", "Undefeated Streak (5/10)", "Defeat Grandmaster AI" etc.)

### NEEDS CHECKING
- [ ] Lichess seslerini kullanıyoruz, free to use mu? https://github.com/lichess-org/lila/blob/master/COPYING.md

---

## ✅ Completed Milestones

### 🌐 Phase 1: Foundation & Onboarding

#### Localization (i18n / l10n)
- [x] Multi-language support (English & Türkçe) with runtime toggle and persistence
- [x] Standardized language-agnostic backend error codes
- [x] Full translation key synchronization across frontend and backend

#### Tutorial & Game Guide
- [x] Comprehensive rules reference guide (board layout, tile values, piece movements, win/draw conditions)
- [x] Interactive onboarding tutorial covering movement, reversal prohibition, last-stand defense, and draws
- [x] First-launch tutorial prompt with skip option and progress saving

---

### 👤 Phase 2: User Identity & Profiles

- [x] **Authentication**: Guest/anonymous play and email registration & login
- [x] **User Profiles**: Custom display names, avatar selection, and profile inspection modal
- [x] **Player Statistics**: Total matches, W/L/D records, win rate, and streak tracking
- [x] **Match History**: Recent match list with termination badges (timeout, resignation, draw) and auto-refresh
- [x] **User Settings**: Cloud & local preferences for board themes, audio, orientation, and move highlights

---

### 🤖 Phase 3: Single Player & AI Engine

- [x] **Local Pass & Play**: Two-player single-device play with dynamic board orientation and piece rotation
- [x] **Rule Enforcement**: Full engine validation for reversal prohibition, last-stand retaliation, and draw rules
- [x] **Offline Mode Experience**: Seamless offline dashboard routing, connection banners, and local game state persistence
- [x] **AI Neural Network Engine**: Pure Dart forward-pass inference model with negamax search
- [x] **AI Difficulty & Opening Book**: 4 difficulty tiers (Novice, Beginner, Intermediate, Grandmaster) with 3-depth blunder-checking tactical search and bundled opening book
- [x] **Unified Game Screen**: Integrated AI and Pass & Play into the standard match interface

---

### ⚔️ Phase 4: Real-Time Multiplayer & Social

#### Rooms & Invites
- [x] Room creation with custom time controls (Bullet, Blitz, Rapid, Unlimited) and privacy settings
- [x] Public room browser with live synchronization and 6-character room codes
- [x] Friend invite system with color preference, real-time presence checks, and expiry timers
- [x] Dashboard active/pending match widget with instant rejoin, cancellation, and activity guards

#### Matchmaking
- [x] Real-time matchmaking queue with rating-based pairing
- [x] Live online player count and queue metrics broadcasting
- [x] Fair 50/50 side allocation and matchmaking bottom sheet UI

#### Chat & Direct Messaging
- [x] In-match WebSocket chat panel with rate limiting and unread counters
- [x] Direct 1-on-1 messaging screen with conversation list and search
- [x] Unread message badges across top bar, friends ribbon, and profile cards

#### Persistent Notifications
- [x] Backend database-driven notification infrastructure with REST API
- [x] Real-time notification synchronization for challenges, friend requests, and system alerts
- [x] Actionable notification banners and home dashboard summary feed

---

### 🏆 Phase 5: Competitive & Leaderboards

- [x] **Rating System**: Post-match rating adjustments with rules for draws, resignations, and timeouts
- [x] **Leaderboards**: Global rankings with podium display and friend-filtered leaderboards
- [x] **Viewport Tracking**: Floating rank indicator for quick navigation to the user's position

---

### 📜 Phase 6: Match Recording, Replay & Analysis

- [x] **Match Recording**: Server-side JSONB move sequence logging and local device history for offline games
- [x] **Interactive Replay Viewer**: Step-by-step playback, auto-play with speed controls, and outcome markers
- [x] **AI Game Analysis**: Visual board advantage bar and move quality badges (good, inaccuracy, mistake, blunder) powered by progressive depth-3 Negamax search refinement
- [x] **Interactive Sandbox Fork**: Explore alternate move variations directly from any replay position
- [x] **Replay Sharing**: Export and import `.kita` / `.json` match files with instant replay viewing

---

### 🎨 Phase 7: UI & Design Systems

- [x] **Modular Game Board**: Responsive edge-to-edge board supporting 7x4 horizontal and 4x7 vertical layouts
- [x] **Board Aesthetics & Themes**: Built-in themes (Classic, Dark Slate, Wood), custom tile coloring, and in-tile coordinates
- [x] **Controls & Interaction**: Drag-and-drop and tap-to-move piece controls with valid-move hover previews
- [x] **Portrait Match Layout**: Clean layout with mirrored player cards, move history ribbon, inline chat, and action controls
- [x] **Last Move Indicators**: Configurable visual trail (Line, Highlight, Off) showing recent moves
- [x] **Move History & Notation**: In-game move ribbon with live board scrubbing and algebraic notation
- [x] **Settings, Audio & Haptics**: In-game audio toggles, sound effects, low-time countdown warning chime, tactile haptic feedback, board themes, and auto-rotation settings
