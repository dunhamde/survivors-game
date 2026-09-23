"""Pack the generated Troll Headhunter art into the game's 5x11 atlas.

The source uses facing columns (N, NE, E, SE, S), followed by five walking,
four thrust, and two death rows. The generated rows are not evenly spaced,
so detect their transparent gaps before scaling each pose to game size.
The source also carries a low-alpha glow, which is discarded.

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
ROW_PIXEL_MIN = 15
SCALE = 0.34
BOTTOM_MARGIN = 6
SIDE_MARGIN = 3


def visible(source_rows: list[bytearray], x: int, y: int) -> bool:
    return source_rows[y][x * 4 + 3] >= ALPHA_CUTOFF


def find_row_bands(source_rows: list[bytearray], width: int) -> list[tuple[int, int]]:
    bands: list[tuple[int, int]] = []
    start: int | None = None
    for y, pixels in enumerate(source_rows):
        count = sum(pixels[x * 4 + 3] >= ALPHA_CUTOFF for x in range(width))
        if count > ROW_PIXEL_MIN and start is None:
            start = y
        elif count <= ROW_PIXEL_MIN and start is not None:
            if y - start >= 40:
                bands.append((start, y - 1))
            start = None
    if start is not None and len(source_rows) - start >= 40:
        bands.append((start, len(source_rows) - 1))
    if len(bands) != ROWS:
        raise ValueError(f"expected {ROWS} sprite rows, found {len(bands)}: {bands}")
    return bands


def sprite_bounds(
    source_rows: list[bytearray], x0: int, x1: int, y0: int, y1: int
) -> tuple[int, int, int, int]:
    left, top, right, bottom = x1, y1 + 1, x0 - 1, y0 - 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1):
            if visible(source_rows, x, y):
                left = min(left, x)
                top = min(top, y)
                right = max(right, x)
                bottom = max(bottom, y)
    if right < left:
        raise ValueError(f"empty sprite in source region {x0}:{x1}, {y0}:{y1}")
    return left, top, right, bottom


def body_anchor_x(
    source_rows: list[bytearray], bounds: tuple[int, int, int, int], row: int
) -> float:
    left, top, right, bottom = bounds
    if row >= 9:
        return (left + right) * 0.5
    blue_x: list[int] = []
    lower_body = top + int((bottom - top) * 0.45)
    for y in range(lower_body, bottom + 1):
        pixels = source_rows[y]
        for x in range(left, right + 1):
            offset = x * 4
            red, green, blue, alpha = pixels[offset : offset + 4]
            if (
                alpha >= ALPHA_CUTOFF
                and blue >= 75
                and blue > red * 1.5
                and blue > green * 1.1
            ):
                blue_x.append(x)
    if not blue_x:
        return (left + right) * 0.5
    blue_x.sort()
    return float(blue_x[len(blue_x) // 2])


def remove_isolated_pixels(atlas_rows: list[bytearray]) -> None:
    # A spear at a source column boundary can leave a one-pixel remnant in
    # the neighboring pose. Drop single pixels without neighbors.
    for row in range(ROWS):
        for col in range(COLS):
            x0 = col * CELL_WIDTH
            y0 = row * CELL_HEIGHT
            for y in range(y0, y0 + CELL_HEIGHT):
                for x in range(x0, x0 + CELL_WIDTH):
                    if atlas_rows[y][x * 4 + 3] == 0:
                        continue
                    connected = any(
                        atlas_rows[ny][nx * 4 + 3] > 0
                        for ny in range(max(y0, y - 1), min(y0 + CELL_HEIGHT, y + 2))
                        for nx in range(max(x0, x - 1), min(x0 + CELL_WIDTH, x + 2))
                        if (nx, ny) != (x, y)
                    )
                    if not connected:
                        atlas_rows[y][x * 4 : x * 4 + 4] = b"\x00\x00\x00\x00"


def main() -> None:
    width, _height, source_rows = read_png(SOURCE)
    bands = find_row_bands(source_rows, width)
    atlas_width = COLS * CELL_WIDTH
    atlas_height = ROWS * CELL_HEIGHT
    atlas_rows = [bytearray(atlas_width * 4) for _ in range(atlas_height)]

    for row, (y0, y1) in enumerate(bands):
        for col in range(COLS):
            x0 = round(col * width / COLS)
            x1 = round((col + 1) * width / COLS)
            left, top, right, bottom = sprite_bounds(source_rows, x0, x1, y0, y1)
            source_width = right - left + 1
            source_height = bottom - top + 1
            sprite_width = round(source_width * SCALE)
            sprite_height = round(source_height * SCALE)
            anchor = body_anchor_x(source_rows, (left, top, right, bottom), row)
            dest_x = round(CELL_WIDTH * 0.5 - (anchor - left) * SCALE)
            dest_x = max(SIDE_MARGIN, min(CELL_WIDTH - SIDE_MARGIN - sprite_width, dest_x))
            dest_y = CELL_HEIGHT - BOTTOM_MARGIN - sprite_height
            if dest_y < SIDE_MARGIN:
                raise ValueError(f"sprite {row},{col} exceeds its cell height")

            for dy in range(sprite_height):
                sy = top + min(source_height - 1, int((dy + 0.5) * source_height / sprite_height))
                dest_row = atlas_rows[row * CELL_HEIGHT + dest_y + dy]
                source_row = source_rows[sy]
                for dx in range(sprite_width):
                    sx = left + min(source_width - 1, int((dx + 0.5) * source_width / sprite_width))
                    if not visible(source_rows, sx, sy):
                        continue
                    rgba = source_row[sx * 4 : sx * 4 + 3]
                    offset = (col * CELL_WIDTH + dest_x + dx) * 4
                    dest_row[offset : offset + 4] = rgba + b"\xff"

    remove_isolated_pixels(atlas_rows)
    write_png(OUTPUT, atlas_width, atlas_height, [bytes(row) for row in atlas_rows])
    print(f"wrote {OUTPUT} ({atlas_width}x{atlas_height})")


if __name__ == "__main__":
    main()
