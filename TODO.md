# Kita Fullstack — Roadmap & To-Do List

This document tracks planned features, active backlog items, and completed milestones for **Kita Fullstack**.

---

## 📋 Backlog & In Progress

### 🔐 Auth, Forms & Account Management
- [x] **Strict Username Validation**: Disallow whitespace and invalid special characters in username/nickname registration (min 2, max 15, alphanumeric/underscore/hyphen, case-insensitive uniqueness, reserved keywords).
- [x] **Dedicated Account Settings Tab**: Extract avatar and user profile options into a dedicated Account Settings view, supporting password change and account deletion.
- [x] **Password Confirmation for Account Deletion**: Require entering current account password instead of a simple confirmation checkbox before permanently deleting user account.

### 🎨 UI & Design Systems
- [x] **Unified Design System & Screen Harmonization (Leaderboard Parity)**:
  - [x] **Auth Pages Vertical Centering**: Vertically center all content (emblem/logo, forms, buttons) on `LoginScreen` and `RegisterScreen` while preserving top bar and on-screen keyboard scrolling.
  - [x] **Guest Setup Simplification**: Streamline `GuestSetupScreen` to exclusively feature the nickname input, randomize button, and play button, removing the avatar preview and avatar grid (auto-assigning a default avatar).
  - [x] **Avatar Selector Differentiation**: Visually segregate default classic icons from custom emote/emoji selection into distinct sections with dedicated styling rather than a mixed 3x3 grid.
  - [x] **Centered Username in Profile Overview**: Ensure the username in `UserProfileDialog` remains strictly centered, preventing the right-hand customize icon from shifting it off-center.
  - [x] **Registered Tag Removal & Guest Ranking Text**: Remove the "Registered Player" tag across all views (`UserProfileDialog`, `AccountSettingsDialog`), and replace numeric ranking displays for guest accounts with localized `"GUEST"` text.
  - [x] **Main Menu Action Buttons Parity**: Unify "+ Add Friend" (`dashboard_friends_ribbon.dart`) and "+ Create Room" (`dashboard_open_rooms_card.dart`) in shape, typography, padding, width, and styling matching the create room button.
  - [x] **Floating Action Button for Friend Search**: Replace the dedicated search tab in `FriendsScreen` with a bottom-right floating action button (matching `RoomBrowserScreen`) to launch the player search view.
  - [x] **Leaderboard-Style Segmented Tab Bar for Friends**: Replace `FriendsScreen`'s standard Flutter `TabBar` with the segmented pill toggle bar matching `LeaderboardScreen` (`_buildFilterSelector`), supporting Friends and Friend Requests tabs with badge counter.
  - [x] **Screen Layout Consistency (Leaderboard Parity)**: Standardize secondary screens (`FriendsScreen`, `RoomBrowserScreen`) to follow `LeaderboardScreen` styling: `KitaAppBar`, unified background colors, `ResponsiveLayout(maxWidth: 640)`, card padding, page padding, button hierarchy and general styling.
  - [x] **Vertical Gradient Backdrop for Main Menu Play Button**: In `DashboardScreen`, add a smooth vertical gradient backdrop behind `DashboardActionDock` (fading from background color to transparent) to eliminate abrupt overlap with scrolling content.
  - [x] **Separation of Board Settings & Match Settings Dialogs**: In `SettingsDialog`, rename the existing configuration dialog to "Board Settings" (`BoardSettingsDialog` focusing on themes, tile colors, tile style, and last move indicator), and create a separate "Match Settings" dialog (`MatchSettingsDialog` for board orientation, piece rotation, and flip viewpoint).
  - [x] **Minimalist 3x2 Board Theme Grid**: In board theme selection, keep the 3-tile color palette preview swatches, remove the text labels, and arrange themes into a clean, responsive 3x2 grid with minimal padding.
  - [x] **Hide Local Co-op UI Customizations**: Remove the 2P local co-op board orientation, piece angle, and auto-rotate controls from the settings UI dialogs while preserving underlying functionality and default preferences.
  - [x] **Segmented Toggles for Board & Piece Orientation**: Replace the rotation cycle tiles with Leaderboard-style segmented toggle bars:
    - Board Orientation: Horizontal on the left, Vertical on the right.
    - Piece Rotation / Angle: Fixed 0° on the left, Auto on the right.
 
