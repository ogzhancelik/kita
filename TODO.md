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
- [ ] **Frontend**: Configure Flutter localization setup (`flutter_localizations`, `.arb` or JSON translation files).
- [ ] **Frontend**: Implement language switcher (English / Türkçe) with persistence (`shared_preferences`).
- [ ] **Backend**: Standardize error and status messages with language-agnostic error codes.
- [ ] **Content**: Translate all in-game terminology (King/Şah, Pawn/Piyon, Jump/Sıçrama, Repetition/Tekrar, etc.).

### 2. Interactive Tutorial & Game Guide
- [ ] **Rules Reference**: Static visual guide detailing board layout (4×7 grid), piece movements, and capture rules.
- [ ] **Interactive Onboarding**: Step-by-step interactive tutorial board teaching:
  - Movement range and dynamic step calculations
  - Jump mechanisms over other pieces
  - King capture defense / last-stand mechanic
  - Threefold repetition draw condition

---

## 👤 Phase 2: User Identity & Profiles

- [ ] **Auth / Guest System**:
  - [ ] Support Guest/Anonymous play (zero barrier to entry)
  - [ ] User registration & login (email/password or OAuth)
- [ ] **User Profile**:
  - [ ] Custom display name and avatar selection
  - [ ] Player statistics (total matches, wins, losses, win rate, current streak)
  - [ ] Match history summary list (recent opponents, results, dates)

---

## 🤖 Phase 3: Single Player & AI Engine

Allows instant gameplay without relying on active server matchmaking, and serves as an engine testing harness.

- [ ] **Backend AI Logic**:
  - [ ] Implement move generation & evaluation heuristic in Go (`kita_backend`)
  - [ ] Difficulty tiers (e.g., Easy: random/greedy heuristic, Medium: Minimax with alpha-beta pruning, Hard: deeper lookahead/positional weighting)
- [ ] **Game Mode Integration**:
  - [ ] "Play vs Computer" game option
  - [ ] Turn delay simulation for natural AI pacing

---

## ⚔️ Phase 4: Real-Time Multiplayer & Social

### 1. Direct Rooms & Invites
- [ ] **Room Management (Backend)**:
  - [ ] Room creation API with custom settings (time controls, privacy)
  - [ ] Generate short room codes or shareable invite links
  - [ ] Room state lifecycle (Waiting, In-Game, Finished, Closed)
- [ ] **Room Join & Invitation (Frontend)**:
  - [ ] "Create Room" and "Join by Code" screens
  - [ ] Deep-linking support to join via invite link
  - [ ] Friend / user direct invite system

### 2. Matchmaking
- [ ] **Matchmaking Queue (Backend)**:
  - [ ] Real-time queue pool for active players looking for a match
  - [ ] Rating-based matchmaking (pair players within similar skill brackets)
  - [ ] Fallback handling (expand search window if queue wait time exceeds threshold, or offer AI match)
- [ ] **Queue UI (Frontend)**:
  - [ ] "Find Match" matchmaking screen with elapsed timer and cancel option

### 3. In-Match Messaging & Communication
- [ ] **WebSocket Chat Channel**:
  - [ ] Room-scoped chat stream alongside game state packets
  - [ ] Rate limiting and basic profanity/spam prevention
- [ ] **In-Game Chat Features**:
  - [ ] Text chat overlay or slide-out drawer
  - [ ] Quick-reaction emoji buttons / predefined tactical emotes (e.g., "Good move!", "Well played!")

---

## 🏆 Phase 5: Competitive & Leaderboards

- [ ] **Rating System**:
  - [ ] ELO or Glicko rating calculation on match completion (Backend)
  - [ ] Rating adjustment rules for draws, resignations, and disconnects
- [ ] **Leaderboards**:
  - [ ] Global top players ranking (All-time and Seasonal/Monthly)
  - [ ] User rank tier badges (e.g., Bronze, Silver, Gold, Grandmaster)
  - [ ] Filter by friends or regional leaderboard

---

## 📜 Phase 6: Match Recording, Replay & Analysis

- [ ] **Match Recording**:
  - [ ] Persistent match logs in DB (move sequence, timestamps, piece states, final outcome)
  - [ ] Export match notation (JSON or custom PGN-like format)
- [ ] **Replay Viewer**:
  - [ ] Step-by-step game playback (Next move, Previous move, Jump to start/end, Auto-play with speed controls)
  - [ ] Turn indicator and captured piece timeline
- [ ] **Game Analysis**:
  - [ ] Highlight critical turns, blunders, and winning moves
  - [ ] Interactive "sandbox" fork: test alternate moves from any board state in the replay

---

## 🎨 UI & Design Systems

*(Note: UI tasks, styling specifications, animations, sound design, and component breakdown will be updated later.)*
