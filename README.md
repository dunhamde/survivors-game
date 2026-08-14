# survivors-game

A survivors-style action game built with **Godot 4.7**.

## Run

1. Open Godot 4.7+
2. Import / open this folder (`survivors-game`)
3. Press **F5** (or Play)

Or from a terminal (if `godot` is on your PATH):

```bash
godot --path .
```

## Controls

| Input | Action |
| --- | --- |
| WASD / Arrow keys | Move |
| (automatic) | Fire at nearest enemy |
| Enter | Retry after death |

## Project layout

```
scenes/     # main, player, enemy, projectile
scripts/    # gameplay scripts
project.godot
```

## Current prototype

- Top-down movement
- Auto-targeting weapon
- Enemy waves that ramp up over time
- Health, kills, survival timer, and retry
