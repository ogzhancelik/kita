# Kita Fullstack — MVP Roadmap & To-Do List

This document outlines the planned features and development milestones for the Minimum Viable Product (MVP) of **Kita Fullstack**. Tasks are organized in a logical progression from foundational systems to multiplayer infrastructure and competitive features.

---

## 📋 Phase Overview & Sensible Progression

```
[Phase 1: Foundation & Onboarding] ──► [Phase 2: Identity & Profiles]
                 │
                 ▼
[Phase 3: Solo Play & AI Engine]   ──► [Phase 4: Real-Time Multiplayer & Rooms]
                 │
                 ▼
[Phase 5: Competitive & Rankings]  ──► [Phase 6: Replay & Analysis System]
```

---

## 🌐 Phase 1: Foundation & Onboarding

Foundational systems to establish early so game strings and rules are never hardcoded.

### 1. Localization (i18n / l10n) — TR & EN
- [x] **Frontend**: Configure Flutter localization setup (`easy_localization`, JSON translation files `en.json`, `tr.json`).
- [x] **Frontend**: Implement language switcher (English / Türkçe) with runtime toggle & persistence.
- [x] **Backend**: Standardize error and status messages with language-agnostic error codes.
- [x] **Content**: Translate all in-game terminology (King/Şah, Pawn/Piyon, Jump/Sıçrama, Repetition/Tekrar, etc.) across en.json and tr.json with full key synchronization.

### 2. Interactive Tutorial & Game Guide
- [ ] **Rules Reference**: Static visual guide detailing board layout (4×7 grid), piece movements, and capture rules.
- [ ] **Interactive Onboarding**: Step-by-step interactive tutorial board teaching:
  - Movement range and dynamic step calculations
  - King capture defense / last-stand mechanic
  - Threefold repetition draw condition
---

## 👤 Phase 2: User Identity & Profiles

- [x] **Auth / Guest System**:
  - [x] Support Guest/Anonymous play (zero barrier to entry)
  - [x] User registration & login (email/password or OAuth)
- [x] **User Profile**:
  - [x] Custom display name and avatar selection (Guest onboarding, logged-in user profile avatar picker & backend sync)
  - [x] Player statistics (total matches, wins, losses, win rate, current streak)
  - [x] Match history summary list (recent opponents, results, dates)
  - [x] Dedicated User Profile modal dialog & detailed stats view
- [ ] **Settings & Preferences**:
  - [x] Backend settings API (`/api/settings`) & DB persistence (board themes, audio, orientation, move highlights)
  - [x] In-game integration: wire board themes, orientation, flip direction, and match settings dialog

---

## 🤖 Phase 3: Single Player & AI Engine

Allows instant gameplay without relying on active server matchmaking, serves as an engine testing harness, and provides intelligent sparring partners.

### 1. Offline Engine (Local Play)
- [x] **Local Pass & Play**: Single device 2-player pass-and-play with board flipping and theme controls.
- [x] **Rule Enforcement**: Reversal prevention, Last-Stand auto-retaliation draw & immediate win/loss condition, and stalemate checks.

### 2. AI Engine Integration
- [x] **Inference Engine (Pure Dart Forward Pass)**:
  - [x] Export PyTorch weights to flat JSON (`export_weights.py`).
  - [x] Implement pure-Dart neural network forward pass (`kita_neural_net.dart`) — matrix multiply, LayerNorm, ReLU, Tanh.
- [x] **State Encoding & Action Space Representation**:
  - [x] Serialize Kita board state into 7-channel × 20-tile feature tensor matching training pipeline (`kita_ai.dart`).
  - [x] Map model output value + negamax search back to valid `KitaMove` actions via legal move ranking.
  - [x] Legal move masking guaranteed by evaluating only `getLegalMoves()` candidates.
- [x] **Difficulty & Sparring Configuration**:
  - [x] Pre-game configuration dialogue (`VsAiConfigDialog`) with three AI difficulty tiers (Beginner: 1000 ELO / Intermediate: 1200 ELO / Grandmaster: 1400 ELO), Side selection (White / Random / Black), and local persistence of user preferences.
