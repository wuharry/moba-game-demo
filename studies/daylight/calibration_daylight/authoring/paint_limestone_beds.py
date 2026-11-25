"""Author an original, seamless, linear-data pigment mask for Godot.

R is a succession of exposed mineral faces, G is an open parting, B is a
chipped calcite lip. A is dry-brushed exfoliation around a neutral 128.
Drawing in a 100-unit square keeps the brush dimensions
independent of PNG resolution. Each tuple is one individually placed outcrop.
Run with Python, NumPy and Pillow from any directory.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIDE = 1024
SUPERSAMPLE = 2
SCALE = SIDE * SUPERSAMPLE / 100
SOURCE = Path(__file__).resolve().parents[1] / "assets" / "limestone_beds.png"
RNG = np.random.default_rng(12028)

# Left to right along the top edge of each exposed bed. Bed thickness and
# mineral value are independent; a recess sometimes exposes a warmer layer.
BEDS = [
    ([(-6, 5), (1, 7), (3, 10), (9, 11), (12, 10), (17, 13)], 3.0, -40),
    ([(23, 6), (28, 8), (33, 7), (39, 10)], 4.5, 37),
    ([(55, 7), (58, 5), (66, 6), (72, 8), (77, 12), (83, 12)], 6.1, -30),
    ([(5, 25), (14, 23), (19, 22), (24, 20), (31, 21), (37, 17)], 6.1, 40),
    ([(39, 22), (44, 19), (48, 19), (53, 16)], 2.6, -40),
    ([(69, 23), (75, 26), (80, 27), (86, 32)], 3.4, 32),
    ([(88, 14), (92, 18), (94, 24), (99, 27), (105, 28)], 6.5, -54),
    ([(18, 35), (24, 35), (30, 39), (35, 40), (43, 46)], 5.0, -37),
    ([(45, 32), (51, 29), (56, 29), (58, 28), (66, 29), (69, 27)], 5.2, 43),
    ([(69, 44), (74, 43), (77, 45), (82, 44), (84, 45), (91, 42)], 6.4, -46),
    ([(-7, 51), (1, 51), (6, 49), (14, 50), (20, 46)], 3.5, 40),
    ([(39, 54), (46, 55), (50, 53), (52, 49), (56, 47)], 7.2, -54),
    ([(54, 61), (59, 60), (62, 59), (69, 59), (73, 56)], 3.5, 39),
    ([(87, 55), (91, 54), (95, 55), (98, 54)], 2.2, 34),
    ([(6, 67), (10, 65), (14, 66), (19, 64), (21, 60), (23, 59)], 5.7, -57),
    ([(24, 72), (30, 72), (38, 68), (46, 69), (50, 67)], 5.0, 45),
    ([(71, 67), (78, 68), (83, 72), (87, 72), (92, 75)], 6.3, 37),
    ([(-4, 80), (0, 78), (3, 79), (7, 78), (11, 80)], 3.4, 46),
    ([(10, 89), (16, 85), (24, 82), (28, 78)], 6.2, -41),
    ([(33, 91), (38, 89), (45, 90), (48, 89)], 2.0, 44),
    ([(50, 82), (56, 77), (59, 76), (65, 77), (69, 74)], 6.1, -47),
    ([(69, 95), (73, 92), (86, 90), (92, 86), (95, 86)], 5.6, 44),
    ([(29, 100), (37, 102), (42, 100), (46, 98)], 3.3, -42),
]
# Connected breaks that descend across beds, with branches on a few shoulders.
SPLITS = [
    [(14, 23), (14, 27), (12, 30), (13, 34)],
    [(14, 27), (16, 29), (17, 32)],
    [(58, 5), (59, 9), (62, 12), (62, 17), (64, 20)],
    [(30, 39), (28, 44), (24, 47), (23, 52)],
    [(28, 44), (30, 47), (29, 51)],
    [(51, 29), (52, 34), (54, 37)],
    [(77, 45), (76, 51), (77, 55), (75, 58)],
    [(6, 49), (8, 54), (7, 57)],
    [(19, 64), (17, 70), (14, 74), (14, 79)],
    [(17, 70), (18, 71), (20, 72)],
    [(83, 72), (83, 76), (85, 79), (85, 83)],
    [(38, 89), (39, 94), (42, 97)],
    [(92, 18), (89, 20), (88, 24), (85, 28)],
]


def polygon(draw, pts, value):
    """Paint periodic copies, including shapes that touch a corner."""
    pts = np.asarray(pts, dtype=float)
    low, high = pts.min(axis=0), pts.max(axis=0)
    for x in range(int(np.ceil(-high[0] / 100)), int(np.floor(1 - low[0] / 100)) + 1):
        for y in range(int(np.ceil(-high[1] / 100)), int(np.floor(1 - low[1] / 100)) + 1):
            vertices = ((pts + (x * 100, y * 100)) * SCALE).round().astype(int)
            draw.polygon([tuple(point) for point in vertices], fill=int(value))


def ribbon(draw, path, width, value, offset=0):
    path = np.asarray(path, dtype=float)
    distances = np.r_[0., np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))]
    # Keep the geological corners. Abrade each intervening edge in unequal
    # strokes instead of drawing straight saw cuts with a constant-width pen.
    intervals = np.linspace(0, distances[-1], max(6, int(distances[-1] * 1.5)))
    visits = np.unique(np.r_[intervals, distances])
    path = np.stack([np.interp(visits, distances, axis) for axis in path.T], axis=1)
    tangent = np.gradient(path, visits, axis=0)
    normal = np.stack((-tangent[:, 1], tangent[:, 0]), axis=1)
    normal /= np.linalg.norm(normal, axis=1, keepdims=True)
    progress = visits / distances[-1]
    wear = RNG.uniform(.55, 1.15, len(path))
    taper = (np.sin(np.pi * progress) ** .72) * wear
    drift = np.sin(progress*np.pi) * RNG.uniform(-.08, .08, len(path))
    center = path + normal * (offset + drift[:, None])
    edge = normal * width * taper[:, None]
    polygon(draw, np.concatenate([center + edge, (center - edge)[::-1]]), value)


def worn_faces(size):
    # This is a fourth data channel, stored in the alpha byte. Values stay well
    # above zero because the map describes pigment, not geometric transparency.
    surface = Image.new("L", size, 128)
    draw = ImageDraw.Draw(surface)
    brush_rng = np.random.default_rng(12029)
    for path, thickness, mineral in BEDS:
        path = np.asarray(path, dtype=float)
        for k in (0, 1):
            j = int(brush_rng.integers(len(path)-1))
            tangent = path[j+1] - path[j]
            tangent /= np.linalg.norm(tangent)
            normal = np.array((-tangent[1], tangent[0]))
            center = (path[j]+path[j+1])*.5
            center += normal*thickness*(.65 if k == 0 else 1.4)
            # Read a ledge first and individual flecks second. The worn face
            # inherits a mineral value so its marks do not form alternating
            # bright/dark confetti. Dry, blunt ends taper into the same field.
            parent_value = 128 + mineral*.68
            for i in range(int(brush_rng.integers(9,19))):
                x = center + tangent*brush_rng.normal(0,2.5) + normal*brush_rng.normal(0,1.17)
                length = brush_rng.uniform(1.15,4.1)
                width = brush_rng.uniform(.24,1.02)
                if i < 3:
                    length *= 1.65
                    width *= 1.45
                delta = (parent_value + brush_rng.uniform(-16,16) - 128)
                if i == 3 and k == 0:
                    delta = -delta*.65
                # Cross-sections along a worn stratum: a broken hard shoulder,
                # a blunt middle shelf, then a long low-contrast swept tail.
                along = np.array([0, .09, .34, .46, .69, .87, 1.0])
                upper = width*np.array([0, .36, .42, .21, .22, .10, 0])
                lower = width*np.array([0, -.30, -.67, -.55, -.60, -.18, 0])
                drift = normal*brush_rng.uniform(-.45,.45)
                axis = x + along[:,None]*(tangent*length+drift)
                high = axis + upper[:,None]*normal
                low = axis + lower[:,None]*normal
                fade = [.43,.89,1,.79,.46,.21]
                for j,strength in enumerate(fade):
                    polygon(draw,[high[j],high[j+1],low[j+1],low[j]],128+delta*strength)
                if i == 2:
                    polygon(draw,[high[1],high[3],axis[3],axis[2]],
                            128+delta*1.16)
    return surface


def make_mask():
    dim = (SIDE * SUPERSAMPLE,) * 2
    faces, cracks, lips = [Image.new("L", dim, initial) for initial in (128, 0, 0)]
    fd, cd, ld = (ImageDraw.Draw(image) for image in (faces, cracks, lips))
    for index, (path, thickness, mineral) in enumerate(BEDS):
        path = np.asarray(path, dtype=float)
        # A short undercut ends inside a wide plane. Other strokes from the
        # same bed share its dip but stop before the next exposed section.
        belly = np.sin(np.pi * np.linspace(0, 1, len(path)))
        lower = path + np.stack((belly * RNG.uniform(0, 3), belly * thickness), axis=1)
        polygon(fd, np.concatenate((path, lower[::-1])), 128 + mineral)
        ledge = path[:max(3, len(path) - index % 3)]
        ribbon(cd, ledge, RNG.uniform(.18, .51), RNG.integers(133, 227))
        ribbon(ld, ledge, RNG.uniform(.16, .47), RNG.integers(110, 214), -.39)
        if index % 3 == 0:
            ribbon(ld, lower[-3:], .31, 131, .2)
        if index % 2 == 1:
            inset = (lower[:-1] * .55 + path[:-1] * .45) + (.6, .15)
            ribbon(fd, inset, RNG.uniform(.33, .68), 128 + mineral * .52)
    for path in SPLITS:
        ribbon(cd, path, RNG.uniform(.19, .46), RNG.integers(143, 226))
        ribbon(ld, path[:3], .18, RNG.integers(85, 162), -.39)

    # A few chipped shelves carry short pale flakes. Leave other planes quiet.
    for cx, cy, spread in [(12, 25, 3), (32, 39, 2.5), (50, 53, 4), (76, 43, 4),
                            (18, 64, 2), (86, 74, 4), (55, 80, 4), (91, 18, 3)]:
        for _ in range(21):
            x, y = RNG.normal([cx, cy], [spread, spread * .46])
            length, h = RNG.uniform(.4, 1.68), RNG.uniform(.09, .32)
            polygon(ld, [(x, y), (x + length, y - h), (x + length * .6, y + h)],
                    RNG.integers(53, 137))

    y, x = np.mgrid[:SIDE, :SIDE] * (2 * np.pi / SIDE)
    wave = (13 * np.sin(2 * x - y + .65 * np.sin(2 * y)) +
            10 * np.sin(x + 3 * y + .6 * np.cos(x)) + 5 * np.cos(4 * x + y))
    def down(image):
        return np.array(image.resize((SIDE, SIDE), Image.Resampling.LANCZOS), dtype=float)

    # Paint from the bed outward: part of a dark or warm plane bleeds into
    # adjacent rock, but its remaining hard edge still turns at the break.
    stain = down(faces.filter(ImageFilter.GaussianBlur(37))) - 128
    pigment = (128 + .52*(down(faces)-128)
               + .18*(down(faces.filter(ImageFilter.GaussianBlur(7)))-128)
               + .58*stain + wave)
    # Some mineral lines survive on an exposed plane, then wear completely
    # away. The lip and cavity do not disappear in exactly the same places.
    sweep = 2*x + 5*y + .9*np.sin(x-3*y)
    exposure = np.clip(.86 + .49*np.cos(sweep) + .36*np.sin(5*x-2*y), .21, 1)
    lip_survival = np.clip(.55 + .53*np.sin(4*x-3*y+np.sin(3*y))
                           + .27*np.cos(sweep+.8), .03, 1)
    scuff = worn_faces(dim)
    relief = (.80*down(scuff) + .20*down(scuff.filter(ImageFilter.GaussianBlur(3))))
    rgba = np.stack((pigment, down(cracks)*exposure, down(lips)*lip_survival, relief), axis=-1)
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8))


if __name__ == "__main__":
    make_mask().save(SOURCE, optimize=True)
