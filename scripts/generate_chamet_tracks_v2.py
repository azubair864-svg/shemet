#!/usr/bin/env python3
"""Generate 4 distinct cartoon racing tracks with realistic road details.
Outputs overwrite current Chamet-track files used by the game.
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

W, H = 640, 640
OUT_DIR = Path('/Users/naveensandeepa/StudioProjects/dating_live_app/assets/images/track_images')


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
        self.p = bytearray(w * h * 3)

    def set(self, x: int, y: int, c: tuple[int, int, int]):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 3
            self.p[i], self.p[i + 1], self.p[i + 2] = c

    def get(self, x: int, y: int) -> tuple[int, int, int]:
        i = (y * self.w + x) * 3
        return self.p[i], self.p[i + 1], self.p[i + 2]

    def blend(self, x: int, y: int, c: tuple[int, int, int], a: float):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        aa = max(0.0, min(1.0, a))
        r0, g0, b0 = self.get(x, y)
        self.set(
            x,
            y,
            (
                clamp(r0 * (1.0 - aa) + c[0] * aa),
                clamp(g0 * (1.0 - aa) + c[1] * aa),
                clamp(b0 * (1.0 - aa) + c[2] * aa),
            ),
        )

    def fill_grad(self, y0: int, y1: int, a: tuple[int, int, int], b: tuple[int, int, int]):
        for y in range(y0, y1):
            t = (y - y0) / max(1, y1 - y0 - 1)
            c = mix(a, b, t)
            for x in range(self.w):
                self.set(x, y, c)

    def save_png(self, out: Path):
        def chunk(tag: bytes, data: bytes) -> bytes:
            return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)

        raw = bytearray()
        stride = self.w * 3
        for y in range(self.h):
            raw.append(0)
            s = y * stride
            raw.extend(self.p[s:s + stride])

        png = bytearray(b'\x89PNG\r\n\x1a\n')
        png.extend(chunk(b'IHDR', struct.pack('!IIBBBBB', self.w, self.h, 8, 2, 0, 0, 0)))
        png.extend(chunk(b'IDAT', zlib.compress(bytes(raw), level=9)))
        png.extend(chunk(b'IEND', b''))
        out.write_bytes(png)


def base_curbs(c: Canvas, top_colors: tuple[tuple[int, int, int], tuple[int, int, int]], side_checker: tuple[tuple[int, int, int], tuple[int, int, int]]):
    curb_h = 34
    tile = 42
    for y in range(curb_h):
        for x in range(W):
            cc = top_colors[(x // tile) % 2]
            glow = 0.82 + 0.25 * (y / max(1, curb_h - 1))
            c.set(x, y, (clamp(cc[0] * glow), clamp(cc[1] * glow), clamp(cc[2] * glow)))
    for y in range(H - curb_h, H):
        yy = y - (H - curb_h)
        for x in range(W):
            cc = top_colors[(x // tile) % 2]
            glow = 1.07 - 0.25 * (yy / max(1, curb_h - 1))
            c.set(x, y, (clamp(cc[0] * glow), clamp(cc[1] * glow), clamp(cc[2] * glow)))

    rail_w = 20
    for y in range(H):
        cc = side_checker[(y // 24) % 2]
        for x in range(rail_w):
            c.set(x, y, cc)
            c.set(W - 1 - x, y, cc)


def dashed(c: Canvas, y: int, x0: int, x1: int, color: tuple[int, int, int], dash: int, gap: int, thick: int = 2):
    x = x0
    while x < x1:
        for xx in range(x, min(x + dash, x1)):
            for t in range(-thick // 2, thick // 2 + 1):
                c.blend(xx, y + t, color, 0.9 if t == 0 else 0.45)
        x += dash + gap


def draw_crack(c: Canvas, pts: list[tuple[int, int]], color: tuple[int, int, int]):
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            t = s / steps
            x = int(x0 + (x1 - x0) * t)
            y = int(y0 + (y1 - y0) * t)
            c.blend(x, y, color, 0.55)
            c.blend(x, y + 1, color, 0.28)


def draw_pothole(c: Canvas, cx: int, cy: int, rx: int, ry: int):
    for y in range(cy - ry - 2, cy + ry + 3):
        for x in range(cx - rx - 2, cx + rx + 3):
            dx = (x - cx) / max(1, rx)
            dy = (y - cy) / max(1, ry)
            d = dx * dx + dy * dy
            if d <= 1.15:
                if d > 0.88:
                    c.blend(x, y, (88, 78, 67), 0.40)
                elif d > 0.40:
                    c.blend(x, y, (59, 52, 47), 0.42)
                else:
                    c.blend(x, y, (38, 34, 32), 0.48)


def track_asphalt(out_name: str):
    c = Canvas(W, H)
    base_curbs(c, ((243, 64, 68), (240, 244, 248)), ((29, 30, 33), (242, 244, 247)))

    road_top, road_bottom = 64, 576
    # dark asphalt with subtle temperature variation
    for y in range(road_top, road_bottom):
        t = (y - road_top) / (road_bottom - road_top)
        base = mix((66, 69, 75), (54, 58, 64), t)
        for x in range(22, W - 22):
            side = abs((x - W / 2) / (W / 2))
            tone = 1.0 - 0.12 * (side ** 1.5)
            n = (math.sin(x * 0.07 + y * 0.05) + math.sin(x * 0.19 - y * 0.04)) * 0.8
            cc = (
                clamp(base[0] * tone + n),
                clamp(base[1] * tone + n),
                clamp(base[2] * tone + n),
            )
            c.set(x, y, cc)

    # three lanes
    l1 = road_top + (road_bottom - road_top) // 3
    l2 = road_top + 2 * (road_bottom - road_top) // 3
    dashed(c, l1, 44, W - 44, (235, 239, 242), 42, 24, 2)
    dashed(c, l2, 44, W - 44, (235, 239, 242), 42, 24, 2)

    # road patches (rectangular repairs)
    repairs = [(145, 140, 90, 32), (450, 190, 110, 30), (300, 350, 140, 38), (500, 470, 90, 28)]
    for x, y, w, h in repairs:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                c.blend(xx, yy, (78, 82, 89), 0.45)
        # edge tar
        for xx in range(x, x + w):
            c.blend(xx, y, (38, 40, 44), 0.55)
            c.blend(xx, y + h - 1, (38, 40, 44), 0.55)

    # cracks + potholes
    draw_crack(c, [(75, 125), (130, 134), (190, 126), (260, 138)], (30, 31, 35))
    draw_crack(c, [(350, 420), (405, 430), (470, 422), (530, 438)], (28, 30, 34))
    draw_crack(c, [(120, 520), (170, 505), (230, 516)], (29, 31, 35))
    draw_pothole(c, 96, 210, 12, 9)
    draw_pothole(c, 232, 468, 16, 10)
    draw_pothole(c, 512, 280, 14, 10)

    # shoulder dust + guard color near edges
    for y in range(road_top, road_bottom):
        c.blend(22, y, (250, 199, 89), 0.15)
        c.blend(W - 23, y, (250, 199, 89), 0.15)

    c.save_png(OUT_DIR / out_name)


def track_sand(out_name: str):
    c = Canvas(W, H)
    base_curbs(c, ((242, 82, 75), (241, 245, 247)), ((28, 30, 32), (243, 245, 247)))

    road_top, road_bottom = 64, 576
    left = 210

    # left sand shoulder w/ dunes and stones
    for y in range(road_top, road_bottom):
        t = (y - road_top) / (road_bottom - road_top)
        sb = mix((236, 217, 166), (224, 202, 151), t)
        for x in range(22, left):
            wave = math.sin((x * 0.05) + (y * 0.018)) * 1.8
            c.set(x, y, (clamp(sb[0] + wave), clamp(sb[1] + wave), clamp(sb[2] + wave)))

    # right sandy-asphalt hybrid
    for y in range(road_top, road_bottom):
        t = (y - road_top) / (road_bottom - road_top)
        rb = mix((129, 116, 79), (113, 100, 70), t)
        for x in range(left, W - 22):
            n = math.sin(x * 0.11 + y * 0.03) * 1.4
            c.set(x, y, (clamp(rb[0] + n), clamp(rb[1] + n), clamp(rb[2] + n)))

    # split line
    for y in range(road_top, road_bottom):
        c.blend(left, y, (248, 203, 79), 0.55)
        c.blend(left + 1, y, (248, 203, 79), 0.30)

    # lane dashes + center block strips
    l1 = road_top + (road_bottom - road_top) // 3
    l2 = road_top + 2 * (road_bottom - road_top) // 3
    dashed(c, l1, left + 16, W - 36, (239, 205, 94), 28, 18, 2)
    dashed(c, l2, left + 16, W - 36, (239, 205, 94), 28, 18, 2)

    cols = [left + 56, left + 132, left + 208, left + 284, left + 360]
    for cx in cols:
        y = road_top + 24
        while y < road_bottom - 24:
            for yy in range(y, y + 30):
                for xx in range(cx - 8, cx + 8):
                    c.blend(xx, yy, (198, 173, 98), 0.52)
            y += 50

    # sand rocks + grooves
    for cx, cy, r in [(66, 150, 9), (120, 230, 7), (176, 300, 10), (90, 430, 8), (150, 510, 11)]:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    c.blend(x, y, (163, 148, 111), 0.42)

    for k in range(7):
        y0 = road_top + 40 + k * 68
        pts = [(34, y0 + int(5 * math.sin(0.2 * 34 + k))), (90, y0 + int(5 * math.sin(0.2 * 90 + k))), (145, y0 + int(5 * math.sin(0.2 * 145 + k))), (196, y0 + int(5 * math.sin(0.2 * 196 + k)))]
        draw_crack(c, pts, (141, 129, 102))

    c.save_png(OUT_DIR / out_name)


def track_ice(out_name: str):
    c = Canvas(W, H)
    base_curbs(c, ((48, 152, 232), (240, 249, 255)), ((29, 50, 64), (238, 248, 255)))

    road_top, road_bottom = 64, 576
    left = 210

    for y in range(road_top, road_bottom):
        t = (y - road_top) / (road_bottom - road_top)
        lb = mix((219, 236, 248), (202, 224, 241), t)
        rb = mix((140, 170, 198), (126, 156, 185), t)
        for x in range(22, left):
            shine = 2.0 * math.sin(x * 0.03 + y * 0.02)
            c.set(x, y, (clamp(lb[0] + shine), clamp(lb[1] + shine), clamp(lb[2] + shine)))
        for x in range(left, W - 22):
            n = math.sin(x * 0.09 - y * 0.02) * 1.5
            c.set(x, y, (clamp(rb[0] + n), clamp(rb[1] + n), clamp(rb[2] + n)))

    for y in range(road_top, road_bottom):
        c.blend(left, y, (156, 216, 255), 0.60)

    l1 = road_top + (road_bottom - road_top) // 3
    l2 = road_top + 2 * (road_bottom - road_top) // 3
    dashed(c, l1, left + 16, W - 36, (226, 246, 255), 30, 18, 2)
    dashed(c, l2, left + 16, W - 36, (226, 246, 255), 30, 18, 2)

    # icy blocks
    cols = [left + 56, left + 132, left + 208, left + 284, left + 360]
    for cx in cols:
        y = road_top + 24
        while y < road_bottom - 24:
            for yy in range(y, y + 30):
                for xx in range(cx - 8, cx + 8):
                    c.blend(xx, yy, (176, 214, 237), 0.48)
            y += 50

    # fractures and frost cracks
    draw_crack(c, [(52, 120), (90, 108), (125, 122), (166, 112)], (128, 163, 186))
    draw_crack(c, [(66, 320), (106, 334), (155, 318), (196, 338)], (121, 155, 178))
    draw_crack(c, [(260, 178), (310, 190), (350, 170), (398, 188)], (101, 134, 157))
    draw_crack(c, [(360, 460), (418, 442), (482, 468), (550, 454)], (96, 130, 154))

    # snow chunks on shoulder
    for cx, cy, r in [(70, 160, 9), (118, 248, 7), (166, 296, 10), (90, 430, 8), (150, 512, 9)]:
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    c.blend(x, y, (204, 228, 243), 0.45)

    c.save_png(OUT_DIR / out_name)


def track_neon(out_name: str):
    c = Canvas(W, H)
    base_curbs(c, ((45, 231, 255), (255, 72, 192)), ((14, 12, 21), (240, 244, 255)))

    road_top, road_bottom = 64, 576
    left = 210

    for y in range(road_top, road_bottom):
        t = (y - road_top) / (road_bottom - road_top)
        lb = mix((61, 50, 88), (51, 42, 76), t)
        rb = mix((88, 70, 117), (73, 58, 102), t)
        for x in range(22, left):
            glow = math.sin(x * 0.04 + y * 0.03) * 1.5
            c.set(x, y, (clamp(lb[0] + glow), clamp(lb[1] + glow), clamp(lb[2] + glow)))
        for x in range(left, W - 22):
            n = math.sin(x * 0.10 - y * 0.025) * 1.5
            c.set(x, y, (clamp(rb[0] + n), clamp(rb[1] + n), clamp(rb[2] + n)))

    for y in range(road_top, road_bottom):
        c.blend(left, y, (255, 174, 78), 0.55)

    l1 = road_top + (road_bottom - road_top) // 3
    l2 = road_top + 2 * (road_bottom - road_top) // 3
    dashed(c, l1, left + 16, W - 36, (120, 240, 255), 30, 18, 2)
    dashed(c, l2, left + 16, W - 36, (120, 240, 255), 30, 18, 2)

    cols = [left + 56, left + 132, left + 208, left + 284, left + 360]
    for cx in cols:
        y = road_top + 24
        while y < road_bottom - 24:
            for yy in range(y, y + 30):
                for xx in range(cx - 8, cx + 8):
                    c.blend(xx, yy, (255, 157, 89), 0.50)
            y += 50

    # hazard triangles and electric cracks
    for cx in range(left + 42, W - 40, 78):
        cy = road_top + (road_bottom - road_top) // 2 + int(5 * math.sin(cx * 0.1))
        for y in range(cy - 10, cy + 11):
            w = 12 - abs(y - cy)
            for x in range(cx - w, cx + w + 1):
                c.blend(x, y, (255, 86, 182), 0.20)

    draw_crack(c, [(45, 126), (87, 118), (128, 130), (175, 122)], (123, 106, 160))
    draw_crack(c, [(66, 328), (112, 340), (158, 328), (198, 346)], (123, 106, 160))
    draw_crack(c, [(270, 210), (320, 195), (377, 214), (430, 200)], (89, 189, 225))
    draw_crack(c, [(355, 470), (412, 452), (482, 480), (550, 462)], (89, 189, 225))

    c.save_png(OUT_DIR / out_name)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    track_asphalt('cartoon_chamet_3lane.png')
    track_sand('cartoon_chamet_sand_3lane.png')
    track_ice('cartoon_chamet_ice_3lane.png')
    track_neon('cartoon_chamet_neon_3lane.png')
    print('Done: 4 distinct tracks generated.')


if __name__ == '__main__':
    main()
