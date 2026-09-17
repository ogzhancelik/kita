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
- [ ] **Content**: Translate all in-game terminology (King/Şah, Pawn/Piyon, Jump/Sıçrama, Repetition/Tekrar, etc.).

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
- [ ] **User Profile**:
  - [x] Custom display name and avatar selection (Guest profile onboarding & avatar picker)
  - [x] Player statistics (total matches, wins, losses, win rate, current streak)
  - [x] Match history summary list (recent opponents, results, dates)

---

## 🤖 Phase 3: Single Player & AI Engine

Allows instant gameplay without relying on active server matchmaking, serves as an engine testing harness, and provides intelligent sparring partners.

### 1. Offline Engine (Local Play)
- [x] **Local Pass & Play**: Single device 2-player pass-and-play with board flipping and theme controls.
- [x] **Rule Enforcement**: Reversal prevention, Last-Stand revenge draw condition, and stalemate checks.

### 2. AI Engine Integration
- [x] **Inference Engine (Pure Dart Forward Pass)**:
  - [x] Export PyTorch weights to flat JSON (`export_weights.py`).
  - [x] Implement pure-Dart neural network forward pass (`kita_neural_net.dart`) — matrix multiply, LayerNorm, ReLU, Tanh.
- [x] **State Encoding & Action Space Representation**:
  - [x] Serialize Kita board state into 7-channel × 20-tile feature tensor matching training pipeline (`kita_ai.dart`).
  - [x] Map model output value + negamax search back to valid `KitaMove` actions via legal move ranking.
  - [x] Legal move masking guaranteed by evaluating only `getLegalMoves()` candidates.
- [x] **Difficulty & Sparring Configuration**:
  - [x] Three AI difficulty tiers (Easy: depth=1/temp=0.5, Medium: depth=2/temp=0.2, Hard: depth=3/temp=0.1) in `offline_ai_screen.dart`.
- [x] **Frontend Integration (Offline)**:
  - [x] AI Bot integrated into `offline_ai_screen.dart` as unified Easy / Medium / Hard difficulty options.
  - [x] Opening book (923 positions) bundled as Flutter asset for instant lookup.

---

## ⚔️ Phase 4: Real-Time Multiplayer & Social

### 1. Direct Rooms & Invites
- [x] **Room Management (Backend)**:
  - [x] Room creation API with custom settings (time controls, privacy)
  - [x] Generate short room codes or shareable invite links
  - [x] Room state lifecycle (Waiting, In-Game, Finished, Closed)
- [ ] **Room Join & Invitation (Frontend)**:
  - [ ] "Create Room" and "Join by Code" screens
  - [ ] Deep-linking support to join via invite link
  - [ ] Friend / user direct invite system

### 2. Matchmaking
- [ ] **Matchmaking Queue (Backend)**:
  - [x] Real-time queue pool for active players looking for a match
  - [x] Rating-based matchmaking (pair players within similar skill brackets)
  - [ ] Fallback handling (expand search window if queue wait time exceeds threshold, or offer AI match)
- [ ] **Queue UI (Frontend)**:
  - [ ] "Find Match" matchmaking screen with elapsed timer and cancel option

### 3. In-Match Messaging & Communication
- [ ] **WebSocket Chat Channel**:
  - [x] Room-scoped chat stream alongside game state packets
  - [ ] Rate limiting and basic profanity/spam prevention
- [ ] **In-Game Chat Features**:
  - [ ] Text chat overlay or slide-out drawer
  - [ ] Quick-reaction emoji buttons / predefined tactical emotes (e.g., "Good move!", "Well played!")

---

## 🏆 Phase 5: Competitive & Leaderboards

- [x] **Rating System**:
  - [x] ELO or Glicko rating calculation on match completion (Backend)
  - [x] Rating adjustment rules for draws, resignations, and disconnects
- [x] **Leaderboards**:
  - [x] Global top players ranking (Backend API & Frontend Leaderboard Screen with Top 3 Podium)
  - [ ] User rank tier badges (e.g., Bronze, Silver, Gold, Grandmaster)
  - [ ] Filter by friends or regional leaderboard

---

## 📜 Phase 6: Match Recording, Replay & Analysis

- [ ] **Match Recording**:
  - [x] Persistent match logs in DB (move sequence, timestamps, piece states, final outcome)
  - [ ] Export match notation (JSON or custom PGN-like format)
- [ ] **Replay Viewer**:
  - [ ] Step-by-step game playback (Next move, Previous move, Jump to start/end, Auto-play with speed controls)
- [ ] **Game Analysis**:
  - [ ] Highlight critical turns, blunders, and winning moves
  - [ ] Interactive "sandbox" fork: test alternate moves from any board state in the replay

---

## 🎨 UI & Design Systems

- [x] **Modular Kita Board Component**: Responsive board widget supporting responsive scaling (`LayoutBuilder`), horizontal (7x4) and vertical (4x7) orientations, transparent non-playable hole cells, custom themes (Classic, Dark Slate, Wood), dynamic tile values, and piece movement handlers.
- [x] **Tactile UI System**: Chess.com-style 3D buttons, floating toast notifications, and dark/light mode theming.
