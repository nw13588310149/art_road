"""72x72 line icon for the left nav「今日」entry, matching the other leftNav icons.

Usage: python tool/icons/make_nav_icon.py assets/images/shell/leftNav/jinri.png
"""
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
S = 8  # supersampling
N = 72 * S
c = (217, 217, 217, 255)
w = 6 * S  # stroke on the 72 px grid

im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(im)


def P(x, y):
    return (x * S, y * S)


def line(points, width=w):
    pts = [P(*p) for p in points]
    d.line(pts, fill=c, width=width, joint="curve")
    r = width / 2
    for x, y in pts:
        d.ellipse((x - r, y - r, x + r, y + r), fill=c)


# calendar body
d.rounded_rectangle((*P(9, 13), *P(63, 64)), radius=15 * S, outline=c, width=w)
# binder rings
line([(24, 7), (24, 19)])
line([(48, 7), (48, 19)])
# check mark
line([(25, 41), (33, 49), (48, 33)])

im.resize((72, 72), Image.LANCZOS).save(out)
