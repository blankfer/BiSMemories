"""BiSMemories :: dev/art.py - draws the Clipper Lounge's own art into Media/ (8 Nov 2026).

Our own pictures, made here from arithmetic - nothing from a website, nothing of the game's:
  * Media/window.tga  the cabin window's surround: a cream frame round an oval hole (the sky and the 3D models show
                      through it), a grey lip, the cabin's teal outside it so the square corners of the models' box are
                      covered, a soft shadow round the frame and inside the hole.
  * Media/disc.tga    a white disc (tinted in the game): a gauge's face, a button's round ends, the map's round keys.
  * Media/ring.tga    a white ring: a gauge's bezel.
  * Media/oval.tga    the share card's oval window: cream and grey rings round a clear oval, the seat's paper outside.

Plain uncompressed 32-bit TGA, bottom-left origin - the oldest kind every WoW client reads. Run it again only to change
the art:   python dev/art.py   (from the addon root). No libraries needed.
"""
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
MEDIA = os.path.join(HERE, "..", "Media")

# the lounge's measurements, in the mockup's units (1 = 1% of the lounge's width) - Core/Lounge.lua uses the same
WIN_W, WIN_H = 24.0, 29.2          # the hole's box (the sky, the models' box) - Lounge.lua L.WIN
RAD_Y = 12.5                       # the rounded ends' height: a cabin window's straight sides between them
CREAM, LIP = 1.1, 0.4              # the frame, then its grey lip
SHADE = 1.2                        # the shadow outside the frame
ART_W, ART_H = WIN_W + 2 * (CREAM + LIP + SHADE), WIN_H + 2 * (CREAM + LIP + SHADE)
TEAL = (0x1F, 0x4F, 0x57)          # the cabin's panel, Lounge.lua L.COLOUR.teal - the two must match
CREAM_C = (0xD8, 0xD2, 0xC3)
CREAM_D = (0xBF, 0xB8, 0xA6)
LIP_C = (0xA5, 0x9E, 0x8E)


def write_tga(path, w, h, pixel):
    """pixel(x, y) -> (r, g, b, a) with y = 0 at the TOP; written bottom row first."""
    head = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    rows = []
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = pixel(x, y)
            row += bytes((int(b), int(g), int(r), int(a)))
        rows.append(bytes(row))
    with open(path, "wb") as fh:
        fh.write(head)
        fh.write(b"".join(rows))


def grow(px, py):
    """How far (lounge units) the point lies outside the window's hole: < 0 inside. The hole is a rounded rectangle
    whose ends are half-ellipses (rx = half its width, ry = RAD_Y) - measured along the normal, near enough."""
    hx, hy = WIN_W / 2, WIN_H / 2
    ax, ay = abs(px), abs(py)
    straight = hy - RAD_Y
    if ay <= straight:
        return ax - hx
    dy = ay - straight
    # distance from the ellipse along the ray from its middle: its radius that way is ab / sqrt((b cos)^2 + (a sin)^2) -
    # good to a few % here, and the art is soft at its edges anyway
    d = (ax ** 2 + dy ** 2) ** 0.5
    if d == 0:
        return -min(hx, RAD_Y)
    r = (hx * RAD_Y) / ((RAD_Y * ax / d) ** 2 + (hx * dy / d) ** 2) ** 0.5
    return d - r


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def window_pixel(u, v):
    """One sample at (u, v) lounge units from the art's middle -> (r, g, b, a) floats 0-255."""
    t = grow(u, v)
    if t < 0:
        # the hole: clear, with a shadow just inside the frame (the mockup's inset shadow)
        s = 0.6 * max(0.0, 1 + t / 1.6) ** 2
        return (0, 0, 0, 255 * s)
    if t < CREAM:
        # the frame: lighter at its inner edge, a touch darker toward the lip
        c = mix(CREAM_C, CREAM_D, (t / CREAM) ** 1.5)
        return (c[0], c[1], c[2], 255)
    if t < CREAM + LIP:
        return (LIP_C[0], LIP_C[1], LIP_C[2], 255)
    s = 0.38 * max(0.0, 1 - (t - CREAM - LIP) / SHADE)
    if abs(u) <= WIN_W / 2 + 0.25 and abs(v) <= WIN_H / 2 + 0.25:
        # a corner of the models' box: the cabin's teal, opaque, so nothing of a model shows past the frame
        c = mix(TEAL, (0, 0, 0), s)
        return (c[0], c[1], c[2], 255)
    return (0, 0, 0, 255 * s)


