"""Pack the ripped skeleton sheet into a 5x10, 52px atlas with transparency.

Layout (rows): SE, E, NE, N, NW, W, SW, S walk (5 frames each), then hit, then death.
Columns are animation frames. All 8 facings are drawn, so the game does not flip.

Run: python tools/process_skeleton_sheet.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "sprites" / "enemies" / "skeleton_sheet_raw.png"
OUT = ROOT / "assets" / "sprites" / "enemies" / "skeleton.png"

COLS = 5
ROWS = 10
CELL = 52
WATERMARK_Y = 487


def read_png(path: Path) -> tuple[int, int, list[bytearray]]:
    with path.open("rb") as f:
        assert f.read(8) == b"\x89PNG\r\n\x1a\n"
        chunks: list[tuple[bytes, bytes]] = []
        while True:
            hdr = f.read(8)
            if len(hdr) < 8:
                break
            length, ctype = struct.unpack(">I4s", hdr)
            data = f.read(length)
            f.read(4)
            chunks.append((ctype, data))
            if ctype == b"IEND":
                break

    width = height = 0
    raw = b""
    for ctype, data in chunks:
        if ctype == b"IHDR":
            width, height, bit, color, _comp, _filt, inter = struct.unpack(">IIBBBBB", data)
            if bit != 8 or color != 6 or inter != 0:
                raise SystemExit(f"unsupported PNG {bit}/{color}/{inter}")
        elif ctype == b"IDAT":
            raw += data

    data = zlib.decompress(raw)
    bpp = 4
    stride = width * bpp
    rows: list[bytearray] = []
    i = 0
    prev = bytearray(stride)
    for _y in range(height):
        ft = data[i]
        i += 1
        row = bytearray(data[i : i + stride])
        i += stride
        if ft == 1:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + a) & 255
        elif ft == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif ft == 3:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((a + prev[x]) // 2)) & 255
        elif ft == 4:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                row[x] = (row[x] + pr) & 255
        elif ft != 0:
            raise SystemExit(f"unknown filter {ft}")
        rows.append(row)
        prev = row
    return width, height, rows


def write_png(path: Path, width: int, height: int, rows: list[bytes]) -> None:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)

    raw = b"".join(b"\x00" + row for row in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def _visible(px: bytes) -> bool:
    return len(px) >= 4 and px[3] > 0


def _content_bands(height: int, rows: list[bytearray], width: int) -> list[tuple[int, int]]:
    bands: list[tuple[int, int]] = []
    start: int | None = None
    for y in range(min(height, WATERMARK_Y)):
        row = rows[y]
        has = any(_visible(row[x * 4 : x * 4 + 4]) for x in range(width))
        if has:
            if start is None:
                start = y
        elif start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, min(height, WATERMARK_Y) - 1))
    return bands


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing source sheet: {SRC}")

    width, height, rows = read_png(SRC)
    if width % COLS != 0:
        raise SystemExit(f"sheet width {width} is not divisible by {COLS}")
    col_w = width // COLS
    bands = _content_bands(height, rows, width)
    if len(bands) < ROWS:
        raise SystemExit(f"expected {ROWS} sprite rows, found {len(bands)}")
    bands = bands[:ROWS]

    out_w = COLS * CELL
    out_h = ROWS * CELL
    out_rows: list[bytearray] = [bytearray(out_w * 4) for _ in range(out_h)]
    copied = 0
    max_w = 0
    max_h = 0

    for row_i, (y0, y1) in enumerate(bands):
        for col_i in range(COLS):
            x0 = col_i * col_w
            x1 = x0 + col_w
            minx, miny, maxx, maxy = width, height, -1, -1
            for y in range(y0, y1 + 1):
                src_row = rows[y]
                for x in range(x0, x1):
                    if _visible(src_row[x * 4 : x * 4 + 4]):
                        minx = min(minx, x)
                        maxx = max(maxx, x)
                        miny = min(miny, y)
                        maxy = max(maxy, y)
            if maxx < 0:
                continue
            bw = maxx - minx + 1
            bh = maxy - miny + 1
            max_w = max(max_w, bw)
            max_h = max(max_h, bh)
            if bw > CELL or bh > CELL:
                raise SystemExit(f"sprite {row_i},{col_i} is {bw}x{bh}, cell is {CELL}")
            dest_x = col_i * CELL + (CELL - bw) // 2
            dest_y = row_i * CELL + (CELL - bh)
            for y in range(miny, maxy + 1):
                src_row = rows[y]
                dst_row = out_rows[dest_y + (y - miny)]
                for x in range(minx, maxx + 1):
                    px = src_row[x * 4 : x * 4 + 4]
                    if not _visible(px):
                        continue
                    i = (dest_x + (x - minx)) * 4
                    dst_row[i : i + 4] = bytes(px)
                    copied += 1

    write_png(OUT, out_w, out_h, [bytes(row) for row in out_rows])
    print(f"wrote {OUT} ({out_w}x{out_h}) copied={copied} max_sprite={max_w}x{max_h}")


if __name__ == "__main__":
    main()
