"""Pack the generated Troll Headhunter art into the game's 5x11 atlas.

The source uses the usual facing columns (N, NE, E, SE, S), followed by
five walking, four thrust, and two death rows. The generated PNG carries a
low-alpha background glow, so discard it before shrinking to game scale.

Run: python tools/process_troll_sheet.py
"""

from pathlib import Path

from process_wc2_sheet import read_png, write_png


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/enemies/troll_headhunter_sheet_raw.png"
OUTPUT = ROOT / "assets/sprites/enemies/troll_headhunter.png"
COLS = 5
ROWS = 11
CELL_WIDTH = 112
CELL_HEIGHT = 80
ALPHA_CUTOFF = 225


def main() -> None:
    width, height, source_rows = read_png(SOURCE)
    atlas_width = COLS * CELL_WIDTH
    atlas_height = ROWS * CELL_HEIGHT
    atlas_rows = [bytearray(atlas_width * 4) for _ in range(atlas_height)]

    for row in range(ROWS):
        for col in range(COLS):
            x0 = round(col * width / COLS)
            x1 = round((col + 1) * width / COLS)
            y0 = round(row * height / ROWS)
            y1 = round((row + 1) * height / ROWS)
            for dy in range(CELL_HEIGHT):
                sy = y0 + min(y1 - y0 - 1, int((dy + 0.5) * (y1 - y0) / CELL_HEIGHT))
                dest_row = atlas_rows[row * CELL_HEIGHT + dy]
                source_row = source_rows[sy]
                for dx in range(CELL_WIDTH):
                    sx = x0 + min(x1 - x0 - 1, int((dx + 0.5) * (x1 - x0) / CELL_WIDTH))
                    rgba = source_row[sx * 4 : sx * 4 + 4]
                    if rgba[3] < ALPHA_CUTOFF:
                        continue
                    offset = (col * CELL_WIDTH + dx) * 4
                    dest_row[offset : offset + 4] = rgba[:3] + b"\xff"

    write_png(OUTPUT, atlas_width, atlas_height, [bytes(row) for row in atlas_rows])
    print(f"wrote {OUTPUT} ({atlas_width}x{atlas_height})")


if __name__ == "__main__":
    main()