- [x] **Settings Quick Controls Row**: Consolidate Theme, Vibration, and Sound toggles into a single compact horizontal strip of 3 rounded/square action tiles within the Settings modal.
- [x] **Custom Piece Icons for Move Notation**: Replace generic King icons in the move history ribbon and match replay moves list with custom SVG icon, matching the app's visual identity.
- [x] **Recent Matches Count Indicator**: Remove Recent Matches dashboard header's match counter (e.g., "5").
- [x] **Compact Dashboard Action Symbols**: Convert top-bar notification, chat, and settings circular buttons to sleek clickable icon symbols, saving horizontal space for the user profile card.
- [x] **Settings Menu Cleanup**: Reorder Settings dialog to place "How to Play" immediately above "Logout", and remove the redundant "About Kita" tile.
- [x] **Standardize Draw Outcome Color**: Standardize draw match status badges, chips, and result banners to warning yellow in theme colors.
- [x] **Custom Emoji Profile Avatars & Accent Color Palette**: Allow players to select custom emojis (free text input or quick popular emoji grid) and customize their avatar's background & border accent color from 8 theme tones, or retain classic icon avatars with real-time preview and cross-platform synchronization (matches, chats, leaderboards, profile dialogs).
- [ ] **Text Visibility & Overflow Resilience Audit**: Audit labels, chips, and subtitles across small screens; ensure multi-line reflow (Wrap), tooltips for truncated nicknames/rooms, and fallback ellipsis without losing essential context.
- [x] **Android 12+ Splash Screen Tuning**: Configure native Android splash screen theme to eliminate double-splash flicker on app launch.
- [x] App logo, branding, and icon design (Android launcher icons, Web icons & Kita Online naming)


### 👥 Friends & Social
- [x] **Global Player Search & Friend Requests**: Replace manual nickname entry box with a dedicated player search view backed by server-side query, showing player tiles with inline "Add Friend" actions.
- [x] **Direct Player Challenge**: Allow challenging any user directly from their profile card or chat without requiring an accepted friendship first.
- [x] **Quick "Add Friend" from Match & History**: Add one-tap friend request actions directly inside in-match player cards and post-match history views.
- [x] **Add Friend Shortcut on Home Dashboard**: Add an explicit "+ Add Friend" action to the dashboard friends widget or as a tail card at the end of the friends carousel.
- [x] **Friends List Overflow Action Menu**: Replace inline Challenge, Chat, and Remove action buttons on friends cards with a unified "more options" (three dots) popup menu.

### 💬 Chat & In-Game Messaging
- [ ] **Direct Chat Layout Spacing**: Tighten excessive horizontal/vertical padding in direct message conversation views.
- [ ] **Localized Message Timestamps**: Format direct and in-match message timestamps using the client's local device timezone.
- [ ] **Desktop In-Match Chat Focus**: Auto-focus the match chat input upon typing on desktop/web without requiring an initial mouse click.
- [x] **Chat Emoji Picker & In-Match Reaction Emotes**: Add an emoji selector to chat input and a quick-tap in-game reaction emotes sheet during live matches.

### 🚪 Lobby, Rooms & Matchmaking
- [ ] **Room Waiting State Animation**: Add dynamic loading/searching visual indicator while waiting for opponent in rooms.
- [ ] **Lobby Room Expansion Indicator (>5 Rooms)**: Show a clickable `...` / "View All" tile in the dashboard public rooms widget when more than 5 rooms exist to navigate to the full Room Browser page.
- [ ] **Room Code Share Sheet**: Add one-tap "Share Room Code" action invoking native share sheet (WhatsApp, clipboard, etc.).
- [ ] **Room Join Alert & Timed Match Start Confirmation**: Notify the host immediately upon an opponent joining, and introduce a mutual "Ready" confirmation before starting the countdown clock in timed rooms.

### ♟️ Board & Gameplay Experience
- [x] **Tutorial Redesign & Board Unification**: Revamped step-by-step tutorial with tap-to-progress engine, sequential card reveals, unified KitaGameBoard parity, and practice match against Beginner AI.
- [x] **Scrubbing Live State Restoration**: Clicking the latest move in the notation ribbon should immediately restore interactive live game state with the persistent color.
- [ ] **Automatic Perspective Mirroring**: Auto-orient board perspective so the local player's pieces always appear on the bottom-right across all non-coop modes.
- [x] **Independent Orientation Preferences**: Support independent board orientation and piece angle preferences for Online/AI and Local 2P Co-op modes, with auto-flip and cycle toggles.
- [x] **Local Coop Horizontal Board Flip & Drag Parity**: Auto-flip board in Local Coop mode when default piece orientation is horizontal 90° so the player is positioned at bottom-right, with drag-and-drop feedback offset oriented sideways away from finger in landscape mode.
- [x] **Board & Background Deselect**: Allow deselecting selected pieces when tapping on background areas, holes/gaps inside the board, or board margins.
- [x] **Provisional Rating Display ('?')**: Display provisional unrated status (`?`) for new accounts until calibration match count is completed.

