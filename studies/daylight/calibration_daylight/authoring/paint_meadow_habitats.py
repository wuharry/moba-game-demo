"""Paint two original, world-registered growing conditions for the terrace scene.

The coordinates are metres in the Godot X/Z plane. R marks the drier flowering
sward; G follows the cool margins of gullies and tree groups. B marks a
second, paler new growth in two clearings and on sheltered terrace rims.
Alpha stores exposed mineral earth under sparse grasses.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

X0, Z0 = -76., -122.
XM, ZM = 76., 60.
SIZE = (456, 546)  # 3 samples per metre

# Irregular open meadows separated by woody margins. The first follows the
# front rise; a narrower band stays lit below the west diagonal of rock.
SUN = [
    (244, 1.75, [(-29,23),(-18,19),(-14,17),(-9,16),(-6,13),(-2,14),
                 (4,14),(9,16),(13,14.2),(19,15.5),(26,13.8),(31,17),(42,16),
                 (49,19),(44,31),(43,51),(19,52),(-4,46),(-28,32)]),
    (243, 1.15, [(-33,14),(-27,10),(-25,8),(-21,8),(-18,3.4),(-16,4.8),
                 (-10,4.4),(-7,2.3),(-3,4.8),(-6.7,9.8),(-12,10.8),(-17,12.6),
                 (-22,12.4),(-29,16)]),
    (85, 2.2, [(13,7),(16,3),(21,2),(23,-2),(27,-4),(34,-8),
                (39,-15),(47,-17),(52,-14),(49,-3),(43,3),(32,7),(24,7),(18,10)]),
    (183, 1.8, [(-60,-37),(-46,-35),(-44,-28),(-31,-31),(-29,-26),
                 (-37,-19),(-46,-20),(-56,-17),(-62,-24)]),
    (142, 2.7, [(-27,-60),(-11,-59),(-2,-53),(2,-47),(-7,-43),(-22,-48)]),
    (174, 2.1, [(23,-48),(39,-49),(48,-57),(56,-56),(61,-45),(43,-36),(30,-39)]),
    (128, 3.0, [(1,-104),(29,-101),(36,-91),(21,-86),(13,-79),(-4,-83)])]
MOIST = [
    (237, 1.75, [(-26,2),(-17,0),(-12,-4),(-4,-7),(1,-4),(6,-6),(12,-5),
                 (14,-7),(19,-10),(23,-7),(20,-1),(13,.1),(8,4),(3,5),
                 (-.5,8),(-5,8),(-5,2.5),(-9,1.8),(-15,4)]),
    (173, 1.45, [(-27,11),(-21,8.5),(-17.3,9),(-15,7),(-11.5,9.3),
                 (-11.8,11.7),(-16,13),(-20,13),(-26,15)]),
    (221, 2.1, [(13,-34),(20,-28),(26,-26),(30,-29),(46,-31),(53,-24),
                 (46,-22),(40,-24),(33,-20),(24,-19),(16,-21)]),
    (213, 2.0, [(-58,-52),(-43,-48),(-30,-52),(-19,-47),(-17,-41),
                 (-28,-40),(-38,-43),(-47,-40),(-59,-44)]),
    (165, 2.3, [(-32,-88),(-18,-86),(-7,-90),(5,-87),(8,-77),(-2,-72),
                 (-17,-76),(-25,-74),(-39,-77)]),
    (174, 1.8, [(2,18),(5.3,13.8),(7.5,13),(8,10),(11.5,9.3),(12.6,11.7),
                 (10.5,14),(8.7,17.2),(5.5,20)])]

# The east meadow stays cooler than the forward lip. Between the darker west
# witnesses of the rock units a secondary new-growth strip spreads along the foot.
PALE = [
    # A companion cool-green sward among the three near clover openings;
    # its leaf colour eases out into the upper, ripe part of the oat bank.
    (235,1.85, [(17.0,17.7),(18.35,16.1),(21.8,16.1),(22.7,14.3),(25.6,13.6),
                (26.3,14.7),(29.0,15.75),(27.3,17.4),(26.4,18.8),(23.8,19.2),
                (21.7,18.65),(19.8,19.4),(17.6,18.6)]),
    (243, 2.0, [(16,1.2),(20.5,-1.7),(22.4,-6.4),(27,-6.6),(30,-11),(37,-14.9),
                 (47,-15.1),(49.7,-9.3),(45,-4),(37,0.8),(28,1.6),(23,4.3),(18,4.1)]),
    (221, 1.18, [(-40,15.4),(-32,13.2),(-27,8.9),(-21,7.2),(-17,4.4),(-12,4.1),
                  (-7.6,2.2),(-5,3.1),(-8.3,7.7),(-13,8.3),(-17,11.3),
                  (-25,13.7),(-36,18.7)]),
    (162, 2.6, [(-56,-65),(-39,-65),(-28,-61),(-23,-55),(-39,-55),(-50,-58)]),
    (146, 1.9, [(15,-64),(27,-62),(39,-66),(50,-62),(44,-57),(29,-56),(18,-57)])]

# Chalk-rich soil reaches out from the toe where rain and traffic have
# scuffed the short sward. Separate tongues leave unbroken grassy islands.
CALCAREOUS = [
    (240,.52,[(-28.4,9.1),(-24.2,7.85),(-20.7,8.1),(-17.9,9.6),(-18.7,10.35),
              (-19.9,10.1),(-21.4,11.35),(-24.8,10.45),(-28.8,10.75)]),
    (249,.46,[(-21.0,13.9),(-18.2,11.6),(-15.65,10.75),(-14.0,8.8),(-12.65,8.6),
              (-12.95,9.8),(-14.7,11.45),(-14.05,12.05),(-16.55,13.25),(-18.3,13.0),
              (-20.0,14.4)]),
    (230,.48,[(-13.0,14.3),(-11.4,12.6),(-9.2,12.0),(-7.9,10.8),(-6.95,11.5),
              (-8.15,12.5),(-7.4,13.2),(-9.2,13.6),(-10.2,13.4),(-12.1,14.85)]),
    (207,.45,[(-9.5,8.7),(-6.9,6.75),(-4.65,6.9),(-3.8,5.9),(-3.1,6.15),(-4.25,8.15),
              (-6.0,7.85),(-7.8,8.95)])]

def channel(washes):
    layer = Image.new("L",SIZE,0)
    for pigment, feather, polygon in washes:
        piece=Image.new("L",SIZE,0)
        coordinates=[((x-X0)/(XM-X0)*SIZE[0],(z-Z0)/(ZM-Z0)*SIZE[1]) for x,z in polygon]
        ImageDraw.Draw(piece).polygon(coordinates,fill=pigment)
        layer=ImageChops.lighter(layer,piece.filter(ImageFilter.GaussianBlur(feather*3)))
    return layer

output=Path(__file__).resolve().parents[1]/"assets/habitat_wash.png"
Image.merge("RGBA",(channel(SUN),channel(MOIST),channel(PALE),channel(CALCAREOUS))).save(output)
