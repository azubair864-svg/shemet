#!/usr/bin/env python3
"""Generate a stylized 3-lane ice track PNG using Python stdlib only."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W = 640
H = 640
ROAD_TOP = 74
ROAD_BOTTOM = 566


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return lo if v < lo else hi if v > hi else int(v)


def mix(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(c1[0] + (c2[0] - c1[0]) * t),
        clamp(c1[1] + (c2[1] - c1[1]) * t),
        clamp(c1[2] + (c2[2] - c1[2]) * t),
    )


def hash_noise(x: int, y: int) -> float:
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    n ^= n >> 16
    return ((n & 0xFFFF) / 65535.0) * 2.0 - 1.0


pixels = bytearray(W * H * 3)


def set_px(x: int, y: int, c: tuple[int, int, int]) -> None:
    if x < 0 or x >= W or y < 0 or y >= H:
        return
    i = (y * W + x) * 3
    pixels[i] = c[0]
    pixels[i + 1] = c[1]
    pixels[i + 2] = c[2]


def get_px(x: int, y: int) -> tuple[int, int, int]:
    i = (y * W + x) * 3
    return pixels[i], pixels[i + 1], pixels[i + 2]


def blend_px(x: int, y: int, c: tuple[int, int, int], a: float) -> None:
    if x < 0 or x >= W or y < 0 or y >= H:
        return
    r0, g0, b0 = get_px(x, y)
    aa = max(0.0, min(1.0, a))
    set_px(
        x,
        y,
        (
            clamp(r0 * (1.0 - aa) + c[0] * aa),
            clamp(g0 * (1.0 - aa) + c[1] * aa),
            clamp(b0 * (1.0 - aa) + c[2] * aa),
        ),
    )


# 1) Whole canvas base gradient (cold ambiance)
for y in range(H):
    t = y / (H - 1)
    base = mix((188, 223, 244), (168, 208, 234), t)
    for x in range(W):
        n = hash_noise(x, y) * 2.2
        set_px(x, y, (clamp(base[0] + n), clamp(base[1] + n), clamp(base[2] + n)))


# 2) Top and bottom curb checkers
curb_h = 50
tile_w = 50
for y in list(range(0, curb_h)) + list(range(H - curb_h, H)):
    for x in range(W):
        idx = (x // tile_w) % 2
        c = (48, 145, 221) if idx == 0 else (236, 245, 252)

        # slight bevel for cartoon look
        edge_factor = 1.0
        if y < curb_h:
            edge_factor = 0.85 + 0.15 * (y / max(1, curb_h - 1))
        else:
            yy = y - (H - curb_h)
            edge_factor = 1.0 - 0.15 * (yy / max(1, curb_h - 1))
        c = (clamp(c[0] * edge_factor), clamp(c[1] * edge_factor), clamp(c[2] * edge_factor))

        set_px(x, y, c)


# 3) Transition snow band between curb and track
for y in range(curb_h, ROAD_TOP):
    t = (y - curb_h) / max(1, ROAD_TOP - curb_h - 1)
    c = mix((210, 232, 246), (186, 218, 239), t)
    for x in range(W):
        n = hash_noise(x, y) * 1.5
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))

for y in range(ROAD_BOTTOM, H - curb_h):
    t = (y - ROAD_BOTTOM) / max(1, (H - curb_h) - ROAD_BOTTOM - 1)
    c = mix((186, 218, 239), (210, 232, 246), t)
    for x in range(W):
        n = hash_noise(x, y) * 1.5
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))


# 4) Main road surface (kept clean so vehicles pop)
road_h = ROAD_BOTTOM - ROAD_TOP
for y in range(ROAD_TOP, ROAD_BOTTOM):
    yt = (y - ROAD_TOP) / max(1, road_h - 1)

    # lane-center emphasis: slightly cleaner and brighter around middle band
    focus = 1.0 - abs(yt - 0.5) * 2.0
    focus = max(0.0, focus)

    c = mix((180, 216, 238), (169, 205, 229), yt)
    c = (
        clamp(c[0] + 6 * focus),
        clamp(c[1] + 7 * focus),
        clamp(c[2] + 8 * focus),
    )

    # soft vignette near top/bottom of road
    edge = min(y - ROAD_TOP, ROAD_BOTTOM - 1 - y)
    edge_t = max(0.0, min(1.0, edge / 70.0))
    dark = 0.89 + 0.11 * edge_t
    c = (clamp(c[0] * dark), clamp(c[1] * dark), clamp(c[2] * dark))

    for x in range(W):
        # tiny texture only; avoids visual noise over vehicles
        n = hash_noise(x, y)
        set_px(x, y, (clamp(c[0] + n * 1.2), clamp(c[1] + n * 1.2), clamp(c[2] + n * 1.2)))


# 5) Track edge bands
for x in range(W):
    for dy in range(3):
        blend_px(x, ROAD_TOP + dy, (141, 193, 224), 0.75)
        blend_px(x, ROAD_BOTTOM - 1 - dy, (141, 193, 224), 0.75)

    blend_px(x, ROAD_TOP - 1, (232, 244, 252), 0.8)
    blend_px(x, ROAD_BOTTOM, (232, 244, 252), 0.8)


# 6) Dashed lane dividers (3-lane road -> 2 divider lines)
divider_ys = [ROAD_TOP + road_h // 3, ROAD_TOP + (2 * road_h) // 3]
for y0 in divider_ys:
    for t in range(-3, 4):
        y = y0 + t
        dash = 40
        gap = 25
        x = 48
        while x < W - 48:
            for xx in range(x, min(x + dash, W - 48)):
                base = (232, 243, 251) if abs(t) <= 1 else (197, 222, 239)
                blend_px(xx, y, base, 0.95 if abs(t) <= 1 else 0.55)
            x += dash + gap


# 7) Subtle ice streaks (away from lane-center for readability)
streak_rows = [ROAD_TOP + 44, ROAD_TOP + 112, ROAD_BOTTOM - 120, ROAD_BOTTOM - 58]
for idx, y_start in enumerate(streak_rows):
    for x in range(36, W - 36):
        y = int(y_start + 7.0 * math.sin((x / 52.0) + idx * 1.3))
        # avoid drawing too strong on divider region
        if any(abs(y - d) < 14 for d in divider_ys):
            continue
        blend_px(x, y, (224, 243, 255), 0.22)
        blend_px(x, y + 1, (208, 232, 247), 0.16)


# 8) Blue edge glow to sell ice theme
for y in range(ROAD_TOP, ROAD_BOTTOM):
    glow = (math.sin((y - ROAD_TOP) / 18.0) + 1.0) * 0.5
    blend_px(4, y, (74, 167, 236), 0.2 * glow)
    blend_px(W - 5, y, (74, 167, 236), 0.2 * glow)


# --- PNG encoding ---
def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)


raw = bytearray()
stride = W * 3
for y in range(H):
    raw.append(0)  # filter type 0 (None)
    s = y * stride
    raw.extend(pixels[s : s + stride])

png = bytearray(b'\x89PNG\r\n\x1a\n')
png.extend(chunk(b'IHDR', struct.pack('!IIBBBBB', W, H, 8, 2, 0, 0, 0)))
png.extend(chunk(b'IDAT', zlib.compress(bytes(raw), level=9)))
png.extend(chunk(b'IEND', b''))

out = Path('assets/images/track_images/cartoon_ice_3lane.png')
out.write_bytes(png)
print(f'Wrote {out} ({W}x{H})')
