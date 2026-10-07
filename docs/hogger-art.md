# Hogger art provenance and packing

Generated with the built-in ImageGen tool, with a transparent background.
The original output is tracked as `assets/sprites/enemies/hogger_sheet_raw.png`.
The reproducible, standard-library packer is `tools/process_hogger_sheet.py`.
The packed atlas is `assets/sprites/enemies/hogger_boss.png`. This deliberately
uses a different path from the original 48×48 `hogger.png`, so an existing
Godot project cannot silently use that old cached texture with the new layout.

## Generation prompt

Use case: stylized-concept. Asset type: production sprite atlas for a Warcraft II
style top-down survivors game. Create a complete replacement Hogger boss sprite
sheet, transparent alpha background. Hogger is a hulking brown hyena-like gnoll
with spotted tawny fur, dark mane, pointed ears, toothy muzzle, heavy red ragged
sash, scarred iron shoulder armor, leather belt, and enormous crude iron cleaver.
Detailed hand-painted pixel art comparable to Warcraft II unit sprites, strong
readable silhouette, NOT a flat icon. Exact layout: 5 columns by 11 rows, 55
distinct separate sprites, generous transparent padding between every pose,
even rectangular grid. Columns are facing N (back), NE, E (profile), SE, S
(front), same directions in every row. Rows 1-5: five-frame walking cycle with
cleaver at his side. Rows 6-9: four-frame overhead cleaver attack: raise weapon,
windup, slam, recover. Row 10: collapsed crouch death pose in five directions.
Row 11: dead prone corpse in five directions. Maintain body size and foot
baseline within each frame; no pose touches another cell, no clipped weapons.
Tall portrait atlas aspect ratio appropriate to 5 by 11 cells. No text, labels,
borders, ground, shadows outside sprites, magic effects, or background. Pixel art
must remain clear when scaled to about 64 pixels tall in the game.

## Inspected result

The generated output actually has **ten rows**, including three attack poses.
The resource uses the inspected 5×10 layout rather than the requested 5×11.
Rows 0–4 walk, 5–7 attack, and 8–9 die. Cells are 112×96; standing art is about
60–64 pixels tall, and raised cleaver poses reach 75 pixels. The boss is larger
than ordinary grunt/ogre art without changing the game's pixel density.

The packer uses inspected source row bands, removes disconnected neighbouring
fragments, scales all poses with one nearest-neighbour factor, anchors the red
sash to reduce body drift, and aligns feet eight pixels above each cell bottom.
Every cell has transparent padding; no visible pose crosses an atlas boundary.
Ground warnings and the shockwave are drawn separately by the boss script.

Visual checks used the actual game renderer, with screenshots of the charge,
slam, and shockwave at gameplay scale. `tools/verify_sheet_animator.gd` checks
layout, directional mirroring, death frames, and hit flash. The run integration
check exercises both isolated attack geometry and the live scene.
