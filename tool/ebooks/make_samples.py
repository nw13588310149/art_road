# -*- coding: utf-8 -*-
"""生成「美术书刊」模块的示例书刊图片（封面 + 内页）。

    python tool/ebooks/make_samples.py                 # 生成全部
    python tool/ebooks/make_samples.py eb-cast-head    # 只生成指定的书

- 封面 480×640、内页 720×960，JPEG 质量约 72，单张不超过 90 KB，总量不超过 6 MB；
- 输出平铺在 assets/demo/ebooks/（Flutter 资源目录不递归）：
  <bookId>-cover.jpg、<bookId>-p01.jpg …；
- 同时写出 tool/ebooks/manifest.json（页数与目录），测试用它核对
  lib/core/demo/fixtures/content_ebooks.dart。

所有书刊均为「美术之路」演示用的自制示例，不对应任何真实出版物，没有书号与定价。
插图取自 assets/demo/art、papers、scene 中的演示图片，示意图由本脚本绘制。
"""
from __future__ import annotations

import io
import json
import math
import re
import sys
from pathlib import Path

from PIL import (
    Image,
    ImageChops,
    ImageDraw,
    ImageEnhance,
    ImageFilter,
    ImageFont,
    ImageOps,
)

ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / 'assets' / 'demo'
OUT = DEMO / 'ebooks'
MANIFEST = Path(__file__).resolve().with_name('manifest.json')

PAGE_W, PAGE_H = 720, 960
COVER_W, COVER_H = 480, 640
QUALITY = 68
MIN_QUALITY = 52
MAX_BYTES = 80 * 1024
TOTAL_LIMIT = 6 * 1024 * 1024

MX = 60
TOP = 86
BOTTOM = PAGE_H - 72

WHITE = (255, 255, 255)
PAPER = (252, 251, 248)
INK = (11, 8, 26)
BODY = (44, 41, 54)
SECONDARY = (109, 107, 117)
TERTIARY = (139, 137, 147)
LINE = (228, 226, 232)
GOOD = (22, 150, 112)
BAD = (214, 58, 64)

SAMPLE_MARK = '示例书刊 · 仅供演示'

# ── 字体 ────────────────────────────────────────────────────────────────

_FONT_FILES = {
    'body': ['C:/Windows/Fonts/msyh.ttc'],
    'bold': ['C:/Windows/Fonts/msyhbd.ttc', 'C:/Windows/Fonts/simhei.ttf'],
    'hei': ['C:/Windows/Fonts/simhei.ttf', 'C:/Windows/Fonts/msyhbd.ttc'],
    'kai': [
        r'D:\桌面\阅卷系统\yikao-marketing\brand\fonts\LXGWWenKai-Regular.ttf',
        'C:/Windows/Fonts/msyhbd.ttc',
    ],
    'num': [
        str(ROOT / 'assets' / 'fonts' / 'Manrope Medium.ttf'),
        'C:/Windows/Fonts/msyhbd.ttc',
    ],
}
_fonts: dict = {}


def F(kind: str, size: int) -> ImageFont.FreeTypeFont:
    key = (kind, size)
    font = _fonts.get(key)
    if font is None:
        for path in _FONT_FILES[kind]:
            if Path(path).exists():
                font = ImageFont.truetype(path, size)
                break
        else:
            raise SystemExit(f'缺少字体：{kind}')
        _fonts[key] = font
    return font


# ── 颜色与文字 ──────────────────────────────────────────────────────────


def mix(c1, c2, t):
    return tuple(int(round(c1[i] * (1 - t) + c2[i] * t)) for i in range(3))


def baseline(top, lh, font):
    """行框顶部 → 基线：让汉字字身在行框内垂直居中。"""
    return top + lh / 2 + font.size * 0.36


NO_START = set('，。、；：？！）》」』】…—·%,.;:?!)]')
NO_END = set('（《「『【([')
_TOKEN = re.compile(r'[A-Za-z0-9][A-Za-z0-9.%/+\-–～~:]*|\n|.')


def wrap(text, font, width, first=None):
    """按字宽断行：西文与数字不拆开，句读不放行首，前括号不放行尾。"""
    lines, cur = [], ''
    limit = width if first is None else first
    for tok in _TOKEN.findall(text):
        if tok == '\n':
            lines.append(cur)
            cur, limit = '', width
            continue
        trial = cur + tok
        if not cur or font.getlength(trial) <= limit or tok in NO_START:
            cur = trial
            continue
        if cur[-1] in NO_END:
            lines.append(cur[:-1])
            cur = cur[-1] + tok
        else:
            lines.append(cur)
            cur = tok
        limit = width
    lines.append(cur)
    return lines


def split_head(item):
    """「术语：说明」拆成加粗的术语与说明。"""
    idx = item.find('：')
    if 0 < idx <= 10:
        return item[: idx + 1], item[idx + 1:]
    return '', item


# ── 图片 ────────────────────────────────────────────────────────────────

_images: dict = {}


def art(name):
    im = _images.get(name)
    if im is None:
        im = Image.open(DEMO / name).convert('RGB')
        _images[name] = im
    return im


def fit(im, w, h, crop=None, focus=(0.5, 0.5)):
    """在 crop（源图比例坐标）范围内按 cover 方式裁切缩放，返回图片与坐标映射。"""
    W, H = im.size
    l, t, r, b = crop or (0, 0, 1, 1)
    rx0, ry0, rw, rh = l * W, t * H, (r - l) * W, (b - t) * H
    target = w / h
    if rw / rh > target:
        nw = rh * target
        x = rx0 + (rw - nw) * focus[0]
        box = (x, ry0, x + nw, ry0 + rh)
    else:
        nh = rw / target
        y = ry0 + (rh - nh) * focus[1]
        box = (rx0, y, rx0 + rw, y + nh)
    out = im.resize((int(w), int(h)), Image.LANCZOS, box=box)

    def to_local(fx, fy):
        return (
            (fx * W - box[0]) / (box[2] - box[0]) * w,
            (fy * H - box[1]) / (box[3] - box[1]) * h,
        )

    return out, to_local


def fx_lines(im):
    """模拟起稿线稿：高斯差分提取主要轮廓，线条偏浅。"""
    g = ImageOps.grayscale(im)
    a = g.filter(ImageFilter.GaussianBlur(1.4))
    b = g.filter(ImageFilter.GaussianBlur(4.0))
    diff = ImageChops.subtract(b, a).point(lambda v: 0 if v < 6 else min(255, (v - 6) * 10))
    diff = diff.filter(ImageFilter.GaussianBlur(0.6))
    out = ImageOps.invert(diff).point(lambda v: int(v * 0.6 + 255 * 0.4))
    return Image.merge('RGB', (out, out, out))


def fx_values(im):
    """模拟铺大关系：去掉细节，归纳成亮、灰、暗三个柔和的明度层次，叠淡淡的轮廓线。"""
    g = ImageOps.grayscale(im).filter(ImageFilter.MedianFilter(7)).filter(ImageFilter.GaussianBlur(7))
    g = ImageOps.autocontrast(g, cutoff=3)

    def curve(v):
        x = v / 255
        if x < 0.42:
            return int(96 + 72 * smooth(0.34, 0.44, x))
        return int(168 + 68 * smooth(0.66, 0.76, x))

    lines = ImageOps.grayscale(fx_lines(im)).point(lambda v: 140 + v * 115 // 255)
    out = ImageChops.multiply(g.point(curve), lines)
    return Image.merge('RGB', (out, out, out))


def fx_blocks(im):
    """模拟铺大色块。"""
    q = im.filter(ImageFilter.GaussianBlur(2.5)).quantize(
        colors=8, method=Image.Quantize.MEDIANCUT
    )
    return q.convert('RGB').filter(ImageFilter.ModeFilter(9))


def fx_shaping(im):
    """模拟塑造阶段：色块细分但尚未深入。"""
    q = im.filter(ImageFilter.GaussianBlur(1.2)).quantize(
        colors=24, method=Image.Quantize.MEDIANCUT
    )
    return q.convert('RGB').filter(ImageFilter.ModeFilter(5))


def fx_flat(im):
    """模拟“画面发灰”：降低明暗对比。"""
    out = ImageEnhance.Contrast(im).enhance(0.42)
    return ImageEnhance.Brightness(out).enhance(1.1)


def fx_fade(im):
    return Image.blend(im, Image.new('RGB', im.size, WHITE), 0.62)


# ── 绘图工具 ────────────────────────────────────────────────────────────


def dashed(d, p0, p1, fill, width=2, dash=8, gap=6):
    x0, y0 = p0
    x1, y1 = p1
    length = math.hypot(x1 - x0, y1 - y0)
    if length == 0:
        return
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    pos = 0.0
    while pos < length:
        end = min(pos + dash, length)
        d.line(
            [(x0 + ux * pos, y0 + uy * pos), (x0 + ux * end, y0 + uy * end)],
            fill=fill,
            width=width,
        )
        pos = end + gap


def pill(d, x, y, text, tone, size=13, h=22):
    f = F('bold', size)
    w = f.getlength(text) + 14
    d.rounded_rectangle([x, y, x + w, y + h], 6, fill=mix(WHITE, tone, 0.15))
    d.text((x + w / 2, baseline(y, h, f)), text, font=f, fill=tone, anchor='ms')
    return w


def text_at(d, x, y, s, size=15, fill=INK, anchor='ls', kind='body'):
    d.text((x, y), s, font=F(kind, size), fill=fill, anchor=anchor)


def label_box(d, x, y, s, size=14, fill=INK, bg=WHITE, anchor='l'):
    f = F('body', size)
    w = f.getlength(s) + 14
    h = size + 12
    if anchor == 'r':
        x -= w
    elif anchor == 'm':
        x -= w / 2
    d.rounded_rectangle([x, y, x + w, y + h], 5, fill=bg)
    d.text((x + 7, baseline(y, h, f)), s, font=f, fill=fill, anchor='ls')


def intersect(p1, p2, p3, p4):
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3
    x4, y4 = p4
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    a = x1 * y2 - y1 * x2
    b = x3 * y4 - y3 * x4
    return ((a * (x3 - x4) - (x1 - x2) * b) / den, (a * (y3 - y4) - (y1 - y2) * b) / den)


def rot(points, c, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [
        (c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca)
        for x, y in points
    ]


def catmull(points, steps=14):
    """经过所有点的平滑曲线。"""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t
                       + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in range(2)
            ))
    out.append(points[-1])
    return out


def limb(d, pts, width=9, fill=(160, 156, 168), joint=INK):
    d.line(pts, fill=fill, width=width, joint='curve')
    for x, y in pts:
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=joint)


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def norm(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


LIGHT = norm((-0.5, -0.55, 0.67))
BOUNCE = norm((0.3, 0.9, 0.3))
HALF = norm((LIGHT[0], LIGHT[1], LIGHT[2] + 1))


def sphere(r, shader):
    """逐像素渲染受左上方光照的球体（带桌面反光），返回 RGBA。"""
    size = 2 * r
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = im.load()
    for j in range(size):
        ny = (j + 0.5 - r) / r
        for i in range(size):
            nx = (i + 0.5 - r) / r
            dd = nx * nx + ny * ny
            if dd > 1:
                continue
            nz = math.sqrt(1 - dd)
            lam = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
            b = max(0.0, nx * BOUNCE[0] + ny * BOUNCE[1] + nz * BOUNCE[2])
            spec = max(0.0, nx * HALF[0] + ny * HALF[1] + nz * HALF[2]) ** 36
            c = shader(lam, b, spec)
            a = int(255 * min(1.0, (1 - math.sqrt(dd)) * r * 1.2))
            px[i, j] = (c[0], c[1], c[2], a)
    return im


def gray_shader(lam, b, spec):
    lit = 0.52 + 0.40 * max(lam, 0) ** 0.75
    dark = 0.26 + 0.2 * (b ** 1.3) * smooth(0, 0.35, -lam)
    t = smooth(-0.02, 0.14, lam)
    v = min(1.0, dark * (1 - t) + lit * t + 0.16 * spec)
    return (int(232 * v + 10), int(230 * v + 10), int(226 * v + 10))


def color_shader(light, shadow):
    def shade(lam, b, spec):
        t = smooth(-0.02, 0.16, lam)
        lit = [c * (0.80 + 0.20 * max(lam, 0)) for c in light]
        dark = [c * (0.80 + 0.32 * b * smooth(0, 0.4, -lam)) for c in shadow]
        return tuple(
            int(min(255, dark[k] * (1 - t) + lit[k] * t + 70 * spec)) for k in range(3)
        )

    return shade


def cast_shadow(im, cx, cy, rx, ry, color=(70, 66, 78), strength=0.6):
    """投影：靠近物体（左端）深而实，远端浅而虚。"""
    w, h = int(rx * 2 + 40), int(ry * 2 + 40)
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).ellipse([20, 20, w - 20, h - 20], fill=255)
    grad = ImageOps.invert(Image.linear_gradient('L').rotate(90).resize((w, h)))
    grad = grad.point(lambda v: int(50 + v * 205 / 255))
    m = ImageChops.multiply(mask, grad).filter(ImageFilter.GaussianBlur(5))
    m = m.point(lambda v: int(v * strength))
    im.paste(Image.new('RGB', (w, h), color), (int(cx - w / 2), int(cy - h / 2)), m)


def gradient_fill(im, box, top, bottom):
    x0, y0, x1, y1 = [int(v) for v in box]
    g = Image.linear_gradient('L').resize((x1 - x0, y1 - y0))
    im.paste(Image.composite(
        Image.new('RGB', g.size, bottom), Image.new('RGB', g.size, top), g
    ), (x0, y0))


def shade_box(im, box, color, alpha):
    box = tuple(int(v) for v in box)
    region = im.crop(box)
    im.paste(Image.blend(region, Image.new('RGB', region.size, color), alpha), box[:2])


def gradient_overlay(im, box, color, a0, a1):
    x0, y0, x1, y1 = [int(v) for v in box]
    mask = Image.linear_gradient('L').resize((x1 - x0, y1 - y0))
    mask = mask.point(lambda v: int(255 * (a0 + (a1 - a0) * v / 255)))
    region = im.crop((x0, y0, x1, y1))
    region.paste(Image.new('RGB', region.size, color), (0, 0), mask)
    im.paste(region, (x0, y0))


# ── 示意图 ──────────────────────────────────────────────────────────────

OBJ_FILL = (214, 209, 202)
OBJ_LINE = (88, 84, 96)


def _jar(d, cx, top, w, h):
    d.ellipse([cx - w / 2, top + h * 0.2, cx + w / 2, top + h], fill=OBJ_FILL, outline=OBJ_LINE, width=2)
    d.rectangle([cx - w * 0.27, top + h * 0.07, cx + w * 0.27, top + h * 0.32], fill=OBJ_FILL)
    d.line([(cx - w * 0.27, top + h * 0.07), (cx - w * 0.27, top + h * 0.27)], fill=OBJ_LINE, width=2)
    d.line([(cx + w * 0.27, top + h * 0.07), (cx + w * 0.27, top + h * 0.27)], fill=OBJ_LINE, width=2)
    d.ellipse([cx - w * 0.31, top, cx + w * 0.31, top + h * 0.13], fill=(184, 178, 170), outline=OBJ_LINE, width=2)
    d.chord([cx - w / 2, top + h * 0.2, cx + w / 2, top + h], 300, 60, fill=(190, 184, 176))


def _apple(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(222, 218, 212), outline=OBJ_LINE, width=2)
    d.chord([cx - r, cy - r, cx + r, cy + r], 300, 80, fill=(198, 193, 186))


def _cloth(d, pts):
    d.polygon(pts, fill=(238, 236, 232), outline=(160, 156, 166))


def dg_composition(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    gap = 18
    fw = (x1 - x0 - gap * 2) / 3
    fh = y1 - y0 - 40
    frames = [('三角形组合', True), ('等距一排', False), ('过大撑满', False)]
    for i, (text, ok) in enumerate(frames):
        fx = x0 + i * (fw + gap)
        d.rectangle([fx, y0, fx + fw, y0 + fh], fill=WHITE, outline=(205, 203, 210), width=2)
        if i == 0:
            _cloth(d, [(fx + fw * 0.05, y0 + fh * 0.66), (fx + fw * 0.5, y0 + fh * 0.58),
                       (fx + fw * 0.95, y0 + fh * 0.7), (fx + fw * 0.9, y0 + fh * 0.94),
                       (fx + fw * 0.12, y0 + fh * 0.95)])
            _jar(d, fx + fw * 0.47, y0 + fh * 0.13, fw * 0.34, fh * 0.6)
            _apple(d, fx + fw * 0.25, y0 + fh * 0.78, fw * 0.09)
            _apple(d, fx + fw * 0.71, y0 + fh * 0.81, fw * 0.08)
            pts = [(fx + fw * 0.47, y0 + fh * 0.1), (fx + fw * 0.12, y0 + fh * 0.88),
                   (fx + fw * 0.84, y0 + fh * 0.9)]
            for k in range(3):
                dashed(d, pts[k], pts[(k + 1) % 3], pg.accent, width=2, dash=6, gap=5)
        elif i == 1:
            for k in range(3):
                _jar(d, fx + fw * (0.2 + 0.3 * k), y0 + fh * 0.32, fw * 0.2, fh * 0.4)
            d.line([(fx + 8, y0 + fh * 0.74), (fx + fw - 8, y0 + fh * 0.74)], fill=(200, 196, 204), width=2)
        else:
            _jar(d, fx + fw * 0.5, y0 + fh * 0.015, fw * 0.8, fh * 0.97)
        tw = pill(d, fx, y0 + fh + 10, '推荐' if ok else '避免', GOOD if ok else BAD)
        text_at(d, fx + tw + 8, baseline(y0 + fh + 10, 22, F('body', 15)), text, 15, SECONDARY)


def dg_tones(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    h = y1 - y0
    r = int(min(108, h * 0.34))
    cx, cy = int(x0 + (x1 - x0) * 0.42), int(y0 + 34 + r)
    ground = cy + r - int(r * 0.06)
    d.rectangle([x0, y0, x1, ground], fill=(247, 245, 240))
    d.rectangle([x0, ground, x1, y1], fill=(235, 232, 225))
    cast_shadow(pg.im, cx + r * 0.8, ground + r * 0.1, r * 1.05, r * 0.24)
    sp = sphere(r, gray_shader)
    pg.im.paste(sp, (cx - r, cy - r), sp)
    # 光源方向
    ax, ay = x0 + 18, y0 + 16
    d.line([(ax, ay), (ax + 70, ay + 44)], fill=(214, 160, 40), width=3)
    d.polygon([(ax + 78, ay + 49), (ax + 62, ay + 46), (ax + 70, ay + 34)], fill=(214, 160, 40))
    text_at(d, ax + 84, ay + 10, '光源', 14, SECONDARY)
    left = [('高光', (-0.27, -0.31)), ('亮面', (-0.55, 0.12))]
    right = [('灰面', (0.42, 0.18)), ('明暗交界线', (0.64, 0.34)), ('反光', (0.52, 0.74))]
    f = F('bold', 16)
    for k, (name, (fx, fy)) in enumerate(left):
        px, py = cx + fx * r, cy + fy * r
        ly = y0 + 96 + k * 70
        d.line([(x0 + 54, ly), (px, py)], fill=INK, width=1)
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=INK)
        d.text((x0 + 2, ly + 6), name, font=f, fill=INK, anchor='ls')
    lx = int(x1 - 150)
    for k, (name, (fx, fy)) in enumerate(right):
        px, py = cx + fx * r, cy + fy * r
        ly = y0 + 40 + k * 62
        d.line([(px, py), (lx - 10, ly)], fill=INK, width=1)
        d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=INK)
        d.text((lx, ly + 6), name, font=f, fill=INK, anchor='ls')
    sx, sy = cx + r * 1.25, ground + r * 0.1
    ly = y0 + 40 + 3 * 62
    d.line([(sx, sy), (lx - 10, ly)], fill=INK, width=1)
    d.ellipse([sx - 3, sy - 3, sx + 3, sy + 3], fill=INK)
    d.text((lx, ly + 6), '投影', font=f, fill=INK, anchor='ls')
    text_at(d, lx, ly + 30, '近实远虚', 14, SECONDARY)


