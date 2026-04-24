#!/usr/bin/env python3
"""Generate 3 distinct layouts for chamet sand/ice/neon tracks (640x640)."""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

W, H = 640, 640
OUT = Path('/Users/naveensandeepa/StudioProjects/dating_live_app/assets/images/track_images')


def clamp(v, lo=0, hi=255):
    return lo if v < lo else hi if v > hi else int(v)


def mix(a, b, t):
    return (
        clamp(a[0] + (b[0] - a[0]) * t),
        clamp(a[1] + (b[1] - a[1]) * t),
        clamp(a[2] + (b[2] - a[2]) * t),
    )


class C:
    def __init__(self):
        self.p = bytearray(W * H * 3)

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            i = (y * W + x) * 3
            self.p[i], self.p[i+1], self.p[i+2] = c

    def get(self, x, y):
        i = (y * W + x) * 3
        return self.p[i], self.p[i+1], self.p[i+2]

    def blend(self, x, y, c, a):
        if not (0 <= x < W and 0 <= y < H):
            return
        a = max(0.0, min(1.0, a))
        r0,g0,b0 = self.get(x,y)
        self.set(x,y,(
            clamp(r0*(1-a)+c[0]*a),
            clamp(g0*(1-a)+c[1]*a),
            clamp(b0*(1-a)+c[2]*a),
        ))

    def fill(self, c):
        for y in range(H):
            for x in range(W):
                self.set(x,y,c)

    def grad_v(self, y0, y1, a, b):
        for y in range(y0,y1):
            t = (y-y0)/max(1,y1-y0-1)
            cc = mix(a,b,t)
            for x in range(W):
                self.set(x,y,cc)

    def save(self, path: Path):
        def chunk(tag, data):
            return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag+data) & 0xffffffff)

        raw = bytearray()
        s = W*3
        for y in range(H):
            raw.append(0)
            raw.extend(self.p[y*s:(y+1)*s])

        out = bytearray(b'\x89PNG\r\n\x1a\n')
        out.extend(chunk(b'IHDR', struct.pack('!IIBBBBB', W,H,8,2,0,0,0)))
        out.extend(chunk(b'IDAT', zlib.compress(bytes(raw),9)))
        out.extend(chunk(b'IEND', b''))
        path.write_bytes(out)