- [x] **Frontend Integration (Offline)**:
  - [x] AI Bot and Local Pass & Play integrated directly into the unified modern `OnlineMatchScreen` architecture, eliminating legacy prototype screen.
  - [x] Opening book (923 positions) bundled as Flutter asset for instant lookup.
  - [x] Player side selection (White / Black / Random) with auto-opening move for AI when playing as White, perspective board flipping, and dynamic turn indicators.

---

## ⚔️ Phase 4: Real-Time Multiplayer & Social

### 1. Direct Rooms & Invites
- [x] **Room Management (Backend)**:
  - [x] Room creation API with custom settings (time controls, privacy)
  - [x] Generate short room codes or shareable invite links
  - [x] Room state lifecycle (Waiting, In-Game, Finished, Closed)
  - [x] Paginated public rooms listing API with search & limits
  - [x] Real-time public rooms list broadcasting & sync across all connected clients on room creation, joining, cancellation, and disconnection
- [x] **Room Join & Invitation (Frontend)**:
  - [x] "Create Room" dialog with time controls (Bullet, Blitz, Rapid, Unlimited) & private toggle
  - [x] "Join by Code" dialog with 6-character room code input
  - [x] Paginated public room browser screen (`RoomBrowserScreen`) with pull-to-refresh
  - [x] Friend / user direct invite system & Rematch requests via unified top-of-screen animated notification banner (`TopMatchInviteBanner`) with countdown timer and one-tap accept/decline
  - [x] Friend invite side/color preference dialog (Random, White, Black) and recipient side indicator
  - [x] Real-time friend online presence synchronization (`Hub.IsUserOnline`), offline challenge guard with clear UI warning, and server-confirmed invitation feedback (preventing false "invite sent" toasts when challenged friend is offline)
  - [x] Ephemeral Live Challenge Lifecycle: 60-second automatic challenge timeout on Hub, automatic teardown and friend cancellation on disconnect (`handleDisconnect`), and notification inbox expiration guard (`isExpired` / "Süresi Doldu" badge) preventing invalid acceptance of dead challenges
  - [x] Single-item priority Pending/Active Game section on Dashboard above notifications: seamless Rejoin for active matches (with backend disconnect grace period & reconnection support), open room info (synchronized with live rooms list, host room tracking, host room excluded from joinable open rooms list, and swipe to close), and outgoing friend challenges (swipe to cancel with real-time removal & database deletion from friend's notifications)
  - [x] Mutual Exclusivity & Activity Preemption Guard: Canonical state handling preventing overlapping activities (Active Match, Open Room, Outgoing Challenge, Queue). Soft states provide interactive confirmation prompts ("Change Activity?") across room creation, joining, friend invites, and incoming challenge acceptance, backed by unified backend teardown (`cleanupWaitingRoomLocked`, `cleanupPendingInviteLocked`).

### 2. Matchmaking
- [x] **Matchmaking Queue (Backend)**:
  - [x] Real-time queue pool for active players looking for a match
  - [x] Rating-based matchmaking (pair players within similar skill brackets)
  - [x] Live online player count & queue count broadcasting
  - [x] Unbiased 50/50 side toss (White/Black) when pairing players from queue
- [x] **Queue UI (Frontend)**:
  - [x] "Find Match" matchmaking bottom sheet with animated pulse, online counter, low-count warning, elapsed timer, and cancel option

### 3. In-Match Messaging & Communication
- [x] **WebSocket Chat Channel**:
  - [x] Room-scoped chat stream alongside game state packets
  - [x] Rate limiting (max 200 chars) and message validation
- [x] **In-Game Chat & Navigation Features**:
  - [x] Inline chat panel (`ChatPanel`) with unread badge counter, auto-scroll, and sticked layout with player cards and board
  - [x] In-game bottom bar with match elapsed timer and chat toggle
  - [x] In-game Hamburger Menu: Quick access to Settings (`SettingsDialog` / `MatchSettingsDialog`), Resign, Draw Offer, and Rotate Board (dynamic board panel and chat panel resizing keeping all components sticked together)
  - [x] In-game Board Interaction: Smooth drag-and-drop piece movement + tap-to-move; dynamic hover feedback on valid drop targets; deselect already selected tile on second tap; inspect own pieces & legal moves during opponent turn without moving
  - [x] Post-Game Board & Match Review: Dismissible Game Over dialog with close button ('X'), backdrop tap-to-dismiss, and 'Review Board' action allowing players to freely inspect the final board, step through moves, and use in-game chat; persistent match outcome top banner with one-tap 'Show Results', Rematch, and Leave controls; and match menu post-game options.

### 4. Persistent Notifications (Backend-Driven)
- [x] **Backend Infrastructure**:
  - [x] PostgreSQL `notifications` table schema with GORM auto-migration (`domain.Notification`).
  - [x] Repository and Service layer (`NotificationRepository`, `NotificationService`) supporting pagination, unread counts, status transitions, and dismissal.
  - [x] REST API endpoints (`GET /api/notifications`, `PATCH /api/notifications/:id/status`, `POST /api/notifications/mark-all-read`, `DELETE /api/notifications/:id`).
  - [x] Automatic database persistence of friend requests, accept/decline responses, friend match challenges, and challenge/rematch rejections in `FriendHandler` and `Hub`.
- [x] **Frontend Synchronization**:
  - [x] `NotificationApiService` with Dio client and API constants.
  - [x] `KitaNotification` serialization (`fromJson` / `toJson`).
  - [x] `NotificationProvider` optimistic state management with background API synchronization.
  - [x] Automatic startup loading and polling synchronization across dashboard and notification views.

---

## 🏆 Phase 5: Competitive & Leaderboards

- [x] **Rating System**:
  - [x] ELO or Glicko rating calculation on match completion (Backend)
  - [x] Rating adjustment rules for draws, resignations, and disconnects
- [x] **Leaderboards**:
  - [x] Global top players ranking (Backend API & Frontend Leaderboard Screen with Top 3 Podium)
  - [x] Filter by friends leaderboard

---

## 📜 Phase 6: Match Recording, Replay & Analysis

- [x] **Match Recording**:
  - [x] Persistent match logs in DB (compact single-table JSONB move sequence, think time `time_ms`, piece transitions, and outcome)
  - [x] Offline Play vs Computer game saving in device storage (`LocalMatchHistoryService`)
  - [x] Guest match isolation and automatic cleanup on guest logout or quit
  - [x] Match History toggle filter to show/hide offline matches with synchronized replay viewer
- [x] **Replay & Review Viewer**:
  - [x] Step-by-step game playback (Next move, Previous move, Jump to start/end, Auto-play with speed controls)
  - [x] Post-game review workflow: Replay past recorded matches directly from match history (both online and offline matches)
  - [x] Direct post-game AI review entry: "Review Match" on Play vs Computer game over panel directly opens AI Match Replay screen
  - [x] Unified In-Game Template Redesign: Modern layout matching online/offline game screens (Exit & settings top panel, Opponent info bar, Board, Player info bar with player's color on bottom-right, AI advantage bar below player's info, expanded move list where chat is located, and bottom playback controls panel)
- [x] **Game Analysis & AI Evaluation**:
  - [x] AI Advantage Bar: Visual evaluation bar showing real-time board balance and which team (White vs. Black) is advantageous at any board state
  - [x] Post-game AI move review & quality indicators: Real-time advantage deltas (e.g. +0.1, -0.3, 0.0), semantic color badges (good, inaccuracy, mistake, blunder), and tooltips next to moves in Match History AI Review & Sandbox fork
  - [x] Interactive "sandbox" fork: test alternate moves from any board state in the replay

---

## 🎨 UI & Design Systems

- [x] **Modular Kita Board Component**: Responsive board widget supporting responsive scaling (`LayoutBuilder`), horizontal (7x4) and vertical (4x7) orientations, transparent non-playable hole cells, custom themes (Classic, Dark Slate, Wood), dynamic tile values, and piece movement handlers.
- [x] **UI Redesign - Board & Move Notation (Section 2)**:
  - Flex & Expanded inside AspectRatio layout: perfect 1:1 square tiles with no pixel drift or overflow.
  - Zero-margin edge-to-edge screen fit: removed outer coordinate bars/margins.
  - In-tile coordinates: A, B, C, D on column 0 (bottom-left) and 1..7 on bottom row (bottom-right); tile values at top-left.
  - Centered & proportionally scaled pieces inside tile safe area.
  - Standardized algebraic move notation (`A2C3` for pawns, `♚A2C3` for kings).
  - Maintained full backwards-compatibility with custom themes (`KitaBoardTheme`), heatmap palettes, and piece builders.
- [x] **Tactile UI System**: Chess.com-style 3D buttons, floating toast notifications, and dark/light mode theming.
- [x] **UI Redesign - Portrait Game Screen (Section 3)**:
  - Top bar with centered total elapsed match time (`MatchTopBar`).
  - Horizontal scrollable move history ribbon (`MoveHistoryPanel`) with synchronized scrubbing.
  - Mirrored player cards (`PlayerInfoBar`): Opponent (avatar/name/elo left, clock right with real-time opponent avatar synchronization), User (clock left, name/elo/avatar right with tap-to-profile modal).
  - Zero-margin edge-to-edge board fit: board spans 100% width with 0 padding to screen borders.
  - Inline responsive chat (`ChatPanel`): open by default; when toggled closed, board cleanly centers via distributed vertical alignment; when soft keyboard opens, secondary elements hide and board shrinks to fit without overflow.
  - Bottom control bar (`MatchBottomBar`): menu with Resign, Draw Offer, and Report Opponent dialogs; Chat toggle; and `<` / `>` move history step buttons.
  - Strict zero page margins with balanced, equal horizontal container padding.
- [ ] **Drag & Drop Piece Movement**:
  - Support dragging and dropping pieces onto valid target tiles as an intuitive alternative/addition to tap-to-select and tap-to-move.
  - Visual feedback during drag (lifted piece preview, hover / valid drop target highlights, snap-to-tile).
- [x] **In-Game Move History Panel**:
  - [x] Dedicated in-game panel displaying the chronological list of moves made during a match (White / Black turns, notation, piece icons).
  - [x] Interactive navigation to view previous moves and state progression during gameplay (Chess.com-style scrub and live return).
- [ ] **Last Move Indicator & Toggle Setting**:
  - Visual highlight / marker on origin and destination tiles of the last executed move (essential for Kita's reversal prevention and last-stand tracking).
  - In-game / user settings toggle option to enable or disable the "Last Move" visual indicator (Backend ready, frontend integration pending).
- [x] **Leaderboard Floating Player Indicator & Seamless Scroll**:
  - Automatically detect if current player's profile row is outside visible viewport (above or below).
  - Floating row docked at top or bottom with directional arrow, user rank, avatar, rating, and win rate.
  - Seamless animated scroll (`Scrollable.ensureVisible`) to player's row on tap, with auto-hiding when row is in view.
  - Unranked / 50+ player support pinned at bottom.
- [x] **Notifications System & Hub**:
  - [x] Shared real-time state management (`NotificationProvider`) across all screens with reactive updates.
  - [x] Actionable priority hierarchy: Rematch (1) > Challenge (2) > Friend Request (3).
  - [x] Home menu notification summary card docked above Leaderboard with max 3 non-interacted items and auto-fill on dismiss.
  - [x] Reusable notification tile with right-aligned accept/decline buttons and horizontal swipe-to-ignore (`Dismissible`).
  - [x] Main Notifications Screen (`NotificationsScreen`) displaying chronological notifications, auto-marking informational alerts as read on mount, and dimming read/ignored items.
  - [x] Intelligent top floating dialog: suppressed on home dashboard screen, displayed on other screens (e.g. Settings, Leaderboard, Friends, In-Game).

