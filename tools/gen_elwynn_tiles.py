#!/usr/bin/env python3
"""Original Elwynn summer tiles inspired by classic RTS summer biomes (32x32).

Generates a procedural atlas + props. Does not copy third-party pixel data.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "tiles" / "elwynn"
TILE = 32
COLS = 12
ROWS = 6

# WC2-inspired summer palette (sampled hues, original patterns).
G = {
    "deep": (0, 68, 0),
    "mid": (16, 96, 4),
    "bright": (36, 112, 12),
    "lit": (52, 132, 24),
    "shadow": (0, 44, 0),
    "blade": (72, 140, 28),
    "flower_y": (220, 200, 60),
    "flower_w": (236, 236, 220),
    "flower_p": (200, 100, 140),
}
D = {
    "mid": (108, 64, 4),
    "dark": (84, 48, 0),
    "lit": (132, 84, 20),
    "deep": (64, 36, 0),
    "pebble": (148, 108, 48),
}
W = {
    "deep": (4, 44, 96),
    "mid": (4, 56, 116),
    "lit": (20, 84, 148),
    "foam": (140, 180, 220),
    "bank": (96, 56, 0),
}
F = {
    "canopy": (0, 76, 0),
    "dark": (0, 40, 0),
    "lit": (24, 108, 8),
    "trunk": (80, 48, 0),
    "trunk_d": (56, 32, 0),
}
R = {
    "mid": (92, 92, 92),
    "dark": (48, 48, 48),
    "lit": (140, 140, 140),
    "deep": (28, 28, 28),
    "moss": (36, 72, 4),
}


def hash2(x: int, y: int, seed: int = 0) -> int:
    n = x * 374761393 + y * 668265263 + seed * 982451653
    n = (n ^ (n >> 13)) * 1274126177
    return n & 0x7FFFFFFF


def chance(x: int, y: int, seed: int, mod: int) -> bool:
    return hash2(x, y, seed) % mod == 0


def lerp_rgb(a, b, t: float):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def new_tile(rgb=(0, 0, 0)) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (*rgb, 255))
    return img


def put(img: Image.Image, x: int, y: int, rgb, a: int = 255) -> None:
    if 0 <= x < TILE and 0 <= y < TILE:
        img.putpixel((x, y), (*rgb, a))


def stipple_fill(img: Image.Image, base, dots, seed: int, density: int = 5) -> None:
    for y in range(TILE):
        for x in range(TILE):
            h = hash2(x, y, seed)
            col = base
            if h % density == 0:
                col = dots[h % len(dots)]
            elif h % (density + 3) == 0:
                col = dots[(h >> 3) % len(dots)]
            put(img, x, y, col)


def grass_tile(variant: int) -> Image.Image:
    bases = [G["deep"], G["mid"], G["bright"], G["mid"], G["mid"], G["bright"]]
    base = bases[variant % len(bases)]
    dots = [G["shadow"], G["mid"], G["bright"], G["lit"], G["blade"], G["deep"]]
    img = new_tile(base)
    stipple_fill(img, base, dots, 100 + variant, density=4 + (variant % 3))
    # Fine dither checker for RTS grass grain.
    for y in range(TILE):
        for x in range(TILE):
            if (x + y * 3 + variant) % 7 == 0:
                put(img, x, y, G["shadow"] if variant % 2 == 0 else G["deep"])
            if (x * 5 + y * 2 + variant * 9) % 11 == 0:
                put(img, x, y, G["lit"])
    if variant == 3:  # flowers
        for fx, fy, c in (
            (7, 9, G["flower_y"]),
            (8, 9, G["flower_w"]),
            (20, 14, G["flower_p"]),
            (21, 14, G["flower_w"]),
            (14, 22, G["flower_y"]),
            (25, 6, G["flower_w"]),
        ):
            put(img, fx, fy, c)
    if variant == 4:  # pebbles
        for px, py in ((6, 10), (18, 7), (22, 20), (10, 24), (15, 15)):
            put(img, px, py, R["mid"])
            put(img, px + 1, py, R["lit"])
            put(img, px, py + 1, R["dark"])
    if variant == 5:  # brighter meadow
        for y in range(TILE):
            for x in range(TILE):
                if hash2(x, y, 55) % 6 == 0:
                    put(img, x, y, G["blade"])
    return img


def dirt_tile(variant: int) -> Image.Image:
    bases = [D["mid"], D["lit"], D["dark"], D["mid"]]
    base = bases[variant % len(bases)]
    dots = [D["dark"], D["lit"], D["deep"], D["pebble"], D["mid"]]
    img = new_tile(base)
    stipple_fill(img, base, dots, 200 + variant, density=5)
    # Soft horizontal “raked earth” streaks.
    for y in range(2, TILE, 5):
        for x in range(TILE):
            if hash2(x, y, 210 + variant) % 3:
                put(img, x, y, D["dark"] if variant != 1 else D["mid"])
    if variant == 3:
        for px, py in ((8, 8), (20, 12), (12, 22), (24, 24)):
            put(img, px, py, R["dark"])
            put(img, px + 1, py, R["mid"])
    return img


def jagged_mask(side: str, x: int, y: int, seed: int) -> bool:
    """True where grass fringe should appear on a dirt/water transition tile."""
    noise = (hash2(x, y, seed) % 5) - 2
    if side == "N":
        depth = 6 + (hash2(x, 0, seed) % 5) + noise
        return y < depth
    if side == "S":
        depth = 6 + (hash2(x, 1, seed) % 5) + noise
        return y >= TILE - depth
    if side == "W":
        depth = 6 + (hash2(y, 2, seed) % 5) + noise
        return x < depth
    if side == "E":
        depth = 6 + (hash2(y, 3, seed) % 5) + noise
        return x >= TILE - depth
    return False


def blend_grass_on_dirt(sides: str, seed: int = 0) -> Image.Image:
    img = dirt_tile(0)
    g = grass_tile(1)
    for y in range(TILE):
        for x in range(TILE):
            on = False
            for s in sides:
                if jagged_mask(s, x, y, seed + ord(s)):
                    on = True
                    break
            # Outer corner: require near both edges for cleaner NE/NW/etc.
            if len(sides) == 2 and sides in ("NE", "NW", "SE", "SW"):
                a, b = sides[0], sides[1]
                on = jagged_mask(a, x, y, seed + 1) and jagged_mask(b, x, y, seed + 2)
                # Soften with OR near the corner tip.
                if sides == "NE":
                    on = on or (x > 22 and y < 10)
                elif sides == "NW":
                    on = on or (x < 10 and y < 10)
                elif sides == "SE":
                    on = on or (x > 22 and y > 22)
                elif sides == "SW":
                    on = on or (x < 10 and y > 22)
            if on:
                put(img, x, y, g.getpixel((x, y))[:3])
    return img


def water_tile(variant: int = 0) -> Image.Image:
    img = new_tile(W["mid"])
    for y in range(TILE):
        for x in range(TILE):
            wave = int(2 * math.sin((x + variant * 3) * 0.45 + y * 0.15))
            band = (y + wave) % 8
            if band < 2:
                put(img, x, y, W["lit"])
            elif band < 5:
                put(img, x, y, W["mid"])
            else:
                put(img, x, y, W["deep"])
            if hash2(x, y, 300 + variant) % 40 == 0:
                put(img, x, y, W["foam"])
    return img


def shore_tile(sides: str, seed: int = 0) -> Image.Image:
    img = water_tile(seed % 2)
    bank = dirt_tile(0)
    for y in range(TILE):
        for x in range(TILE):
            on = False
            for s in sides:
                if jagged_mask(s, x, y, seed + 50 + ord(s)):
                    on = True
            if len(sides) == 2:
                a, b = sides[0], sides[1]
                on = jagged_mask(a, x, y, seed + 51) and jagged_mask(b, x, y, seed + 52)
            if on:
                # Muddy bank rim then dirt.
                rim = False
                for s in sides:
                    # one pixel inside water side of fringe
                    if s == "N" and y == 6 + (hash2(x, 0, seed) % 4):
                        rim = True
                    if s == "S" and y == TILE - (6 + (hash2(x, 1, seed) % 4)):
                        rim = True
                    if s == "W" and x == 6 + (hash2(y, 2, seed) % 4):
                        rim = True
                    if s == "E" and x == TILE - (6 + (hash2(y, 3, seed) % 4)):
                        rim = True
                put(img, x, y, W["foam"] if rim else bank.getpixel((x, y))[:3])
    return img


def draw_pine(img: Image.Image, cx: int, cy: int, scale: int, seed: int) -> None:
    # Layered triangles / diamonds for canopy.
    layers = [
        (cy - scale, scale + 2, F["lit"]),
        (cy - scale // 3, scale + 4, F["canopy"]),
        (cy + scale // 3, scale + 5, F["dark"]),
    ]
    for top, half, col in layers:
        for y in range(top, top + half * 2):
            t = (y - top) / max(1, half * 2)
            w = int(1 + t * half)
            for x in range(cx - w, cx + w + 1):
                if hash2(x, y, seed) % 5 != 0:
                    put(img, x, y, col)
                else:
                    put(img, x, y, F["lit"] if col != F["lit"] else F["canopy"])
    # Trunk peek
    for ty in range(cy + scale, cy + scale + 5):
        put(img, cx, ty, F["trunk"])
        put(img, cx - 1, ty, F["trunk_d"])


def forest_tile(variant: int) -> Image.Image:
    img = grass_tile(0 if variant < 4 else 1)
    if variant == 0:  # dense
        draw_pine(img, 10, 12, 7, 1)
        draw_pine(img, 22, 14, 8, 2)
        draw_pine(img, 16, 22, 6, 3)
        draw_pine(img, 8, 24, 5, 4)
    elif variant == 1:
        draw_pine(img, 12, 14, 9, 5)
        draw_pine(img, 23, 20, 7, 6)
    elif variant == 2:
        draw_pine(img, 18, 12, 8, 7)
        draw_pine(img, 9, 20, 7, 8)
        draw_pine(img, 24, 24, 5, 9)
    elif variant == 3:  # sparse
        draw_pine(img, 16, 16, 8, 10)
    elif variant == 4:  # edge N (open south)
        draw_pine(img, 10, 8, 6, 11)
        draw_pine(img, 22, 10, 7, 12)
    elif variant == 5:  # edge E
        draw_pine(img, 22, 12, 7, 13)
        draw_pine(img, 24, 22, 6, 14)
    elif variant == 6:  # edge S
        draw_pine(img, 12, 22, 7, 15)
        draw_pine(img, 22, 24, 6, 16)
    else:  # edge W
        draw_pine(img, 8, 12, 7, 17)
        draw_pine(img, 10, 22, 6, 18)
    return img


def rock_tile(variant: int) -> Image.Image:
    img = grass_tile(1) if variant < 3 else dirt_tile(0)
    draw = ImageDraw.Draw(img)

    def boulder(cx, cy, rx, ry):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                dx = (x - cx) / max(1, rx)
                dy = (y - cy) / max(1, ry)
                if dx * dx + dy * dy <= 1.05:
                    shade = R["mid"]
                    if dx + dy < -0.3:
                        shade = R["lit"]
                    elif dx + dy > 0.35:
                        shade = R["dark"]
                    if hash2(x, y, 400 + variant) % 9 == 0:
                        shade = R["deep"]
                    put(img, x, y, shade)

    if variant == 0:
        boulder(16, 18, 12, 10)
        boulder(10, 12, 6, 5)
    elif variant == 1:
        boulder(14, 16, 10, 9)
        boulder(22, 20, 7, 6)
    elif variant == 2:
        boulder(18, 14, 9, 8)
        # moss speckles
        for y in range(TILE):
            for x in range(TILE):
                if img.getpixel((x, y))[:3] == R["mid"] and hash2(x, y, 9) % 14 == 0:
                    put(img, x, y, R["moss"])
    else:  # low cliff band
        for y in range(TILE):
            for x in range(TILE):
                if y < 10:
                    put(img, x, y, G["mid"] if hash2(x, y, 1) % 3 else G["deep"])
                elif y < 14:
                    put(img, x, y, R["lit"] if (x + y) % 2 == 0 else R["mid"])
                else:
                    t = (y - 14) / 18.0
                    put(img, x, y, lerp_rgb(R["mid"], R["deep"], t))
                    if hash2(x, y, 2) % 8 == 0:
                        put(img, x, y, R["dark"])
    # suppress unused warning
    _ = draw
    return img


def paste_tile(atlas: Image.Image, tile: Image.Image, col: int, row: int) -> None:
    atlas.paste(tile, (col * TILE, row * TILE))


def build_atlas() -> Image.Image:
    atlas = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))

    # Row 0: grass
    for i in range(6):
        paste_tile(atlas, grass_tile(i), i, 0)

    # Row 1: dirt
    for i in range(4):
        paste_tile(atlas, dirt_tile(i), i, 1)

    # Row 2: grass-on-dirt transitions
    transitions = [
        ("N", 0),
        ("E", 1),
        ("S", 2),
        ("W", 3),
        ("NE", 4),
        ("NW", 5),
        ("SE", 6),
        ("SW", 7),
        ("NS", 8),
        ("EW", 9),
        ("NEW", 10),  # approx via N+E+W
        ("NES", 11),
    ]
    for sides, col in transitions:
        if len(sides) <= 2:
            paste_tile(atlas, blend_grass_on_dirt(sides, 20 + col), col, 2)
        else:
            # Triple: start dirt, apply each side fringe.
            img = dirt_tile(0)
            g = grass_tile(1)
            for y in range(TILE):
                for x in range(TILE):
                    if any(jagged_mask(s, x, y, 30 + col + ord(s)) for s in sides):
                        put(img, x, y, g.getpixel((x, y))[:3])
            paste_tile(atlas, img, col, 2)

    # Row 3: forest
    for i in range(8):
        paste_tile(atlas, forest_tile(i), i, 3)

    # Row 4: water + shores
    paste_tile(atlas, water_tile(0), 0, 4)
    paste_tile(atlas, water_tile(1), 1, 4)
    shores = [("N", 2), ("E", 3), ("S", 4), ("W", 5), ("NE", 6), ("NW", 7), ("SE", 8), ("SW", 9)]
    for sides, col in shores:
        paste_tile(atlas, shore_tile(sides, 40 + col), col, 4)

    # Row 5: rocks
    for i in range(4):
        paste_tile(atlas, rock_tile(i), i, 5)

    return atlas


def gen_tree(path: Path, w: int, h: int, variant: int) -> None:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx = w // 2
    # Trunk
    tw = 5 + variant
    for y in range(h - 28, h):
        for x in range(cx - tw // 2, cx + tw // 2 + 1):
            col = F["trunk_d"] if x < cx else F["trunk"]
            img.putpixel((x, y), (*col, 255))
    # Pine canopy stacks
    scales = [10 + variant, 12 + variant, 9 + variant]
    tops = [h - 54, h - 40, h - 28]
    if variant == 1:
        scales.append(8)
        tops.append(h - 62)
    for i, (top, sc) in enumerate(zip(tops, scales)):
        cy = top + sc
        # temporary draw into full image coords via helper adapted
        for y in range(top, top + sc * 2):
            t = (y - top) / max(1, sc * 2)
            half = int(1 + t * sc)
            for x in range(cx - half, cx + half + 1):
                if 0 <= x < w and 0 <= y < h:
                    col = F["lit"] if i == 0 else (F["canopy"] if i == 1 else F["dark"])
                    if hash2(x, y, 70 + variant + i) % 6 == 0:
                        col = F["lit"]
                    img.putpixel((x, y), (*col, 255))
    img.save(path)


def gen_lantern(path: Path) -> None:
    img = Image.new("RGBA", (16, 40), (0, 0, 0, 0))
    for y in range(14, 40):
        img.putpixel((7, y), (*F["trunk_d"], 255))
        img.putpixel((8, y), (*F["trunk"], 255))
    for y in range(4, 14):
        for x in range(4, 12):
            img.putpixel((x, y), (40, 32, 20, 255))
    for y in range(5, 13):
        for x in range(5, 11):
            img.putpixel((x, y), (255, 200, 60, 255))
    for y in range(6, 12):
        for x in range(6, 10):
            img.putpixel((x, y), (255, 240, 180, 255))
    img.save(path)


def gen_goldshire(path: Path) -> None:
    img = Image.new("RGBA", (320, 64), (0, 0, 0, 0))
    roofs = [16, 56, 100, 148, 196, 248]
    for rx in roofs:
        for y in range(28, 56):
            for x in range(rx, rx + 36):
                img.putpixel((x, y), (42, 30, 18, 255))
        for y in range(14, 30):
            for x in range(rx + 2, rx + 34):
                # peaked roof
                peak = 14 + abs((x - (rx + 18)) // 2)
                if y >= peak:
                    img.putpixel((x, y), (90, 32, 20, 255))
        img.putpixel((rx + 10, 40), (255, 200, 60, 255))
        img.putpixel((rx + 11, 40), (255, 200, 60, 255))
        img.putpixel((rx + 24, 44), (255, 180, 40, 255))
    for y in range(56, 64):
        for x in range(320):
            img.putpixel((x, y), (20, 48, 16, 255))
    img.save(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = build_atlas()
    atlas_path = OUT / "elwynn_tiles.png"
    atlas.save(atlas_path)
    print(f"wrote {atlas_path} ({atlas.size[0]}x{atlas.size[1]})")

    gen_tree(OUT / "tree_oak_a.png", 64, 80, 0)
    gen_tree(OUT / "tree_oak_b.png", 72, 88, 1)
    gen_tree(OUT / "tree_oak_c.png", 56, 72, 2)
    gen_lantern(OUT / "lantern.png")
    gen_goldshire(OUT / "goldshire_silhouette.png")
    print("wrote props")

    # Preview contact sheet for review.
    preview = atlas.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST)
    preview_path = Path("/opt/cursor/artifacts/elwynn_tiles_preview.png")
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(preview_path)
    print(f"preview {preview_path}")


if __name__ == "__main__":
    main()
