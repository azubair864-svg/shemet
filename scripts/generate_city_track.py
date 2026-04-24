#!/usr/bin/env python3
"""Generate a Shemet-style cartoon city 3-lane track (stdlib-only PNG)."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W, H = 640, 640
ROAD_TOP, ROAD_BOTTOM = 74, 566


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return lo if v < lo else hi if v > hi else int(v)


def mix(a, b, t: float):
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def noise(x: int, y: int) -> float:
    n = (x * 1103515245 + y * 12345) & 0xFFFFFFFF
    n ^= n >> 15
    n = (n * 2654435761) & 0xFFFFFFFF
    n ^= n >> 13
    return ((n & 0xFFFF) / 65535.0) * 2.0 - 1.0


pix = bytearray(W * H * 3)


def set_px(x: int, y: int, c):
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 3
        pix[i], pix[i + 1], pix[i + 2] = c


def get_px(x: int, y: int):
    i = (y * W + x) * 3
    return pix[i], pix[i + 1], pix[i + 2]


def blend_px(x: int, y: int, c, a: float):
    if not (0 <= x < W and 0 <= y < H):
        return
    r0, g0, b0 = get_px(x, y)
    aa = max(0.0, min(1.0, a))
    set_px(
        x,
        y,
        (
            clamp(r0 * (1 - aa) + c[0] * aa),
            clamp(g0 * (1 - aa) + c[1] * aa),
            clamp(b0 * (1 - aa) + c[2] * aa),
        ),
    )


# 1) Base ambient background
for y in range(H):
    t = y / (H - 1)
    c = mix((45, 52, 67), (35, 41, 56), t)
    for x in range(W):
        n = noise(x, y) * 1.8
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))

# 2) Top/bottom curb checkers (yellow/black, city racing vibe)
curb_h, tile_w = 50, 36
for y in list(range(curb_h)) + list(range(H - curb_h, H)):
    for x in range(W):
        k = (x // tile_w) % 2
        base = (250, 185, 46) if k == 0 else (35, 36, 39)

        # bevel shine
        if y < curb_h:
            edge = y / max(1, curb_h - 1)
        else:
            edge = (H - 1 - y) / max(1, curb_h - 1)
        f = 0.82 + 0.26 * edge
        set_px(x, y, (clamp(base[0] * f), clamp(base[1] * f), clamp(base[2] * f)))

# dark separator strip under curbs
for x in range(W):
    for d in range(4):
        blend_px(x, curb_h + d, (15, 16, 18), 0.55)
        blend_px(x, H - curb_h - 1 - d, (15, 16, 18), 0.55)

# 3) Main road surface
road_h = ROAD_BOTTOM - ROAD_TOP
for y in range(ROAD_TOP, ROAD_BOTTOM):
    t = (y - ROAD_TOP) / max(1, road_h - 1)
    base = mix((70, 76, 88), (62, 68, 80), t)

    # Center focus so vehicles pop
    focus = max(0.0, 1.0 - abs(t - 0.5) * 2.0)
    base = (
        clamp(base[0] + 6 * focus),
        clamp(base[1] + 6 * focus),
        clamp(base[2] + 8 * focus),
    )

    # side falloff
    for x in range(W):
        side = abs((x / (W - 1)) - 0.5) * 2.0
        side_dark = 1.0 - (side**1.6) * 0.18
        n = noise(x, y) * 1.4
        c = (
            clamp(base[0] * side_dark + n),
            clamp(base[1] * side_dark + n),
            clamp(base[2] * side_dark + n),
        )
        set_px(x, y, c)

# 4) Lane dashed lines
divs = [ROAD_TOP + road_h // 3, ROAD_TOP + (2 * road_h) // 3]
for y0 in divs:
    for t in range(-2, 3):
        y = y0 + t
        x = 46
        dash, gap = 42, 24
        while x < W - 46:
            for xx in range(x, min(W - 46, x + dash)):
                blend_px(xx, y, (233, 236, 241), 0.95 if abs(t) <= 1 else 0.5)
            x += dash + gap

# 5) Add middle diversity: small reflective arrows pattern at center lane
mid = ROAD_TOP + road_h // 2
for cx in range(80, W - 80, 95):
    for yy in range(mid - 8, mid + 9):
        d = abs(yy - mid)
        half = max(0, 12 - d)
        for xx in range(cx - half, cx + half + 1):
            if xx <= cx:
                blend_px(xx, yy, (115, 227, 255), 0.12)
            else:
                blend_px(xx, yy, (255, 146, 86), 0.10)

# 6) edge strips for readability
for y in range(ROAD_TOP, ROAD_BOTTOM):
    blend_px(8, y, (255, 201, 73), 0.20)
    blend_px(W - 9, y, (255, 201, 73), 0.20)

# 7) transition bands
for x in range(W):
    for d in range(3):
        blend_px(x, ROAD_TOP + d, (120, 129, 145), 0.68)
        blend_px(x, ROAD_BOTTOM - 1 - d, (120, 129, 145), 0.68)


# PNG encode

def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)

raw = bytearray()
stride = W * 3
for y in range(H):
    raw.append(0)
    s = y * stride
    raw.extend(pix[s:s + stride])

png = bytearray(b'\x89PNG\r\n\x1a\n')
png.extend(chunk(b'IHDR', struct.pack('!IIBBBBB', W, H, 8, 2, 0, 0, 0)))
png.extend(chunk(b'IDAT', zlib.compress(bytes(raw), level=9)))
png.extend(chunk(b'IEND', b''))

out = Path('assets/images/track_images/cartoon_city_3lane.png')
out.write_bytes(png)
print(f'Wrote {out} ({W}x{H})')
