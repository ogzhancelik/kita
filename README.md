# Kita Fullstack

Welcome to the **Kita** repository! This project is a complete fullstack implementation of the "Kita" board game. It separates the core game engine from the user interface, utilizing a modern, scalable architecture.

## Project Structure

This repository is split into two main components:

### 1. Backend (`kita_backend`)
- **Language**: Go
- **Description**: Contains the core game engine, REST API, WebSocket hub for real-time multiplayer, and PostgreSQL repository layer.
- **Running the API & WebSocket server**:
  ```bash
  cd kita_backend
  go run cmd/api/main.go
  ```
- **Running tests**:
  ```bash
  cd kita_backend
  go test -v ./...
  ```
- **Testing via Bruno / WebSockets**:
  Collection available in `kita_backend/bruno`. Connect to `ws://localhost:8080/ws?token=<JWT>`.

### 2. Frontend (`kita_frontend`)
- **Framework**: Flutter
- **Description**: The cross-platform user interface for the Kita game. Currently initialized as a template, this project will provide a rich, interactive, and aesthetic UI for playing the game across Web, Desktop, and Mobile devices.
- **Future Plans**: Will connect to the Go backend via WebSockets to synchronize game state in real-time.

### 📁 Repository Structure

```text
Kita_Fullstack/
├── README.md                   # Project documentation & overview
├── kita_backend/               # Go backend game engine, REST API & WebSocket server
│   ├── cmd/
│   │   ├── api/
│   │   │   └── main.go         # HTTP & WebSocket API server entry point
│   │   └── cli/
│   │       └── main.go         # Terminal-based CLI game entry point
│   ├── internal/
│   │   ├── core/               # Domain models and repository ports
│   │   ├── game/               # Real-time Hub, Room, and Client managers
│   │   ├── handler/            # HTTP and WebSocket controllers
│   │   ├── repository/         # PostgreSQL persistence layer with GORM
│   │   └── service/            # Auth, User, Match, and Message business logic
│   ├── pkg/
│   │   └── game/               # Core board rules, pieces, and move validation
│   ├── bruno/                  # Bruno API & WebSocket test collection
│   └── go.mod                  # Go module definition
└── kita_frontend/              # Flutter cross-platform user interface
    ├── lib/
    │   └── main.dart           # Flutter application entry point
    ├── test/
    │   └── widget_test.dart    # Frontend widget & unit tests
    ├── pubspec.yaml            # Flutter packages & build configuration
    ├── android/                # Android platform runner
    ├── ios/                    # iOS platform runner
    ├── linux/                  # Linux desktop runner
    ├── macos/                  # macOS desktop runner
    ├── web/                    # Web platform runner
    └── windows/                # Windows desktop runner
```

## Prerequisites
- **Go**: Version 1.21 or higher.
- **Flutter**: Latest stable release (Ensure `flutter/bin` is added to your system PATH).


## Game Overview & Pieces

* **Board**: 4 rows × 7 columns grid.
* **Pieces**:
  * **White**: King (`WK`), Pawn 1 (`WP1`), Pawn 2 (`WP2`)
  * **Black**: King (`BK`), Pawn 1 (`BP1`), Pawn 2 (`BP2`)
* **Movement**: Step-count is dynamically determined by tile distances and rules.
* **Winning / Terminal Conditions**:
  * Capturing the opponent's king (with last-stand defense mechanic).
  * Threefold repetition results in a draw.

---