### 📜 Match Analysis, Replay & History
- [x] **Online Post-Match Replay**: Support "Review Match" replay navigation directly from GameOverDialog in online matches.
- [x] **Unified Deep Linking, File Association & Replay Sharing**: Comprehensive match replay sharing supporting in-app sharing links/codes (auto-uploading local offline games to server), direct `.kita` file OS association, and deep link universal routing.
- [x] **Account-Scoped Local Match Storage**: Isolate locally saved matches per user account ID instead of global shared device storage.
- [x] **Match History Lazy Pagination**: Implement infinite scrolling or lazy pagination for the Match History view to optimize performance and prevent bulk fetch lag.
- [x] **Match History Date Grouping Dividers**: Remove individual date badges from match cards and group matches by day with slim date divider headers (e.g. "Today", "Yesterday", "2 Sep 2026", same format as Direct Chat.).
- [x] **Match History Guest & Deleted Player Avatars**: Distinct face avatar with guest orange styling for guests and muted gray styling with gray text for deleted accounts instead of defaulting to Wolf.
- [x] **Match-Time Player Rating Snapshot & Guest Rating Suppression**: Persist and display the exact ratings of players at the time each match was played (preserving historical ratings for deleted and existing accounts), and hide rating indicators for Guest players across live matches, match history, and replays.

### 🛡️ Moderation & Support
- [ ] In-game player reporting system
- [ ] In-app bug report submission system

### 💡 Under Review / Exploratory (To Be Decided)
- [ ] Spectator mode (live match viewing)
- [ ] Achievements & progression badges (for milestones like "First Win", "Undefeated Streak (5/10)", "Defeat Grandmaster AI" etc.)
- [ ] **Connection & Lifecycle Pipeline**: Unified offline/online state pipeline, web vs. mobile disconnect handling, and dynamic visibility/disabled guards across menu widgets.
- [ ] **Web Tab Switch Re-render Investigation**: Analyze why switching browser tabs on web triggers a full menu re-render while game view remains unaffected.
- [ ] **Connection Retry Resiliency**: Validate retry connection edge cases after hot restart or browser cache drops.
- [ ] **System Push Notifications**: OS notifications for opponent moves when app is backgrounded or terminated.
- [ ] **In-Match Chat vs. Direct Message Architecture**: Decide whether in-match chat should mirror direct messages bidirectionally or remain strictly temporary/ephemeral per match.
- [ ] **Password Reset & Account Recovery**: Forgot password and email-based recovery pipeline.
- [ ] **Theme-Adaptive Last Move Indicator**: Custom indicator line/glow styling harmonized with each board theme.
- [ ] **In-Game Settings Menu Simplification**: Redesign and declutter the in-game hamburger settings drawer.

### NEEDS CHECKING
- [ ] Lichess seslerini kullanıyoruz, free to use mu? https://github.com/lichess-org/lila/blob/master/COPYING.md
- [ ] Play Store compliances

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
- [x] **In-App Logo Branding (4-Grid BG + White Pawn)**: Replaced legacy `#` grid icon with vector-exact pawn emblem (matching app_icon SVG geometry, bottom 3D shadow, and 4-grid checkered quadrant colors), and cleaned redundant top-left logo from main menu.
- [x] **User Roles & Tags**: JSONB-backed list on User domain and DB schema with auto-migration, admin/premium/custom tag helpers, and role management API endpoint.

---

### 🤖 Phase 3: Single Player & AI Engine

- [x] **Local Pass & Play**: Two-player single-device play with dynamic board orientation and piece rotation
- [x] **Rule Enforcement**: Full engine validation for reversal prohibition, last-stand retaliation, and draw rules
- [x] **Offline Mode Experience**: Seamless offline dashboard routing, connection banners, and local game state persistence
- [x] **AI Neural Network Engine**: Pure Dart forward-pass inference model with negamax search
- [x] **AI Difficulty & Opening Book**: 5 difficulty tiers (Novice, Beginner, Intermediate, Master, Grandmaster) with depth-4 Negamax search and bundled opening book
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
