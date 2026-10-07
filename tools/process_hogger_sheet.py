"""Pack generated Hogger art, preserving pixel edges and body/feet alignment.

The generated source has ten uneven rows: five walk, three cleaver attack,
then crouched/prone death. The bands below were inspected against the source;
blind equal-height slicing would cut weapons and bleed into adjacent frames.
Run: python -B tools/process_hogger_sheet.py
"""
from collections import deque
from pathlib import Path
from process_wc2_sheet import read_png, write_png

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sprites/enemies/hogger_sheet_raw.png"
OUTPUT = ROOT / "assets/sprites/enemies/hogger.png"
COLS, ROWS = 5, 10
CELL_W, CELL_H = 112, 96
BANDS = [(0, 163), (164, 323), (324, 483), (484, 643), (644, 800),
         (801, 985), (986, 1140), (1141, 1296), (1297, 1417), (1418, 1551)]
ALPHA = 225


def extract(rows, x0, x1, y0, y1):
    # A weapon tip from a neighbouring pose can enter a source cell. Keep
    # the connected character and drop those disconnected fragments.
    remaining = {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1)
                 if rows[y][x * 4 + 3] >= ALPHA}
    components = []
    while remaining:
        seed = remaining.pop()
        component = {seed}
        pending = deque([seed])
        while pending:
            x, y = pending.popleft()
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                point = x + dx, y + dy
                if point in remaining:
                    remaining.remove(point)
                    component.add(point)
                    pending.append(point)
        components.append(component)
    if not components:
        raise ValueError("Empty Hogger source frame")
    return max(components, key=len)


def main():
    width, height, source = read_png(SOURCE)
    if (width, height) != (1013, 1552):
        raise ValueError("Source dimensions changed; inspect and update row bands")
    frames = []
    for row, (y0, y1) in enumerate(BANDS):
        for col in range(COLS):
            points = extract(source, round(col * width / COLS), round((col + 1) * width / COLS), y0, y1)
            left, right = min(x for x, y in points), max(x for x, y in points)
            top, bottom = min(y for x, y in points), max(y for x, y in points)
            frames.append((points, (left, top, right, bottom)))
    scale = 64.0 / max(bounds[3] - bounds[1] + 1 for points, bounds in frames[:25])
    atlas_w, atlas_h = COLS * CELL_W, ROWS * CELL_H
    atlas = [bytearray(atlas_w * 4) for _ in range(atlas_h)]
    for index, (points, (left, top, right, bottom)) in enumerate(frames):
        row, col = divmod(index, COLS)
        sw, sh = right - left + 1, bottom - top + 1
        dw, dh = round(sw * scale), round(sh * scale)
        anchors = sorted(x for x, y in points if y > top + sh * 0.4
                         and source[y][x * 4] > 80
                         and source[y][x * 4] > source[y][x * 4 + 1] * 1.45
                         and source[y][x * 4 + 1] < 85)
        anchor = anchors[len(anchors) // 2] if row < 8 and anchors else (left + right) / 2
        ox = max(4, min(CELL_W - 4 - dw, round(CELL_W / 2 - (anchor - left) * scale)))
        oy = CELL_H - 8 - dh
        if dw > CELL_W - 8 or oy < 4:
            raise ValueError(f"Frame {row},{col} does not fit with padding")
        for dy in range(dh):
            sy = top + min(sh - 1, int((dy + 0.5) * sh / dh))
            for dx in range(dw):
                sx = left + min(sw - 1, int((dx + 0.5) * sw / dw))
                if (sx, sy) not in points:
                    continue
                offset = (col * CELL_W + ox + dx) * 4
                atlas[row * CELL_H + oy + dy][offset:offset + 4] = source[sy][sx * 4:sx * 4 + 3] + b"\xff"
        print(f"frame {row},{col}: visible {dw}x{dh}, padding x={ox}, y={oy}")
    write_png(OUTPUT, atlas_w, atlas_h, [bytes(row) for row in atlas])
    print(f"Wrote {OUTPUT}: {atlas_w}x{atlas_h}, {COLS}x{ROWS} cells")


if __name__ == "__main__":
    main()
