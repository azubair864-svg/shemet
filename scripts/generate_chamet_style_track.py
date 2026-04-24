#!/usr/bin/env python3
"""Generate a Chamet-style cartoon race track (640x640, stdlib only)."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W, H = 640, 640
ROAD_TOP, ROAD_BOTTOM = 58, 582
LEFT_SHOULDER = 245  # left sandy area width


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return lo if v < lo else hi if v > hi else int(v)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def noise(x: int, y: int) -> float:
    n = (x * 73856093 ^ y * 19349663) & 0xFFFFFFFF
    n ^= n >> 13
    n = (n * 1274126177) & 0xFFFFFFFF
    n ^= n >> 16
    return ((n & 0xFFFF) / 65535.0) * 2.0 - 1.0


pix = bytearray(W * H * 3)


def set_px(x: int, y: int, c: tuple[int, int, int]) -> None:
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 3
        pix[i], pix[i + 1], pix[i + 2] = c


def get_px(x: int, y: int) -> tuple[int, int, int]:
    i = (y * W + x) * 3
    return pix[i], pix[i + 1], pix[i + 2]


def blend_px(x: int, y: int, c: tuple[int, int, int], a: float) -> None:
    if not (0 <= x < W and 0 <= y < H):
        return
    aa = max(0.0, min(1.0, a))
    r0, g0, b0 = get_px(x, y)
    set_px(
        x,
        y,
        (
            clamp(r0 * (1.0 - aa) + c[0] * aa),
            clamp(g0 * (1.0 - aa) + c[1] * aa),
            clamp(b0 * (1.0 - aa) + c[2] * aa),
        ),
    )


# 1) base ambience
for y in range(H):
    t = y / (H - 1)
    c = mix((230, 214, 168), (210, 193, 150), t)
    for x in range(W):
        n = noise(x, y) * 1.6
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))


# 2) top and bottom curb bars (red-white)
curb_h = 32
tile_w = 42
for y in list(range(0, curb_h)) + list(range(H - curb_h, H)):
    for x in range(W):
        block = (x // tile_w) % 2
        c = (242, 71, 74) if block == 0 else (241, 245, 248)
        # cartoon bevel
        if y < curb_h:
            edge = y / max(1, curb_h - 1)
        else:
            edge = (H - 1 - y) / max(1, curb_h - 1)
        lift = 0.82 + 0.25 * edge
        set_px(x, y, (clamp(c[0] * lift), clamp(c[1] * lift), clamp(c[2] * lift)))


# 3) road section split into shoulder + main road
for y in range(ROAD_TOP, ROAD_BOTTOM):
    yt = (y - ROAD_TOP) / max(1, (ROAD_BOTTOM - ROAD_TOP - 1))

    for x in range(W):
        if x < LEFT_SHOULDER:
            # sandy shoulder
            st = x / max(1, LEFT_SHOULDER)
            s = mix((238, 219, 167), (224, 203, 154), st * 0.8)
            s = mix(s, (233, 214, 161), yt * 0.15)
            n = noise(x, y) * 2.1
            c = (clamp(s[0] + n), clamp(s[1] + n), clamp(s[2] + n))
            set_px(x, y, c)
        else:
            # main dark asphalt-brown
            rt = (x - LEFT_SHOULDER) / max(1, (W - LEFT_SHOULDER - 1))
            r = mix((122, 109, 74), (102, 90, 62), rt * 0.65)
            r = mix(r, (108, 96, 66), yt * 0.2)
            # keep center readable for cars
            lane_focus = 1.0 - abs(rt - 0.55) * 1.6
            lane_focus = max(0.0, min(1.0, lane_focus))
            r = (clamp(r[0] + 8 * lane_focus), clamp(r[1] + 8 * lane_focus), clamp(r[2] + 6 * lane_focus))
            n = noise(x, y) * 2.0
            set_px(x, y, (clamp(r[0] + n), clamp(r[1] + n), clamp(r[2] + n)))


# 4) vertical black-white checker side rails like screenshot edges
rail_w = 20
for y in range(H):
    for x in range(rail_w):
        block = (y // 24) % 2
        c = (28, 30, 32) if block == 0 else (243, 245, 247)
        set_px(x, y, c)
        set_px(W - 1 - x, y, c)


# 5) boundary between shoulder and road
for y in range(ROAD_TOP, ROAD_BOTTOM):
    for d in range(3):
        blend_px(LEFT_SHOULDER + d, y, (248, 204, 81), 0.55)
    blend_px(LEFT_SHOULDER - 1, y, (70, 60, 38), 0.35)


# 6) lane separators on main road (3 lanes -> 2 divider lines)
road_w = W - LEFT_SHOULDER
lane_h = (ROAD_BOTTOM - ROAD_TOP) / 3.0
div_ys = [int(ROAD_TOP + lane_h), int(ROAD_TOP + 2 * lane_h)]
for y0 in div_ys:
    for t in range(-1, 2):
        y = y0 + t
        x = LEFT_SHOULDER + 14
        while x < W - 28:
            dash = 26
            gap = 18
            for xx in range(x, min(W - 24, x + dash)):
                blend_px(xx, y, (239, 205, 94), 0.88 if t == 0 else 0.5)
            x += dash + gap


# 7) rectangular lane blocks across road (key feature from screenshot)
block_cols = [LEFT_SHOULDER + 58, LEFT_SHOULDER + 132, LEFT_SHOULDER + 206, LEFT_SHOULDER + 280, LEFT_SHOULDER + 354]
for cx in block_cols:
    y = ROAD_TOP + 28
    while y < ROAD_BOTTOM - 26:
        h = 30
        w = 18
        for yy in range(y, min(ROAD_BOTTOM - 6, y + h)):
            for xx in range(cx - w // 2, cx + w // 2):
                # soft 3D tint
                top_shade = 1.12 if yy - y < 6 else 1.0
                col = (clamp(202 * top_shade), clamp(175 * top_shade), clamp(97 * top_shade))
                blend_px(xx, yy, col, 0.52)
                if xx == cx - w // 2 or xx == cx + w // 2 - 1:
                    blend_px(xx, yy, (145, 124, 66), 0.3)
        y += 52


# 8) shoulder details: cracks + oil-like dots to avoid empty look
for k in range(8):
    sy = ROAD_TOP + 36 + k * 58
    amp = 5 + (k % 3)
    for x in range(34, LEFT_SHOULDER - 26):
        yy = int(sy + amp * math.sin((x / 28.0) + k * 0.9))
        blend_px(x, yy, (122, 112, 92), 0.22)
        if k % 2 == 0:
            blend_px(x, yy + 1, (98, 88, 72), 0.18)

for i in range(9):
    cx = 46 + i * 22
    cy = ROAD_TOP + 70 + (i % 3) * 90
    r = 7 + (i % 2) * 3
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d <= r * r:
                blend_px(x, y, (50, 48, 45), 0.2)


# 9) road vignette and top/bottom transitions
for y in range(ROAD_TOP, ROAD_BOTTOM):
    edge = min(y - ROAD_TOP, ROAD_BOTTOM - 1 - y)
    fade = max(0.0, min(1.0, edge / 36.0))
    alpha = (1.0 - fade) * 0.3
    for x in range(rail_w, W - rail_w):
        blend_px(x, y, (0, 0, 0), alpha)

for x in range(rail_w, W - rail_w):
    for d in range(3):
        blend_px(x, ROAD_TOP + d, (243, 244, 248), 0.35)
        blend_px(x, ROAD_BOTTOM - 1 - d, (243, 244, 248), 0.35)


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

out = Path('/Users/naveensandeepa/StudioProjects/dating_live_app/assets/images/track_images/cartoon_chamet_3lane.png')
out.write_bytes(png)
print(f'Wrote {out} ({W}x{H})')