def dg_perspective(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    hy = y0 + 44
    d.line([(x0, hy), (x1, hy)], fill=(140, 136, 150), width=2)
    text_at(d, x0, hy - 10, '视平线（画者眼睛的高度）', 14, SECONDARY)
    vl, vr = (x0 + 4, hy), (x0 + 430, hy)
    fx, ft, fb = x0 + 170, hy + 52, hy + 150

    def toward(p, v, x):
        t = (x - p[0]) / (v[0] - p[0])
        return (x, p[1] + (v[1] - p[1]) * t)

    lt, lb = toward((fx, ft), vl, x0 + 122), toward((fx, fb), vl, x0 + 122)
    rt, rb = toward((fx, ft), vr, x0 + 262), toward((fx, fb), vr, x0 + 262)
    back = intersect(lt, vr, rt, vl)
    light = (196, 192, 204)
    for p in (lt, (fx, ft), lb, (fx, fb)):
        dashed(d, p, vl, light, width=1, dash=5, gap=5)
    for p in (rt, (fx, ft), rb, (fx, fb)):
        dashed(d, p, vr, light, width=1, dash=5, gap=5)
    d.polygon([lt, (fx, ft), rt, back], fill=(242, 240, 236))
    d.polygon([lt, (fx, ft), (fx, fb), lb], fill=(214, 210, 204))
    d.polygon([(fx, ft), rt, rb, (fx, fb)], fill=(176, 172, 166))
    for a, b in [(lt, (fx, ft)), ((fx, ft), rt), (rt, back), (back, lt), (lt, lb),
                 ((fx, ft), (fx, fb)), (rt, rb), (lb, (fx, fb)), ((fx, fb), rb)]:
        d.line([a, b], fill=INK, width=2)
    for v in (vl, vr):
        d.ellipse([v[0] - 5, v[1] - 5, v[0] + 5, v[1] + 5], fill=pg.accent)
        text_at(d, v[0], v[1] + 22, '灭点', 14, pg.accent, anchor='ms')
    # 圆柱：离视平线越远，椭圆越宽
    cx, rx = x0 + 494, 56
    ty, by = hy + 66, hy + 186
    ry_t, ry_b = 11, 25
    body_w, body_h = 2 * rx, by + ry_b - ty
    strip = Image.new('L', (body_w, 1))
    for i in range(body_w):
        nx = (i + 0.5) / rx - 1
        lam = nx * -0.62 + math.sqrt(max(0.0, 1 - nx * nx)) * 0.78
        v = (0.5 + 0.42 * lam ** 0.8) if lam > 0.06 else 0.34 + 0.12 * smooth(0.55, 1.0, nx)
        strip.putpixel((i, 0), int(232 * v + 10))
    shading = strip.resize((body_w, body_h))
    mask = Image.new('L', (body_w, body_h), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([0, 0, body_w, by - ty], fill=255)
    md.ellipse([0, by - ty - ry_b, body_w - 1, by - ty + ry_b], fill=255)
    pg.im.paste(Image.merge('RGB', (shading, shading, shading)), (cx - rx, ty), mask)
    d.line([(cx - rx, ty), (cx - rx, by)], fill=INK, width=2)
    d.line([(cx + rx, ty), (cx + rx, by)], fill=INK, width=2)
    d.arc([cx - rx, by - ry_b, cx + rx, by + ry_b], 0, 180, fill=INK, width=2)
    d.arc([cx - rx, by - ry_b, cx + rx, by + ry_b], 180, 360, fill=(170, 166, 178), width=1)
    d.ellipse([cx - rx, ty - ry_t, cx + rx, ty + ry_t], fill=(236, 234, 229), outline=INK, width=2)
    text_at(d, cx, ty - ry_t - 12, '离视平线近：椭圆窄', 14, SECONDARY, anchor='ms')
    text_at(d, cx, by + ry_b + 22, '离视平线远：椭圆宽', 14, SECONDARY, anchor='ms')


def dg_values(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    n, gap = 9, 8
    sw = (x1 - x0 - gap * (n - 1)) / n
    top, sh = y0 + 38, 56
    for name, a, b in [('亮部', 0, 2), ('灰部', 3, 5), ('暗部', 6, 8)]:
        xa = x0 + a * (sw + gap)
        xb = x0 + b * (sw + gap) + sw
        d.line([(xa, y0 + 24), (xb, y0 + 24)], fill=pg.accent, width=2)
        d.line([(xa, y0 + 24), (xa, y0 + 31)], fill=pg.accent, width=2)
        d.line([(xb, y0 + 24), (xb, y0 + 31)], fill=pg.accent, width=2)
        text_at(d, (xa + xb) / 2, y0 + 16, name, 15, pg.accent, anchor='ms', kind='bold')
    for i in range(n):
        v = int(247 - i * (247 - 26) / (n - 1))
        sx = x0 + i * (sw + gap)
        d.rectangle([sx, top, sx + sw, top + sh], fill=(v, v, v),
                    outline=(206, 204, 210) if v > 225 else None)
        text_at(d, sx + sw / 2, top + sh + 22, str(i + 1), 15, SECONDARY, anchor='ms', kind='num')


HUES = [
    ('黄', (247, 214, 0)), ('黄橙', (248, 176, 16)), ('橙', (242, 136, 24)),
    ('红橙', (232, 88, 34)), ('红', (212, 36, 42)), ('红紫', (168, 32, 108)),
    ('紫', (108, 46, 138)), ('蓝紫', (70, 62, 150)), ('蓝', (22, 96, 178)),
    ('蓝绿', (0, 142, 146)), ('绿', (44, 156, 72)), ('黄绿', (150, 192, 42)),
]


def dg_color_strips(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    blue, red = (22, 96, 178), (212, 36, 42)
    rows = [
        ('色相', [c for _, c in HUES], '红、橙、黄、绿、蓝、紫……不同的颜色相貌'),
        ('明度', [mix(blue, WHITE, 0.8 - k * 0.2) if k < 4 else mix(blue, INK, (k - 4) * 0.2)
                for k in range(9)], '同一色相由亮到暗'),
        ('纯度', [mix(red, (128, 120, 122), k / 8) for k in range(9)], '同一色相由鲜艳到灰'),
    ]
    rh = (y1 - y0) / 3
    for i, (name, colors, note) in enumerate(rows):
        top = y0 + i * rh
        text_at(d, x0, baseline(top, 46, F('bold', 18)), name, 18, INK, kind='bold')
        sx0 = x0 + 64
        n = len(colors)
        gap = 4
        sw = (x1 - sx0 - gap * (n - 1)) / n
        for k, c in enumerate(colors):
            sx = sx0 + k * (sw + gap)
            d.rectangle([sx, top + 4, sx + sw, top + 46], fill=c)
        text_at(d, sx0, top + 70, note, 14, TERTIARY)


def dg_wheel(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    R, r_in = 124, 58
    cx, cy = x0 + 150, (y0 + y1) / 2
    seg = 360 / 12
    start = -90 - seg / 2
    for i, (_, c) in enumerate(HUES):
        a0 = start + i * seg
        d.pieslice([cx - R, cy - R, cx + R, cy + R], a0, a0 + seg, fill=c, outline=PAPER, width=2)
    d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=PAPER)
    for i, (name, _) in enumerate(HUES):
        a = math.radians(start + (i + 0.5) * seg)
        text_at(d, cx + math.cos(a) * (R + 20), cy + math.sin(a) * (R + 20) + 5, name, 14,
                BODY, anchor='ms')
    for a_i, b_i in [(0, 6), (2, 8), (4, 10)]:
        pa = math.radians(start + (a_i + 0.5) * seg)
        pb = math.radians(start + (b_i + 0.5) * seg)
        p = (cx + math.cos(pa) * (R - 10), cy + math.sin(pa) * (R - 10))
        q = (cx + math.cos(pb) * (R - 10), cy + math.sin(pb) * (R - 10))
        d.line([p, q], fill=INK, width=2)
        for pt in (p, q):
            d.ellipse([pt[0] - 4, pt[1] - 4, pt[0] + 4, pt[1] + 4], fill=INK)
    lx = x0 + 330
    groups = [
        ('互补色（相距 180°）', [[0, 6], [2, 8], [4, 10]]),
        ('对比色（约 120°）', [[4, 0, 8]]),
        ('邻近色（约 60° 以内）', [[0, 1, 2]]),
    ]
    y = y0 + 22
    for title, sets in groups:
        text_at(d, lx, y, title, 16, INK, kind='bold')
        y += 14
        x = lx
        for s in sets:
            for k in s:
                d.rectangle([x, y, x + 30, y + 30], fill=HUES[k][1])
                text_at(d, x + 15, y + 50, HUES[k][0], 13, SECONDARY, anchor='ms')
                x += 34
            x += 14
        y += 82


def dg_warm_cool(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    half = (x1 - x0 - 20) / 2
    specs = [
        ('暖光照射', '亮部偏暖 · 暗部偏冷', (250, 214, 168), (92, 100, 140), (122, 128, 160), (236, 190, 120)),
        ('冷光照射', '亮部偏冷 · 暗部偏暖', (208, 224, 248), (130, 100, 80), (150, 124, 104), (150, 186, 236)),
    ]
    r = int(min(84, (y1 - y0 - 90) / 2))
    for i, (title, note, light, shadow, shade_col, ray) in enumerate(specs):
        px0 = x0 + i * (half + 20)
        top = y0 + 30
        bottom = y1 - 34
        cx, cy = int(px0 + half * 0.46), int(top + 14 + r)
        ground = cy + r - 4
        d.rectangle([px0, top, px0 + half, ground], fill=(244, 243, 240))
        d.rectangle([px0, ground, px0 + half, bottom], fill=(230, 228, 222))
        cast_shadow(pg.im, cx + r * 0.8, ground + r * 0.1, r * 1.0, r * 0.22, color=shade_col, strength=0.7)
        sp = sphere(r, color_shader(light, shadow))
        pg.im.paste(sp, (cx - r, cy - r), sp)
        d.line([(px0 + 10, top + 8), (px0 + 56, top + 38)], fill=ray, width=4)
        d.polygon([(px0 + 63, top + 43), (px0 + 48, top + 40), (px0 + 56, top + 28)], fill=ray)
        text_at(d, px0, y0 + 18, title, 16, INK, kind='bold')
        text_at(d, px0 + half / 2, y1 - 8, note, 15, SECONDARY, anchor='ms')


def _egg(cx, top, w, h, n=120):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        factor = 0.86 + 0.14 * math.cos(t)
        pts.append((cx + (w / 2) * math.sin(t) * factor, top + h / 2 - (h / 2) * math.cos(t)))
    return pts


def _width_at(pts, y):
    xs = []
    for (xa, ya), (xb, yb) in zip(pts, pts[1:] + pts[:1]):
        if (ya - y) * (yb - y) <= 0 and ya != yb:
            xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
    return (min(xs), max(xs)) if xs else (0, 0)


def _eye(d, x0, x1, y, fill=(90, 86, 100)):
    w = x1 - x0
    upper = [(x0 + w * t / 20, y - w * 0.22 * math.sin(math.pi * t / 20)) for t in range(21)]
    lower = [(x0 + w * t / 20, y + w * 0.14 * math.sin(math.pi * t / 20)) for t in range(20, -1, -1)]
    d.polygon(upper + lower, fill=WHITE, outline=fill)
    r = w * 0.16
    cx = (x0 + x1) / 2
    d.ellipse([cx - r, y - r, cx + r, y + r], fill=(110, 104, 118))


def dg_face(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    H = y1 - y0 - 44
    W = H * 0.7
    cx, top = x0 + 248, y0 + 6
    chin = top + H
    pts = _egg(cx, top, W, H)
    d.polygon(pts, fill=(246, 244, 240), outline=INK)
    yH, yB, yE, yN, yM = (top + H * k for k in (0.19, 0.46, 0.5, 0.73, 0.82))
    for y in (yH, yB, yN, chin):
        dashed(d, (x0 + 74, y), (cx + W / 2 + 40, y), pg.accent, width=1, dash=6, gap=5)
    for name, y in [('发际线', yH), ('眉弓', yB), ('鼻底', yN), ('下巴', chin)]:
        text_at(d, x0, y + 5, name, 14, SECONDARY)
    el, er = _width_at(pts, yE)
    e = (er - el) / 5
    dashed(d, (el - 14, yE), (er + 14, yE), (170, 166, 178), width=1, dash=4, gap=4)
    for k in range(6):
        x = el + k * e
        d.line([(x, yE - 7), (x, yE + 7)], fill=pg.accent, width=2)
    for k in (1, 3):
        _eye(d, el + k * e + e * 0.1, el + (k + 1) * e - e * 0.1, yE)
        d.arc([el + k * e, yB - 8, el + (k + 1) * e, yB + 12], 200, 340, fill=(90, 86, 100), width=3)
    for k in range(5):
        text_at(d, el + (k + 0.5) * e, yE + 30, str(k + 1), 13, pg.accent, anchor='ms', kind='num')
    d.line([(cx - e * 0.16, yB + 14), (cx - e * 0.3, yN - 16)], fill=(150, 146, 158), width=2)
    d.line([(cx + e * 0.16, yB + 14), (cx + e * 0.3, yN - 16)], fill=(150, 146, 158), width=2)
    d.arc([cx - e / 2, yN - 22, cx + e / 2, yN + 6], 20, 160, fill=(90, 86, 100), width=2)
    for side in (-1, 1):
        d.ellipse([cx + side * e * 0.22 - 4, yN - 9, cx + side * e * 0.22 + 4, yN - 3], fill=(150, 146, 158))
    d.arc([cx - e, yM - 10, cx + e, yM + 8], 25, 155, fill=(110, 96, 104), width=3)
    for side in (-1, 1):
        ex = el if side < 0 else er
        ear_x = _width_at(pts, (yB + yN) / 2)[0 if side < 0 else 1]
        d.ellipse([ear_x - 12 if side < 0 else ear_x - 4, yB + 4,
                   ear_x + 4 if side < 0 else ear_x + 12, yN - 2],
                  fill=(240, 237, 232), outline=(110, 104, 118), width=2)
    bx = cx + W / 2 + 46
    for name, a, b in [('上庭', yH, yB), ('中庭', yB, yN), ('下庭', yN, chin)]:
        d.line([(bx, a + 3), (bx, b - 3)], fill=pg.accent, width=2)
        d.line([(bx - 6, a + 3), (bx + 6, a + 3)], fill=pg.accent, width=2)
        d.line([(bx - 6, b - 3), (bx + 6, b - 3)], fill=pg.accent, width=2)
        text_at(d, bx + 14, (a + b) / 2 + 6, name, 16, pg.accent, kind='bold')
    text_at(d, cx, chin + 32, '五眼：在眼睛的水平线上，脸宽约为五只眼宽', 14, SECONDARY, anchor='ms')


def dg_head_turns(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    cw = (x1 - x0) / 3
    hw, hh = 118, 158
    specs = [('平视', '连线基本水平', 0), ('仰视', '连线上拱，耳朵偏低', 1), ('俯视', '连线下弯，耳朵偏高', -1)]
    for i, (name, note, k) in enumerate(specs):
        cx = x0 + cw * i + cw / 2
        top = y0 + 6
        d.ellipse([cx - hw / 2, top, cx + hw / 2, top + hh], fill=(246, 244, 240), outline=INK, width=2)
        d.line([(cx, top + 4), (cx, top + hh - 4)], fill=(170, 166, 178), width=1)
        for rel in (0.48, 0.68, 0.8):
            y = top + hh * rel
            half = hw / 2 * (0.94 if rel < 0.7 else 0.8)
            if k == 0:
                d.line([(cx - half, y), (cx + half, y)], fill=pg.accent, width=2)
            else:
                bend = 15
                bbox = [cx - half, y - bend, cx + half, y + bend]
                d.arc(bbox, 180, 360, fill=pg.accent, width=2) if k > 0 else d.arc(bbox, 0, 180, fill=pg.accent, width=2)
        shift = hh * 0.08 * k
        for side in (-1, 1):
            ex = cx + side * hw / 2
            d.ellipse([ex - 7 if side > 0 else ex - 9, top + hh * 0.46 + shift,
                       ex + 9 if side > 0 else ex + 7, top + hh * 0.68 + shift],
                      fill=(236, 232, 226), outline=(110, 104, 118), width=2)
        text_at(d, cx, top + hh + 30, name, 17, INK, anchor='ms', kind='bold')
        text_at(d, cx, top + hh + 54, note, 14, SECONDARY, anchor='ms')


def dg_mannequin(pg, box, labels=True):
    x0, y0, x1, y1 = box
    d = pg.d
    u = (y1 - y0 - 16) / 7.3
    cx = x0 + (150 if labels else (x1 - x0) / 2)
    top = y0 + 6

    def P(x, y):
        return (cx + x * u, top + y * u)

    ground = top + 7.15 * u
    d.line([(cx - 2.2 * u, ground), (cx + 2.4 * u, ground)], fill=(200, 196, 204), width=2)
    sl, sr = P(-0.95, 1.62), P(1.0, 1.36)
    chest = [sl, sr, P(0.56, 2.72), P(-0.6, 2.86)]
    pelvis = [P(-0.64, 3.02), P(0.62, 3.26), P(0.5, 3.98), P(-0.56, 3.72)]
    limb(d, [sl, P(-1.22, 2.95), P(-1.12, 3.95)])
    limb(d, [sr, P(1.28, 2.66), P(1.4, 3.66)])
    limb(d, [P(-0.38, 3.62), P(-0.16, 5.3), P(0.05, 6.9)])
    limb(d, [P(0.46, 3.84), P(0.92, 5.38), P(1.08, 6.84)])
    d.polygon([P(0.05, 6.9), P(0.5, 6.96), P(0.52, 7.12), P(-0.05, 7.12)], fill=(150, 146, 158))
    d.polygon([P(1.08, 6.84), P(1.48, 6.98), P(1.46, 7.1), P(1.0, 7.06)], fill=(150, 146, 158))
    d.polygon(chest, fill=(226, 222, 216), outline=INK)
    d.polygon(pelvis, fill=(214, 210, 204), outline=INK)
    d.line([P(0.1, 1.0), P(0.05, 1.4)], fill=(150, 146, 158), width=8)
    hx, hy = P(0.18, 0.52)
    d.ellipse([hx - 0.37 * u, hy - 0.52 * u, hx + 0.37 * u, hy + 0.52 * u], fill=(236, 232, 226), outline=INK, width=2)
    if labels:
        dashed(d, P(-1.6, 1.62 + 0.13 * 0.6), P(1.7, 1.36 - 0.13 * 0.7), (150, 146, 158), width=1)
        dashed(d, P(-1.4, 3.02 - 0.19 * 0.76), P(1.5, 3.26 + 0.19 * 0.88), (150, 146, 158), width=1)
    curve = catmull([P(0.22, 0.04), P(0.06, 1.36), P(-0.08, 2.6), P(-0.32, 3.66), P(-0.14, 5.3), P(0.06, 6.95)])
    d.line(curve, fill=pg.accent, width=5, joint='curve')
    neck = P(0.05, 1.4)
    dashed(d, neck, (neck[0], ground), (214, 72, 60), width=3, dash=9, gap=6)
    d.ellipse([neck[0] - 5, neck[1] - 5, neck[0] + 5, neck[1] + 5], fill=(214, 72, 60))
    if not labels:
        return
    lx = x0 + 330
    items = [
        ('动态线', '贯穿头、躯干与支撑腿的主线', pg.accent, 'solid'),
        ('重心线', '自颈窝垂直向下，落在支撑脚上', (214, 72, 60), 'dash'),
        ('肩线与胯线', '支撑腿一侧胯高肩低，方向相反', (150, 146, 158), 'dash'),
    ]
    y = y0 + 40
    for title, note, color, style in items:
        if style == 'solid':
            d.line([(lx, y - 6), (lx + 36, y - 6)], fill=color, width=5)
        else:
            dashed(d, (lx, y - 6), (lx + 36, y - 6), color, width=3, dash=7, gap=5)
        text_at(d, lx + 48, y, title, 17, INK, kind='bold')
        for j, line in enumerate(wrap(note, F('body', 14), x1 - lx - 48)):
            text_at(d, lx + 48, y + 26 + j * 21, line, 14, SECONDARY)
        y += 92
    text_at(d, cx - 1.15 * u, ground + 4, '支撑腿', 13, TERTIARY, anchor='mt')


def _figure_stand(d, cx, ground, u):
    def P(x, y):
        return (cx + x * u, ground - (7 - y) * u)

    limb(d, [P(-0.95, 1.3), P(-1.12, 2.6), P(-1.15, 3.5)], width=7)
    limb(d, [P(0.95, 1.3), P(1.12, 2.6), P(1.15, 3.5)], width=7)
    limb(d, [P(-0.4, 3.45), P(-0.38, 5.1), P(-0.33, 6.85)], width=8)
    limb(d, [P(0.4, 3.45), P(0.38, 5.1), P(0.33, 6.85)], width=8)
    d.polygon([P(-0.95, 1.25), P(0.95, 1.25), P(0.62, 2.6), P(-0.62, 2.6)], fill=(226, 222, 216), outline=INK)
    d.polygon([P(-0.64, 2.6), P(0.64, 2.6), P(0.72, 3.5), P(-0.72, 3.5)], fill=(214, 210, 204), outline=INK)
    for s in (-1, 1):
        hx, hy = P(s * 1.15, 3.9)
        d.ellipse([hx - 0.16 * u, hy - 0.42 * u, hx + 0.16 * u, hy + 0.42 * u], fill=(226, 222, 216), outline=INK)
        fx, fy = P(s * 0.38, 6.93)
        d.ellipse([fx - 0.26 * u, fy - 0.1 * u, fx + 0.26 * u, fy + 0.07 * u], fill=(150, 146, 158))
    hx, hy = P(0, 0.5)
    d.ellipse([hx - 0.36 * u, hy - 0.5 * u, hx + 0.36 * u, hy + 0.5 * u], fill=(236, 232, 226), outline=INK, width=2)


def _figure_sit(d, cx, ground, u):
    def P(x, y):
        return (cx + x * u, ground - (5 - y) * u)

    d.rectangle([*P(-0.75, 3.32), *P(0.45, 3.46)], fill=(176, 150, 120))
    for x in (-0.65, 0.35):
        d.line([P(x, 3.46), P(x, 5)], fill=(176, 150, 120), width=5)
    limb(d, [P(-0.1, 3.25), P(1.5, 3.15), P(1.45, 4.85)], width=8)
    fx, fy = P(1.62, 4.92)
    d.ellipse([fx - 0.3 * u, fy - 0.1 * u, fx + 0.3 * u, fy + 0.08 * u], fill=(150, 146, 158))
    d.polygon([P(-0.42, 1.2), P(0.5, 1.25), P(0.38, 2.6), P(-0.5, 2.6)], fill=(226, 222, 216), outline=INK)
    d.polygon([P(-0.55, 2.6), P(0.42, 2.6), P(0.35, 3.3), P(-0.6, 3.3)], fill=(214, 210, 204), outline=INK)
    limb(d, [P(0.05, 1.35), P(0.3, 2.55), P(0.95, 3.05)], width=7)
    hx, hy = P(0.06, 0.5)
    d.ellipse([hx - 0.4 * u, hy - 0.5 * u, hx + 0.4 * u, hy + 0.5 * u], fill=(236, 232, 226), outline=INK, width=2)


def _figure_cross(d, cx, ground, u):
    def P(x, y):
        return (cx + x * u, ground - (3.5 - y) * u)

    limb(d, [P(-0.45, 3.2), P(-1.45, 3.15), P(0.35, 3.42)], width=8)
    limb(d, [P(0.45, 3.2), P(1.45, 3.15), P(-0.35, 3.42)], width=8)
    d.polygon([P(-0.9, 1.25), P(0.9, 1.25), P(0.6, 2.55), P(-0.6, 2.55)], fill=(226, 222, 216), outline=INK)
    d.polygon([P(-0.62, 2.55), P(0.62, 2.55), P(0.7, 3.3), P(-0.7, 3.3)], fill=(214, 210, 204), outline=INK)
    limb(d, [P(-0.9, 1.3), P(-1.05, 2.4), P(-1.35, 3.0)], width=7)
    limb(d, [P(0.9, 1.3), P(1.05, 2.4), P(1.35, 3.0)], width=7)
    hx, hy = P(0, 0.5)
    d.ellipse([hx - 0.36 * u, hy - 0.5 * u, hx + 0.36 * u, hy + 0.5 * u], fill=(236, 232, 226), outline=INK, width=2)


def dg_proportions(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    u = (y1 - y0 - 64) / 7
    ground = y0 + 12 + 7 * u
    rx = x0 + 34
    d.line([(rx, ground), (rx, ground - 7 * u)], fill=INK, width=2)
    for k in range(8):
        y = ground - k * u
        d.line([(rx - 6, y), (rx + 6, y)], fill=INK, width=2)
        if k:
            text_at(d, rx - 12, y + u / 2 + 5, str(8 - k), 13, SECONDARY, anchor='rs', kind='num')
    text_at(d, rx - 14, ground + 26, '头长', 13, SECONDARY)
    d.line([(rx + 8, ground), (x1, ground)], fill=(200, 196, 204), width=2)
    figs = [(x0 + 150, 7, _figure_stand, '站：约 7 个头长'), (x0 + 318, 5, _figure_sit, '坐：约 5 个头长'),
            (x0 + 500, 3.5, _figure_cross, '盘腿：约 3.5 个头长')]
    for fx, heads, fn, note in figs:
        y = ground - heads * u
        dashed(d, (rx + 8, y), (fx + 1.6 * u, y), mix(PAPER, pg.accent, 0.6), width=1, dash=5, gap=5)
        fn(d, fx, ground, u)
        text_at(d, fx + (0.5 * u if fn is _figure_sit else 0), ground + 30, note, 15, INK, anchor='ms', kind='bold')


def dg_blocks(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    cw = (x1 - x0) / 3
    u = (y1 - y0 - 60) / 6.6
    specs = [('直立', '三个体块上下对齐', 0, 0, False), ('侧倾', '胸腔与骨盆反向倾斜', -11, 9, False),
             ('扭转', '胸腔与骨盆朝向不同', 0, 0, True)]
    for i, (name, note, a_chest, a_pelvis, twist) in enumerate(specs):
        cx = x0 + cw * i + cw / 2
        top = y0 + 4

        def P(x, y):
            return (cx + x * u, top + y * u)

        cc, pc = P(0, 2.0), P(0, 3.35)
        chest = rot([P(-1.0, 1.25), P(1.0, 1.25), P(0.7, 2.7), P(-0.7, 2.7)], cc, a_chest)
        pelvis = rot([P(-0.75, 2.95), P(0.75, 2.95), P(0.75, 3.75), P(-0.75, 3.75)], pc, a_pelvis)
        hips = rot([P(-0.4, 3.7), P(0.4, 3.7)], pc, a_pelvis)
        limb(d, [hips[0], (hips[0][0] - 0.05 * u, top + 5.1 * u), (hips[0][0], top + 6.5 * u)], width=7)
        limb(d, [hips[1], (hips[1][0] + 0.1 * u, top + 5.1 * u), (hips[1][0] + 0.2 * u, top + 6.5 * u)], width=7)
        if twist:
            front = [P(-0.95, 1.25), P(0.45, 1.25), P(0.3, 2.7), P(-0.7, 2.7)]
            side = [P(0.45, 1.25), P(0.95, 1.4), P(0.75, 2.62), P(0.3, 2.7)]
            d.polygon(front, fill=(226, 222, 216), outline=INK)
            d.polygon(side, fill=(196, 192, 186), outline=INK)
        else:
            d.polygon(chest, fill=(226, 222, 216), outline=INK)
        d.polygon(pelvis, fill=(214, 210, 204), outline=INK)
        spine = [rot([P(0, 1.05)], cc, a_chest)[0], cc, P(0, 2.85), pc]
        d.line(catmull(spine), fill=pg.accent, width=3)
        hc = rot([P(0, 0.55)], cc, a_chest)[0]
        d.ellipse([hc[0] - 0.36 * u, hc[1] - 0.5 * u, hc[0] + 0.36 * u, hc[1] + 0.5 * u],
                  fill=(236, 232, 226), outline=INK, width=2)
        text_at(d, cx, y1 - 30, name, 16, INK, anchor='ms', kind='bold')
        text_at(d, cx, y1 - 8, note, 14, SECONDARY, anchor='ms')


def dg_horizons(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    gap = 18
    fw = (x1 - x0 - gap * 2) / 3
    fh = y1 - y0 - 40
    specs = [('高地平线：突出地面', 0.34, True), ('低地平线：突出天空', 0.68, True), ('居中：画面被等分', 0.5, False)]
    for i, (text, ratio, ok) in enumerate(specs):
        fx = x0 + i * (fw + gap)
        hy = y0 + fh * ratio
        gradient_fill(pg.im, (fx, y0, fx + fw, hy), (150, 190, 232), (226, 236, 242))
        gradient_fill(pg.im, (fx, hy, fx + fw, y0 + fh), (178, 186, 120), (132, 146, 84))
        d.rectangle([fx + fw * 0.18, hy - 18, fx + fw * 0.34, hy], fill=(236, 220, 190))
        d.polygon([(fx + fw * 0.16, hy - 18), (fx + fw * 0.26, hy - 30), (fx + fw * 0.36, hy - 18)], fill=(168, 84, 60))
        d.ellipse([fx + fw * 0.66, hy - 46, fx + fw * 0.8, hy - 16], fill=(70, 104, 60))
        d.line([(fx + fw * 0.73, hy - 18), (fx + fw * 0.73, hy)], fill=(96, 70, 50), width=3)
        d.rectangle([fx, y0, fx + fw, y0 + fh], outline=(205, 203, 210), width=2)
        tw = pill(d, fx, y0 + fh + 10, '适用' if ok else '避免', GOOD if ok else BAD)
        text_at(d, fx + tw + 6, baseline(y0 + fh + 10, 22, F('body', 13)), text, 13, SECONDARY)


def _ridge(w, base, amp, f1, f2, p1, p2):
    return [(x, base - amp * (0.6 * math.sin(x * f1 + p1) + 0.4 * math.sin(x * f2 + p2)))
            for x in range(0, int(w) + 8, 8)]


def dg_aerial(pg, box):
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = x1 - x0, y1 - y0
    panel = Image.new('RGB', (w, h), WHITE)
    gradient_fill(panel, (0, 0, w, h), (118, 160, 214), (232, 236, 238))
    pd = ImageDraw.Draw(panel)
    far = _ridge(w, h * 0.5, h * 0.12, 0.011, 0.027, 0.4, 1.7)
    pd.polygon(far + [(w, h), (0, h)], fill=(170, 184, 208))
    mid = _ridge(w, h * 0.66, h * 0.08, 0.017, 0.041, 2.1, 0.3)
    pd.polygon(mid + [(w, h), (0, h)], fill=(118, 146, 116))
    for k in range(9):
        tx = 40 + k * 66
        pd.ellipse([tx, h * 0.6 - 10 + (k % 3) * 6, tx + 26, h * 0.6 + 14 + (k % 3) * 6], fill=(92, 120, 92))
    near = _ridge(w, h * 0.82, h * 0.04, 0.02, 0.05, 1.0, 2.5)
    pd.polygon(near + [(w, h), (0, h)], fill=(184, 146, 72))
    for k, tx in enumerate((30, 120, 470, 540)):
        pd.ellipse([tx, h * 0.52, tx + 56, h * 0.8], fill=(44, 64, 36))
        pd.line([(tx + 28, h * 0.78), (tx + 28, h * 0.9)], fill=(70, 50, 30), width=4)
    for k in range(14):
        sx = 200 + k * 18
        pd.line([(sx, h * 0.9), (sx + 8, h * 0.86)], fill=(232, 198, 110), width=3)
    pg.im.paste(panel, (x0, y0))
    d = pg.d
    label_box(d, x0 + w - 12, y0 + int(h * 0.36), '远景：偏冷 · 偏灰 · 对比弱', anchor='r')
    label_box(d, x0 + w - 12, y0 + int(h * 0.58), '中景：主体所在，关系完整', anchor='r')
    label_box(d, x0 + 210, y0 + int(h * 0.74), '近景：偏暖 · 纯度高 · 对比强', anchor='l')
    d.rectangle([x0, y0, x1, y1], outline=(205, 203, 210), width=1)


def dg_reflection(pg, box):
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = x1 - x0, y1 - y0
    panel = Image.new('RGB', (w, h), WHITE)
    axis = int(h * 0.46)
    gradient_fill(panel, (0, 0, w, axis), (150, 190, 228), (222, 232, 240))
    gradient_fill(panel, (0, axis, w, h), (164, 186, 204), (120, 146, 170))
    pd = ImageDraw.Draw(panel)
    pd.rectangle([0, axis - 12, w, axis], fill=(112, 140, 88))
    house = (int(w * 0.16), int(h * 0.2), int(w * 0.36), axis)
    pd.rectangle(house, fill=(246, 243, 236))
    pd.polygon([(house[0] - 8, house[1]), ((house[0] + house[2]) / 2, house[1] - 34), (house[2] + 8, house[1])], fill=(172, 84, 62))
    pd.rectangle([house[0] + 22, house[1] + 26, house[0] + 44, axis - 8], fill=(120, 90, 70))
    r_top = axis + (axis - house[1])
    pd.rectangle([house[0], axis, house[2], r_top], fill=(204, 210, 214))
    pd.polygon([(house[0] - 8, r_top), ((house[0] + house[2]) / 2, r_top + 30), (house[2] + 8, r_top)], fill=(150, 112, 104))
    tx = int(w * 0.64)
    pd.ellipse([tx - 46, int(h * 0.04), tx + 46, int(h * 0.36)], fill=(36, 56, 38))
    pd.line([(tx, int(h * 0.3)), (tx, axis)], fill=(52, 40, 30), width=7)
    pd.line([(tx, axis), (tx, axis + (axis - int(h * 0.3)))], fill=(96, 104, 104), width=7)
    pd.ellipse([tx - 46, axis + (axis - int(h * 0.36)), tx + 46, axis + (axis - int(h * 0.04))], fill=(76, 98, 92))
    for k in range(26):
        rx = (k * 97) % (w - 60)
        ry = axis + 14 + (k * 37) % (h - axis - 20)
        pd.line([(rx, ry), (rx + 28 + (k % 4) * 10, ry)], fill=(198, 212, 224), width=2)
    pg.im.paste(panel, (x0, y0))
    d = pg.d
    label_box(d, x0 + house[2] + 10, y0 + axis + 30, '亮的物体：倒影略暗')
    label_box(d, x0 + tx + 54, y0 + axis + 66, '暗的物体：倒影略亮')
    label_box(d, x0 + w - 12, y0 + h - 34, '横向波纹打破倒影边缘', anchor='r')
    d.rectangle([x0, y0, x1, y1], outline=(205, 203, 210), width=1)


def dg_street(pg, box):
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = x1 - x0, y1 - y0
    d = pg.d
    hy = y0 + int(h * 0.42)
    vp = (x0 + w * 0.52, hy)
    d.rectangle([x0, y0, x1, hy], fill=(247, 247, 249))
    d.rectangle([x0, hy, x1, y1], fill=(236, 232, 224))

    def at(p, x):
        t = (x - p[0]) / (vp[0] - p[0])
        return (x, p[1] + (vp[1] - p[1]) * t)

    for side in (0, 1):
        near_x = x0 if side == 0 else x1
        far_x = x0 + w * (0.38 if side == 0 else 0.66)
        top_n, bot_n = (near_x, y0 + h * 0.04), (near_x, y0 + h * 0.98)
        top_f, bot_f = at(top_n, far_x), at(bot_n, far_x)
        d.polygon([top_n, top_f, bot_f, bot_n], fill=(222, 216, 206) if side == 0 else (210, 204, 194), outline=OBJ_LINE)
        for k in range(1, 6):
            x = near_x + (far_x - near_x) * (1 - 0.72 ** k)
            d.line([at(top_n, x), at(bot_n, x)], fill=(160, 154, 146), width=1)
    for xb in (x0 + w * 0.2, x0 + w * 0.82):
        d.line([(xb, y1), vp], fill=(190, 184, 176), width=2)
    d.line([(x0, hy), (x1, hy)], fill=pg.accent, width=2)
    d.ellipse([vp[0] - 5, vp[1] - 5, vp[0] + 5, vp[1] + 5], fill=pg.accent)
    for fx, s in ((x0 + w * 0.3, h * 0.62), (x0 + w * 0.6, h * 0.3), (x0 + w * 0.47, h * 0.15)):
        r = s * 0.075
        d.rounded_rectangle([fx - s * 0.11, hy + r * 0.9, fx + s * 0.11, hy + s * 0.55], int(r), fill=(120, 116, 132))
        d.line([(fx - s * 0.05, hy + s * 0.5), (fx - s * 0.07, hy + s * 0.9)], fill=(90, 86, 100), width=max(2, int(s * 0.06)))
        d.line([(fx + s * 0.05, hy + s * 0.5), (fx + s * 0.08, hy + s * 0.9)], fill=(90, 86, 100), width=max(2, int(s * 0.06)))
        d.ellipse([fx - r, hy - r, fx + r, hy + r], fill=(236, 232, 226), outline=INK, width=2)
    label_box(d, x0 + 8, hy - 30, '视平线', fill=pg.accent)
    label_box(d, vp[0] + 10, hy - 30, '灭点', fill=pg.accent)
    label_box(d, x0 + w * 0.52, y1 - 36, '人物头部都在视平线附近，近大远小', anchor='m')
    d.rectangle([x0, y0, x1, y1], outline=(205, 203, 210), width=1)


def dg_pencils(pg, box):
    x0, y0, x1, y1 = box
    d = pg.d
    grades = ['2H', 'H', 'HB', 'B', '2B', '4B', '6B', '8B']
    n, gap = len(grades), 10
    sw = (x1 - x0 - gap * (n - 1)) / n
    top, sh = y0 + 40, y1 - y0 - 76
    d.line([(x0, y0 + 14), (x1, y0 + 14)], fill=(180, 176, 188), width=2)
    d.polygon([(x1, y0 + 14), (x1 - 10, y0 + 8), (x1 - 10, y0 + 20)], fill=(180, 176, 188))
    text_at(d, x0, y0 + 32, '硬 · 浅', 14, SECONDARY)
    text_at(d, x1, y0 + 32, '软 · 深', 14, SECONDARY, anchor='rs')
    for i, g in enumerate(grades):
        sx = x0 + i * (sw + gap)
        tone = int(196 - i * 23)
        d.rectangle([sx, top, sx + sw, top + sh], fill=WHITE, outline=(214, 212, 218))
        spacing = max(3, 9 - i)
        k = 4
        while sx + k + 8 < sx + sw - 2:
            d.line([(sx + k, top + 5), (sx + k + 8, top + sh - 5)], fill=(tone, tone, tone + 6), width=2)
            k += spacing
        text_at(d, sx + sw / 2, top + sh + 24, g, 16, INK, anchor='ms', kind='num')


DIAGRAMS = {
    'composition': dg_composition,
    'tones': dg_tones,
    'perspective': dg_perspective,
    'values': dg_values,
    'color_strips': dg_color_strips,
    'wheel': dg_wheel,
    'warm_cool': dg_warm_cool,
    'face': dg_face,
    'head_turns': dg_head_turns,
    'mannequin': dg_mannequin,
    'proportions': dg_proportions,
    'blocks': dg_blocks,
    'horizons': dg_horizons,
    'aerial': dg_aerial,
    'reflection': dg_reflection,
    'street': dg_street,
    'pencils': dg_pencils,
}

FX = {
    'lines': fx_lines,
    'values': fx_values,
    'blocks': fx_blocks,
    'shaping': fx_shaping,
    'flat': fx_flat,
    'fade': fx_fade,
}

# ── 页面与排版块 ────────────────────────────────────────────────────────


class Page:
    def __init__(self, book, number):
        self.book = book
        self.number = number
        self.im = Image.new('RGB', (PAGE_W, PAGE_H), PAPER)
        self.d = ImageDraw.Draw(self.im)
        self.x0, self.x1 = MX, PAGE_W - MX
        self.y = TOP

    @property
    def w(self):
        return self.x1 - self.x0

    @property
    def accent(self):
        return self.book['accent']

    def chrome(self, header=True, footer=True):
        d = self.d
        if header:
            f = F('body', 14)
            d.text((MX, 44), self.book['running'], font=f, fill=TERTIARY, anchor='ls')
            d.text((PAGE_W - MX, 44), self.book.get('mark', SAMPLE_MARK), font=f, fill=TERTIARY, anchor='rs')
            d.line([(MX, 58), (PAGE_W - MX, 58)], fill=LINE, width=1)
        if footer:
            d.line([(PAGE_W / 2 - 12, PAGE_H - 52), (PAGE_W / 2 + 12, PAGE_H - 52)], fill=self.accent, width=2)
            d.text((PAGE_W / 2, PAGE_H - 26), str(self.number), font=F('num', 16), fill=SECONDARY, anchor='ms')


def place_image(pg, spec, x, y, w, h):
    """贴图（可裁切、可加处理效果与编号标注），返回图片 + 图注之后的 y。"""
    if 'draw' in spec:
        frame = Image.new('RGB', (int(w), int(h)), WHITE)
        sub = Page(pg.book, pg.number)
        sub.im, sub.d = frame, ImageDraw.Draw(frame)
        DIAGRAMS[spec['draw']](sub, (8, 8, w - 8, h - 8), **spec.get('args', {}))
        pg.im.paste(frame, (int(x), int(y)))
    else:
        im, to_local = fit(art(spec['src']), w, h, spec.get('crop'), spec.get('focus', (0.5, 0.5)))
        if spec.get('fx'):
            im = FX[spec['fx']](im)
        pg.im.paste(im, (int(x), int(y)))
        for k, (fx, fy) in enumerate(spec.get('points', [])):
            px, py = to_local(fx, fy)
            px, py = x + px, y + py
            pg.d.ellipse([px - 14, py - 14, px + 14, py + 14], fill=pg.accent, outline=WHITE, width=3)
            pg.d.text((px, py + 6), str(k + 1), font=F('num', 16), fill=WHITE, anchor='ms')
    pg.d.rectangle([x, y, x + w - 1, y + h - 1], outline=(222, 220, 226), width=1)
    bottom = y + h
    caption = spec.get('caption')
    if caption:
        f = F('body', 15)
        bottom += 6
        for line in wrap(caption, f, w):
            pg.d.text((x, baseline(bottom, 22, f)), line, font=f, fill=TERTIARY, anchor='ls')
            bottom += 22
    return bottom


def b_chapter(pg, label, title):
    d = pg.d
    fl = F('num', 18) if label.isdigit() else F('bold', 16)
    d.text((pg.x0, pg.y + 18), label, font=fl, fill=pg.accent, anchor='ls')
    y = pg.y + 28
    ft = F('kai', 34)
    for line in wrap(title, ft, pg.w):
        d.text((pg.x0, baseline(y, 46, ft)), line, font=ft, fill=INK, anchor='ls')
        y += 46
    d.rectangle([pg.x0, y + 6, pg.x0 + 36, y + 10], fill=pg.accent)
    pg.y = y + 28


def b_h2(pg, text):
    f = F('bold', 21)
    pg.d.text((pg.x0, baseline(pg.y, 34, f)), text, font=f, fill=INK, anchor='ls')
    pg.y += 40


def b_p(pg, text, size=20, lh=33, color=BODY):
    f = F('body', size)
    ind = size * 2
    for i, line in enumerate(wrap(text, f, pg.w, first=pg.w - ind)):
        pg.d.text((pg.x0 + (ind if i == 0 else 0), baseline(pg.y, lh, f)), line, font=f, fill=color, anchor='ls')
        pg.y += lh
    pg.y += 10


def b_list(pg, items, style='dot'):
    d = pg.d
    f, fb = F('body', 20), F('bold', 20)
    lh, indent = 32, 30
    for k, item in enumerate(items):
        x, top = pg.x0, pg.y
        if style == 'dot':
            d.ellipse([x + 6, top + 13, x + 13, top + 20], fill=pg.accent)
        elif style == 'num':
            d.ellipse([x, top + 5, x + 22, top + 27], fill=pg.accent)
            d.text((x + 11, top + 22), str(k + 1), font=F('num', 14), fill=WHITE, anchor='ms')
        else:
            d.rounded_rectangle([x + 2, top + 7, x + 20, top + 25], 4, outline=pg.accent, width=2)
        head, rest = split_head(item)
        tx, avail = x + indent, pg.w - indent
        if head:
            hw = fb.getlength(head)
            d.text((tx, baseline(top, lh, fb)), head, font=fb, fill=INK, anchor='ls')
            lines = wrap(rest, f, avail, first=avail - hw)
        else:
            hw, lines = 0, wrap(item, f, avail)
        for i, line in enumerate(lines):
            d.text((tx + (hw if i == 0 else 0), baseline(top + i * lh, lh, f)), line, font=f, fill=BODY, anchor='ls')
        pg.y = top + len(lines) * lh + 8
    pg.y += 6


def b_tip(pg, title, text, kind='tip'):
    d = pg.d
    f, ft = F('body', 18), F('bold', 18)
    lh, pad = 29, 16
    lines = wrap(text, f, pg.w - pad * 2 - 6)
    h = pad + 30 + len(lines) * lh + pad - 6
    top = pg.y
    if kind == 'question':
        d.rounded_rectangle([pg.x0, top, pg.x1, top + h], 10, fill=WHITE, outline=pg.accent, width=2)
    else:
        d.rounded_rectangle([pg.x0, top, pg.x1, top + h], 10, fill=mix(PAPER, pg.accent, 0.09))
        d.rectangle([pg.x0, top + 12, pg.x0 + 4, top + h - 12], fill=pg.accent)
    d.text((pg.x0 + pad + 6, baseline(top + pad - 4, 30, ft)), title, font=ft, fill=pg.accent, anchor='ls')
    for i, line in enumerate(lines):
        d.text((pg.x0 + pad + 6, baseline(top + pad + 26 + i * lh, lh, f)), line, font=f, fill=BODY, anchor='ls')
    pg.y = top + h + 14


def b_table(pg, headers, rows, widths):
    d = pg.d
    scale = pg.w / sum(widths)
    widths = [w * scale for w in widths]
    fh, fb, fk = F('bold', 16), F('body', 16), F('bold', 16)
    lh, px, py = 25, 10, 8

    def height(cells, font):
        return max(len(wrap(c, font, w - 2 * px)) for c, w in zip(cells, widths)) * lh + 2 * py

    def draw_row(cells, top, fonts, colors):
        x = pg.x0
        for c, w, font, color in zip(cells, widths, fonts, colors):
            for i, line in enumerate(wrap(c, font, w - 2 * px)):
                d.text((x + px, baseline(top + py + i * lh, lh, font)), line, font=font, fill=color, anchor='ls')
            x += w

    hh = height(headers, fh)
    d.rectangle([pg.x0, pg.y, pg.x1, pg.y + hh], fill=mix(PAPER, pg.accent, 0.13))
    draw_row(headers, pg.y, [fh] * len(headers), [INK] * len(headers))
    pg.y += hh
    for i, row in enumerate(rows):
        rh = height(row, fb)
        if i % 2 == 1:
            d.rectangle([pg.x0, pg.y, pg.x1, pg.y + rh], fill=(246, 245, 249))
        draw_row(row, pg.y, [fk] + [fb] * (len(row) - 1), [INK] + [BODY] * (len(row) - 1))
        pg.y += rh
        d.line([(pg.x0, pg.y), (pg.x1, pg.y)], fill=LINE, width=1)
    pg.y += 16


def b_timeline(pg, entries):
    d = pg.d
    fe, ft, fd = F('bold', 14), F('bold', 19), F('body', 17)
    x, lh = pg.x0, 27
    layout = []
    y = pg.y
    for era, title, desc in entries:
        lines = wrap(desc, fd, pg.w - 26)
        layout.append((y, era, title, lines))
        y += 34 + len(lines) * lh + 12
    line_x = x + 7
    d.line([(line_x, pg.y + 15), (line_x, layout[-1][0] + 15)], fill=mix(PAPER, pg.accent, 0.35), width=2)
    for top, era, title, lines in layout:
        d.ellipse([line_x - 6, top + 9, line_x + 6, top + 21], fill=pg.accent)
        ew = pill(d, x + 24, top + 4, era, pg.accent, size=13)
        d.text((x + 24 + ew + 10, baseline(top, 30, ft)), title, font=ft, fill=INK, anchor='ls')
        for i, line in enumerate(lines):
            d.text((x + 26, baseline(top + 34 + i * lh, lh, fd)), line, font=fd, fill=BODY, anchor='ls')
    pg.y = y + 4


def b_img(pg, spec):
    bottom = place_image(pg, spec, pg.x0, pg.y, pg.w, spec['h'])
    pg.y = bottom + 14


def b_imgs(pg, spec):
    items = spec['items']
    cols = spec.get('cols', len(items))
    gap = 14
    w = (pg.w - gap * (cols - 1)) / cols
    rows_bottom = pg.y
    for r in range(0, len(items), cols):
        top = rows_bottom
        bottom = top
        for c, item in enumerate(items[r:r + cols]):
            bottom = max(bottom, place_image(pg, item, pg.x0 + c * (w + gap), top, w, spec['h']))
        rows_bottom = bottom + 12
    pg.y = rows_bottom + 2


def b_side(pg, img, blocks, side='left'):
    gap = 22
    w, h = img['w'], img['h']
    top = pg.y
    if side == 'left':
        ix, tx0, tx1 = pg.x0, pg.x0 + w + gap, pg.x1
    else:
        ix, tx0, tx1 = pg.x1 - w, pg.x0, pg.x1 - w - gap
    img_bottom = place_image(pg, img, ix, top, w, h)
    saved = (pg.x0, pg.x1)
    pg.x0, pg.x1 = tx0, tx1
    for block in blocks:
        render_block(pg, block)
    pg.x0, pg.x1 = saved
    pg.y = max(pg.y, img_bottom + 14)


def b_diagram(pg, name, h):
    DIAGRAMS[name](pg, (pg.x0, pg.y, pg.x1, pg.y + h))
    pg.y += h + 14


def render_block(pg, block):
    kind, *args = block
    {
        'chapter': b_chapter,
        'h2': b_h2,
        'p': b_p,
        'bullets': lambda p, items: b_list(p, items, 'dot'),
        'steps': lambda p, items: b_list(p, items, 'num'),
        'checks': lambda p, items: b_list(p, items, 'check'),
        'tip': b_tip,
        'question': lambda p, title, text: b_tip(p, title, text, 'question'),
        'table': b_table,
        'timeline': b_timeline,
        'img': b_img,
        'imgs': b_imgs,
        'side': b_side,
        'diagram': b_diagram,
        'gap': lambda p, h: setattr(p, 'y', p.y + h),
    }[kind](pg, *args)


def content_page(book, number, blocks):
    pg = Page(book, number)
    pg.chrome()
    for block in blocks:
        render_block(pg, block)
    if pg.y > BOTTOM + 6:
        print(f'  ! {book["id"]} p{number:02d} 超出 {int(pg.y - BOTTOM)} px')
    return pg.im


def title_page(book):
    pg = Page(book, 1)
    d, cx, accent = pg.d, PAGE_W / 2, book['accent']
    d.rectangle([0, 0, PAGE_W, 10], fill=accent)
    y = 96
    f = F('bold', 16)
    d.text((cx, baseline(y, 28, f)), '美术之路 · 示例书刊', font=f, fill=accent, anchor='ms')
    y += 44
    ft = F('kai', 46)
    for line in book['cover_title']:
        d.text((cx, baseline(y, 60, ft)), line, font=ft, fill=INK, anchor='ms')
        y += 60
    fs = F('body', 20)
    d.text((cx, baseline(y + 4, 32, fs)), book['subtitle'], font=fs, fill=SECONDARY, anchor='ms')
    y += 56
    src, crop = book['title_art']
    place_image(pg, {'src': src, 'crop': crop}, cx - 200, y, 400, 250)
    y += 272
    fe = F('body', 20)
    d.text((cx, baseline(y, 32, fe)), f'{book["editor"]}　编', font=fe, fill=INK, anchor='ms')
    y += 32
    fp = F('body', 16)
    d.text((cx, baseline(y, 26, fp)), book['publisher'], font=fp, fill=TERTIARY, anchor='ms')
    y += 42
    fd = F('body', 17)
    lines = wrap(book['description'], fd, 520)
    box_h = len(lines) * 28 + 30
    d.rounded_rectangle([cx - 276, y, cx + 276, y + box_h], 10, fill=mix(PAPER, accent, 0.08))
    for i, line in enumerate(lines):
        d.text((cx - 260, baseline(y + 15 + i * 28, 28, fd)), line, font=fd, fill=BODY, anchor='ls')
    note = ('示例声明：本书为「美术之路」演示用示例内容，非正式出版物，无书号、不对外发行；'
            '书中图片均来自画室示例图库，文字仅供学习交流与功能演示。')
    fn = F('body', 14)
    ny = PAGE_H - 30 - len(wrap(note, fn, 560)) * 22
    d.line([(cx - 280, ny - 14), (cx + 280, ny - 14)], fill=LINE, width=1)
    for i, line in enumerate(wrap(note, fn, 560)):
        d.text((cx, baseline(ny + i * 22, 22, fn)), line, font=fn, fill=TERTIARY, anchor='ms')
    if y + box_h > ny - 20:
        print(f'  ! {book["id"]} 扉页内容过长')
    return pg.im


def editorial_page(book):
    pg = Page(book, 1)
    pg.chrome()
    d, accent = pg.d, book['accent']
    fm = F('kai', 48)
    d.text((pg.x0, baseline(pg.y + 4, 64, fm)), '画室月刊', font=fm, fill=accent, anchor='ls')
    fi = F('body', 18)
    d.text((pg.x1, baseline(pg.y + 20, 40, fi)), book['issue'], font=fi, fill=SECONDARY, anchor='rs')
    pg.y += 84
    d.line([(pg.x0, pg.y), (pg.x1, pg.y)], fill=accent, width=2)
    pg.y += 24
    b_chapter(pg, '卷首语', book['editorial_title'])
    for para in book['editorial']:
        b_p(pg, para)
    f = F('body', 18)
    d.text((pg.x1, baseline(pg.y, 30, f)), '—— 画室月刊编辑部', font=f, fill=SECONDARY, anchor='rs')
    pg.y += 48
    src, crop = book['title_art']
    place_image(pg, {'src': src, 'crop': crop}, pg.x0, pg.y, pg.w, BOTTOM - pg.y - 40)
    note = '示例期刊：本刊为「美术之路」演示用示例内容，非正式出版物，无刊号、不对外发行。'
    fn = F('body', 14)
    d.text((PAGE_W / 2, BOTTOM - 10), note, font=fn, fill=TERTIARY, anchor='ms')
    return pg.im


def toc_page(book, entries):
    pg = Page(book, 2)
    pg.chrome()
    d = pg.d
    ft = F('kai', 40)
    d.text((pg.x0, baseline(pg.y, 56, ft)), '本期目录' if book.get('issue') else '目录', font=ft, fill=INK, anchor='ls')
    d.text((pg.x1, baseline(pg.y + 8, 48, F('num', 14))), 'CONTENTS', font=F('num', 14), fill=TERTIARY, anchor='rs')
    pg.y += 76
    d.line([(pg.x0, pg.y), (pg.x1, pg.y)], fill=book['accent'], width=2)
    pg.y += 10
    fl, fb, fn = F('num', 18), F('body', 20), F('num', 18)
    rh = 58 if len(entries) <= 10 else 52
    for label, title, page in entries:
        top = pg.y
        x = pg.x0
        if label.isdigit() or len(label) == 1:
            font = fl if label.isdigit() else F('bold', 18)
            d.text((x, baseline(top, rh, font)), label, font=font, fill=book['accent'], anchor='ls')
            x += 44
        text = title if len(label) == 1 else toc_title(label, title)
        d.text((x, baseline(top, rh, fb)), text, font=fb, fill=INK, anchor='ls')
        end = x + fb.getlength(text) + 12
        num = str(page)
        nx = pg.x1 - fn.getlength(num)
        dot_x = end
        while dot_x < nx - 12:
            d.ellipse([dot_x, top + rh / 2 + 6, dot_x + 2, top + rh / 2 + 8], fill=(190, 188, 196))
            dot_x += 8
        d.text((pg.x1, baseline(top, rh, fn)), num, font=fn, fill=book['accent'], anchor='rs')
        pg.y += rh
        d.line([(pg.x0, pg.y), (pg.x1, pg.y)], fill=LINE, width=1)
    if book.get('excerpt'):
        pg.y += 20
        b_tip(pg, '示例节选', book['excerpt'])
    return pg.im


# ── 封面 ────────────────────────────────────────────────────────────────


def badge(d, right, top, text, fg, bg):
    f = F('bold', 14)
    w = f.getlength(text) + 18
    d.rounded_rectangle([right - w, top, right, top + 26], 6, fill=bg)
    d.text((right - w / 2, baseline(top, 26, f)), text, font=f, fill=fg, anchor='ms')


def cover_title(d, x, y, lines, color, size=42, lh=56, anchor='ls'):
    f = F('kai', size)
    for line in lines:
        d.text((x, baseline(y, lh, f)), line, font=f, fill=color, anchor=anchor, stroke_width=1, stroke_fill=color)
        y += lh
    return y


def cover_frame(book, im, d):
    bg, accent = book['cover_bg'], book['accent']
    soft = mix(bg, WHITE, 0.72)
    d.text((36, 46), '美术之路 · 示例书刊', font=F('body', 14), fill=soft, anchor='ls')
    badge(d, COVER_W - 36, 26, '示例', bg, WHITE)
    y = cover_title(d, 36, 70, book['cover_title'], WHITE)
    d.text((36, baseline(y + 4, 28, F('body', 16))), book['subtitle'], font=F('body', 16), fill=mix(bg, WHITE, 0.85), anchor='ls')
    src, crop = book['cover_art']
    d.rectangle([36, 282, COVER_W - 36, 562], fill=(246, 244, 238))
    art_im, _ = fit(art(src), COVER_W - 88, 264, crop)
    im.paste(art_im, (44, 290))
    d.text((36, 594), f'{book["editor"]}　编', font=F('body', 15), fill=WHITE, anchor='ls')
    d.text((36, 616), book['publisher'], font=F('body', 12), fill=soft, anchor='ls')
    d.text((COVER_W - 36, 616), book['category'], font=F('body', 13), fill=soft, anchor='rs')


def cover_split(book, im, d):
    bg = book['cover_bg']
    soft = mix(bg, WHITE, 0.75)
    src, crop = book['cover_art']
    art_im, _ = fit(art(src), COVER_W, 352, crop)
    im.paste(art_im, (0, 0))
    gradient_overlay(im, (0, 0, COVER_W, 80), (0, 0, 0), 0.45, 0.0)
    d.text((32, 40), '美术之路 · 示例书刊', font=F('body', 14), fill=(240, 240, 240), anchor='ls')
    badge(d, COVER_W - 32, 22, '示例', bg, WHITE)
    d.rectangle([0, 352, COVER_W, COVER_H], fill=bg)
    d.rectangle([32, 352, 92, 358], fill=book['accent_light'])
    y = cover_title(d, 32, 372, book['cover_title'], WHITE, size=40, lh=52)
    d.text((32, baseline(y + 2, 28, F('body', 16))), book['subtitle'], font=F('body', 16), fill=mix(bg, WHITE, 0.85), anchor='ls')
    d.text((32, 596), f'{book["editor"]}　编', font=F('body', 15), fill=WHITE, anchor='ls')
    d.text((32, 618), book['publisher'], font=F('body', 12), fill=soft, anchor='ls')
    d.text((COVER_W - 32, 618), book['category'], font=F('body', 13), fill=soft, anchor='rs')


def cover_paper(book, im, d):
    accent = book['accent']
    d.rectangle([0, 0, COVER_W, COVER_H], fill=(245, 242, 235))
    d.rectangle([0, 0, 14, COVER_H], fill=accent)
    d.text((40, 46), '美术之路 · 示例书刊', font=F('body', 14), fill=SECONDARY, anchor='ls')
    badge(d, COVER_W - 32, 26, '示例', WHITE, accent)
    y = cover_title(d, 40, 70, book['cover_title'], INK)
    d.text((40, baseline(y + 4, 28, F('body', 16))), book['subtitle'], font=F('body', 16), fill=SECONDARY, anchor='ls')
    src, crop = book['cover_art']
    art_im, _ = fit(art(src), 250, 330, crop)
    im.paste(art_im, (COVER_W - 32 - 250, 238))
    d.rectangle([COVER_W - 32 - 250, 238, COVER_W - 33, 567], outline=(214, 210, 200))
    d.rectangle([40, 300, 48, 420], fill=accent)
    for i, word in enumerate(book.get('cover_words', [])):
        d.text((62, 316 + i * 34), word, font=F('bold', 18), fill=INK, anchor='ls')
    d.text((40, 600), f'{book["editor"]}　编', font=F('body', 15), fill=INK, anchor='ls')
    d.text((40, 620), book['publisher'], font=F('body', 12), fill=TERTIARY, anchor='ls')
    d.text((COVER_W - 32, 620), book['category'], font=F('body', 13), fill=TERTIARY, anchor='rs')


def cover_full(book, im, d):
    src, crop = book['cover_art']
    art_im, _ = fit(art(src), COVER_W, COVER_H, crop)
    im.paste(art_im, (0, 0))
    gradient_overlay(im, (0, 0, COVER_W, 110), (0, 0, 0), 0.5, 0.0)
    gradient_overlay(im, (0, 300, COVER_W, COVER_H), book['cover_bg'], 0.0, 0.92)
    d.text((32, 44), '美术之路 · 示例书刊', font=F('body', 14), fill=(236, 236, 236), anchor='ls')
    badge(d, COVER_W - 32, 24, '示例', book['cover_bg'], WHITE)
    y = cover_title(d, 32, 410, book['cover_title'], WHITE, size=42, lh=54)
    d.text((32, baseline(y + 2, 28, F('body', 16))), book['subtitle'], font=F('body', 16), fill=(236, 236, 236), anchor='ls')
    d.text((32, 600), f'{book["editor"]}　编', font=F('body', 15), fill=WHITE, anchor='ls')
    d.text((32, 620), book['publisher'], font=F('body', 12), fill=(214, 214, 214), anchor='ls')
    d.text((COVER_W - 32, 620), book['category'], font=F('body', 13), fill=(214, 214, 214), anchor='rs')


def cover_magazine(book, im, d):
    src, crop = book['cover_art']
    art_im, _ = fit(art(src), COVER_W, COVER_H, crop)
    im.paste(art_im, (0, 0))
    gradient_overlay(im, (0, 0, COVER_W, 200), book['cover_bg'], 0.9, 0.0)
    gradient_overlay(im, (0, 420, COVER_W, COVER_H), (0, 0, 0), 0.0, 0.7)
    fm = F('kai', 68)
    d.text((28, 96), '画室月刊', font=fm, fill=WHITE, anchor='ls', stroke_width=1, stroke_fill=WHITE)
    d.text((30, 130), book['issue'], font=F('bold', 18), fill=WHITE, anchor='ls')
    badge(d, COVER_W - 28, 26, '示例', book['cover_bg'], WHITE)
    y = 452
    for line in book['cover_lines']:
        f = F('bold', 18)
        w = f.getlength(line) + 24
        d.rectangle([28, y, 28 + 6, y + 30], fill=book['accent_light'])
        shade_box(im, (34, y, 34 + w, y + 30), (20, 18, 28), 0.55)
        d.text((46, baseline(y, 30, f)), line, font=f, fill=WHITE, anchor='ls')
        y += 40
    d.text((28, 622), book['publisher'] + ' · 仅供演示', font=F('body', 12), fill=(226, 226, 226), anchor='ls')


COVERS = {
    'frame': cover_frame,
    'split': cover_split,
    'paper': cover_paper,
    'full': cover_full,
    'magazine': cover_magazine,
}


def make_cover(book):
    im = Image.new('RGB', (COVER_W, COVER_H), book['cover_bg'])
    COVERS[book['cover_style']](book, im, ImageDraw.Draw(im))
    return im


# ── 书目与内容 ──────────────────────────────────────────────────────────


def I(src, h=None, caption=None, crop=None, fx=None, points=None, focus=None, w=None):
    spec = {'src': src}
    for key, value in (('h', h), ('caption', caption), ('crop', crop), ('fx', fx),
                       ('points', points), ('focus', focus), ('w', w)):
        if value is not None:
            spec[key] = value
    return spec


BOOKS = [
    dict(
        id='eb-sketch-still',
        title='联考素描静物高分解析（示例）',
        running='联考素描静物高分解析（示例）',
        cover_title=['联考素描静物', '高分解析'],
        subtitle='构图 · 明暗 · 质感 · 空间',
        editor='张明远　李静',
        publisher='示范画室教研组（示例）',
        category='高分范画集',
        accent=(70, 88, 140), cover_bg=(40, 38, 50), cover_style='frame',
        cover_art=('art/sketch-still-1.jpg', (0.04, 0.06, 0.98, 0.94)),
        title_art=('art/sketch-still-1.jpg', (0.02, 0.05, 0.98, 0.95)),
        description='以联考素描静物为线索，按「整体—构图—明暗—透视—步骤—质感—空间」的顺序，'
                    '结合画室范画逐页讲解高分作品的处理方法，并附常见问题与改法。',
        pages=[
            [
                ('chapter', '01', '高分作品的共同点'),
                ('img', I('art/sketch-still-1.jpg', 270, '画室范画《陶罐与水果衬布》', crop=(0, 0.04, 1, 0.96))),
                ('p', '素描静物的高分作品各有面貌，但在阅卷老师眼里，它们往往有几处相同的“底子”：'
                      '画面第一眼就站得住，黑白灰分得开，主体物经得起细看。'),
                ('steps', [
                    '构图：主体突出，组合稳定饱满，四周留空得当。',
                    '造型：比例、透视与结构准确，经得起推敲。',
                    '明暗：三大面、五大调子清楚，层次拉得开。',
                    '质感与空间：材质有区分，前后关系明确。',
                    '完整度：按时完成，整体统一，没有“画花”。',
                ]),
            ],
            [
                ('chapter', '02', '构图：让画面稳定饱满'),
                ('p', '构图决定画面给人的第一印象。动笔前先想清楚：画什么为主、放在哪里、占多大。'),
                ('diagram', 'composition', 200),
                ('bullets', [
                    '大小：物体组合约占画面的三分之二左右，饱满而不拥挤。',
                    '位置：主体物放在视觉中心附近，略偏离正中更生动。',
                    '组合：物体之间有前后遮挡、高低错落，外轮廓连成三角形或不规则多边形。',
                    '留空：上下左右都留出余地，避免物体贴边、顶天立地。',
                ]),
                ('tip', '易错提醒', '物体等距排列、轮廓线相切、主体物被次要物体挡住大半，都会让构图显得呆板或拥挤。'),
            ],
            [
                ('chapter', '03', '明暗：三大面与五大调子'),
                ('p', '物体在光照下呈现出有规律的明暗变化，把握这套规律，画面才有体积感。'),
                ('diagram', 'tones', 290),
                ('bullets', [
                    '三大面：受光的亮面、侧受光的灰面、背光的暗面。',
                    '五大调子：亮面、灰面、明暗交界线、反光、投影；高光是亮面中最亮的点。',
                    '明暗交界线：亮部与暗部的转折地带，不是一条细线，常是物体自身最暗的区域。',
                    '反光：来自桌面、衬布的反射，再亮也要统一在暗部里，不能亮过灰面。',
                ]),
            ],
            [
                ('chapter', '04', '透视：静物里的近大远小'),
                ('p', '瓶罐、盘子和桌面都遵循透视规律。透视错了，明暗画得再细也站不住。'),
                ('diagram', 'perspective', 290),
                ('bullets', [
                    '视平线：画者眼睛的高度。静物多在视平线以下，能看到瓶口与桌面。',
                    '圆形透视：瓶口、瓶底、盘口画成椭圆；离视平线越远，椭圆越宽，所以瓶底比瓶口更圆。',
                    '椭圆两端是圆转的弧线，不要画成尖角；前半弧略实，后半弧略虚。',
                    '方形物体与桌面边线：同一组平行线消失到同一个灭点。',
                ]),
            ],
            [
                ('chapter', '05', '步骤一：起稿与铺大关系'),
                ('imgs', {'h': 200, 'items': [
                    I('art/sketch-still-1.jpg', caption='① 起稿：长直线切出外形', fx='lines', crop=(0.02, 0.05, 0.98, 0.95)),
                    I('art/sketch-still-1.jpg', caption='② 铺大关系：分出黑白灰', fx='values', crop=(0.02, 0.05, 0.98, 0.95)),
                ]}),
                ('h2', '起稿'),
                ('bullets', [
                    '先定上下左右四个边界点，再用长直线切出整组物体的外轮廓。',
                    '画出每个物体的中轴线与椭圆，检查比例、透视和遮挡。',
                    '线条轻、松、准，暂时不画细节，方便修改。',
                ]),
                ('h2', '铺大关系'),
                ('bullets', [
                    '从明暗交界线入手，向暗部铺调子，再画投影。',
                    '分出亮、灰、暗三大层次，背景与衬布同步铺开。',
                    '排线方向跟随形体结构，不在一处反复加深。',
                ]),
            ],
            [
                ('chapter', '06', '步骤二：深入塑造与整体调整'),
                ('img', I('art/sketch-still-1.jpg', 240, '深入局部：陶罐的结构转折与明暗过渡', crop=(0.26, 0.08, 0.6, 0.58))),
                ('h2', '深入塑造'),
                ('bullets', [
                    '从主体物开始，由明暗交界线向两边推进，画出灰面的细微层次。',
                    '刻画结构转折处，如瓶口厚度、瓶肩、水果的窝和柄。',
                ]),
                ('h2', '整体调整'),
                ('bullets', [
                    '退后看整体：主体对比强、刻画充分，次要物体适当概括。',
                    '统一色调：过亮的反光压下去，零碎的高光合并。',
                ]),
                ('tip', '时间提示', '以 3 小时的静物写生为例，深入塑造通常占一半左右的时间，留出 15～20 分钟做整体调整。'),
            ],
            [
                ('chapter', '07', '质感：陶罐、玻璃与衬布'),
                ('p', '同一组静物中往往有几种材质，区分质感的关键在于高光、反光与明暗对比的不同处理。'),
                ('imgs', {'h': 200, 'items': [
                    I('art/sketch-still-3.jpg', caption='玻璃瓶：通透，高光与边线明确', crop=(0.58, 0.04, 0.86, 0.72)),
                    I('art/sketch-still-2.jpg', caption='深色酒瓶：高光锐利、对比强', crop=(0.42, 0.0, 0.66, 0.86)),
                ]}),
                ('table', ['物体', '质感特点', '表现方法'], [
                    ['陶罐', '表面较粗，光泽柔和', '调子均匀扎实，高光不宜过亮'],
                    ['瓷器', '光滑，高光与反光明显', '过渡细腻，高光干净利落'],
                    ['玻璃', '透明，透出背后的景物', '先画透过的形，再提高光与边线'],
                    ['金属', '反射强，明暗对比大', '黑白对比果断，边缘清晰'],
                    ['水果', '圆润，固有色各不相同', '注意窝、柄等结构，调子饱满'],
                    ['衬布', '柔软，褶皱有主有次', '抓大褶皱的转折，小褶皱概括'],
                ], [80, 220, 300]),
            ],
            [
                ('chapter', '08', '空间：前后与虚实'),
                ('img', I('art/sketch-still-2.jpg', 280, '重调子画面：前景物体刻画充分，背景与远处衬布概括处理')),
                ('bullets', [
                    '前实后虚：近处物体对比强、刻画具体，远处对比弱、概括处理。',
                    '主实次虚：主体物刻画充分，次要物体与边角适当减弱。',
                    '边缘：转向背面、与背景明暗接近的边缘宜虚，对比强处宜实。',
                ]),
                ('tip', '自查方法', '眯起眼睛看画面：如果前后物体一样清楚、一样黑，说明空间还没有拉开。'),
            ],
            [
                ('chapter', '09', '对照：一张范画的六个细节'),
                ('img', I('art/sketch-still-1.jpg', 330, crop=(0.02, 0.06, 0.98, 0.94), points=[
                    (0.42, 0.13), (0.55, 0.36), (0.68, 0.52), (0.24, 0.56), (0.46, 0.75), (0.8, 0.66),
                ])),
                ('steps', [
                    '瓶口椭圆透视准确，口沿厚度交代清楚。',
                    '陶罐明暗交界线肯定，暗部透气不发闷。',
                    '梨的体积饱满，与苹果的质感有区分。',
                    '两个苹果大小、前后有变化，避免雷同。',
                    '衬布褶皱有主有次，穿插关系清楚。',
                    '投影近实远虚，物体稳稳地“坐”在衬布上。',
                ]),
            ],
            [
                ('chapter', '附', '常见问题与改法'),
                ('table', ['问题', '常见原因', '改法'], [
                    ['画面发灰', '黑白灰层次少，暗部不敢加深', '先加重明暗交界线与投影，拉开亮暗对比'],
                    ['画面发花', '局部对比太多，高光反光零碎', '合并小块调子，减弱次要物体的对比'],
                    ['构图偏小', '起稿时没有先定边界点', '先定四个边界点，物体约占画面三分之二'],
                    ['透视错误', '椭圆、桌面边线没有统一', '对照视平线检查椭圆宽窄与灭点'],
                    ['物体发飘', '投影与接触面处理太弱', '加强物体与台面接触处的暗部和投影'],
                    ['质感雷同', '每个物体都用同一种排线', '按材质调整高光、反光与对比强弱'],
                ], [96, 230, 274]),
                ('tip', '练习建议', '每次作业完成后，对照这张表圈出一个主要问题，下一张作业专门解决它。'),
            ],
        ],
    ),
    dict(
        id='eb-color-warmcool',
        title='色彩静物冷暖关系 30 讲（示例）',
        running='色彩静物冷暖关系 30 讲（示例）',
        cover_title=['色彩静物', '冷暖关系 30 讲'],
        subtitle='光源色 · 固有色 · 环境色',
        editor='刘芳',
        publisher='示范画室教研组（示例）',
        category='色彩教程',
        accent=(36, 86, 156), accent_light=(242, 150, 60), cover_bg=(26, 50, 96), cover_style='split',
        cover_art=('art/color-still-1.jpg', (0.0, 0.0, 1.0, 1.0)),
        title_art=('art/color-still-1.jpg', (0.05, 0.1, 0.95, 0.95)),
        description='从色彩三要素、色相环讲起，逐步讲清光源色、固有色、环境色与冷暖关系，'
                    '配合静物范画对照练习。',
        excerpt='本书正式内容共 30 讲，示例书刊仅收录其中 8 讲，用于功能演示。',
        pages=[
            [
                ('chapter', '第 1 讲', '色彩三要素：色相、明度、纯度'),
                ('p', '描述一块颜色，可以从三个方面入手：它是什么颜色（色相）、有多亮（明度）、有多鲜艳（纯度）。'),
                ('diagram', 'color_strips', 280),
                ('bullets', [
                    '色相：颜色的相貌，如红、橙、黄、绿、蓝、紫。',
                    '明度：颜色的明暗程度。同一色相加白变亮、加深色变暗；黄色明度高，紫色明度低。',
                    '纯度：颜色的鲜艳程度。加入灰色、黑白或补色，纯度都会降低。',
                ]),
            ],
            [
                ('chapter', '第 2 讲', '色相环与补色'),
                ('diagram', 'wheel', 320),
                ('bullets', [
                    '互补色：色相环上相对的两色，如红与绿、黄与紫、蓝与橙，并置时对比强烈。',
                    '对比色：相距约 120° 的颜色，如红与黄、黄与蓝，对比鲜明。',
                    '邻近色：相距较近的颜色，如黄与橙，组合起来和谐统一。',
                    '少量补色可以降低纯度，调出有倾向的灰；补色等量混合则容易变脏。',
                ]),
            ],
            [
                ('chapter', '第 3 讲', '物体的颜色从哪里来'),
                ('img', I('art/color-still-1.jpg', 260, '白盘与水果：亮部受光源色影响，暗部与盘中可见周围物体的环境色',
                          crop=(0.3, 0.36, 0.86, 0.84))),
                ('bullets', [
                    '固有色：物体在白光下呈现的本来颜色，在灰面最容易看到。',
                    '光源色：光的颜色，主要影响亮部与高光。',
                    '环境色：周围物体反射过来的颜色，在暗部、反光和光滑物体上更明显。',
                ]),
                ('p', '画面里的每一块颜色，都是这三种因素共同作用的结果。写生时不要只画“苹果是红的”，'
                      '而要观察它在亮部、灰面、暗部分别偏向什么颜色。'),
            ],
            [
                ('chapter', '第 4 讲', '冷暖是比较出来的'),
                ('diagram', 'warm_cool', 270),
                ('bullets', [
                    '冷暖是相对的：柠檬黄比中黄偏冷，玫瑰红比朱红偏冷。',
                    '暖光下，亮部偏暖、暗部相对偏冷；冷光下，亮部偏冷、暗部相对偏暖。',
                    '画室的北窗天光多偏冷，静物常呈现亮部偏冷、暗部偏暖的关系。',
                    '判断冷暖时把两块颜色放在一起比较，而不是孤立地看一块颜色。',
                ]),
            ],
            [
                ('chapter', '第 5 讲', '环境色：白布与陶罐的暗部'),
                ('imgs', {'h': 220, 'items': [
                    I('art/color-still-4.jpg', caption='蓝紫背景下，白布暗部带有冷色倾向', crop=(0.45, 0.0, 1.0, 0.62)),
                    I('art/color-still-1.jpg', caption='陶罐暗部融入背景与衬布的颜色', crop=(0.05, 0.08, 0.45, 0.66)),
                ]}),
                ('bullets', [
                    '浅色、光滑的物体受环境色影响大，白布、白瓷盘、玻璃尤其明显。',
                    '暗部与反光处最容易看到环境色，如蓝衬布映在白盘底部的蓝灰。',
                    '投影的颜色受桌面颜色与光源共同影响，不要一律用黑色或深灰。',
                    '环境色是微妙的倾向，画得过纯过重，物体反而失去固有色。',
                ]),
            ],
            [
                ('chapter', '第 6 讲', '色调：先定调子再画细节'),
                ('imgs', {'h': 160, 'cols': 2, 'items': [
                    I('art/color-still-2.jpg', caption='暖调：黄橙背景统一画面'),
                    I('art/color-still-4.jpg', caption='冷调：蓝紫环境中的橙色水果'),
                    I('art/color-still-3.jpg', caption='灰调：低纯度色彩的和谐'),
                    I('art/color-still-5.jpg', caption='亮调：浅背景，画面明快'),
                ]}),
                ('bullets', [
                    '色调是画面整体的色彩倾向，可从冷暖、明度、纯度上描述，如暖灰调、冷亮调。',
                    '起稿后先铺大色块，确定主色调，细节服从整体。',
                    '小面积的对比色可作点缀，让画面统一而不单调。',
                ]),
            ],
            [
                ('chapter', '第 7 讲', '写生步骤与冷暖控制'),
                ('imgs', {'h': 150, 'items': [
                    I('art/color-still-1.jpg', caption='① 铺大色块', fx='blocks'),
                    I('art/color-still-1.jpg', caption='② 塑造形体', fx='shaping'),
                    I('art/color-still-1.jpg', caption='③ 深入调整'),
                ]}),
                ('steps', [
                    '起稿：用单色（如群青或熟褐）简洁地勾出构图与形体。',
                    '铺大色块：从暗部或背景入手，大笔铺色，确定冷暖与明度关系。',
                    '塑造形体：由主体物开始，画出亮部、灰面、暗部的色彩变化。',
                    '深入调整：刻画高光、边缘与质感，最后回到整体，统一色调。',
                ]),
                ('tip', '水粉小提示', '水粉颜色湿时深、干后变浅，铺色时可略深一些；调色时颜色种类不宜过多，一般不超过三种，以免变脏。'),
            ],
            [
                ('chapter', '第 8 讲', '常见问题：粉、脏、灰、花'),
                ('table', ['问题', '表现', '原因', '改法'], [
                    ['粉', '颜色发白、缺少纯度', '提亮只靠加白', '借助浅色相提亮，暗部少用白'],
                    ['脏', '颜色浑浊、发黑', '调色次数多、补色乱混', '调色不超过三种，及时换水'],
                    ['灰', '画面没精神', '明度、纯度对比不足', '拉开主体的明暗与冷暖对比'],
                    ['花', '颜色跳、不统一', '局部对比过多', '统一色调，减弱次要物体'],
                ], [60, 150, 170, 220]),
                ('p', '这四类问题常常同时出现。改画时先解决整体（灰、花），再处理局部（粉、脏）。'),
                ('tip', '本讲小结', '冷暖关系不是背出来的，而是比较出来的。写生时多问自己：这块颜色和旁边相比，偏冷还是偏暖？'),
                ('img', I('art/detail-color.jpg', 170, '橙子局部：亮部暖黄、暗部橙红，盘中投影偏蓝灰', crop=(0.0, 0.1, 1.0, 0.9))),
            ],
        ],
    ),
    dict(
        id='eb-speed-figure',
        title='人物速写动态与比例（示例）',
        running='人物速写动态与比例（示例）',
        cover_title=['人物速写', '动态与比例'],
        subtitle='动态线 · 重心 · 比例 · 衣纹',
        cover_words=['动态线', '重心线', '站七坐五盘三半'],
        editor='何佳　高峰',
        publisher='示范画室教研组（示例）',
        category='速写教程',
        accent=(22, 118, 138), cover_bg=(245, 242, 235), cover_style='paper',
        cover_art=('art/speed-figure-1.jpg', (0.12, 0.0, 0.88, 1.0)),
        title_art=('art/speed-figure-3.jpg', (0.0, 0.05, 1.0, 0.95)),
        description='以动态线、重心线和「站七坐五盘三半」为主线，讲解单人速写的观察方法、'
                    '比例、体块、衣纹与线条组织。',
        pages=[
            [
                ('chapter', '01', '速写的观察方法'),
                ('side', I('art/speed-figure-1.jpg', caption='单人站姿速写（画室范画）', crop=(0.12, 0.0, 0.88, 1.0), w=230, h=330), [
                    ('p', '速写要在短时间内抓住人物的整体特征，观察时由整体到局部：'),
                    ('steps', [
                        '先看动势：人物在做什么，身体朝哪个方向倾斜或扭转。',
                        '再看比例：头、躯干、四肢的长短关系，重心落在哪里。',
                        '最后看细节：手、脚、五官与衣纹，只选关键处表现。',
                    ]),
                ]),
                ('p', '初学者常从头部开始一点点往下画，结果人物越画越长、比例失调。'
                      '先用几根线定出整体动态，再分体块深入，是更稳妥的方法。'),
                ('tip', '练习建议', '每天安排 10～15 分钟的单人慢写和 2～3 分钟的动态快写，长短结合。'),
            ],
            [
                ('chapter', '02', '动态线与重心线'),
                ('diagram', 'mannequin', 400),
                ('bullets', [
                    '动态线：贯穿头部、躯干到支撑腿的一条主线，概括人物的整体动势。',
                    '重心线：从颈窝向地面作的垂直线。站立时它应落在支撑脚上或两脚之间，人物才站得稳。',
                    '一条腿支撑身体时，支撑腿一侧的胯部抬高、肩部相对降低。',
                ]),
            ],
            [
                ('chapter', '03', '比例口诀：站七坐五盘三半'),
                ('diagram', 'proportions', 390),
                ('p', '以头长为单位：成年人站立约 7 个头长，坐在椅子上约 5 个头长，盘腿坐约 3.5 个头长。'
                      '口诀是快速检查比例的“尺子”，具体还要结合人物的年龄、体型与透视。'),
                ('tip', '注意', '透视会改变比例：俯视、仰视或肢体朝向画者时，要按实际看到的长度画。'),
            ],
            [
                ('chapter', '04', '比例的细节'),
                ('table', ['部位', '参考比例（约）'], [
                    ['人体中点', '站立时约在耻骨（大腿根）附近'],
                    ['肘关节', '手臂自然下垂时约与腰部（肚脐附近）平齐'],
                    ['腕关节', '约与大腿根部平齐'],
                    ['中指指尖', '约到大腿中部'],
                    ['手的长度', '约等于脸长（发际线到下巴），即“一手一脸”'],
                    ['肩宽', '男性约两个头长，女性略窄'],
                    ['膝关节', '约在大腿根到脚底的中点附近'],
                ], [130, 470]),
                ('p', '参考比例是帮助观察的工具，不要机械套用。写生时用笔杆比量，先比大关系，再比小关系。'),
                ('imgs', {'h': 200, 'items': [
                    I('art/speed-figure-2.jpg', caption='坐姿：大腿有透视缩短', crop=(0.1, 0.05, 0.9, 0.95)),
                    I('art/speed-figure-5.jpg', caption='蹲姿：肢体折叠，比例变化大', crop=(0.08, 0.05, 0.92, 0.95)),
                ]}),
            ],
            [
                ('chapter', '05', '三大体块：头、胸腔、骨盆'),
                ('diagram', 'blocks', 300),
                ('bullets', [
                    '把人体概括为头部、胸腔、骨盆三个体块，用脊柱把它们连起来。',
                    '体块之间的倾斜、扭转与前后关系，决定了人物的动态。',
                    '胸腔与骨盆之间是腰部，转动、弯曲多发生在这里，衣纹也常在此聚集。',
                    '蹲、坐、弯腰时体块会产生透视缩短，要按看到的实际长度画。',
                ]),
            ],
            [
                ('chapter', '06', '衣纹：画在结构转折处'),
                ('side', I('art/speed-figure-2.jpg', caption='坐姿读书：衣纹集中在肘、膝与腰部', crop=(0.1, 0.02, 0.9, 0.98), w=230, h=320), [
                    ('bullets', [
                        '衣纹产生于关节和受力处：肘、膝、腋下、腰部、裆部最集中。',
                        '挤压纹：关节弯曲处布料堆积形成，线条短而密。',
                        '拉伸纹：布料被拉紧时形成，从受力点向外伸展。',
                        '悬垂纹：布料自然下垂形成，线条长而顺。',
                    ]),
                ]),
                ('p', '画衣纹前先确认衣服下面的身体结构：肩点、肘点、膝点、胯点决定了衣纹从哪里出发、往哪里走。'),
                ('tip', '取舍', '衣纹不是越多越好。只保留说明结构和动态的关键衣纹，其余概括或省略。'),
            ],
            [
                ('chapter', '07', '单人速写步骤'),
                ('imgs', {'h': 230, 'items': [
                    {'draw': 'mannequin', 'args': {'labels': False}, 'caption': '① 动态与体块'},
                    I('art/speed-figure-1.jpg', caption='② 外形与衣纹', fx='fade', crop=(0.12, 0.0, 0.88, 1.0)),
                    I('art/speed-figure-1.jpg', caption='③ 调整完成', crop=(0.12, 0.0, 0.88, 1.0)),
                ]}),
                ('steps', [
                    '定动态：画出动态线与重心线，标出头、肩、胯、膝、脚的位置。',
                    '画体块：用简单的形概括头、胸腔、骨盆，连接四肢。',
                    '画外形与衣纹：从上到下画出轮廓，抓住关节处的关键衣纹。',
                    '调整：加重主要转折与暗部，减弱次要线条，检查比例。',
                ]),
                ('tip', '时间分配', '以 15 分钟单人速写为例：动态与体块约 3 分钟，外形与衣纹约 9 分钟，调整约 3 分钟。'),
            ],
            [
                ('chapter', '08', '线条与黑白：让画面有节奏'),
                ('imgs', {'h': 250, 'items': [
                    I('art/speed-figure-5.jpg', caption='重色压在头发、鞋与暗部，画面结实', crop=(0.08, 0.04, 0.92, 0.96)),
                    I('art/speed-figure-3.jpg', caption='双人组合：线条疏密衬托主体', crop=(0.1, 0.05, 0.62, 0.95)),
                ]}),
                ('bullets', [
                    '长线概括：躯干、四肢的大轮廓尽量用长线，一气呵成。',
                    '疏密对比：关节与衣纹聚集处线条密，平整处线条疏。',
                    '虚实变化：受光一侧线条轻，背光与转折处线条重。',
                    '黑白布局：重色集中在头发、鞋子和主要暗部，面积不宜平均。',
                ]),
            ],
        ],
    ),
    dict(
        id='eb-cast-head',
        title='石膏头像结构入门（示例）',
        running='石膏头像结构入门（示例）',
        cover_title=['石膏头像', '结构入门'],
        subtitle='三庭五眼 · 骨点 · 体块 · 明暗',
        editor='王海波',
        publisher='示范画室教研组（示例）',
        category='素描教程',
        accent=(132, 88, 52), cover_bg=(74, 58, 46), cover_style='frame',
        cover_art=('art/sketch-bust-1.jpg', (0.1, 0.08, 0.9, 0.62)),
        title_art=('art/sketch-bust-3.jpg', (0.05, 0.05, 0.95, 0.75)),
        description='从常见石膏像入手，讲解三庭五眼、五官位置、头部体块与骨点，'
                    '并按起稿—铺明暗—深入调整的步骤完成一张石膏头像。',
        pages=[
            [
                ('chapter', '01', '认识常见石膏像'),
                ('imgs', {'h': 230, 'items': [
                    I('art/sketch-bust-1.jpg', caption='大卫', crop=(0.1, 0.08, 0.9, 0.9)),
                    I('art/sketch-bust-2.jpg', caption='荷马', crop=(0.05, 0.04, 0.95, 0.9)),
                    I('art/sketch-bust-3.jpg', caption='维纳斯', crop=(0.05, 0.04, 0.95, 0.9)),
                ]}),
                ('p', '画室常用的石膏像多翻制自古希腊、古罗马与文艺复兴时期的雕塑。'
                      '它们形体概括、结构明确，是学习头部结构的“标准教具”。'),
                ('bullets', [
                    '入门可从结构清楚的维纳斯、小卫等头像开始，再过渡到大卫、荷马等起伏丰富的头像。',
                    '四分之三侧面能同时看到正面与侧面，更能体现体块转折。',
                    '光线以侧上方单一光源为宜，明暗交界线清楚，便于理解结构。',
                ]),
            ],
            [
                ('chapter', '02', '三庭五眼'),
                ('diagram', 'face', 420),
                ('bullets', [
                    '三庭：发际线到眉弓、眉弓到鼻底、鼻底到下巴，三段长度大致相等。',
                    '五眼：在眼睛所在的水平线上，脸宽约等于五只眼的宽度，两眼之间约一只眼宽。',
                    '眼睛约在头顶到下巴的二分之一处，初学者常把眼睛画得偏高。',
                ]),
            ],
            [
                ('chapter', '03', '五官的位置关系'),
                ('bullets', [
                    '耳朵：上缘约与眉弓平齐，下缘约与鼻底平齐。',
                    '鼻翼：两侧鼻翼的宽度约等于两眼内眼角之间的距离。',
                    '嘴：口缝约在鼻底到下巴的上三分之一处，嘴角约在瞳孔向下的垂线附近。',
                    '眉弓：额骨在眉毛处的隆起，侧光下会形成明显的明暗转折。',
                ]),
                ('img', I('art/sketch-portrait-1.jpg', 250, '四分之三侧面：远侧的眼睛与嘴角因透视而变短', crop=(0.12, 0.08, 0.88, 0.62))),
                ('tip', '比较法', '用笔杆比量时，先比“三庭”这样的大长度，再比五官之间的小距离，最后检查左右是否对称。'),
            ],
            [
                ('chapter', '04', '头部的体块与透视'),
                ('diagram', 'head_turns', 250),
                ('bullets', [
                    '头部可以概括成一个立方体：正面、侧面、顶面、底面，转折处就是骨点所在。',
                    '面部中线（眉心、鼻梁、人中、下巴的连线）随头部转动而移动，是判断角度的依据。',
                    '抬头（仰视）时，眉、眼、鼻底、嘴的连线呈向上拱起的弧线，耳朵位置相对下移；低头时相反。',
                    '离画者远的一侧形体会缩短，五官也随之变窄。',
                ]),
            ],
            [
                ('chapter', '05', '骨点与结构'),
                ('img', I('art/sketch-bust-1.jpg', 360, crop=(0.1, 0.24, 0.87, 0.62), points=[
                    (0.41, 0.305), (0.455, 0.385), (0.36, 0.405), (0.37, 0.505), (0.565, 0.475), (0.56, 0.56),
                ])),
                ('steps', [
                    '眉弓：额骨在眉毛处的隆起，决定眼窝的深度。',
                    '颧骨：面部正面与侧面的转折点。',
                    '鼻底：鼻头与鼻翼形成的底面，常处在暗部。',
                    '颏隆凸：下巴前端的突起，决定下巴的体积。',
                    '下颌角：下颌骨的转角，连接面部与颈部。',
                    '胸锁乳突肌：从耳后斜向颈窝，头部转动时清晰可见。',
                ]),
            ],
            [
                ('chapter', '06', '起稿：长直线切形'),
                ('side', I('art/sketch-bust-1.jpg', caption='起稿阶段：只用线条确定比例与结构', fx='lines', crop=(0.1, 0.08, 0.9, 0.92), w=250, h=340), [
                    ('steps', [
                        '定位置：确定头顶、下巴与左右最宽点，头像略偏上，留出颈部与胸像的空间。',
                        '切大形：用长直线切出外轮廓，注意头、颈、胸的转向。',
                        '找中线：画出面部中线与眉、眼、鼻底、嘴的横向辅助线。',
                        '定五官：按三庭五眼确定位置，用短直线概括形状。',
                    ]),
                ]),
                ('tip', '线条', '起稿线条要轻，以方代圆、以直代曲，不急于画出圆润的轮廓。'),
                ('p', '起稿阶段多花几分钟检查比例，比后期在明暗上反复修改省时得多。'),
            ],
            [
                ('chapter', '07', '铺明暗：从交界线开始'),
                ('side', I('art/sketch-bust-1.jpg', caption='铺大关系：亮、灰、暗三个层次', fx='values', crop=(0.1, 0.08, 0.9, 0.92), w=250, h=340), [
                    ('steps', [
                        '找交界线：沿额头、眉弓、颧骨、下颌一线，把亮部与暗部分开。',
                        '铺暗部：先统一铺出暗部与投影，暂时不画反光。',
                        '分灰面：在亮部找出转向暗部的灰面，形成三大层次。',
                        '背景同步：根据需要铺出背景，衬托头像的轮廓。',
                    ]),
                ], 'right'),
                ('p', '这一步追求的是整体的黑白灰关系。大关系对了，后面的深入就有了依据。'),
                ('tip', '提醒', '暗部的调子要统一，不要过早画出反光和细节，否则画面容易“花”。'),
            ],
            [
                ('chapter', '08', '深入与调整'),
                ('img', I('art/sketch-bust-2.jpg', 290, '荷马像局部：胡须与头发按体块成组刻画', crop=(0.12, 0.1, 0.88, 0.66))),
                ('bullets', [
                    '五官深入：眼睛先画上眼睑与眼窝的结构，鼻子抓住鼻底与鼻翼，嘴巴抓住口缝与嘴角。',
                    '头发、胡须：按大的体块分组，先画暗部，再画受光的卷曲。',
                    '整体调整：五官的对比不能超过头部大的明暗关系。',
                ]),
                ('tip', '自查', '把画放远看：头部的体积是否成立？中线是否通顺？局部抢眼就适当减弱。'),
            ],
        ],
    ),
    dict(
        id='eb-exam-sketch',
        title='联考真题与评分要点·素描（示例）',
        running='联考真题与评分要点·素描（示例）',
        cover_title=['联考素描', '真题与评分要点'],
        subtitle='示例命题 · 评分维度 · 档次对照',
        editor='陈立　张明远',
        publisher='示范画室教研组（示例）',
        category='联考真题解析',
        accent=(84, 66, 176), accent_light=(255, 196, 70), cover_bg=(44, 34, 96), cover_style='split',
        cover_art=('scene/exam-hall.jpg', (0.1, 0.0, 0.8, 1.0)),
        title_art=('scene/exam-hall.jpg', (0.0, 0.05, 1.0, 1.0)),
        description='以示例命题为例，梳理素描评分的主要维度与 A–E 档次特征，附档次对照、'
                    '考场时间分配与考前自查清单。书中命题均为示例，非真实考题。',
        pages=[
            [
                ('chapter', '01', '读懂考试说明'),
                ('img', I('scene/exam-hall.jpg', 240, '考场示意（示例图片）')),
                ('p', '各省每年都会公布美术类专业统考的考试说明。备考的第一步，是把考试说明逐条读懂。'),
                ('bullets', [
                    '考试内容：考哪些科目，素描考静物、头像还是其他内容。',
                    '考试形式：写生、默写或看照片作画。',
                    '时间与分值：每科的时长与满分，决定练习时的时间分配。',
                ]),
                ('tip', '说明', '本书命题均为示例，非任何地区的真实考题。考试内容与要求以本省当年公布的考试说明为准。'),
            ],
            [
                ('chapter', '02', '示例命题一：素描静物'),
                ('question', '示例命题（非真题）', '根据提供的物体组合完成一幅素描静物写生：陶罐一个、玻璃瓶一个、苹果两个、'
                                          '白色衬布一块。要求构图完整，表现出物体的结构、体积、空间与质感，画面整洁。'
                                          '（示例：4 开素描纸，3 小时）'),
                ('img', I('art/sketch-still-3.jpg', 250, '参考作答（画室学员作业）')),
                ('h2', '审题要点'),
                ('bullets', [
                    '数清物体：四类物体一个不能少，衬布的大小与走向可自行安排。',
                    '找出主体：陶罐体量大，适合作主体，玻璃瓶与之形成质感对比。',
                ]),
            ],
            [
                ('chapter', '03', '示例命题二：人物头像'),
                ('question', '示例命题（非真题）', '根据提供的照片，完成一幅青年女性头像素描。要求比例结构准确，'
                                          '形象特征鲜明，明暗关系清楚，表现完整。（示例：4 开素描纸，3 小时）'),
                ('side', I('art/sketch-portrait-1.jpg', caption='参考作答（画室范画）', crop=(0.08, 0.04, 0.92, 0.9), w=230, h=320), [
                    ('bullets', [
                        '抓特征：脸型、五官与发型的特点，是“画得像”的关键。',
                        '定角度：注意中线与远侧五官的透视缩短。',
                        '控明暗：照片暗部常偏黑，作画时要保留暗部层次。',
                        '处理头发：按体块概括，与脸部形成虚实对比。',
                    ]),
                ]),
            ],
            [
                ('chapter', '04', '评分维度一：构图与造型'),
                ('p', '阅卷时通常从几个维度综合评价一张试卷。各地细则表述不同，但关注点大体一致。'),
                ('diagram', 'composition', 180),
                ('h2', '构图'),
                ('bullets', ['画面完整，物体大小适中，主次关系明确；组合有变化，避免过大、过小、过偏。']),
                ('h2', '造型'),
                ('bullets', [
                    '比例准确：物体之间的高宽、大小关系正确。',
                    '透视正确：椭圆、桌面边线与视平线统一。',
                    '结构清楚：形体转折明确，物体“立”得住。',
                ]),
            ],
            [
                ('chapter', '05', '评分维度二：明暗、体积与空间'),
                ('diagram', 'values', 130),
                ('bullets', [
                    '黑白灰层次：画面有明确的亮、灰、暗层次，而不是一片灰或只有黑白。',
                    '体积感：明暗交界线与反光处理得当，物体有厚度。',
                    '空间感：前后物体的对比与虚实有区别，背景与物体拉得开。',
                ]),
                ('img', I('art/sketch-still-2.jpg', 250, '重调子画面同样需要清楚的层次：暗部之中仍有深浅变化')),
            ],
            [
                ('chapter', '06', '评分维度三：质感、刻画与完整度'),
                ('imgs', {'h': 220, 'items': [
                    I('art/detail-sketch.jpg', caption='局部刻画：眼睛的结构与层次', crop=(0.0, 0.12, 1.0, 0.88)),
                    I('art/sketch-still-3.jpg', caption='质感对比：陶罐与玻璃瓶', crop=(0.45, 0.05, 0.95, 0.8)),
                ]}),
                ('bullets', [
                    '质感：玻璃的通透、陶罐的厚重、衬布的柔软各有表现。',
                    '刻画：主体物与视觉中心刻画深入，细节服从整体。',
                    '完整度：在规定时间内完成，没有明显未画完的区域。',
                    '卷面：画面整洁，没有破损与大面积擦痕。',
                ]),
            ],
            [
                ('chapter', '07', 'A–E 档次特征'),
                ('p', '以满分 100 分、按 90%、80%、70%、60% 划分档次为例（各地档次划分与分值以当年评分细则为准）：'),
                ('table', ['档次', '分数段', '特征'], [
                    ['A', '90–100', '构图饱满完整，形体结构准确，明暗层次丰富，空间感与质感表现突出，画面整体生动。'],
                    ['B', '80–89.5', '构图合理，形体比例基本准确，明暗关系清楚，有一定空间感，局部刻画略欠深入。'],
                    ['C', '70–79.5', '构图基本完整，形体比例有偏差，明暗层次较少，画面略显平淡。'],
                    ['D', '60–69.5', '构图欠完整，形体结构问题较多，明暗关系混乱，刻画不充分。'],
                    ['E', '0–59.5', '未完成作答，或基本造型能力明显不足。'],
                ], [64, 104, 432]),
                ('tip', '读档次的方法', '相邻两档的差别往往只在一两个维度上。对照自己的作业，找出离上一档还差的那一项。'),
            ],
            [
                ('chapter', '08', '档次对照：差在哪里'),
                ('imgs', {'h': 200, 'items': [
                    I('art/sketch-still-1.jpg', caption='原作：层次清楚，主体突出'),
                    I('art/sketch-still-1.jpg', caption='模拟：降低明暗对比后，画面发灰', fx='flat'),
                ]}),
                ('p', '右图由左图降低明暗对比模拟而成，仅用于说明“画面发灰”的问题。可以看到：'),
                ('bullets', [
                    '明暗交界线与投影变浅后，物体的体积感明显减弱。',
                    '主体物与背景、衬布的对比接近，空间被“压平”。',
                    '同样的构图与造型，仅明暗层次一项就会影响档次。',
                ]),
                ('tip', '对照练习', '把自己的作业拍照转成黑白，与范画并排比较，更容易发现层次上的差距。'),
            ],
            [
                ('chapter', '09', '考场时间分配'),
                ('p', '以 3 小时素描静物为例的参考分配（请按考试说明的实际时长调整）：'),
                ('table', ['阶段', '参考时长', '要做的事'], [
                    ['构图起稿', '20～30 分钟', '定边界点，切外形，校对比例与透视'],
                    ['铺大关系', '30～40 分钟', '交界线、暗部、投影，分出黑白灰'],
                    ['深入塑造', '约 90 分钟', '由主体到次要，刻画结构与质感'],
                    ['整体调整', '15～20 分钟', '统一色调，加强主体，检查完整度'],
                ], [110, 130, 360]),
                ('bullets', [
                    '每个阶段结束时退后看一眼整体，再进入下一阶段。',
                    '不在某一个局部停留过久，先保证画面整体完成。',
                    '收尾的十分钟不再开新的局部，只做减法和统一。',
                ]),
                ('tip', '考前演练', '考前用示例命题按考试时长完整练几次，熟悉自己的节奏。'),
            ],
            [
                ('chapter', '10', '常见失分点与考前自查'),
                ('h2', '常见失分点'),
                ('bullets', [
                    '构图过大、过小或偏向一侧，画面不完整。',
                    '比例、透视错误，椭圆与桌面边线不统一。',
                    '画面发灰或发花，黑白灰层次不清。',
                    '局部刻画过多，整体关系松散。',
                    '时间分配不当，画面没有完成。',
                    '卷面脏乱，或留下与作答无关的标记。',
                ]),
                ('h2', '考前自查清单'),
                ('checks', [
                    '能在 30 分钟内完成一张构图准确的起稿。',
                    '清楚自己经常出现的两个问题，并有对应的改法。',
                    '按考试时长完整模拟过，并能按时完成。',
                    '熟悉考试说明中的纸张、工具与考场要求。',
                ]),
            ],
        ],
    ),
    dict(
        id='eb-academy-works',
        title='美院校考作品集选编（示例）',
        running='美院校考作品集选编（示例）',
        cover_title=['美院校考', '作品集选编'],
        subtitle='素描 · 色彩 · 速写 · 创作',
        editor='赵雪　朱琳',
        publisher='示范画室教研组（示例）',
        category='美院校考',
        accent=(36, 104, 78), cover_bg=(20, 46, 36), cover_style='full',
        cover_art=('scene/studio-wall.jpg', (0.3, 0.0, 0.85, 1.0)),
        title_art=('scene/studio-wall.jpg', (0.15, 0.0, 1.0, 1.0)),
        description='选编画室学员校考方向的素描、色彩、速写与创作练习作品，逐幅附点评，'
                    '并整理作品集的整理建议。',
        pages=[
            [
                ('chapter', '01', '校考与联考有什么不同'),
                ('img', I('scene/studio-wall.jpg', 230, '画室作品墙（示例图片）')),
                ('bullets', [
                    '组织方式：联考由省级招生考试机构统一组织；校考由招生院校自主命题、组织。',
                    '考查科目：除素描、色彩、速写外，部分院校或专业还会考查创作、设计等。',
                    '评价侧重：在扎实造型的基础上，更关注个人的观察与表达。',
                    '政策变化：组织校考的院校与专业范围近年有所调整，以当年官方发布为准。',
                ]),
                ('tip', '提示', '本书作品为画室示例图片，点评用于说明校考方向的练习要点。'),
            ],
            [
                ('chapter', '02', '素描 · 长期头像'),
                ('img', I('art/sketch-bust-2.jpg', 400, '荷马石膏像 · 长期作业（画室范画）', crop=(0.06, 0.04, 0.94, 0.78))),
                ('h2', '点评'),
                ('bullets', [
                    '整体色调沉稳，黑白灰层次丰富而统一。',
                    '胡须与卷发按体块成组刻画，疏密有节奏，不琐碎。',
                    '额头横纹、眉弓与颧骨的起伏刻画细致，结构清楚。',
                ]),
            ],
            [
                ('chapter', '03', '素描 · 人物头像'),
                ('side', I('art/sketch-portrait-1.jpg', caption='女青年头像 · 四分之三侧面（画室范画）', crop=(0.06, 0.02, 0.94, 0.98), w=270, h=360), [
                    ('h2', '点评'),
                    ('bullets', [
                        '头部转向与颈部动势协调，中线与五官透视统一。',
                        '鼻梁、眼窝、颧骨的结构转折交代清楚。',
                        '背景局部压暗衬托受光面，主次分明。',
                        '发丝按体块组织，边缘虚实变化丰富。',
                    ]),
                ]),
                ('p', '人物头像在校考中较为常见。与石膏像相比，真人头像更需要表现人物的神态与特征，而不仅是结构。'),
                ('tip', '练习要点', '多画不同年龄、性别与脸型的模特，积累对形象特征的敏感度。'),
            ],
            [
                ('chapter', '04', '色彩 · 静物'),
                ('img', I('art/color-still-4.jpg', 290, '蓝调静物 · 冷色背景（画室范画）')),
                ('h2', '点评'),
                ('bullets', [
                    '蓝紫背景营造冷调，橙色水果形成补色对比，视觉中心明确。',
                    '陶罐暗部融入环境色，物体之间关系自然。',
                    '白衬布亮部笔触概括大胆，暗部冷暖变化丰富。',
                ]),
                ('tip', '练习要点', '同一组静物尝试冷调、暖调、灰调三种画法，锻炼对色调的控制。'),
            ],
            [
                ('chapter', '05', '色彩 · 风景'),
                ('img', I('art/color-landscape-1.jpg', 320, '秋日村落 · 白杨与远山（画室范画）')),
                ('h2', '点评'),
                ('bullets', [
                    '近景土墙暖黄、远山蓝紫，用冷暖拉开大空间。',
                    '白杨树高低错落，构图有节奏。',
                    '天空笔触松动，与地面形成虚实对比。',
                ]),
                ('tip', '练习要点', '风景写生先定天、地、景物三大色块的关系，再画细节。'),
            ],
            [
                ('chapter', '06', '速写 · 组合与场景'),
                ('imgs', {'h': 210, 'items': [
                    I('art/speed-scene-1.jpg', caption='老街集市 · 场景速写（画室范画）'),
                    I('art/speed-group-1.jpg', caption='课间 · 教室三人场景（画室范画）'),
                ]}),
                ('h2', '点评'),
                ('bullets', [
                    '场景速写：一点透视的街道纵深感强，人物大小随距离变化，近景充分、远景概括。',
                    '组合速写：三人姿态各异，课桌椅透视统一，人物与环境比例协调。',
                ]),
                ('p', '场景类题目考查的不仅是单个人物的造型，更是画面的组织能力：谁是主体、谁是陪衬、空间如何展开。'),
            ],
            [
                ('chapter', '07', '创作 · 命题构思示例'),
                ('question', '示例命题（非真题）', '以“画室一角”为题完成一幅创作。要求构图完整，内容积极健康，表现形式不限。'),
                ('h2', '构思步骤'),
                ('steps', [
                    '审题：明确“画室一角”的范围，可以是画架、石膏像、窗光或同学作画的瞬间。',
                    '收集素材：回忆或速写记录画室中的人、物与光线。',
                    '小稿比较：画 2～3 个不同构图的小稿，选出画面中心明确的一张。',
                    '完成作品：先定大的明暗或色彩关系，再深入主体。',
                ]),
                ('img', I('scene/studio-wall.jpg', 190, '素材示例：窗光下的作品墙与石膏像', crop=(0.4, 0.0, 1.0, 1.0))),
            ],
            [
                ('chapter', '08', '作品集整理建议'),
                ('bullets', [
                    '选作品：优先选完成度高、能代表自己水平的作品，各科数量均衡。',
                    '分类整理：按素描、色彩、速写、创作分组，每组按时间排序。',
                    '拍摄作品：光线均匀、画面端正、不偏色，避免反光与阴影。',
                    '标注信息：注明作品名称、尺寸、材料与完成时间。',
                    '真实呈现：作品须为本人独立完成，不使用他人作品，不过度修图。',
                ]),
                ('imgs', {'h': 130, 'items': [
                    I('art/sketch-bust-3.jpg', caption='素描'),
                    I('art/color-still-5.jpg', caption='色彩'),
                    I('art/speed-figure-2.jpg', caption='速写'),
                    I('art/color-flower-1.jpg', caption='色彩'),
                ]}),
                ('tip', '提醒', '各院校对作品集的要求不同，是否需要提交、提交形式与数量，以招生简章为准。'),
            ],
        ],
    ),
    dict(
        id='eb-art-history',
        title='中外美术简史图说（示例）',
        running='中外美术简史图说（示例）',
        cover_title=['中外美术', '简史图说'],
        subtitle='从彩陶到现代艺术的时间线',
        editor='郑可',
        publisher='示范画室教研组（示例）',
        category='美术史与鉴赏',
        accent=(140, 44, 58), cover_bg=(92, 28, 40), cover_style='frame',
        cover_art=('art/sketch-bust-3.jpg', (0.08, 0.06, 0.92, 0.7)),
        title_art=('art/sketch-bust-1.jpg', (0.1, 0.1, 0.9, 0.65)),
        description='按时间线梳理中外美术史上的代表作品与流派，介绍「描述—分析—解释—评价」的'
                    '鉴赏方法，附美术常识速记表。',
        pages=[
            [
                ('chapter', '01', '怎样欣赏一件美术作品'),
                ('p', '欣赏作品不只是说“好看”或“不好看”。美术鉴赏中常用的方法分为四步：'),
                ('steps', [
                    '描述：看到了什么？题材、人物、物体、色彩、构图。',
                    '分析：作品如何组织？线条、形体、明暗、色彩与空间的运用。',
                    '解释：作品想表达什么？结合时代背景与作者经历理解主题。',
                    '评价：作品有什么价值？说出自己的判断与理由。',
                ]),
                ('img', I('art/color-still-2.jpg', 230, '练习：试用四步法描述这幅静物（画室范画）')),
                ('tip', '示范', '描述：暖黄背景前放着陶罐、果盘与灰蓝衬布。分析：暖色背景统一色调，灰蓝衬布形成冷暖对比。'
                              '解释：画面营造出温暖的秋日氛围。评价：色调明确、主次清楚。'),
            ],
            [
                ('chapter', '02', '中国美术（一）：从彩陶到秦汉'),
                ('timeline', [
                    ('新石器时代', '彩陶艺术', '仰韶文化彩陶纹饰丰富，《人面鱼纹彩陶盆》出土于陕西西安半坡遗址，现藏中国国家博物馆。'),
                    ('商', '青铜器《后母戊鼎》', '商代后期的青铜方鼎，体量宏大、纹饰庄重，1939 年出土于河南安阳。'),
                    ('秦', '秦始皇陵兵马俑', '1974 年在陕西临潼发现，陶俑形象写实、数量众多，展现了秦代雕塑的水平。'),
                    ('东汉', '铜奔马（马踏飞燕）', '1969 年出土于甘肃武威雷台汉墓，以飞鸟衬托骏马的速度，构思巧妙。'),
                    ('汉', '画像石与画像砖', '以刻画、浮雕表现生产、宴乐、神话等题材，造型古朴，富有动势。'),
                ]),
                ('tip', '记忆方法', '按“彩陶—青铜—陶俑—铜奔马”的材料与时代顺序记忆，并联系作品的出土地点。'),
            ],
            [
                ('chapter', '03', '中国美术（二）：魏晋至隋唐'),
                ('timeline', [
                    ('东晋', '顾恺之', '代表作《洛神赋图》（宋摹本）、《女史箴图》（唐摹本），提出“以形写神”，重视人物的神情。'),
                    ('十六国至元', '敦煌莫高窟', '始建于十六国时期，保存了大量壁画与彩塑，是研究古代美术的重要宝库。'),
                    ('唐', '阎立本《步辇图》', '描绘唐太宗接见吐蕃使者的场景，人物主次分明。'),
                    ('唐', '吴道子', '被后世尊为“画圣”，线条飘逸，有“吴带当风”之誉。'),
                    ('唐', '张萱、周昉', '仕女画代表，作品有《捣练图》（宋摹本）、《簪花仕女图》。'),
                ]),
            ],
            [
                ('chapter', '04', '中国美术（三）：五代两宋'),
                ('timeline', [
                    ('五代', '顾闳中《韩熙载夜宴图》', '以连环长卷的形式描绘夜宴的五个场景，人物刻画细腻，现存为宋摹本。'),
                    ('北宋', '范宽《溪山行旅图》', '巨峰矗立，气势雄伟，是北方山水画的代表作品。'),
                    ('北宋', '张择端《清明上河图》', '长卷描绘汴京城内外的市井生活，人物、舟车、建筑繁多而有序。'),
                    ('北宋', '王希孟《千里江山图》', '青绿山水长卷，色彩明丽，展现江山的壮阔。'),
                    ('两宋', '花鸟画与院体画', '宋代画院兴盛，花鸟画写实精微，讲究观察与法度。'),
                ]),
                ('tip', '长卷怎么看', '长卷从右向左展开，视线随画面移动，采用“散点透视”，与西方绘画的焦点透视不同。'),
            ],
            [
                ('chapter', '05', '中国美术（四）：元明清与近现代'),
                ('timeline', [
                    ('元', '黄公望《富春山居图》', '“元四家”之一黄公望的代表作，现分为《剩山图》与《无用师卷》两段，分藏两地。'),
                    ('明', '明四家', '沈周、文徵明、唐寅、仇英，活跃于苏州一带，又称“吴门四家”。'),
                    ('明末清初', '八大山人、石涛', '八大山人笔墨简练、造型夸张；石涛提出“笔墨当随时代”。'),
                    ('清', '扬州八怪', '以郑板桥等为代表，题材多样，风格不拘一格；郑板桥尤以画竹著称。'),
                    ('近现代', '齐白石、徐悲鸿', '齐白石的花鸟虫鱼质朴生动；徐悲鸿主张以素描为造型基础，代表作有《奔马》。'),
                ]),
            ],
            [
                ('chapter', '06', '西方美术（一）：古希腊与文艺复兴'),
                ('imgs', {'h': 170, 'items': [
                    I('art/sketch-bust-3.jpg', caption='维纳斯石膏像（画室范画）', crop=(0.05, 0.05, 0.95, 0.75)),
                    I('art/sketch-bust-1.jpg', caption='大卫石膏像（画室范画）', crop=(0.1, 0.1, 0.9, 0.7)),
                ]}),
                ('timeline', [
                    ('古希腊', '《米洛斯的维纳斯》', '1820 年发现于米洛斯岛，现藏卢浮宫，体态优美、比例和谐。'),
                    ('古希腊', '米隆《掷铁饼者》', '表现投掷前的瞬间，原作已失，现存为古罗马复制品。'),
                    ('文艺复兴', '达·芬奇', '《蒙娜丽莎》《最后的晚餐》，善用明暗晕染表现人物。'),
                    ('文艺复兴', '米开朗琪罗', '雕塑《大卫》、西斯廷礼拜堂天顶画，人物雄健有力。'),
                    ('文艺复兴', '拉斐尔', '《雅典学院》《西斯廷圣母》，构图和谐，形象秀美。'),
                ]),
            ],
            [
                ('chapter', '07', '西方美术（二）：巴洛克至浪漫主义'),
                ('timeline', [
                    ('17 世纪', '伦勃朗《夜巡》', '荷兰画家，善用强烈的明暗对比，被称为“光影大师”。'),
                    ('17 世纪', '维米尔《戴珍珠耳环的少女》', '荷兰画家，画面宁静，光线柔和细腻。'),
                    ('新古典主义', '大卫《马拉之死》', '法国画家雅克-路易·大卫，构图严谨、造型坚实。'),
                    ('新古典主义', '安格尔《泉》', '线条流畅，造型典雅，重视素描与轮廓。'),
                    ('浪漫主义', '籍里柯《梅杜萨之筏》', '以海难事件为题材，画面充满戏剧性。'),
                    ('浪漫主义', '德拉克洛瓦《自由引导人民》', '色彩热烈、动势强烈，表现 1830 年法国七月革命。'),
                ]),
                ('tip', '易混点', '新古典主义画家雅克-路易·大卫，与米开朗琪罗的雕塑《大卫》不是一回事，答题时注意区分。'),
            ],
            [
                ('chapter', '08', '西方美术（三）：现实主义与印象派'),
                ('timeline', [
                    ('现实主义', '库尔贝', '主张“画眼睛看得见的东西”，代表作《奥尔南的葬礼》。'),
                    ('现实主义', '米勒《拾穗者》', '描绘农妇拾麦穗的劳动场景，朴素庄重。'),
                    ('印象派', '莫奈《日出·印象》', '“印象派”之名即由此画而来，注重表现光与色的瞬间变化。'),
                    ('印象派', '雷诺阿、德加', '雷诺阿善画明媚的人物，德加以芭蕾舞者题材闻名。'),
                    ('后印象派', '塞尚、梵高、高更', '塞尚探索形体结构，被称为“现代绘画之父”；梵高的《星月夜》笔触强烈。'),
                ]),
                ('tip', '联系写生', '印象派对外光与色彩的研究，与色彩写生中观察光源色、环境色的方法一脉相承。'),
            ],
            [
                ('chapter', '09', '西方美术（四）：走向现代'),
                ('timeline', [
                    ('野兽派', '马蒂斯', '色彩大胆强烈，追求画面的装饰性与表现力。'),
                    ('立体主义', '毕加索、布拉克', '把物体分解为几何块面，从多个角度同时表现；毕加索的《格尔尼卡》控诉战争的残酷。'),
                    ('抽象艺术', '康定斯基', '抽象艺术的先驱之一，用点、线、面与色彩表达情感。'),
                    ('超现实主义', '达利《记忆的永恒》', '以软化的钟表等形象营造梦境般的画面。'),
                ]),
                ('p', '现代艺术的探索看起来离考场很远，但它们对形式、色彩和构图的思考，同样能帮助我们理解“画面”本身。'),
                ('img', I('art/color-flower-1.jpg', 190, '写生中的装饰性：花卉静物的色彩与构图（画室范画）')),
            ],
            [
                ('chapter', '10', '美术常识速记表'),
                ('table', ['作品', '作者', '时代 / 流派'], [
                    ['《清明上河图》', '张择端', '北宋'],
                    ['《千里江山图》', '王希孟', '北宋'],
                    ['《富春山居图》', '黄公望', '元'],
                    ['《蒙娜丽莎》', '达·芬奇', '文艺复兴'],
                    ['《雅典学院》', '拉斐尔', '文艺复兴'],
                    ['《夜巡》', '伦勃朗', '17 世纪荷兰'],
                    ['《自由引导人民》', '德拉克洛瓦', '浪漫主义'],
                    ['《拾穗者》', '米勒', '现实主义'],
                    ['《日出·印象》', '莫奈', '印象派'],
                    ['《星月夜》', '梵高', '后印象派'],
                ], [230, 160, 210]),
                ('tip', '说明', '本书为示例内容，作品信息力求准确；详细史实请以正式教材与博物馆资料为准。'),
            ],
        ],
    ),
    dict(
        id='eb-monthly-202610',
        title='画室月刊 2026 年 10 月号（示例）',
        running='画室月刊 · 2026 年 10 月号（示例）',
        mark='示例期刊 · 仅供演示',
        issue='2026 年 10 月号',
        cover_title=['画室月刊', '2026 年 10 月号'],
        subtitle='秋季集训开篇 · 色彩高级灰',
        cover_lines=['秋季集训 · 一周练习怎么排', '名师课堂 · 色彩里的“高级灰”', '学员作品展'],
        editor='画室月刊编辑部',
        publisher='示范画室 编印（示例）',
        category='期刊',
        accent=(192, 92, 36), accent_light=(255, 170, 70), cover_bg=(120, 52, 18), cover_style='magazine',
        cover_art=('art/color-flower-1.jpg', (0.1, 0.0, 0.9, 1.0)),
        title_art=('scene/studio-wall.jpg', (0.0, 0.25, 1.0, 1.0)),
        editorial_title='写在秋季集训开始时',
        editorial=[
            '十月，画室里的画架又排满了。秋季集训是一年中练习时间集中的阶段，也常常是容易疲惫的阶段。',
            '这一期，我们从“一周练习怎么排”谈起，请老师分享色彩高级灰的调法与坐姿速写的要点，也选登了几位同学的作业。',
            '进步往往藏在每天的小目标里：今天把构图画准，明天把交界线画实。愿你在每一张作业里，都比昨天多看懂一点。',
        ],
        description='本期聚焦秋季集训：一周练习安排、高分作品赏析、色彩高级灰的调法、坐姿速写要点、学员作品展与铅笔的选用。',
        pages=[
            [
                ('chapter', '本月话题', '一周练习怎么排'),
                ('p', '集训期每天的练习时间长，合理安排三科的比例，比单纯延长时间更重要。下面是一份示例安排：'),
                ('table', ['', '上午', '下午', '晚上'], [
                    ['周一', '素描长期', '素描长期', '速写'],
                    ['周二', '素描长期', '色彩写生', '速写'],
                    ['周三', '色彩写生', '色彩写生', '素描默写'],
                    ['周四', '素描短期', '色彩默写', '速写'],
                    ['周五', '色彩写生', '素描短期', '速写'],
                    ['周六', '模拟练习', '讲评', '自主补弱'],
                    ['周日', '休息', '复盘本周作业', '—'],
                ], [80, 170, 170, 180]),
                ('bullets', [
                    '长期作业练深入，短期作业练整体，默写练熟练，三者结合。',
                    '速写贵在每天坚持，可安排在精力相对放松的晚上。',
                    '每周留出复盘时间，把作业按时间排开看，找出变化。',
                ]),
                ('tip', '说明', '以上为示例安排，请结合画室课表与老师建议调整。'),
            ],
            [
                ('chapter', '高分作品赏析', '《陶罐与水果衬布》'),
                ('img', I('art/sketch-still-1.jpg', 350, '画室范画 · 素描静物')),
                ('bullets', [
                    '构图：陶罐居中偏后，水果与衬布在前方展开，三角形组合稳定。',
                    '明暗：光源来自左上方，陶罐的明暗交界线肯定，投影方向统一。',
                    '质感：陶罐的厚重、梨的光滑与衬布的柔软区分明确。',
                ]),
                ('tip', '临摹建议', '先用 10 分钟画一张小稿，只画构图与黑白灰大关系，再决定是否深入。'),
            ],
            [
                ('chapter', '名师课堂', '色彩里的“高级灰”'),
                ('img', I('art/color-still-3.jpg', 270, '灰调静物 · 郭*琪（画室学员作业）')),
                ('p', '“高级灰”指纯度较低、但仍有明确色彩倾向的颜色。它让画面含蓄而统一，不是“没有颜色的灰”。'),
                ('bullets', [
                    '用补色降低纯度：加入少量补色，得到偏冷或偏暖的灰。',
                    '用邻近色调和：让灰色带有画面主色调的倾向。',
                    '少用黑白直接调灰，容易发闷、发粉。',
                    '灰中要有对比：大面积的灰配小面积的纯色，画面才有精神。',
                ]),
            ],
            [
                ('chapter', '速写一页通', '坐姿'),
                ('side', I('art/speed-figure-2.jpg', caption='坐姿读书 · 许*懿（画室学员作业）', crop=(0.08, 0.02, 0.92, 0.98), w=250, h=350), [
                    ('bullets', [
                        '重心：落在臀部与凳面，上身可前倾或后靠。',
                        '比例：坐在凳子上约 5 个头长，大腿因透视会缩短。',
                        '体块：胸腔与骨盆的角度决定坐姿的动态。',
                        '衣纹：集中在腰部、膝部与肘部，抓住挤压纹。',
                    ]),
                ]),
                ('tip', '本周练习', '每天画 3 张不同角度的坐姿速写：正面、侧面、四分之三侧面。'),
                ('p', '坐姿看似安静，其实最考验对体块关系的理解。画之前先想一想：模特的身体重量压在了哪里？'),
            ],
            [
                ('chapter', '学员作品展', '本月优秀作业（示例）'),
                ('imgs', {'h': 200, 'cols': 2, 'items': [
                    I('art/color-still-5.jpg', caption='浅灰调静物写生 · 刘*桐'),
                    I('art/sketch-still-3.jpg', caption='陶罐·玻璃瓶·苹果 · 马*轩'),
                    I('art/color-still-3.jpg', caption='灰调静物 · 郭*琪'),
                    I('art/speed-figure-2.jpg', caption='坐姿读书 · 许*懿', crop=(0.0, 0.2, 1.0, 0.8)),
                ]}),
                ('p', '本月入选的作业来自三个班级。点评老师的共同建议：在保证整体的前提下，把主体物再画深入一些。'),
            ],
            [
                ('chapter', '工具角', '铅笔的软与硬'),
                ('diagram', 'pencils', 220),
                ('bullets', [
                    '标号：H 表示硬，数字越大越硬、越浅；B 表示软，数字越大越软、越深；HB 软硬适中。',
                    '起稿多用 HB～2B，线条轻，便于修改；深入暗部可用 4B～8B。',
                    '炭笔颜色更黑、质地更粗，适合重调子，但不易擦改。',
                    '可塑橡皮可以捏成需要的形状，“粘”起石墨提亮局部，不易伤纸。',
                ]),
                ('tip', '小贴士', '同一张画里，软硬不同的铅笔叠加使用，能让暗部更有层次。'),
            ],
            [
                ('chapter', '画室日历', '十月'),
                ('table', ['时间', '安排'], [
                    ['10 月 1–7 日', '国庆期间自主练习：完成速写本，每天 5 张'],
                    ['10 月 8–17 日', '素描静物长期作业、色彩静物写生'],
                    ['10 月 18 日', '2026 年 10 月月考（素描、色彩、速写）'],
                    ['10 月 19–25 日', '月考讲评，按问题分组练习'],
                    ['10 月 26–31 日', '色彩风景写生、场景速写'],
                ], [170, 430]),
                ('p', '月考成绩发布后，可以在「我的学情」中查看各科分数与评分细节，在「作品档案」里对照老师的点评。'),
                ('tip', '提醒', '以上为示例安排，具体以画室通知为准。'),
                ('img', I('scene/studio-wall.jpg', 200, '画室一角（示例图片）', crop=(0.0, 0.2, 1.0, 1.0))),
            ],
        ],
    ),
    dict(
        id='eb-monthly-202611',
        title='画室月刊 2026 年 11 月号（示例）',
        running='画室月刊 · 2026 年 11 月号（示例）',
        mark='示例期刊 · 仅供演示',
        issue='2026 年 11 月号',
        cover_title=['画室月刊', '2026 年 11 月号'],
        subtitle='考前查漏补缺 · 场景速写透视',
        cover_lines=['考前一个月 · 查漏补缺清单', '名师课堂 · 场景速写的透视', '默写训练 · 把常画的物体画熟'],
        editor='画室月刊编辑部',
        publisher='示范画室 编印（示例）',
        category='期刊',
        accent=(28, 92, 142), accent_light=(110, 200, 255), cover_bg=(14, 40, 70), cover_style='magazine',
        cover_art=('art/color-still-4.jpg', (0.22, 0.0, 0.82, 1.0)),
        title_art=('art/speed-scene-1.jpg', (0.0, 0.1, 1.0, 0.95)),
        editorial_title='把节奏放稳',
        editorial=[
            '十一月，离统考越来越近。越是这个时候，越要把节奏放稳：按计划练习，按时休息，把精力用在解决具体问题上。',
            '本期“本月话题”整理了一份查漏补缺清单，名师课堂讲解场景速写中的透视，默写训练帮你把常画的物体画熟。',
            '考试检验的是长期积累的能力。不必和别人比进度，只需要和上个月的自己比。',
        ],
        description='本期聚焦考前一个月：查漏补缺清单、色彩高分卷解读、场景速写的透视、默写训练、考场须知与状态调整。',
        pages=[
            [
                ('chapter', '本月话题', '考前查漏补缺清单'),
                ('h2', '素描'),
                ('checks', [
                    '起稿能否在 30 分钟内定准构图与比例？',
                    '画面黑白灰层次是否清楚？',
                    '陶罐、瓷盘、玻璃器皿、水果、衬布的质感是否熟练？',
                ]),
                ('h2', '色彩'),
                ('checks', [
                    '能否快速确定画面色调？',
                    '亮部、暗部的冷暖关系是否统一？',
                    '是否出现粉、脏、灰、花的问题？',
                ]),
                ('h2', '速写'),
                ('checks', [
                    '单人动态是否准确，重心是否稳定？',
                    '组合与场景的透视是否统一？',
                    '能否在规定时间内完成？',
                ]),
                ('tip', '方法', '把近一个月的作业按科目排开，每科圈出 1～2 个反复出现的问题，作为本月的练习重点。'),
            ],
            [
                ('chapter', '高分卷解读', '色彩静物'),
                ('img', I('art/color-still-1.jpg', 330, '陶罐水果与蓝白衬布（画室范画）')),
                ('bullets', [
                    '色调：深暖背景配蓝白衬布，冷暖对比强烈，色调明确。',
                    '塑造：笔触方向随形体走，陶罐与水果的体积感强。',
                    '环境色：白布暗部有冷暖变化，白盘中可见水果与衬布的反射色。',
                    '主次：橙子与苹果是视觉中心，背景笔触概括。',
                ]),
            ],
            [
                ('chapter', '名师课堂', '场景速写的透视'),
                ('diagram', 'street', 250),
                ('bullets', [
                    '先定视平线：站立平视时，视平线约在画者眼睛的高度。',
                    '一点透视：街道、房屋的纵深线消失到视平线上的同一个灭点。',
                    '平地上站立的人物，头部大致落在视平线附近，近大远小。',
                    '近景人物刻画充分，远景人物概括处理。',
                ]),
                ('img', I('art/speed-scene-1.jpg', 180, '老街集市 · 场景速写（画室范画）', crop=(0.0, 0.15, 1.0, 0.85))),
            ],
            [
                ('chapter', '默写训练', '把常画的物体画熟'),
                ('p', '默写考查的是对物体结构、明暗与色彩规律的掌握程度。平时可以建立自己的“物体库”：'),
                ('steps', [
                    '选物体：陶罐、瓷盘、玻璃杯、苹果、橙子、衬布等常见物体。',
                    '记结构：每个物体从正面、侧面、俯视三个角度各画一遍线稿。',
                    '记规律：记住典型光线下的明暗与冷暖，而不是记某一张画。',
                    '限时练：每天用 30～45 分钟默写一组，画完与写生作业对照。',
                ]),
                ('imgs', {'h': 200, 'items': [
                    I('art/sketch-still-1.jpg', caption='素描默写参考：陶罐与水果'),
                    I('art/color-still-2.jpg', caption='色彩默写参考：暖调组合'),
                ]}),
            ],
            [
                ('chapter', '示范作品展', '画室老师示范（示例）'),
                ('imgs', {'h': 200, 'cols': 2, 'items': [
                    I('art/sketch-portrait-1.jpg', caption='女青年头像 · 王海波', crop=(0.0, 0.15, 1.0, 0.7)),
                    I('art/color-still-2.jpg', caption='暖黄调静物 · 周强'),
                    I('art/speed-group-1.jpg', caption='课间 · 教室三人场景 · 朱琳'),
                    I('art/sketch-bust-3.jpg', caption='维纳斯石膏像 · 赵雪', crop=(0.0, 0.1, 1.0, 0.65)),
                ]}),
                ('p', '示范作品可以帮助我们看清一张画从整体到局部的处理顺序。临摹时先看大关系，再看细节。'),
            ],
            [
                ('chapter', '考场须知', '考前准备清单（示例）'),
                ('checks', [
                    '证件：准考证、身份证等按要求携带，提前放进固定的文件袋。',
                    '画具：按考试说明准备并提前检查，铅笔削好、颜料补齐。',
                    '时间：提前熟悉考点路线，按规定时间入场。',
                    '规则：认真阅读考场规则，不在画面上署名或做与作答无关的标记。',
                    '作答：拿到试题先审题，再按平时的节奏完成。',
                ]),
                ('tip', '以官方为准', '本页为示例清单。考试时间、地点、携带物品等要求，请以本省考试院及考点的正式公告为准。'),
                ('img', I('scene/exam-hall.jpg', 200, '考场示意（示例图片）')),
            ],
            [
                ('chapter', '编读往来', '保持状态的几个小习惯'),
                ('p', '编辑部收到不少同学的来信，问到考前如何保持状态。我们整理了几位老师的建议：'),
                ('bullets', [
                    '规律作息：保证睡眠，不熬夜赶画。',
                    '适度活动：每天留出时间散步或拉伸，缓解久坐的疲劳。',
                    '记录进步：每周挑一张满意的作业拍照留存，看到自己的变化。',
                    '及时沟通：遇到瓶颈时和老师、同学聊一聊，换个角度看问题。',
                ]),
                ('tip', '来信摘登', '“以前一画色彩就紧张，后来每天先画 20 分钟小色稿热身，状态稳定多了。”——色彩班的一位同学'),
                ('img', I('art/color-still-5.jpg', 200, '小色稿热身练习（示例图片）')),
            ],
        ],
    ),
    dict(
        id='eb-color-landscape',
        title='色彩风景写生技法（示例）',
        running='色彩风景写生技法（示例）',
        cover_title=['色彩风景', '写生技法'],
        subtitle='取景 · 空间 · 天空 · 树与水',
        editor='孙磊',
        publisher='示范画室教研组（示例）',
        category='色彩教程',
        accent=(46, 112, 66), accent_light=(250, 200, 80), cover_bg=(30, 66, 40), cover_style='split',
        cover_art=('art/color-landscape-1.jpg', (0.0, 0.0, 1.0, 1.0)),
        title_art=('art/color-landscape-1.jpg', (0.0, 0.05, 1.0, 0.95)),
        description='围绕户外写生，讲解取景构图、色彩透视与空间层次，以及天空、树木、建筑、水面的表现方法和写生步骤。',
        pages=[
            [
                ('chapter', '01', '写生前的准备与取景'),
                ('img', I('art/color-landscape-1.jpg', 270, '秋日村落 · 白杨与远山（画室范画）')),
                ('bullets', [
                    '工具：画板、画箱、水粉颜料、调色盒、水桶、取景框、小凳，注意防晒防风。',
                    '时间：光线变化快，同一幅画尽量在相近的时段完成。',
                    '取景：用取景框或手指框出画面，选择有主体、有层次的角度。',
                    '观察：先看光线方向与天气，确定画面的整体色调。',
                ]),
            ],
            [
                ('chapter', '02', '构图：地平线与视觉中心'),
                ('diagram', 'horizons', 190),
                ('bullets', [
                    '地平线不宜放在画面正中，以免把画面分成均等的两半。',
                    '高地平线：地面占比大，适合表现田野、街巷等丰富的地面景物。',
                    '低地平线：天空占比大，适合表现云层与开阔的空间。',
                    '视觉中心：主体景物放在画面中心附近，用明暗、冷暖或纯度对比突出它。',
                ]),
                ('tip', '小稿', '正式画之前先画 2～3 张小色稿，比较不同取景与构图的效果。'),
            ],
            [
                ('chapter', '03', '空间：近景、中景、远景'),
                ('diagram', 'aerial', 290),
                ('bullets', [
                    '色彩透视：近处色彩纯度高、对比强、偏暖；远处纯度低、对比弱、偏冷偏灰。',
                    '近景：刻画具体，笔触明确，可以出现画面中较重的颜色。',
                    '中景：多为主体所在，形体与色彩关系完整。',
                    '远景：概括处理，形体简化，色彩向天空靠拢。',
                ]),
            ],
            [
                ('chapter', '04', '天空与云'),
                ('img', I('art/color-landscape-1.jpg', 220, '天空局部：云层松动，靠近远山处偏亮偏灰', crop=(0.0, 0.0, 1.0, 0.46))),
                ('bullets', [
                    '天空是光源所在，晴天时天顶偏蓝偏深，靠近地平线处偏亮、偏灰。',
                    '云有体积：受光面亮而暖，背光面灰而冷，底部边缘较虚。',
                    '笔触随云的形态走，松动概括，避免画得过实过碎。',
                    '天空与地面要有明度对比，大面积天空也要有冷暖变化。',
                ]),
                ('tip', '顺序', '天空颜色会影响整幅画的色调，通常先画天空，再由远及近画远景、中景、近景。'),
            ],
            [
                ('chapter', '05', '树木：先画大形再画枝叶'),
                ('img', I('art/color-landscape-1.jpg', 250, '白杨树局部：树冠成组，高低错落', crop=(0.38, 0.0, 0.82, 0.78))),
                ('bullets', [
                    '先画大形：把树冠概括为球体、柱体或块面，分出受光面与背光面。',
                    '透气孔：树冠中透出天空的空隙让树显得松动，不要画成实心的一团。',
                    '树干：上细下粗，有分枝的转折；受光一侧偏暖，背光一侧偏冷。',
                    '成组处理：多棵树要有高低、前后、疏密变化，避免等距排列。',
                ]),
            ],
            [
                ('chapter', '06', '建筑与地面'),
                ('img', I('art/color-landscape-1.jpg', 240, '土墙民居局部：受光墙面偏暖，背光墙面偏冷', crop=(0.0, 0.42, 0.62, 0.96))),
                ('bullets', [
                    '透视统一：屋檐、墙基、门窗线要消失到同一组灭点。',
                    '冷暖对比：阳光下受光墙面偏暖，背光墙面受天空影响偏冷。',
                    '门窗：作为重色点缀，但要服从墙面的大关系，不要画得一样黑。',
                    '地面：近处可画出道路、草丛的细节，远处概括，并注意投影。',
                ]),
            ],
            [
                ('chapter', '07', '水面与倒影'),
                ('diagram', 'reflection', 280),
                ('bullets', [
                    '倒影与实物上下对应，垂直方向的长度相当。',
                    '亮的物体倒影略暗，暗的物体倒影略亮，倒影整体对比比实物弱。',
                    '水面受天空影响，平静时颜色接近天空，有风时出现横向波纹。',
                    '用横向笔触打破倒影的边缘，表现水的流动感。',
                ]),
            ],
            [
                ('chapter', '08', '写生步骤小结'),
                ('imgs', {'h': 150, 'items': [
                    I('art/color-landscape-1.jpg', caption='① 铺大色块', fx='blocks'),
                    I('art/color-landscape-1.jpg', caption='② 塑造景物', fx='shaping'),
                    I('art/color-landscape-1.jpg', caption='③ 调整完成'),
                ]}),
                ('steps', [
                    '起稿：用单色勾出地平线、主要景物的位置与透视。',
                    '铺大色块：按天空、远景、中景、近景铺出大色块，确定冷暖与明度。',
                    '塑造：从主体景物入手，画出受光与背光的色彩变化。',
                    '调整：加强近景对比，减弱远景，统一整体色调。',
                ]),
                ('tip', '写生心得', '风景写生的难点在于取舍。眼前的景物很多，画面只需要能表达感受的那一部分。'),
            ],
        ],
    ),
]


# ── 输出 ────────────────────────────────────────────────────────────────


def save_jpeg(im, path, limit=MAX_BYTES):
    quality = QUALITY
    while True:
        buf = io.BytesIO()
        im.save(buf, 'JPEG', quality=quality, optimize=True, progressive=True)
        data = buf.getvalue()
        if len(data) <= limit or quality <= MIN_QUALITY:
            break
        quality -= 4
    path.write_bytes(data)
    return len(data), quality


def toc_of(book):
    entries = []
    if book.get('issue'):
        entries.append(('', '卷首语', 1))
    for index, blocks in enumerate(book['pages']):
        kind, label, title = blocks[0]
        assert kind == 'chapter', f'{book["id"]} p{index + 3} 缺少章节标题'
        entries.append((label, title, index + 3))
    return entries


def toc_title(label, title):
    if not label:
        return title
    return title if label.isdigit() else f'{label} · {title}'


def build(book):
    OUT.mkdir(parents=True, exist_ok=True)
    entries = toc_of(book)
    pages = [editorial_page(book) if book.get('issue') else title_page(book), toc_page(book, entries)]
    for index, blocks in enumerate(book['pages']):
        pages.append(content_page(book, index + 3, blocks))
    sizes = []
    size, q = save_jpeg(make_cover(book), OUT / f'{book["id"]}-cover.jpg')
    sizes.append(('cover', size, q))
    for number, im in enumerate(pages, start=1):
        size, q = save_jpeg(im, OUT / f'{book["id"]}-p{number:02d}.jpg')
        sizes.append((f'p{number:02d}', size, q))
    for stale in OUT.glob(f'{book["id"]}-p*.jpg'):
        number = int(stale.stem.rsplit('-p', 1)[1])
        if number > len(pages):
            stale.unlink()
    return {
        'title': book['title'],
        'pageCount': len(pages),
        'toc': [{'title': toc_title(label, title), 'page': page} for label, title, page in entries],
    }, sizes


def main(argv):
    wanted = set(argv)
    manifest = json.loads(MANIFEST.read_text('utf-8')) if MANIFEST.exists() else {}
    for book in BOOKS:
        if wanted and book['id'] not in wanted:
            continue
        info, sizes = build(book)
        manifest[book['id']] = info
        total = sum(s for _, s, _ in sizes)
        worst = max(sizes, key=lambda item: item[1])
        print(f'{book["id"]}: {info["pageCount"]} 页 + 封面，{total / 1024:.0f} KB（最大 {worst[0]} {worst[1] / 1024:.0f} KB，q{worst[2]}）')
    ordered = {book['id']: manifest[book['id']] for book in BOOKS if book['id'] in manifest}
    MANIFEST.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    files = sorted(OUT.glob('*.jpg'))
    total = sum(f.stat().st_size for f in files)
    over = [f.name for f in files if f.stat().st_size > 90 * 1024]
    print(f'合计 {len(files)} 张，{total / 1024 / 1024:.2f} MB' + (f'；超过 90 KB：{over}' if over else ''))
    if total > TOTAL_LIMIT:
        print('! 总量超过 6 MB')


if __name__ == '__main__':
    main(sys.argv[1:])