def draw_curbs(c: C, a, b, side_a=(25,25,28), side_b=(245,245,247)):
    h = 36
    tile = 42
    for y in range(h):
        for x in range(W):
            cc = a if (x//tile)%2==0 else b
            f = 0.86 + 0.2*(y/max(1,h-1))
            c.set(x,y,(clamp(cc[0]*f),clamp(cc[1]*f),clamp(cc[2]*f)))
    for y in range(H-h,H):
        yy = y-(H-h)
        for x in range(W):
            cc = a if (x//tile)%2==0 else b
            f = 1.04 - 0.2*(yy/max(1,h-1))
            c.set(x,y,(clamp(cc[0]*f),clamp(cc[1]*f),clamp(cc[2]*f)))

    rail = 20
    for y in range(H):
        cc = side_a if (y//24)%2==0 else side_b
        for x in range(rail):
            c.set(x,y,cc)
            c.set(W-1-x,y,cc)


def draw_polyline(c: C, pts, col, a=0.55):
    for i in range(len(pts)-1):
        x0,y0 = pts[i]
        x1,y1 = pts[i+1]
        steps = max(abs(x1-x0), abs(y1-y0), 1)
        for s in range(steps+1):
            t = s/steps
            x = int(x0 + (x1-x0)*t)
            y = int(y0 + (y1-y0)*t)
            c.blend(x,y,col,a)
            c.blend(x,y+1,col,a*0.4)


def track_sand():
    c = C()
    draw_curbs(c, (245,76,72), (240,244,246))

    top,bot = 64,576
    # Full-width sand base
    for y in range(top,bot):
        t = (y-top)/(bot-top)
        base = mix((239,220,165),(224,199,140),t)
        for x in range(22,W-22):
            # dune waves across width
            wave = math.sin((x*0.02)+(y*0.015))*3.0
            c.set(x,y,(clamp(base[0]+wave),clamp(base[1]+wave),clamp(base[2]+wave)))

    # Curved dark compacted road strip in middle-right (totally different layout)
    for y in range(top+12, bot-12):
        center = 400 + int(55*math.sin(y*0.012))
        half = 135 + int(20*math.sin(y*0.022+1.7))
        x0,x1 = max(24, center-half), min(W-24, center+half)
        for x in range(x0,x1):
            edge = min(x-x0, x1-1-x)
            ef = min(1.0, edge/28.0)
            col = mix((132,111,69),(116,98,63), (x-x0)/max(1,x1-x0))
            c.blend(x,y,(clamp(col[0]*ef+40*(1-ef)), clamp(col[1]*ef+36*(1-ef)), clamp(col[2]*ef+24*(1-ef))),0.9)

    # Three lane separators follow road curvature
    for frac in (0.33,0.66):
        for y in range(top+24, bot-24, 2):
            center = 400 + int(55*math.sin(y*0.012))
            half = 135 + int(20*math.sin(y*0.022+1.7))
            x0,x1 = center-half, center+half
            x = int(x0 + (x1-x0)*frac)
            if ((y//16)%2)==0:
                for t in (-1,0,1):
                    c.blend(x+t,y,(238,203,90),0.8)

    # Stones + grooves + dry cracks
    rnd = random.Random(7)
    for _ in range(45):
        cx = rnd.randint(40,W-40)
        cy = rnd.randint(top+20,bot-20)
        r = rnd.randint(3,9)
        for y in range(cy-r, cy+r+1):
            for x in range(cx-r, cx+r+1):
                if (x-cx)*(x-cx)+(y-cy)*(y-cy) <= r*r:
                    c.blend(x,y,(160,142,102),0.35)

    for k in range(10):
        y0 = top + 30 + k*48
        pts = [(40,y0+int(5*math.sin(k))), (170,y0+int(4*math.sin(k+1.3))), (300,y0+int(6*math.sin(k+2.1))), (430,y0+int(3*math.sin(k+0.7))), (560,y0+int(5*math.sin(k+1.8)))]
        draw_polyline(c, pts, (140,122,92), 0.22)

    c.save(OUT/'cartoon_chamet_sand_3lane.png')


def track_ice():
    c = C()
    draw_curbs(c, (44,151,232), (242,249,255), side_a=(26,48,62), side_b=(238,248,255))

    top,bot = 64,576
    # Frozen lake style full-width (different from sand)
    for y in range(top,bot):
        t = (y-top)/(bot-top)
        base = mix((186,220,244),(165,203,231),t)
        for x in range(22,W-22):
            gloss = 4.0*math.sin(x*0.028 + y*0.012)
            c.set(x,y,(clamp(base[0]+gloss),clamp(base[1]+gloss),clamp(base[2]+gloss)))

    # Broad central racing slab with rounded edges
    for y in range(top+18, bot-18):
        taper = 24 + int(14*math.sin(y*0.02))
        x0, x1 = 70+taper, W-70-taper
        for x in range(x0,x1):
            side = abs((x-(x0+x1)/2)/((x1-x0)/2))
            tone = 1.0 - 0.15*(side**1.6)
            c.blend(x,y,(130,168,198),0.72*tone)

    # Horizontal dashed lane lines (not vertical like before)
    ys = [top+140, top+255, top+370]
    for y in ys:
        for x in range(88, W-88):
            if ((x//20)%2)==0:
                for t in (-1,0,1):
                    c.blend(x, y+t, (228,246,255), 0.88)

    # Ice fracture network
    rnd = random.Random(23)
    for _ in range(16):
        x = rnd.randint(60,W-60)
        y = rnd.randint(top+30,bot-30)
        segs = rnd.randint(3,5)
        pts = [(x,y)]
        for _s in range(segs):
            x += rnd.randint(-65,65)
            y += rnd.randint(-28,28)
            x = max(35,min(W-35,x)); y = max(top+12,min(bot-12,y))
            pts.append((x,y))
        draw_polyline(c, pts, (122,159,186), 0.52)

    # Snow chunks
    for _ in range(35):
        cx = rnd.randint(40,W-40); cy = rnd.randint(top+20,bot-20); r = rnd.randint(4,10)
        for y in range(cy-r, cy+r+1):
            for x in range(cx-r, cx+r+1):
                if (x-cx)*(x-cx)+(y-cy)*(y-cy)<=r*r:
                    c.blend(x,y,(212,234,248),0.34)

    c.save(OUT/'cartoon_chamet_ice_3lane.png')


def track_neon():
    c = C()
    draw_curbs(c, (43,230,255), (255,70,191), side_a=(13,11,22), side_b=(241,244,255))

    top,bot = 64,576
    # Dark gradient base
    for y in range(top,bot):
        t = (y-top)/(bot-top)
        base = mix((63,50,90),(39,32,63),t)
        for x in range(22,W-22):
            pulse = 2.6*math.sin((x*0.035)-(y*0.019))
            c.set(x,y,(clamp(base[0]+pulse),clamp(base[1]+pulse),clamp(base[2]+pulse)))

    # Triangular lane islands (very different geometry)
    bands = [top+95, top+215, top+335, top+455]
    for by in bands:
        for i in range(4):
            cx = 120 + i*130
            for y in range(by-28, by+29):
                w = max(1, 28-abs(y-by))
                # diamond / triangle combo
                for x in range(cx-w, cx+w+1):
                    if (i % 2)==0:
                        c.blend(x,y,(116,238,255),0.28)
                    else:
                        c.blend(x,y,(255,110,207),0.24)

    # 3 racing lanes as diagonal dashed guides
    def diag_line(x0,y0,dx,col):
        for k in range(0,470):
            x = x0 + k
            y = y0 + int(dx*k)
            if 30 < x < W-30 and top < y < bot and ((k//18)%2)==0:
                for t in (-1,0,1):
                    c.blend(x,y+t,col,0.9 if t==0 else 0.45)

    diag_line(64, top+62, 0.18, (124,242,255))
    diag_line(44, top+190, 0.0, (255,163,92))
    diag_line(64, top+320, -0.18, (124,242,255))

    # Hazard neon bolts
    bolt_sets = [
        [(440,125),(470,110),(455,145),(485,132)],
        [(285,262),(315,248),(302,280),(334,265)],
        [(500,410),(532,392),(520,425),(550,410)],
    ]
    for pts in bolt_sets:
        draw_polyline(c, pts, (255,80,195), 0.7)
        draw_polyline(c, pts, (102,230,255), 0.35)

    # Light glow spots
    for cx,cy,col in [(170,145,(80,224,255)),(350,290,(255,96,188)),(520,455,(80,224,255))]:
        for y in range(cy-36,cy+37):
            for x in range(cx-36,cx+37):
                d = ((x-cx)**2 + (y-cy)**2)**0.5
                if d < 36:
                    c.blend(x,y,col,max(0.0,0.18*(1-d/36)))

    c.save(OUT/'cartoon_chamet_neon_3lane.png')


def main():
    track_sand()
    track_ice()
    track_neon()
    print('Generated: sand/ice/neon distinct layouts')


if __name__ == '__main__':
    main()
