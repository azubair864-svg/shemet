#!/usr/bin/env python3
"""Final canonical generator for Chamet car-game track assets.

Generates and overwrites the 4 active 640x640 PNG tracks:
- cartoon_chamet_3lane.png            (ASPHALT)
- cartoon_chamet_sand_3lane.png       (SAND)
- cartoon_chamet_ice_3lane.png        (ICE)
- cartoon_chamet_neon_3lane.png       (NEON)

This script is deterministic and uses Python stdlib only.
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

W, H = 640, 640
OUT_DIR = Path("assets/images/track_images")


# ----------------------------
# Core helpers
# ----------------------------
def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return lo if v < lo else hi if v > hi else int(v)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


class Canvas:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.rgb = bytearray(w * h * 3)

    def set(self, x: int, y: int, c: tuple[int, int, int]) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 3
            self.rgb[i], self.rgb[i + 1], self.rgb[i + 2] = c

    def get(self, x: int, y: int) -> tuple[int, int, int]:
        i = (y * self.w + x) * 3
        return self.rgb[i], self.rgb[i + 1], self.rgb[i + 2]

    def blend(self, x: int, y: int, c: tuple[int, int, int], alpha: float) -> None:
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        a = max(0.0, min(1.0, alpha))
        r0, g0, b0 = self.get(x, y)
        self.set(
            x,
            y,
            (
                clamp(r0 * (1.0 - a) + c[0] * a),
                clamp(g0 * (1.0 - a) + c[1] * a),
                clamp(b0 * (1.0 - a) + c[2] * a),
            ),
        )

    def save_png(self, out_file: Path) -> None:
        def chunk(tag: bytes, data: bytes) -> bytes:
            crc = zlib.crc32(tag + data) & 0xFFFFFFFF
            return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", crc)

        raw = bytearray()
        stride = self.w * 3
        for y in range(self.h):
            raw.append(0)  # filter none
            s = y * stride
            raw.extend(self.rgb[s : s + stride])

        png = bytearray(b"\x89PNG\r\n\x1a\n")
        png.extend(chunk(b"IHDR", struct.pack("!IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)))
        png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
        png.extend(chunk(b"IEND", b""))
        out_file.write_bytes(png)


def draw_curbs(
    c: Canvas,
    top_a: tuple[int, int, int],
    top_b: tuple[int, int, int],
    side_a: tuple[int, int, int],
    side_b: tuple[int, int, int],
) -> None:
    curb_h = 30
    tile_w = 56
    bw_a = (22, 24, 27)
    bw_b = (244, 247, 250)

    for y in range(curb_h):
        for x in range(c.w):
            # Start strip: black/white checker only.
            cc = bw_a if ((x // tile_w) % 2 == 0) else bw_b
            shade = 0.90 + 0.14 * (y / max(1, curb_h - 1))
            c.set(x, y, (clamp(cc[0] * shade), clamp(cc[1] * shade), clamp(cc[2] * shade)))

    for y in range(c.h - curb_h, c.h):
        yy = y - (c.h - curb_h)
        for x in range(c.w):
            # Finish strip: black/white checker only.
            cc = bw_a if ((x // tile_w) % 2 == 0) else bw_b
            shade = 1.00 - 0.14 * (yy / max(1, curb_h - 1))
            c.set(x, y, (clamp(cc[0] * shade), clamp(cc[1] * shade), clamp(cc[2] * shade)))

    # Left-side start strip only (black/white checker), then track.
    start_strip_w = 16
    start_tile_h = 24
    for y in range(c.h):
        cc = bw_a if ((y // start_tile_h) % 2 == 0) else bw_b
        for x in range(start_strip_w):
            c.set(x, y, cc)


def draw_start_finish_zones(
    c: Canvas,
    track_left: int,
    track_right: int,
    top: int,
    bottom: int,
) -> None:
    # Structured start area (top) and finish area (bottom) inside track.
    start_h = 16
    finish_h = 16
    accent = (226, 232, 238)

    # Start strip: clean line + short gate markers.
    y0 = top + 8
    for y in range(y0, y0 + start_h):
        a = 0.22 if y in (y0, y0 + start_h - 1) else 0.12
        for x in range(track_left, track_right):
            c.blend(x, y, accent, a)
    for x in range(track_left + 24, track_right - 24, 64):
        for y in range(y0 - 4, y0 + start_h + 4):
            c.blend(x, y, (245, 249, 252), 0.20)

    # Finish strip: slightly stronger to differentiate from start.
    y1 = bottom - finish_h - 8
    for y in range(y1, y1 + finish_h):
        a = 0.30 if y in (y1, y1 + finish_h - 1) else 0.16
        for x in range(track_left, track_right):
            c.blend(x, y, accent, a)
    for x in range(track_left + 8, track_right - 8, 22):
        for y in range(y1 + 3, y1 + finish_h - 3):
            if ((x // 22) % 2) == 0:
                c.blend(x, y, (245, 249, 252), 0.22)


def draw_polyline(c: Canvas, points: list[tuple[int, int]], col: tuple[int, int, int], alpha: float = 0.5) -> None:
    for i in range(len(points) - 1):
        x0, y0 = points[i]
        x1, y1 = points[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            t = s / steps
            x = int(x0 + (x1 - x0) * t)
            y = int(y0 + (y1 - y0) * t)
            c.blend(x, y, col, alpha)
            c.blend(x, y + 1, col, alpha * 0.35)


def draw_pothole(c: Canvas, cx: int, cy: int, rx: int, ry: int) -> None:
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            dx = (x - cx) / max(1, rx)
            dy = (y - cy) / max(1, ry)
            d = dx * dx + dy * dy
            if d <= 1.15:
                if d > 0.86:
                    c.blend(x, y, (94, 84, 73), 0.40)
                elif d > 0.42:
                    c.blend(x, y, (63, 57, 52), 0.42)
                else:
                    c.blend(x, y, (37, 34, 32), 0.50)


def draw_horizontal_dashes(
    c: Canvas,
    y: int,
    x0: int,
    x1: int,
    col: tuple[int, int, int],
    dash: int,
    gap: int,
    thickness: int = 2,
) -> None:
    x = x0
    while x < x1:
        for xx in range(x, min(x + dash, x1)):
            for t in range(-thickness // 2, thickness // 2 + 1):
                c.blend(xx, y + t, col, 0.9 if t == 0 else 0.45)
        x += dash + gap


# ----------------------------
# Distinct track designs
# ----------------------------
def make_asphalt() -> Canvas:
    c = Canvas(W, H)
    draw_curbs(c, (243, 66, 70), (241, 245, 248), (30, 31, 34), (243, 245, 247))

    top, bot = 64, 576
    for y in range(top, bot):
        t = (y - top) / (bot - top)
        base = mix((67, 71, 78), (55, 59, 66), t)
        for x in range(22, W - 22):
            side = abs((x - W / 2) / (W / 2))
            tone = 1.0 - 0.14 * (side**1.4)
            micro = 1.2 * math.sin(x * 0.07 + y * 0.05) + 0.8 * math.sin(x * 0.19 - y * 0.04)
            c.set(
                x,
                y,
                (
                    clamp(base[0] * tone + micro),
                    clamp(base[1] * tone + micro),
                    clamp(base[2] * tone + micro),
                ),
            )

    l1 = top + (bot - top) // 3
    l2 = top + 2 * (bot - top) // 3
    draw_horizontal_dashes(c, l1, 44, W - 44, (236, 239, 243), 42, 24, 2)
    draw_horizontal_dashes(c, l2, 44, W - 44, (236, 239, 243), 42, 24, 2)

    # Repair patches
    patches = [(142, 140, 92, 32), (448, 190, 110, 30), (292, 352, 142, 38), (495, 470, 92, 28)]
    for x, y, w, h in patches:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                c.blend(xx, yy, (79, 84, 92), 0.44)
        for xx in range(x, x + w):
            c.blend(xx, y, (38, 41, 45), 0.56)
            c.blend(xx, y + h - 1, (38, 41, 45), 0.56)

    # Cracks + potholes
    draw_polyline(c, [(70, 128), (132, 136), (196, 127), (264, 141)], (32, 34, 38), 0.56)
    draw_polyline(c, [(348, 420), (405, 431), (474, 423), (536, 440)], (31, 34, 38), 0.56)
    draw_polyline(c, [(118, 520), (170, 505), (232, 518)], (31, 33, 37), 0.56)

    draw_pothole(c, 98, 210, 12, 9)
    draw_pothole(c, 232, 468, 16, 10)
    draw_pothole(c, 512, 282, 14, 10)

    for y in range(top, bot):
        c.blend(22, y, (249, 200, 88), 0.15)
        c.blend(W - 23, y, (249, 200, 88), 0.15)

    draw_start_finish_zones(c, 38, W - 38, top, bot)
    return c


def make_sand() -> Canvas:
    c = Canvas(W, H)
    draw_curbs(c, (244, 81, 76), (241, 245, 247), (28, 30, 32), (243, 245, 247))

    top, bot = 64, 576

    # Full-width dune base
    for y in range(top, bot):
        t = (y - top) / (bot - top)
        base = mix((238, 218, 160), (222, 198, 137), t)
        for x in range(22, W - 22):
            wave = 3.0 * math.sin((x * 0.022) + (y * 0.014))
            c.set(x, y, (clamp(base[0] + wave), clamp(base[1] + wave), clamp(base[2] + wave)))

    # Curved compacted road corridor (distinct geometry)
    for y in range(top + 12, bot - 12):
        center = 398 + int(58 * math.sin(y * 0.012))
        half = 136 + int(22 * math.sin(y * 0.022 + 1.8))
        x0 = max(24, center - half)
        x1 = min(W - 24, center + half)
        for x in range(x0, x1):
            edge = min(x - x0, x1 - 1 - x)
            ef = min(1.0, edge / 28.0)
            col = mix((134, 113, 70), (116, 97, 61), (x - x0) / max(1, x1 - x0))
            c.blend(
                x,
                y,
                (
                    clamp(col[0] * ef + 40 * (1 - ef)),
                    clamp(col[1] * ef + 36 * (1 - ef)),
                    clamp(col[2] * ef + 24 * (1 - ef)),
                ),
                0.92,
            )

    # Curved lane separators
    for frac in (0.30, 0.50, 0.70):
        for y in range(top + 24, bot - 24, 2):
            center = 398 + int(58 * math.sin(y * 0.012))
            half = 136 + int(22 * math.sin(y * 0.022 + 1.8))
            x0 = center - half
            x1 = center + half
            x = int(x0 + (x1 - x0) * frac)
            if (y // 16) % 2 == 0:
                for t in (-1, 0, 1):
                    c.blend(x + t, y, (238, 205, 92), 0.80)

    rnd = random.Random(707)

    # Stones
    for _ in range(46):
        cx = rnd.randint(38, W - 38)
        cy = rnd.randint(top + 18, bot - 18)
        r = rnd.randint(3, 9)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
                    c.blend(x, y, (161, 143, 100), 0.36)

    # Groove lines
    for k in range(10):
        y0 = top + 28 + k * 48
        pts = [
            (36, y0 + int(5 * math.sin(k * 0.9))),
            (170, y0 + int(4 * math.sin(k + 1.2))),
            (304, y0 + int(6 * math.sin(k + 2.0))),
            (438, y0 + int(3 * math.sin(k + 0.6))),
            (568, y0 + int(5 * math.sin(k + 1.6))),
        ]
        draw_polyline(c, pts, (141, 124, 91), 0.25)

    # Dry cracks
    for _ in range(9):
        x = rnd.randint(80, 540)
        y = rnd.randint(top + 40, bot - 40)
        points = [(x, y)]
        for _s in range(rnd.randint(2, 4)):
            x = max(35, min(W - 35, x + rnd.randint(-70, 70)))
            y = max(top + 15, min(bot - 15, y + rnd.randint(-18, 18)))
            points.append((x, y))
        draw_polyline(c, points, (128, 112, 84), 0.35)

    draw_start_finish_zones(c, 40, W - 40, top, bot)
    return c


def make_ice() -> Canvas:
    c = Canvas(W, H)
    draw_curbs(c, (45, 152, 232), (242, 249, 255), (26, 49, 63), (238, 248, 255))

    top, bot = 64, 576

    # Frozen slab base
    for y in range(top, bot):
        t = (y - top) / (bot - top)
        base = mix((186, 221, 244), (163, 203, 232), t)
        for x in range(22, W - 22):
            gloss = 4.2 * math.sin(x * 0.028 + y * 0.012)
            c.set(x, y, (clamp(base[0] + gloss), clamp(base[1] + gloss), clamp(base[2] + gloss)))

    # Broad central racing slab with tapered sides
    for y in range(top + 18, bot - 18):
        taper = 28 + int(16 * math.sin(y * 0.020))
        x0, x1 = 68 + taper, W - 68 - taper
        for x in range(x0, x1):
            side = abs((x - (x0 + x1) / 2) / max(1, (x1 - x0) / 2))
            tone = 1.0 - 0.17 * (side**1.5)
            c.blend(x, y, (128, 169, 199), 0.74 * tone)

    # Horizontal lanes
    ys = [top + 140, top + 255, top + 370]
    for y in ys:
        draw_horizontal_dashes(c, y, 88, W - 88, (228, 246, 255), 20, 12, 2)

    rnd = random.Random(2307)

    # Fracture network
    for _ in range(18):
        x = rnd.randint(60, W - 60)
        y = rnd.randint(top + 30, bot - 30)
        points = [(x, y)]
        for _s in range(rnd.randint(3, 6)):
            x = max(36, min(W - 36, x + rnd.randint(-70, 70)))
            y = max(top + 12, min(bot - 12, y + rnd.randint(-34, 34)))
            points.append((x, y))
        draw_polyline(c, points, (118, 157, 186), 0.55)

    # Snow chunks
    for _ in range(38):
        cx = rnd.randint(38, W - 38)
        cy = rnd.randint(top + 20, bot - 20)
        r = rnd.randint(4, 11)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
                    c.blend(x, y, (211, 234, 248), 0.36)

    draw_start_finish_zones(c, 84, W - 84, top, bot)
    return c


def make_neon() -> Canvas:
    c = Canvas(W, H)
    draw_curbs(c, (43, 230, 255), (255, 70, 191), (14, 12, 22), (241, 244, 255))

    top, bot = 64, 576

    for y in range(top, bot):
        t = (y - top) / (bot - top)
        base = mix((62, 49, 90), (38, 31, 62), t)
        for x in range(22, W - 22):
            pulse = 2.8 * math.sin((x * 0.035) - (y * 0.019))
            c.set(x, y, (clamp(base[0] + pulse), clamp(base[1] + pulse), clamp(base[2] + pulse)))

    # Geometric islands grid
    rows = [top + 92, top + 212, top + 332, top + 452]
    for ry in rows:
        for i in range(4):
            cx = 120 + i * 130
            for y in range(ry - 30, ry + 31):
                w = max(1, 30 - abs(y - ry))
                col = (113, 235, 255) if (i % 2 == 0) else (255, 108, 205)
                for x in range(cx - w, cx + w + 1):
                    c.blend(x, y, col, 0.24)

    # Diagonal lane guides
    def diag(x0: int, y0: int, slope: float, col: tuple[int, int, int]):
        for k in range(470):
            x = x0 + k
            y = y0 + int(slope * k)
            if 30 < x < W - 30 and top < y < bot and (k // 18) % 2 == 0:
                for t in (-1, 0, 1):
                    c.blend(x, y + t, col, 0.9 if t == 0 else 0.45)

    diag(62, top + 62, 0.18, (124, 242, 255))
    diag(44, top + 190, 0.0, (255, 164, 93))
    diag(62, top + 320, -0.18, (124, 242, 255))

    # Electric hazard bolts
    bolts = [
        [(442, 126), (474, 110), (458, 146), (488, 132)],
        [(286, 262), (319, 247), (304, 282), (336, 266)],
        [(500, 410), (534, 391), (522, 427), (552, 410)],
    ]
    for pts in bolts:
        draw_polyline(c, pts, (255, 80, 195), 0.72)
        draw_polyline(c, pts, (102, 230, 255), 0.36)

    # Glow nodes
    for cx, cy, col in [(170, 145, (80, 224, 255)), (350, 290, (255, 96, 188)), (520, 455, (80, 224, 255))]:
        for y in range(cy - 38, cy + 39):
            for x in range(cx - 38, cx + 39):
                d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
                if d < 38:
                    c.blend(x, y, col, max(0.0, 0.19 * (1.0 - d / 38.0)))

    draw_start_finish_zones(c, 40, W - 40, top, bot)
    return c


# ----------------------------
# Main
# ----------------------------
def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    tracks = {
        "cartoon_chamet_3lane.png": make_asphalt(),
        "cartoon_chamet_sand_3lane.png": make_sand(),
        "cartoon_chamet_ice_3lane.png": make_ice(),
        "cartoon_chamet_neon_3lane.png": make_neon(),
    }

    for name, canvas in tracks.items():
        out = OUT_DIR / name
        canvas.save_png(out)
        print(f"Wrote {out} ({W}x{H})")


if __name__ == "__main__":
    main()
