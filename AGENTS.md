# Agent Guidelines & Workflow Rules

## 1. Task Tracking & Documentation
- **Update `TODO.md`**: Whenever a task, subtask, or feature from `TODO.md` is completed, check off its box (`- [x]`). If new subtasks or prerequisites are discovered during implementation, add them under the appropriate phase.
- **Repository Structure**: Update the repository structure tree in `README.md` when new top-level directories, packages, or major architectural modules are added or reorganized. Do not update it for routine single-file additions.

## 2. Code Quality & Verification
- **Backend (Go)**:
  - Follow idiomatic Go conventions (clear package boundaries, proper error handling).
  - Run `go test ./...` in `kita_backend` to ensure no game logic regressions before marking tasks complete.
- **Frontend (Flutter)**:
  - Keep game state decoupled from UI widgets (manage state via controllers/state management rather than storing board logic directly inside widget `setState`).
  - Run `flutter test` or verify static analysis before concluding tasks.

## 3. Communication & Language
- Support dual-language awareness (TR / EN) for in-game terms, error messages, and documentation where applicable. Use EN for in-game text as default.

## 4. Rule Precedence & Conflict Resolution
- **Developer Prompt Overrides**: If an instruction from the developer conflicts with predefined guidelines in `AGENTS.md`, `TODO.md`, or architecture documents, briefly inform the developer of the conflict. If the developer confirms or directs to proceed, prioritize the developer's explicit prompts over predefined rules.
