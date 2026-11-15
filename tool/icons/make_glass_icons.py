"""Glass-style 132x132 quick-action icons matching assets/images/home/home4..9.png.

Usage: python tool/icons/make_glass_icons.py assets/images/home
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = sys.argv[1]
S = 4
N = 132 * S

PAL = {
    "purple": dict(
        top=(134, 111, 227),
        bottom=(165, 147, 243),
        rim=(200, 190, 248),
        glass=((196, 184, 250), (214, 206, 252)),
    ),
    "pink": dict(
        top=(255, 106, 144),
        bottom=(255, 160, 185),
        rim=(255, 200, 214),
        glass=((255, 176, 197), (255, 204, 217)),
    ),
    "teal": dict(
        top=(63, 227, 195),
        bottom=(128, 239, 217),
        rim=(170, 244, 229),
        glass=((150, 240, 222), (190, 247, 235)),
    ),
}


def px(v):
    return int(round(v * S))


def new_mask():
    return Image.new("L", (N, N), 0)


def rrect_mask(box, r):
    m = new_mask()
    ImageDraw.Draw(m).rounded_rectangle([px(v) for v in box], radius=px(r), fill=255)
    return m


def circle_mask(cx, cy, r):
    m = new_mask()
    ImageDraw.Draw(m).ellipse(
        [px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=255
    )
    return m


def poly_mask(points, soften=0.0):
    m = new_mask()
    ImageDraw.Draw(m).polygon([(px(x), px(y)) for x, y in points], fill=255)
    if soften:
        # Round the corners: blur, threshold, then anti-alias the edge.
        m = m.filter(ImageFilter.GaussianBlur(px(soften)))
        m = m.point(lambda v: 255 if v > 127 else 0)
        m = m.filter(ImageFilter.GaussianBlur(px(0.35)))
    return m


def stroke_mask(points, width):
    m = new_mask()
    d = ImageDraw.Draw(m)
    pts = [(px(x), px(y)) for x, y in points]
    d.line(pts, fill=255, width=px(width), joint="curve")
    r = px(width) / 2
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def vgrad(c1, c2, y0, y1):
    col = Image.new("RGBA", (1, N))
    for y in range(N):
        t = min(1.0, max(0.0, (y / S - y0) / max(1e-6, (y1 - y0))))
        col.putpixel(
            (0, y),
            tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2)) + (255,),
        )
    return col.resize((N, N))


def hfade_mask(mask, x0, x1, a0=1.0, a1=0.38):
    row = Image.new("L", (N, 1))
    for x in range(N):
        t = min(1.0, max(0.0, (x / S - x0) / max(1e-6, (x1 - x0))))
        row.putpixel((x, 0), int(round(255 * (a0 + (a1 - a0) * t))))
    return ImageChops.multiply(mask, row.resize((N, N)))


def vfade_mask(mask, y0, y1, a0=1.0, a1=0.38):
    col = Image.new("L", (1, N))
    for y in range(N):
        t = min(1.0, max(0.0, (y / S - y0) / max(1e-6, (y1 - y0))))
        col.putpixel((0, y), int(round(255 * (a0 + (a1 - a0) * t))))
    return ImageChops.multiply(mask, col.resize((N, N)))


def paint(canvas, color_img, mask):
    layer = color_img.copy()
    layer.putalpha(mask)
    canvas.alpha_composite(layer)


def solid(c):
    return Image.new("RGBA", (N, N), tuple(c) + (255,))


def body(canvas, pal, mask, y0, y1):
    """Main coloured shape: soft lighter rim + vertical gradient."""
    rim = mask.filter(ImageFilter.MaxFilter(px(1.5) * 2 + 1)).filter(
        ImageFilter.GaussianBlur(px(1.6))
    )
    paint(canvas, solid(pal["rim"]), rim.point(lambda v: int(v * 0.95)))
    inner = mask.filter(ImageFilter.GaussianBlur(px(1.1)))
    paint(canvas, vgrad(pal["top"], pal["bottom"], y0, y1), inner)


def glass(canvas, pal, mask, y0, y1, alpha=0.93):
    """Frosted secondary shape: lighter tint with a bright soft edge."""
    g0, g1 = pal["glass"]
    edge = mask.filter(ImageFilter.MaxFilter(px(0.8) * 2 + 1)).filter(
        ImageFilter.GaussianBlur(px(1.0))
    )
    paint(canvas, solid((255, 255, 255)), edge.point(lambda v: int(v * 0.55)))
    soft = mask.filter(ImageFilter.GaussianBlur(px(0.8)))
    paint(canvas, vgrad(g0, g1, y0, y1), soft.point(lambda v: int(v * alpha)))


def white(canvas, mask):
    paint(canvas, solid((255, 255, 255)), mask.filter(ImageFilter.GaussianBlur(px(0.3))))


def bar(x0, y, x1, h=9):
    return hfade_mask(rrect_mask((x0, y - h / 2, x1, y + h / 2), h / 2), x0, x1)


BODY = (20, 18, 112, 118)


def study():
    """Score report: bar chart + glass dot."""
    pal = PAL["pink"]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    body(im, pal, rrect_mask(BODY, 26), 18, 118)
    for x, top in ((40, 70), (59, 54), (78, 40)):
        white(im, vfade_mask(rrect_mask((x, top, x + 10, 98), 5), top, 98, 1.0, 0.42))
    glass(im, pal, circle_mask(100, 104, 19), 85, 123)
    return im


def tools():
    """Toolbox: three tiles + glass diamond."""
    pal = PAL["purple"]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    body(im, pal, rrect_mask(BODY, 26), 18, 118)
    white(im, hfade_mask(rrect_mask((37, 36, 61, 60), 7), 37, 61, 1.0, 0.62))
    white(im, hfade_mask(rrect_mask((69, 36, 93, 60), 7), 69, 93, 0.9, 0.5))
    white(im, hfade_mask(rrect_mask((37, 68, 61, 92), 7), 37, 61, 1.0, 0.62))
    cx, cy, r = 91, 95, 26
    diamond = poly_mask(
        [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], soften=4.5
    )
    glass(im, pal, diamond, cy - r, cy + r)
    return im


def wall():
    """Showcase wall: framed landscape + glass star badge."""
    pal = PAL["teal"]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    body(im, pal, rrect_mask(BODY, 26), 18, 118)
    white(im, circle_mask(46, 46, 8))
    hills = poly_mask([(33, 96), (54, 64), (68, 82), (78, 70), (97, 96)], soften=3.2)
    white(im, hfade_mask(hills, 33, 97, 1.0, 0.45))
    glass(im, pal, circle_mask(99, 103, 21), 82, 124)
    star = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rad = 10.5 if i % 2 == 0 else 4.6
        star.append((99 + rad * math.cos(ang), 103.5 + rad * math.sin(ang)))
    white(im, poly_mask(star, soften=0.9))
    return im


def mailbox():
    """Mailbox: envelope + glass dot."""
    pal = PAL["pink"]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    body(im, pal, rrect_mask((16, 30, 116, 108), 22), 30, 108)
    flap = stroke_mask([(34, 50), (66, 76), (98, 50)], 8.5)
    white(im, hfade_mask(flap, 34, 98, 1.0, 0.5))
    glass(im, pal, circle_mask(102, 36, 17), 19, 53)
    return im


def dorm():
    """Dorm check: moon + bed line + glass check badge."""
    pal = PAL["teal"]
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    body(im, pal, rrect_mask(BODY, 26), 18, 118)
    moon = ImageChops.subtract(circle_mask(54, 56, 19), circle_mask(64, 49, 17))
    white(im, moon)
    white(im, bar(36, 92, 74))
    glass(im, pal, circle_mask(98, 102, 21), 81, 123)
    white(im, stroke_mask([(89, 102), (95.5, 108.5), (107, 96)], 5.2))
    return im


for name, fn in (
    ("quick_study", study),
    ("quick_tools", tools),
    ("quick_wall", wall),
    ("quick_mailbox", mailbox),
    ("quick_dorm", dorm),
):
    fn().resize((132, 132), Image.LANCZOS).save(f"{OUT}/{name}.png")
print("ok")
