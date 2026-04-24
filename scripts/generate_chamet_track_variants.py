#!/usr/bin/env python3
"""Generate 3 Chamet-style cartoon track variants: sand, ice, neon."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

W, H = 640, 640
ROAD_TOP, ROAD_BOTTOM = 58, 582
LEFT_SHOULDER = 245

OUT_DIR = Path('/Users/naveensandeepa/StudioProjects/dating_live_app/assets/images/track_images')


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


def encode_png(rgb: bytearray, out: Path) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    stride = W * 3
    for y in range(H):
        raw.append(0)
        s = y * stride
        raw.extend(rgb[s:s + stride])

    png = bytearray(b'\x89PNG\r\n\x1a\n')
    png.extend(chunk(b'IHDR', struct.pack('!IIBBBBB', W, H, 8, 2, 0, 0, 0)))
    png.extend(chunk(b'IDAT', zlib.compress(bytes(raw), level=9)))
    png.extend(chunk(b'IEND', b''))
    out.write_bytes(png)


def draw_variant(file_name: str, palette: dict[str, tuple[int, int, int]]) -> None:
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

    # Base ambience
    for y in range(H):
        t = y / (H - 1)
        c = mix(palette['ambient_top'], palette['ambient_bottom'], t)
        for x in range(W):
            n = noise(x, y) * 1.5
            set_px(x, y, (clamp(c[0] + n), clamp(c[1] + n), clamp(c[2] + n)))

    # Curbs
    curb_h, tile_w = 32, 42
    for y in list(range(curb_h)) + list(range(H - curb_h, H)):
        for x in range(W):
            c = palette['curb_a'] if ((x // tile_w) % 2 == 0) else palette['curb_b']
            if y < curb_h:
                edge = y / max(1, curb_h - 1)
            else:
                edge = (H - 1 - y) / max(1, curb_h - 1)
            lift = 0.83 + 0.22 * edge
            set_px(x, y, (clamp(c[0] * lift), clamp(c[1] * lift), clamp(c[2] * lift)))

    for x in range(W):
        for d in range(4):
            blend_px(x, curb_h + d, palette['curb_shadow'], 0.5)
            blend_px(x, H - curb_h - 1 - d, palette['curb_shadow'], 0.5)

    # Split road: left shoulder + right main road
    for y in range(ROAD_TOP, ROAD_BOTTOM):
        yt = (y - ROAD_TOP) / max(1, (ROAD_BOTTOM - ROAD_TOP - 1))
        for x in range(W):
            if x < LEFT_SHOULDER:
                st = x / max(1, LEFT_SHOULDER)
                s = mix(palette['shoulder_a'], palette['shoulder_b'], st * 0.8)
                s = mix(s, palette['shoulder_c'], yt * 0.14)
                n = noise(x, y) * 2.0
                set_px(x, y, (clamp(s[0] + n), clamp(s[1] + n), clamp(s[2] + n)))
            else:
                rt = (x - LEFT_SHOULDER) / max(1, (W - LEFT_SHOULDER - 1))
                r = mix(palette['road_a'], palette['road_b'], rt * 0.65)
                r = mix(r, palette['road_c'], yt * 0.2)
                focus = max(0.0, min(1.0, 1.0 - abs(rt - 0.55) * 1.6))
                r = (clamp(r[0] + 6 * focus), clamp(r[1] + 6 * focus), clamp(r[2] + 6 * focus))
                n = noise(x, y) * 1.8
                set_px(x, y, (clamp(r[0] + n), clamp(r[1] + n), clamp(r[2] + n)))

    # Side checker rails
    rail_w = 20
    for y in range(H):
        for x in range(rail_w):
            c = palette['rail_a'] if ((y // 24) % 2 == 0) else palette['rail_b']
            set_px(x, y, c)
            set_px(W - 1 - x, y, c)

    # Shoulder/road split highlight
    for y in range(ROAD_TOP, ROAD_BOTTOM):
        for d in range(3):
            blend_px(LEFT_SHOULDER + d, y, palette['split_line'], 0.55)
        blend_px(LEFT_SHOULDER - 1, y, palette['split_shadow'], 0.35)

    # Lane lines
    lane_h = (ROAD_BOTTOM - ROAD_TOP) / 3.0
    div_ys = [int(ROAD_TOP + lane_h), int(ROAD_TOP + 2 * lane_h)]
    for y0 in div_ys:
        for t in range(-1, 2):
            y = y0 + t
            x = LEFT_SHOULDER + 14
            while x < W - 28:
                for xx in range(x, min(W - 24, x + 26)):
                    blend_px(xx, y, palette['lane_dash'], 0.88 if t == 0 else 0.5)
                x += 44

    # Center road blocks
    block_cols = [LEFT_SHOULDER + 58, LEFT_SHOULDER + 132, LEFT_SHOULDER + 206, LEFT_SHOULDER + 280, LEFT_SHOULDER + 354]
    for cx in block_cols:
        y = ROAD_TOP + 28
        while y < ROAD_BOTTOM - 26:
            h, w = 30, 18
            for yy in range(y, min(ROAD_BOTTOM - 6, y + h)):
                for xx in range(cx - w // 2, cx + w // 2):
                    top = 1.1 if yy - y < 6 else 1.0
                    col = (
                        clamp(palette['block'][0] * top),
                        clamp(palette['block'][1] * top),
                        clamp(palette['block'][2] * top),
                    )
                    blend_px(xx, yy, col, 0.5)
                    if xx == cx - w // 2 or xx == cx + w // 2 - 1:
                        blend_px(xx, yy, palette['block_edge'], 0.3)
            y += 52

    # Shoulder texture details
    for k in range(8):
        sy = ROAD_TOP + 36 + k * 58
        amp = 5 + (k % 3)
        for x in range(34, LEFT_SHOULDER - 26):
            yy = int(sy + amp * math.sin((x / 28.0) + k * 0.9))
            blend_px(x, yy, palette['shoulder_line'], 0.2)
            if k % 2 == 0:
                blend_px(x, yy + 1, palette['shoulder_line_dark'], 0.14)

    for i in range(8):
        cx = 48 + i * 24
        cy = ROAD_TOP + 68 + (i % 3) * 90
        r = 6 + (i % 2) * 3
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    blend_px(x, y, palette['shoulder_spot'], 0.18)

    # Vignette + transitions
    for y in range(ROAD_TOP, ROAD_BOTTOM):
        edge = min(y - ROAD_TOP, ROAD_BOTTOM - 1 - y)
        alpha = (1.0 - max(0.0, min(1.0, edge / 36.0))) * 0.28
        for x in range(rail_w, W - rail_w):
            blend_px(x, y, (0, 0, 0), alpha)

    for x in range(rail_w, W - rail_w):
        for d in range(3):
            blend_px(x, ROAD_TOP + d, palette['transition'], 0.35)
            blend_px(x, ROAD_BOTTOM - 1 - d, palette['transition'], 0.35)

    encode_png(pix, OUT_DIR / file_name)
    print(f'Wrote {OUT_DIR / file_name}')


PALETTES = {
    'cartoon_chamet_sand_3lane.png': {
        'ambient_top': (228, 212, 165), 'ambient_bottom': (209, 191, 148),
        'curb_a': (243, 74, 77), 'curb_b': (241, 245, 248), 'curb_shadow': (16, 16, 17),
        'shoulder_a': (237, 219, 168), 'shoulder_b': (224, 202, 152), 'shoulder_c': (232, 211, 159),
        'road_a': (123, 111, 76), 'road_b': (102, 90, 62), 'road_c': (109, 96, 66),
        'rail_a': (29, 30, 32), 'rail_b': (243, 245, 247),
        'split_line': (248, 205, 82), 'split_shadow': (73, 62, 41),
        'lane_dash': (239, 206, 95), 'block': (201, 174, 96), 'block_edge': (145, 124, 68),
        'shoulder_line': (121, 112, 93), 'shoulder_line_dark': (96, 87, 71), 'shoulder_spot': (51, 48, 44),
        'transition': (243, 244, 248),
    },
    'cartoon_chamet_ice_3lane.png': {
        'ambient_top': (196, 224, 242), 'ambient_bottom': (174, 206, 230),
        'curb_a': (57, 155, 232), 'curb_b': (240, 248, 255), 'curb_shadow': (12, 22, 30),
        'shoulder_a': (223, 238, 250), 'shoulder_b': (204, 226, 244), 'shoulder_c': (214, 232, 247),
        'road_a': (128, 156, 183), 'road_b': (111, 141, 170), 'road_c': (120, 149, 176),
        'rail_a': (28, 46, 60), 'rail_b': (238, 247, 255),
        'split_line': (158, 215, 255), 'split_shadow': (56, 86, 106),
        'lane_dash': (226, 245, 255), 'block': (175, 214, 238), 'block_edge': (121, 169, 199),
        'shoulder_line': (134, 165, 188), 'shoulder_line_dark': (108, 138, 162), 'shoulder_spot': (87, 119, 140),
        'transition': (243, 250, 255),
    },
    'cartoon_chamet_neon_3lane.png': {
        'ambient_top': (38, 28, 58), 'ambient_bottom': (24, 22, 42),
        'curb_a': (45, 230, 255), 'curb_b': (255, 73, 192), 'curb_shadow': (8, 9, 14),
        'shoulder_a': (63, 50, 89), 'shoulder_b': (53, 42, 76), 'shoulder_c': (59, 48, 85),
        'road_a': (86, 69, 116), 'road_b': (71, 56, 101), 'road_c': (79, 62, 108),
        'rail_a': (13, 12, 20), 'rail_b': (240, 244, 255),
        'split_line': (255, 173, 77), 'split_shadow': (39, 28, 52),
        'lane_dash': (133, 244, 255), 'block': (255, 158, 83), 'block_edge': (171, 86, 48),
        'shoulder_line': (130, 111, 166), 'shoulder_line_dark': (98, 83, 133), 'shoulder_spot': (54, 45, 74),
        'transition': (225, 220, 255),
    },
}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, palette in PALETTES.items():
        draw_variant(name, palette)


if __name__ == '__main__':
    main()
