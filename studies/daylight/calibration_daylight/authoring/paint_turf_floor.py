"""Original seamless data mask for soil visible through the grass, at 2.9 m per tile."""
from pathlib import Path
from random import Random
from math import sin, cos, pi
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
rng = Random(68107)
planes = [Image.new("L", (SIZE, SIZE), fill) for fill in (124, 0, 0)]
brushes = list(map(ImageDraw.Draw, planes))

def brush(plane, points, value):
    xs, ys = zip(*points)
    for dx in {0, -SIZE if max(xs) >= SIZE else SIZE if min(xs) < 0 else 0}:
        for dy in {0, -SIZE if max(ys) >= SIZE else SIZE if min(ys) < 0 else 0}:
            brushes[plane].polygon([(x+dx, y+dy) for x,y in points], fill=value)

def swipe(plane, x, y, length, width, bearing, bend, value):
    u, v = cos(bearing), sin(bearing)
    def at(along, across):
        return x+along*u-across*v, y+along*v+across*u
    brush(plane, [at(-.09*length, -.12*width), at(.13*length, -.43*width),
                  at(.52*length, bend-.31*width), at(length, bend+.08*width),
                  at(.57*length, bend+.35*width), at(.17*length,.5*width)], value)

# Distinct turf hummocks. Marks in a hummock share a leaning direction, and the
# spaces between hummocks retain soil and crossed remnants of last year's grass.
for stand in range(63):
    x, y = rng.uniform(0,SIZE), rng.uniform(0,SIZE)
    orientation = -.8 + .49*sin(x/SIZE*2*pi)+rng.uniform(-.75,.75)
    for _ in range(rng.randint(6,17)):
        cx,cy = (x+rng.gauss(0,28))%SIZE,(y+rng.gauss(0,15))%SIZE
        swipe(0,cx,cy,rng.uniform(16,65),rng.uniform(5,21),orientation+rng.uniform(-.4,.4),rng.uniform(-11,10),rng.randint(48,200))
    for _ in range(rng.randint(3,9)):
        base_x,base_y=(x+rng.gauss(0,26))%SIZE,(y+rng.gauss(0,18))%SIZE
        for j in range(rng.randint(2,4)):
            swipe(1,base_x+j*1.9,base_y,rng.uniform(12,42),rng.uniform(1.5,5.3),orientation+rng.uniform(-.84,.84),rng.uniform(-8,5),rng.randint(100,217))
for _ in range(36):
    x,y = rng.uniform(0,SIZE),rng.uniform(0,SIZE)
    bearing=rng.uniform(-2.1,1.2)
    for _ in range(rng.randint(3,9)):
        swipe(2,(x+rng.gauss(0,24))%SIZE,(y+rng.gauss(0,14))%SIZE,rng.uniform(10,33),
              rng.uniform(1.8,5.1),bearing+rng.uniform(-.65,.65),rng.uniform(-5,6),rng.randint(85,210))
output = Path(__file__).resolve().parents[1]/"assets/turf_floor.png"
# Pigment bleeds into the grassy soil. Keep only a few crisp ridges and
# remnant blades, so the low layer reads beneath the actual mesh leaves.
planes[0] = Image.blend(planes[0].filter(ImageFilter.GaussianBlur(4.4)),planes[0],.17)
planes[1] = planes[1].filter(ImageFilter.GaussianBlur(.85))
planes[2] = planes[2].filter(ImageFilter.GaussianBlur(.7))
Image.merge("RGB",planes).resize((512,512),Image.Resampling.LANCZOS).save(output)
