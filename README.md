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

## Weapon Lab (art review)

Open the **Weapon Lab** bottom panel beside **Anim Preview**. If it is missing
in an already-open editor, enable **Weapon Lab** under **Project → Project
Settings → Plugins** (or reopen the project).

- **Inspect Art:** select any weapon or evolution, its component, and level.
  Compare the gameplay camera scale (1.75×, before window scaling) with a
  2×/4×/8× detail view. Switch between checkerboard, dark, and actual Elwynn
  grass; optionally show the Paladin. Drag either view to pan and double-click
  to recenter large effects.
- **Open Art Source / Open Weapon Scene:** jump directly to the imported image,
  procedural art script, shader, or weapon scene. **Reload Art / Catalog**
  rediscovers weapon resources and rebuilds generated textures; imported asset
  changes also refresh the panel automatically.
- **Launch Combat Demo:** opens a separate review scene with the selected weapon,
  level, facing, and background. Enable Godot's **Embed Game on Next Play** to
  keep the demo inside the editor. You can also open
  `addons/weapon_lab/combat_demo.tscn` and press **F6**.
- In the demo, select single, bounce-chain, or crowded targets; fire once or loop;
  pause, slow down, change zoom, or restart. Target markers show hit counts.
  Collision outlines and **Freeze rotation** help diagnose unreadable shield or
  libram art. Scroll the controls column if needed.

The demo uses the real weapon scenes and scripts. Review actors use the shared
Paladin/skeleton animation code, but stay in place and never die, so the same
attack can be compared repeatedly. Orbiting weapons stay active until paused;
**Fire once** applies to volleys and pulses. **Restart** repeats the same random
seed. **Reload art / restart** refreshes imported art and procedural caches;
stop and relaunch the demo after editing scripts.

Lightning source textures and Consecration shader snapshots are labeled as
components in the inspection panel; use Combat Demo to judge their complete
animated appearance. New `WeaponData` resources appear automatically; new weapon
families may need a component mapping in `addons/weapon_lab/catalog.gd`.
The last launch selection is stored locally in the ignored `.godot/` folder.

Validation:

```bash
godot --headless --path . --import
godot --headless --path . --script tools/weapon_lab_smoke.gd --fixed-fps 60
```

## Gameplay controls

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
- Skeletons, grunts, ogres, and Hogger
- XP, level-ups, and upgrade choices
- Touch controls + GitHub Pages web build
