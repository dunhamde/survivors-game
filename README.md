# survivors-game

**Elwynn Survivors** — a Warcraft-themed survivors vertical slice (Paladin in Elwynn Forest), built with **Godot 4.7**.

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
| (automatic) | Attack with equipped weapons |
| Tap upgrade cards (or 1 / 2 / 3) | Level-up choice |
| Enter or **Retry** | Restart after the run ends |

## Current slice

- Elwynn Forest map + Goldshire backdrop
- Paladin with Holy Strike, Consecration, Hammer of Wrath
- Skeletons and Hogger
- XP, level-ups, and upgrade choices
- Touch controls + GitHub Pages web build
