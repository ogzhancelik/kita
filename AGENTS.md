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

## 3. Communication, Localization & Language
- **Dual-Language Awareness**: Support dual-language awareness (TR / EN) for in-game terms, error messages, and documentation where applicable. Use EN as default language.
- **Strict UI Localization**:
  - **No Hardcoded Strings**: All user-facing text (labels, buttons, dialogues, notifications, tooltips, error messages) MUST be extracted into translation files (`kita_frontend/assets/translations/en.json` and `tr.json`). Avoid hardcoding display text directly inside UI widgets.
  - **Exceptions**: Universal standard acronyms or game notations (e.g., shorthand game notation or W/L/D ratios) may remain untouched if translating them causes confusion, but surrounding descriptions or labels must be localized.
  - **Key Synchronization Across Translation Files**: Whenever a new string or key is introduced, add it to ALL active language files (`en.json` and `tr.json`). If the translation for `tr.json` is outside immediate scope or uncertain, insert the English text into `tr.json` as a placeholder so that keys never fall out of sync and can be translated later.

## 4. Rule Precedence & Conflict Resolution
- **Developer Prompt Overrides**: If an instruction from the developer conflicts with predefined guidelines in `AGENTS.md`, `TODO.md`, or architecture documents, briefly inform the developer of the conflict. If the developer confirms or directs to proceed, prioritize the developer's explicit prompts over predefined rules.
