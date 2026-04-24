#!/usr/bin/env python3
"""Generate a cartoon cyber/neon 3-lane track PNG (stdlib only)."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W = 640
H = 640
ROAD_TOP = 72
ROAD_BOTTOM = 568


def clamp(v: float, lo: int = 0, hi: int = 255) -> int:
    return lo if v < lo else hi if v > hi else int(v)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


def noise(x: int, y: int) -> float:
    n = (x * 1597334677 + y * 3812015801) & 0xFFFFFFFF
    n ^= n >> 13
    n = (n * 1274126177) & 0xFFFFFFFF
    n ^= n >> 16
    return ((n & 0xFFFF) / 65535.0) * 2.0 - 1.0


pixels = bytearray(W * H * 3)


def set_px(x: int, y: int, c: tuple[int, int, int]) -> None:
    if 0 <= x < W and 0 <= y < H:
        i = (y * W + x) * 3
        pixels[i] = c[0]
        pixels[i + 1] = c[1]
        pixels[i + 2] = c[2]


def get_px(x: int, y: int) -> tuple[int, int, int]:
    i = (y * W + x) * 3
    return pixels[i], pixels[i + 1], pixels[i + 2]


def blend_px(x: int, y: int, c: tuple[int, int, int], a: float) -> None:
    if not (0 <= x < W and 0 <= y < H):
        return
    aa = max(0.0, min(1.0, a))
    r0, g0, b0 = get_px(x, y)
    set_px(
        x,
        y,
        (
            clamp(r0 * (1 - aa) + c[0] * aa),
            clamp(g0 * (1 - aa) + c[1] * aa),
            clamp(b0 * (1 - aa) + c[2] * aa),
        ),
    )


# 1) Background ambience
for y in range(H):
    t = y / (H - 1)
    base = mix((20, 27, 44), (17, 22, 36), t)
    for x in range(W):
        g = 0.35 + 0.65 * (1.0 - abs((x / (W - 1)) - 0.5) * 2.0)
        c = (clamp(base[0] * g), clamp(base[1] * g), clamp(base[2] * g))
        n = noise(x, y) * 2.0
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))


# 2) Neon curb blocks
curb_h = 50
tile_w = 50
for y in list(range(0, curb_h)) + list(range(H - curb_h, H)):
    for x in range(W):
        idx = (x // tile_w) % 2
        c = (33, 231, 255) if idx == 0 else (255, 70, 187)

        # shine from top/bottom edges
        if y < curb_h:
            edge = y / max(1, curb_h - 1)
        else:
            edge = (H - 1 - y) / max(1, curb_h - 1)
        lift = 0.82 + 0.28 * edge
        set_px(x, y, (clamp(c[0] * lift), clamp(c[1] * lift), clamp(c[2] * lift)))


# 3) Road base
road_h = ROAD_BOTTOM - ROAD_TOP
for y in range(ROAD_TOP, ROAD_BOTTOM):
    yt = (y - ROAD_TOP) / max(1, road_h - 1)
    c = mix((45, 53, 72), (38, 46, 66), yt)

    # central visual focus, but subtle
    focus = max(0.0, 1.0 - abs(yt - 0.5) * 2.0)
    c = (
        clamp(c[0] + 6 * focus),
        clamp(c[1] + 8 * focus),
        clamp(c[2] + 10 * focus),
    )

    # vignette to keep vehicles visible
    edge = min(y - ROAD_TOP, ROAD_BOTTOM - y)
    dark = 0.86 + 0.14 * max(0.0, min(1.0, edge / 65.0))
    c = (clamp(c[0] * dark), clamp(c[1] * dark), clamp(c[2] * dark))

    for x in range(W):
        n = noise(x, y) * 1.3
        set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))


# 4) Lane dividers
divider_ys = [ROAD_TOP + road_h // 3, ROAD_TOP + (2 * road_h) // 3]
for y0 in divider_ys:
    for t in range(-2, 3):
        y = y0 + t
        dash = 40
        gap = 22
        x = 44
        while x < W - 44:
            for xx in range(x, min(x + dash, W - 44)):
                core = (202, 251, 255)
                glow = (64, 227, 255)
                blend_px(xx, y, core, 0.95 if abs(t) <= 1 else 0.5)
                if abs(t) <= 1:
                    blend_px(xx, y + 2, glow, 0.22)
                    blend_px(xx, y - 2, glow, 0.22)
            x += dash + gap


# 5) Middle decorations (user requested diversity in center)
# Draw soft glowing hex nodes across the middle lane centerline.
center_y = ROAD_TOP + road_h // 2
node_xs = range(80, W - 80, 95)
for cx in node_xs:
    cy = center_y + int(4.0 * math.sin(cx / 42.0))
    r = 12
    for y in range(cy - r - 3, cy + r + 4):
        for x in range(cx - r - 3, cx + r + 4):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy)
            # hex-ish by combining circle + angular falloff
            ang = abs(math.cos(math.atan2(dy, dx) * 3.0))
            shell = abs(d - r)
            if shell < 1.4 + ang * 0.8:
                blend_px(x, y, (255, 120, 214), 0.28)
            if d < r - 4:
                blend_px(x, y, (78, 233, 255), 0.09)


# 6) Edge neon strips on road
for y in range(ROAD_TOP, ROAD_BOTTOM):
    glow = 0.18 + 0.1 * math.sin((y - ROAD_TOP) / 14.0)
    blend_px(8, y, (49, 222, 255), glow)
    blend_px(9, y, (49, 222, 255), glow * 0.7)
    blend_px(W - 9, y, (255, 95, 200), glow)
    blend_px(W - 10, y, (255, 95, 200), glow * 0.7)


# 7) Subtle transition bands
for x in range(W):
    for d in range(3):
        blend_px(x, ROAD_TOP + d, (81, 95, 121), 0.7)
        blend_px(x, ROAD_BOTTOM - 1 - d, (81, 95, 121), 0.7)


# PNG encode

def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)


raw = bytearray()
stride = W * 3
for y in range(H):
    raw.append(0)
    s = y * stride
    raw.extend(pixels[s:s + stride])

png = bytearray(b"\x89PNG\r\n\x1a\n")
png.extend(chunk(b"IHDR", struct.pack("!IIBBBBB", W, H, 8, 2, 0, 0, 0)))
png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
png.extend(chunk(b"IEND", b""))

out = Path("assets/images/track_images/cartoon_neon_3lane.png")
out.write_bytes(png)
print(f"Wrote {out} ({W}x{H})")
