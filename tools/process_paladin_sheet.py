"""Slice the Warcraft II knight sheet into a 5x11, 74px atlas with transparency."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "sprites" / "player" / "paladin_sheet_raw.png"
OUT = ROOT / "assets" / "sprites" / "player" / "paladin.png"

COLS = 5
ROWS = 11
CELL = 74
WATERMARK_Y = 800


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


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing source sheet: {SRC}")
    src = SRC

    width, height, rows = read_png(src)
    out_w = COLS * CELL
    out_h = ROWS * CELL
    if width < out_w:
        raise SystemExit(f"sheet too narrow: {width}x{height}")

    out_rows: list[bytearray] = [bytearray(out_w * 4) for _ in range(out_h)]
    keyed = 0
    copied = 0
    for y in range(min(height, out_h)):
        src_row = rows[y]
        dst_row = out_rows[y]
        for x in range(out_w):
            i = x * 4
            r, g, b, a = src_row[i : i + 4]
            if y >= WATERMARK_Y or a == 0:
                dst_row[i : i + 4] = b"\x00\x00\x00\x00"
                keyed += 1
            else:
                dst_row[i : i + 4] = bytes((r, g, b, a))
                copied += 1

    write_png(OUT, out_w, out_h, [bytes(row) for row in out_rows])
    print(f"wrote {OUT} ({out_w}x{out_h}) copied={copied} keyed={keyed}")


if __name__ == "__main__":
    main()
