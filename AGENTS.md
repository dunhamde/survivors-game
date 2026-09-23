# AGENTS.md

## Worktree and branch workflow

- Start each new coding chat in its own worktree and feature branch before changing project files. Use `codex/<short-chat-topic>` for Codex chats. Reuse that worktree and branch for fixes and features requested later in the same chat.
- Never let two active chats or agents edit the same worktree. Prefer a Codex-managed worktree when starting a new Codex chat; otherwise create a Git worktree for its branch. Keep the main checkout available for review and integration when practical.
- When possible, fetch `origin` first and branch from the current `origin/master`. If the remote cannot be reached, branch from the latest locally known `origin/master` and tell the user it could be stale.
- Commit and push completed work to the chat branch. Do not push directly to `master`, mix in unrelated changes, or merge the chat branch until the user asks to merge it.

## Project

This is a **Godot 4.7 (GDScript)** survivors-style action prototype. There is no package manager, build step, or test framework; the Godot engine is the only dependency.

### Running the game

- Run `godot --path .` from the repo root. The main scene is `res://scenes/main.tscn`, configured in `project.godot`.

### Controls
WASD / arrow keys to move; the weapon auto-fires at the nearest enemy; Enter retries after death.

### "Lint" / checking scripts

There is no standalone linter or automated test suite. To validate that GDScript parses, run `godot --headless --import`. This generates `.godot/` (gitignored) and per-script `*.uid` cache files.
