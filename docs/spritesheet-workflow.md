# Sprite sheet workflow

Use this guide when adding or replacing a player or enemy sprite sheet. The packed PNG is the game asset; keep the source sheet and its packing script so the atlas can be rebuilt.

## Match the game's layout and scale

- Inspect a comparable existing sheet first. The enemy sheets do **not** share one cell size: skeleton uses 52×52 cells, grunt 72×72, ogre 80×80, and Troll Headhunter 112×80 to leave room for its spear. Compare the visible character, not the cell dimensions. Grunt and ogre walking poses are roughly 35–57 pixels tall.
- For a directional 5×11 sheet, columns are **N, NE, E, SE, S**. Rows 0–4 are walk, 5–8 are attack, and 9–10 hold hit/death art. `SheetAnimator` mirrors east-facing columns for west-facing directions. Keep a consistent pose and weapon direction within each column. Skeleton is an exception: its rows encode all eight directions, with five walking frames per row.
- Keep every final frame entirely inside its own cell, with transparent space above the head and a consistent feet baseline. Anchor the body consistently as arms or weapons extend; centering each frame's whole bounding box can make the body slide during attacks.
- Make the weapon reach fit the cell without enlarging the character to fill it. Check the visible height against grunt or ogre at the same game zoom. An oversized empty cell is acceptable for a long spear; an oversized troll is not.

## Pack and inspect the atlas

1. Save the source under `assets/sprites/` with a `_sheet_raw.png` suffix. Use real transparency in the packed PNG; generated art can contain a faint alpha glow even when the background looks empty.
2. Add or update a reproducible packer under `tools/`. See `process_wc2_sheet.py` for grunt/ogre and `process_troll_sheet.py` for generated art. The existing packers use Python's standard library, so rebuilding assets does not need extra packages. Detect actual sprite row gaps or bounds when the source rows are uneven; dividing the raw image height evenly can put pixels from the preceding pose into the next frame.
3. Crop each pose, scale to the intended **visible** size, align its body and feet, and place it with padding inside the final cell. Check for stray pixels or parts of neighboring poses. The atlas width must be `sheet_cols × cell_width` and its height `sheet_rows × cell_height`.
4. Inspect the packed PNG cell by cell, especially all walk frames and the transition into attack. Verify that no pose is clipped, no prior-row art appears, and the spear stays attached and points in the intended direction.

## Connect it to Godot

- Create or update `data/enemies/<id>.tres` with the texture, `sheet_cols`, `sheet_rows`, `sheet_cols_are_dirs`, `walk_frames`, and the appropriate attack/death row and frame fields. Use explicit `death_cells` when the source death poses are not a simple linear sequence. `SheetAnimator` uses `row * sheet_cols + col` for each frame.
- Attack rows alone do not make an enemy attack. The enemy script must call `_anim.start_attack()` and coordinate any hit timing with the visible thrust.
- Register a new enemy scene and data in `scenes/elwynn_run.tscn` and `scripts/run/wave_director.gd` if it should spawn in the game. Add it to the hardcoded `_catalog()` in `addons/anim_preview/anim_preview_dock.gd` so it appears in Anim Preview.
- For a player sheet, update `SheetAnimator.from_player_defaults()`, its texture path, and sprite position to match the new layout.
- Keep any new Godot-generated `*.gd.uid` file for a tracked script, as this repository does for existing scripts.

## Verify before committing

1. Run the packer and inspect its output at native size and at in-game scale. Compare visible frame bounds with a comparable enemy, and check every row for bleed into adjacent cells.
2. Run `godot --headless --import --path .` to catch script and resource import errors. If animator layout or metadata changed, run `godot --headless --path . -s res://tools/verify_sheet_animator.gd`.
3. In Anim Preview, play Walk, Attack, and Death for the available directions. In the game, check the enemy's apparent size, first walking frame, loop, and attack transition. A successful import alone does not catch animation alignment or scale problems.
