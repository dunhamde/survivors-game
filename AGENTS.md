# AGENTS.md

## Branch workflow

- Start each new coding chat in its own worktree and feature branch before changing project files. Use `codex/<short-chat-topic>` for Codex chats. Reuse that worktree and branch for fixes and features requested later in the same chat.
- Never let two active chats or agents edit the same worktree. Prefer a Codex-managed worktree when starting a new Codex chat; otherwise create a Git worktree for its branch. Keep the main checkout available for review and integration when practical.
- When possible, fetch `origin` first and branch from the current `origin/master`. If the remote cannot be reached, branch from the latest locally known `origin/master` and tell the user it could be stale.
- Commit and push completed work to the chat branch. Do not push directly to `master`, mix in unrelated changes, or merge the chat branch until the user asks to merge it.

## Cursor Cloud specific instructions

This is a **Godot 4.7 (GDScript)** game — a survivors-style action prototype. There is no package manager, build step, or test framework; the only "dependency" is the Godot engine binary itself. The engine (`godot`, v4.7.1-stable) is installed at `/usr/local/bin/godot`, and the graphics libraries needed for the Forward+ (Vulkan) renderer (`mesa-vulkan-drivers` → software `llvmpipe`, plus `libgl1`/X libs) are installed system-wide. These persist in the VM snapshot; the startup update script only re-installs the engine if it is somehow missing.

### Running the game
- Run from the repo root: `godot --path .` (main scene is `res://scenes/main.tscn`, set in `project.godot`).
- A virtual X display is available at `DISPLAY=:1` — export it (and `XDG_RUNTIME_DIR`, e.g. `export XDG_RUNTIME_DIR=/tmp/xdg-runtime && mkdir -p $XDG_RUNTIME_DIR && chmod 700 $XDG_RUNTIME_DIR`) so the game window renders where computerUse can see it. To play/observe it interactively, launch it under a tmux session on `:1` and drive it with the computerUse subagent.
- Rendering uses **software Vulkan (llvmpipe)** since there is no GPU, so it is slower than native but fully functional.
- Two harmless-but-noisy conditions at startup: (1) ALSA errors ending in `All audio drivers failed, falling back to the dummy driver` — expected, there is no sound card; (2) `vulkaninfo` fails with `BadMatch` when `DISPLAY=:1` is set, but the game itself renders fine on `:1` (run `vulkaninfo` with `DISPLAY` unset to enumerate the llvmpipe device).

### Controls
WASD / arrow keys to move; the weapon auto-fires at the nearest enemy; Enter retries after death.

### "Lint" / checking scripts
There is no standalone linter or automated test suite in this repo. To validate that GDScript parses without errors, run a headless import which parses all scripts and imports assets: `godot --headless --import`. This also generates `.godot/` (gitignored) and per-script `*.uid` cache files.
