# survivors-game

A survivors-style action game built with **Godot 4.7**.

## Run (desktop)

1. Open Godot 4.7+
2. Import / open this folder (`survivors-game`)
3. Press **F5** (or Play)

Or from a terminal (if `godot` is on your PATH):

```bash
godot --path .
```

## Play in a browser (GitHub Pages)

This repo exports a **single-threaded Web** build (Compatibility renderer on web only; desktop stays Forward+) and deploys it with GitHub Actions.

1. In the GitHub repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**
2. Merge to `master` (or run the **Deploy Web to GitHub Pages** workflow)
3. Open `https://<owner>.github.io/survivors-game/`

### Local web export

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
# Serve over HTTP (required by browsers for WASM):
python3 -m http.server -d build/web 8080
```

## Controls

| Input | Action |
| --- | --- |
| WASD / Arrow keys | Move (desktop) |
| On-screen stick | Move (touch / phone) |
| (automatic) | Fire at nearest enemy |
| Enter or **Retry** | Restart after death |

## Project layout

```
scenes/     # main, player, enemy, projectile
scripts/    # gameplay scripts
export_presets.cfg
.github/workflows/deploy-pages.yml
project.godot
```

## Current prototype

- Top-down movement
- Auto-targeting weapon
- Enemy waves that ramp up over time
- Health, kills, survival timer, and retry
- Touch controls + GitHub Pages web build