def window(path, w=512, h=512, n=3):
    def px(x, y):
        acc = [0.0, 0.0, 0.0, 0.0]
        for i in range(n):
            for j in range(n):
                u = ((x + (i + 0.5) / n) / w - 0.5) * ART_W
                v = ((y + (j + 0.5) / n) / h - 0.5) * ART_H
                r, g, b, a = window_pixel(u, v)
                acc[0] += r * a
                acc[1] += g * a
                acc[2] += b * a
                acc[3] += a
        a = acc[3] / (n * n)
        if acc[3] <= 0:
            return (0, 0, 0, 0)
        return (acc[0] / acc[3], acc[1] / acc[3], acc[2] / acc[3], a)
    write_tga(path, w, h, px)


def round_art(path, inner, size=128, n=4):
    """A white disc (inner = 0) or ring (inner = its hole's radius, 0-1), soft edged, clear outside."""
    def px(x, y):
        cover = 0
        for i in range(n):
            for j in range(n):
                u = ((x + (i + 0.5) / n) / size - 0.5) * 2
                v = ((y + (j + 0.5) / n) / size - 0.5) * 2
                d = (u * u + v * v) ** 0.5
                if d <= 0.98 and d >= inner:
                    cover += 1
        return (255, 255, 255, 255 * cover / (n * n))
    write_tga(path, size, size, px)


# THE SHARE CARD'S OVAL WINDOW (8 Nov 2026, Core/Share.lua): the ticket's seat column holds a smaller cabin window -
# the mockup's .oval, 15 x 22 units with corners rounded 50% / 42% (half its width across, 42% of its height down, so
# its sides run straight for a little in the middle), a cream ring 0.9 round it and a grey one 0.3 past that. Outside
# the rings, the seat column's own paper, opaque, so the square corners of the models' box never show.
OVAL_W, OVAL_H = 15.0, 22.0        # Share.lua S.OVAL
OVAL_RY = 0.42 * OVAL_H
OVAL_RING, OVAL_EDGE = 0.9, 0.3    # Share.lua S.RIM = their sum
OVAL_ART_W, OVAL_ART_H = OVAL_W + 2 * (OVAL_RING + OVAL_EDGE), OVAL_H + 2 * (OVAL_RING + OVAL_EDGE)
SEAT_C = (0xE2, 0xD6, 0xBB)        # Share.lua S.COLOUR.seat - the two must match
RING_C = (0xF4, 0xEF, 0xE2)
EDGE_C = (0xB9, 0xAE, 0x95)


def grow_box(px, py, hx, hy, ry):
    """grow() for any rounded box: half-width hx, half-height hy, its ends half-ellipses ry high."""
    ax, ay = abs(px), abs(py)
    straight = hy - ry
    if ay <= straight:
        return ax - hx
    dy = ay - straight
    d = (ax ** 2 + dy ** 2) ** 0.5
    if d == 0:
        return -min(hx, ry)
    r = (hx * ry) / ((ry * ax / d) ** 2 + (hx * dy / d) ** 2) ** 0.5
    return d - r


def oval_pixel(u, v):
    t = grow_box(u, v, OVAL_W / 2, OVAL_H / 2, OVAL_RY)
    if t < 0:
        return (0, 0, 0, 0)
    if t < OVAL_RING:
        return (RING_C[0], RING_C[1], RING_C[2], 255)
    if t < OVAL_RING + OVAL_EDGE:
        return (EDGE_C[0], EDGE_C[1], EDGE_C[2], 255)
    return (SEAT_C[0], SEAT_C[1], SEAT_C[2], 255)


def oval(path, w=512, h=512, n=3):
    def px(x, y):
        acc = [0.0, 0.0, 0.0, 0.0]
        for i in range(n):
            for j in range(n):
                u = ((x + (i + 0.5) / n) / w - 0.5) * OVAL_ART_W
                v = ((y + (j + 0.5) / n) / h - 0.5) * OVAL_ART_H
                r, g, b, a = oval_pixel(u, v)
                acc[0] += r * a
                acc[1] += g * a
                acc[2] += b * a
                acc[3] += a
        if acc[3] <= 0:
            return (0, 0, 0, 0)
        return (acc[0] / acc[3], acc[1] / acc[3], acc[2] / acc[3], acc[3] / (n * n))
    write_tga(path, w, h, px)


if __name__ == "__main__":
    os.makedirs(MEDIA, exist_ok=True)
    window(os.path.join(MEDIA, "window.tga"))
    round_art(os.path.join(MEDIA, "disc.tga"), 0)
    round_art(os.path.join(MEDIA, "ring.tga"), 0.86)
    oval(os.path.join(MEDIA, "oval.tga"))
    print("art: window.tga, disc.tga, ring.tga, oval.tga in", os.path.normpath(MEDIA))
