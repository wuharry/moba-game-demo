"""Generate original Genshin-style textures for Sunvine Lookdev:
1. sunvine_clouds.png (2048x1024 RGBA): Painterly cumulus cloud field (R=silhouette, G=dome light, B=rim highlight, A=cirrus)
2. genshin_foliage_cards.png (1024x1024 RGBA): 2x2 botanical leaf-card clusters with dilated RGB bleed (zero fringe)
3. genshin_daylight_lut.png (256x16 RGB): 16x16x16 3D LUT for crisp anime daylight color grading
4. sunvine_stone_nh.png (512x512 RGBA): Stylized Blur-Slope rock & paving normal (RGB) + height (A)
"""

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


OUT_DIR = Path(__file__).resolve().parents[1] / "textures"


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if x < lo else (hi if x > hi else x)


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = clamp((x - e0) / max(1e-6, e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def hash2(ix: int, iy: int, seed: int = 1337) -> float:
    n = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / float(0x1000000)


def vnoise(x: float, y: float, period_x: int = 0, period_y: int = 0, seed: int = 1337) -> float:
    ix = math.floor(x)
    iy = math.floor(y)
    fx = x - ix
    fy = y - iy
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)

    def h(cx: int, cy: int) -> float:
        if period_x > 0:
            cx %= period_x
        if period_y > 0:
            cy %= period_y
        return hash2(cx, cy, seed)

    a = h(ix, iy)
    b = h(ix + 1, iy)
    c = h(ix, iy + 1)
    d = h(ix + 1, iy + 1)
    return (a + (b - a) * ux) + ((c - a) + (a - b - c + d) * ux) * uy


def fbm(x: float, y: float, octaves: int = 4, px: int = 0, py: int = 0, seed: int = 1337) -> float:
    val = 0.0
    amp = 0.5
    freq = 1
    norm = 0.0
    for o in range(octaves):
        val += amp * vnoise(x * freq, y * freq, px * freq if px else 0, py * freq if py else 0, seed + o * 97)
        norm += amp
        amp *= 0.5
        freq *= 2
    return val / norm


def build_lut() -> None:
    """16x16x16 3D LUT (256x16): Lifts darks with clean sky-cobalt tint, boosts lush emerald, warms sunlit highlights."""
    img = Image.new("RGB", (256, 16))
    px = img.load()
    for b_idx in range(16):
        for y in range(16):
            for x in range(16):
                r = x / 15.0
                g = y / 15.0
                b = b_idx / 15.0

                luma = 0.2126 * r + 0.7152 * g + 0.0722 * b

                # Subtle S-curve that preserves shadow clarity and brightens sunlit mid-highs
                shadow_mask = (1.0 - smoothstep(0.0, 0.48, luma)) ** 1.35
                hi_mask = smoothstep(0.45, 0.98, luma)

                # Chromatic shadow shift: push dark shadows gently toward clean cerulean/periwinkle, away from muddy brown
                r_s = r * (1.0 - 0.07 * shadow_mask) + 0.008 * shadow_mask
                g_s = g * (1.0 - 0.015 * shadow_mask) + 0.020 * shadow_mask
                b_s = b * (1.0 + 0.06 * shadow_mask) + 0.036 * shadow_mask

                # Clean vibrant midtone saturation boost (especially foliage greens & sky blues)
                avg = (r_s + g_s + b_s) / 3.0
                sat_boost = 1.13 - 0.06 * hi_mask
                r_c = avg + (r_s - avg) * sat_boost
                g_c = avg + (g_s - avg) * sat_boost
                b_c = avg + (b_s - avg) * sat_boost

                # Warm creamy-ivory highlight kiss
                r_c += 0.022 * hi_mask
                g_c += 0.014 * hi_mask
                b_c -= 0.010 * hi_mask

                # Gentle contrast polish
                def curve(c: float) -> float:
                    c = clamp(c)
                    return clamp(pow(c, 0.95) * 1.015 - 0.004)

                px[b_idx * 16 + x, y] = (
                    int(round(curve(r_c) * 255)),
                    int(round(curve(g_c) * 255)),
                    int(round(curve(b_c) * 255)),
                )
    img.save(OUT_DIR / "genshin_daylight_lut.png")
    print("Saved genshin_daylight_lut.png")


def build_clouds() -> None:
    """Painterly equirectangular upper-hemisphere cloud map (1536x768 -> upscaled/filtered to 2048x1024):
    u = azimuth [0..1] (seamless wrap!), v = elevation [0=horizon .. 1=zenith].
    R = crisp cumulus coverage, G = 24h vertical/sunward volume gradient, B = silver rim highlight, A = wispy cirrus.
    """
    W, H = 1024, 512
    cov = [[0.0] * W for _ in range(H)]
    dome = [[0.0] * W for _ in range(H)]
    cirrus = [[0.0] * W for _ in range(H)]

    rng = random.Random(20261125)

    # Place sculpted anime cumulus banks around the horizon/mid-sky (especially framing the main camera view!)
    # Camera looks roughly toward -Z (azimuth ~ 0.25..0.75 depending on atan2 convention; we place rich banks all around with varied heights!)
    banks = [
        # (u_center, v_base, width_u, height_v, puff_count, scale_strength)
        (0.14, 0.10, 0.16, 0.22, 18, 1.00),
        (0.36, 0.13, 0.19, 0.26, 22, 1.05),
        (0.58, 0.09, 0.15, 0.19, 16, 0.92),
        (0.79, 0.12, 0.18, 0.24, 20, 1.02),
        (0.95, 0.11, 0.12, 0.17, 13, 0.88),
        # Mid-high floating puffs
        (0.25, 0.34, 0.10, 0.11, 9, 0.72),
        (0.67, 0.31, 0.11, 0.12, 10, 0.75),
    ]

    puffs = []
    for bu, bv, bw, bh, count, strength in banks:
        for i in range(count):
            t = (i / max(1, count - 1)) * 2.0 - 1.0
            # Pyramid/billowing cumulus profile: taller in middle, cascading down sides
            arch = max(0.15, 1.0 - 0.72 * (t * t))
            pu = (bu + t * bw * 0.52 + rng.uniform(-0.018, 0.018)) % 1.0
            pv = bv + rng.uniform(0.0, bh * arch * 0.78)
            rx = rng.uniform(0.022, 0.052) * (0.75 + 0.45 * arch)
            ry = rx * rng.uniform(1.35, 1.85)
            puffs.append((pu, pv, rx, ry, strength * rng.uniform(0.82, 1.08), bv))

    for y in range(H):
        v = y / (H - 1.0)  # 0 = horizon, 1 = zenith
        for x in range(W):
            u = x / float(W)
            # Painterly brush warp (periodic in X!)
            warp_x = (fbm(u * 12.0, v * 6.0, 3, 12, 0, 101) - 0.5) * 0.024
            warp_y = (fbm(u * 12.0, v * 6.0, 3, 12, 0, 202) - 0.5) * 0.030
            fine = (fbm(u * 36.0, v * 18.0, 3, 36, 0, 303) - 0.5) * 0.16

            best_c = 0.0
            best_d = 0.0
            uu = (u + warp_x) % 1.0
            vv = v + warp_y

            for pu, pv, rx, ry, st, flat_base in puffs:
                du = abs(uu - pu)
                if du > 0.5:
                    du = 1.0 - du
                if du > rx * 1.45 or abs(vv - pv) > ry * 1.45:
                    continue
                dx = du / rx
                dy = (vv - pv) / ry
                # Flatten bottom of cumulus bank cleanly like Miyazaki clouds!
                if vv < flat_base:
                    dy *= 2.35
                dist = math.sqrt(dx * dx + dy * dy)
                val = (1.0 - smoothstep(0.52, 1.05, dist + fine * 0.45)) * st
                if val > best_c:
                    # Dome lighting: bright on upper/leftward sun-facing side of each puff!
                    puff_light = clamp(0.52 + 0.42 * dy - 0.22 * ((uu - pu + 0.5) % 1.0 - 0.5) / max(0.01, rx) + fine * 0.25)
                    best_c = val
                    best_d = puff_light

            # Crisp painterly step so clouds have sculpted edges, not高斯霧團!
            sculpted_c = smoothstep(0.22, 0.62, best_c) * smoothstep(0.02, 0.09, v) * (1.0 - smoothstep(0.58, 0.82, v))
            cov[y][x] = sculpted_c
            dome[y][x] = clamp(best_d * 0.68 + smoothstep(0.08, 0.36, v) * 0.32)

            # High wispy anime cirrus streaks
            ang_u = (u * 6.0 + v * 1.35) % 6.0
            streak = fbm(ang_u, v * 14.0, 4, 6, 0, 505)
            streak2 = fbm((u * 12.0 - v * 2.1) % 12.0, v * 22.0, 3, 12, 0, 606)
            wisp = smoothstep(0.60, 0.83, streak * 0.72 + streak2 * 0.28) * smoothstep(0.22, 0.48, v) * (1.0 - smoothstep(0.68, 0.92, v))
            cirrus[y][x] = wisp * 0.78

    img = Image.new("RGBA", (W, H))
    px = img.load()
    for y in range(H):
        ym = max(0, y - 3)
        yp = min(H - 1, y + 3)
        for x in range(W):
            xm = (x - 3) % W
            xp = (x + 3) % W
            c = cov[y][x]
            # Rim highlight = thin outer edge on upper/sunward contour of cumulus silhouette!
            grad_up = max(0.0, c - cov[yp][x])
            grad_side = abs(cov[y][xp] - cov[y][xm]) * 0.5
            edge_band = c * (1.0 - c) * 4.0
            rim = clamp((grad_up * 2.6 + grad_side * 1.1 + edge_band * 0.35) * smoothstep(0.08, 0.45, c))
            px[x, y] = (
                int(round(clamp(c) * 255)),
                int(round(clamp(dome[y][x]) * 255)),
                int(round(clamp(rim) * 255)),
                int(round(clamp(cirrus[y][x]) * 255)),
            )

    img = img.resize((2048, 1024), Image.Resampling.BICUBIC)
    img.save(OUT_DIR / "sunvine_clouds.png")
    print("Saved sunvine_clouds.png")


def draw_leaf(draw_rgb: ImageDraw.ImageDraw, draw_a: ImageDraw.ImageDraw, cx: float, cy: float,
              angle: float, length: float, width: float, base_col: tuple, tip_col: tuple, notched: bool = False) -> None:
    steps = 18
    ca, sa = math.cos(angle), math.sin(angle)
    nx, ny = -sa, ca
    pts_left = []
    pts_right = []
    for i in range(steps + 1):
        t = i / float(steps)
        # Tapered anime leaf profile
        if notched:
            # Sakura petal with delicate apical notch
            profile = math.sin(min(1.0, t * 1.12) * math.pi * 0.88) * (1.0 - 0.18 * smoothstep(0.82, 1.0, t))
        else:
            profile = math.sin(t * math.pi) ** 0.78 * (1.0 - 0.22 * t)
        w = width * profile
        curve = math.sin(t * math.pi) * width * 0.14
        px = cx + ca * (t * length) + nx * curve
        py = cy + sa * (t * length) + ny * curve
        pts_left.append((px + nx * w, py + ny * w))
        pts_right.append((px - nx * w, py - ny * w))

    if notched:
        tip_in = (cx + ca * (length * 0.90) + nx * (width * 0.10), cy + sa * (length * 0.90) + ny * (width * 0.10))
        poly = pts_left + [tip_in] + list(reversed(pts_right))
    else:
        poly = pts_left + list(reversed(pts_right))

    # Draw layered color from base to tip
    r = int(base_col[0] * 0.35 + tip_col[0] * 0.65)
    g = int(base_col[1] * 0.35 + tip_col[1] * 0.65)
    b = int(base_col[2] * 0.35 + tip_col[2] * 0.65)
    draw_rgb.polygon(poly, fill=(r, g, b))
    draw_a.polygon(poly, fill=255)

    # Inner lighter highlight lobe on upper half of leaf
    hi_pts = []
    for i in range(3, steps - 1):
        t = i / float(steps)
        w = width * 0.48 * math.sin(t * math.pi)
        px = cx + ca * (t * length) + nx * (width * 0.12)
        py = cy + sa * (t * length) + ny * (width * 0.12)
        hi_pts.append((px + nx * w, py + ny * w))
    for i in range(steps - 2, 2, -1):
        t = i / float(steps)
        px = cx + ca * (t * length) + nx * (width * 0.06)
        py = cy + sa * (t * length) + ny * (width * 0.06)
        hi_pts.append((px, py))
    if len(hi_pts) >= 3:
        draw_rgb.polygon(hi_pts, fill=tip_col)


def dilate_rgb_under_alpha(rgb: Image.Image, alpha: Image.Image, iterations: int = 16) -> Image.Image:
    """Prevent dark/white alpha mipmap fringes by bleeding valid leaf RGB outward into transparent pixels."""
    curr_rgb = rgb.copy()
    curr_a = alpha.copy()
    for _ in range(iterations):
        blurred_rgb = curr_rgb.filter(ImageFilter.BoxBlur(2))
        blurred_a = curr_a.filter(ImageFilter.MaxFilter(5))
        # Keep opaque pixels untouched, fill newly covered pixels from blurred_rgb
        curr_rgb = Image.composite(curr_rgb, blurred_rgb, curr_a)
        curr_a = blurred_a
    return curr_rgb


def build_foliage_cards() -> None:
    """2x2 2048->1024 supersampled botanical leaf cluster atlas (grayscale/neutralized value + crisp alpha so shader tints cleanly!)."""
    SS = 2048  # 2x supersampling -> 1024x1024 crisp anti-aliased cutout
    Q = SS // 2
    rgb = Image.new("RGB", (SS, SS), (185, 205, 165))
    alpha = Image.new("L", (SS, SS), 0)
    d_rgb = ImageDraw.Draw(rgb)
    d_a = ImageDraw.Draw(alpha)

    rng = random.Random(778899)

    # Quadrant (0,0): Lush Broadleaf Genshin Bough Cluster (dense center + crisp outer leaf tips!)
    d_rgb.rectangle([0, 0, Q, Q], fill=(195, 205, 190))
    cx0, cy0 = Q * 0.50, Q * 0.52
    for ring in range(4):
        count = [8, 12, 16, 14][ring]
        rad_offset = [0, 48, 118, 185][ring]
        val_lo = [156, 174, 198, 222][ring]
        val_hi = [188, 208, 234, 252][ring]
        for i in range(count):
            ang = (i / float(count)) * math.tau + ring * 0.41 + rng.uniform(-0.18, 0.18)
            sx = cx0 + math.cos(ang) * rad_offset * rng.uniform(0.55, 1.12)
            sy = cy0 + math.sin(ang) * rad_offset * rng.uniform(0.55, 1.12)
            length = rng.uniform(225, 295) * (1.06 - ring * 0.06)
            width = length * rng.uniform(0.30, 0.39)
            v0 = int(val_lo + rng.uniform(-6, 6))
            v1 = int(val_hi + rng.uniform(-4, 4))
            draw_leaf(d_rgb, d_a, sx, sy, ang + rng.uniform(-0.25, 0.25), length, width,
                      (v0, v0, v0), (v1, v1, v1), notched=False)

    # Quadrant (1,0): Sakura / Blossom Cluster (full center + delicate outer blossom sprays)
    d_rgb.rectangle([Q, 0, SS, Q], fill=(220, 205, 205))
    cx1, cy1 = Q + Q * 0.50, Q * 0.52
    for ring in range(4):
        blossoms = [5, 8, 11, 10][ring]
        rad = [18, 85, 175, 255][ring]
        val_lo = [172, 192, 212, 230][ring]
        val_hi = [206, 226, 244, 254][ring]
        for b in range(blossoms):
            ba = (b / float(blossoms)) * math.tau + ring * 0.51 + rng.uniform(-0.22, 0.22)
            bx = cx1 + math.cos(ba) * rad * rng.uniform(0.55, 1.10)
            by = cy1 + math.sin(ba) * rad * rng.uniform(0.55, 1.10)
            petals = 5
            rot0 = rng.uniform(0, math.tau)
            plen = rng.uniform(110, 155) * (1.06 - ring * 0.06)
            for p in range(petals):
                pa = rot0 + p * (math.tau / petals) + rng.uniform(-0.08, 0.08)
                draw_leaf(d_rgb, d_a, bx, by, pa, plen, plen * 0.46,
                          (val_lo, val_lo, val_lo), (val_hi, val_hi, val_hi), notched=True)

    # Quadrant (0,1): Slender Olive / Golden Willow-Ginkgo Spray (dense center + graceful tips)
    d_rgb.rectangle([0, Q, Q, SS], fill=(210, 205, 185))
    cx2, cy2 = Q * 0.50, Q + Q * 0.52
    for ring in range(4):
        count = [9, 13, 18, 15][ring]
        rad_offset = [0, 45, 112, 178][ring]
        val_lo = [162, 182, 206, 226][ring]
        val_hi = [196, 218, 238, 253][ring]
        for i in range(count):
            ang = (i / float(count)) * math.tau + ring * 0.42 + rng.uniform(-0.20, 0.20)
            sx = cx2 + math.cos(ang) * rad_offset * rng.uniform(0.55, 1.12)
            sy = cy2 + math.sin(ang) * rad_offset * rng.uniform(0.55, 1.12)
            length = rng.uniform(235, 305) * (1.05 - ring * 0.06)
            width = length * rng.uniform(0.22, 0.29)
            draw_leaf(d_rgb, d_a, sx, sy, ang + rng.uniform(-0.22, 0.22), length, width,
                      (val_lo, val_lo, val_lo), (val_hi, val_hi, val_hi), notched=False)

    # Quadrant (1,1): Ground Lush Shrub / Fern-Clover Tuft (bottom-rooted!)
    d_rgb.rectangle([Q, Q, SS, SS], fill=(190, 208, 185))
    bx3, by3 = Q + Q * 0.50, SS - 42
    for layer in range(3):
        blades = [11, 13, 9][layer]
        val_lo = [155, 185, 212][layer]
        val_hi = [198, 228, 248][layer]
        for i in range(blades):
            frac = (i / max(1, blades - 1)) * 2.0 - 1.0
            ang = -math.pi * 0.5 + frac * 1.08 + rng.uniform(-0.08, 0.08)
            sx = bx3 + frac * 165 + rng.uniform(-18, 18)
            sy = by3 - layer * 16 + rng.uniform(-8, 8)
            length = rng.uniform(360, 560) * (1.0 - 0.22 * abs(frac))
            width = length * rng.uniform(0.14, 0.21)
            draw_leaf(d_rgb, d_a, sx, sy, ang, length, width,
                      (val_lo, val_lo, val_lo), (val_hi, val_hi, val_hi), notched=False)

    rgb_dilated = dilate_rgb_under_alpha(rgb, alpha, iterations=12)
    out = Image.merge("RGBA", (*rgb_dilated.split(), alpha))
    out = out.resize((1024, 1024), Image.Resampling.LANCZOS)
    out.save(OUT_DIR / "genshin_foliage_cards.png")
    print("Saved genshin_foliage_cards.png")


def build_stone_nh() -> None:
    """512x512 seamless Blur-Slope stylized rock & flagstone height (A) + normal map (RGB)."""
    N = 512
    hmap = [[0.0] * N for _ in range(N)]
    for y in range(N):
        v = y / float(N)
        for x in range(N):
            u = x / float(N)
            # Stepped planar rock facets (Blur-Slope inspired!)
            n1 = fbm(u * 4.0, v * 4.0, 3, 4, 4, 901)
            n2 = fbm(u * 8.0 + n1 * 0.35, v * 8.0 - n1 * 0.28, 3, 8, 8, 902)
            # Terraced / quantized bevel planes + smooth brush polish
            terraced = math.floor(n1 * 5.0) / 5.0 + smoothstep(0.65, 0.95, (n1 * 5.0) % 1.0) * 0.2
            chisel = fbm(u * 16.0, v * 16.0, 2, 16, 16, 903)
            hmap[y][x] = clamp(terraced * 0.58 + n2 * 0.30 + chisel * 0.12)

    img = Image.new("RGBA", (N, N))
    px = img.load()
    strength = 2.6
    for y in range(N):
        ym = (y - 1) % N
        yp = (y + 1) % N
        for x in range(N):
            xm = (x - 1) % N
            xp = (x + 1) % N
            dx = (hmap[y][xp] - hmap[y][xm]) * strength
            dy = (hmap[yp][x] - hmap[ym][x]) * strength
            nx, ny, nz = -dx, -dy, 1.0
            inv = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
            nx, ny, nz = nx * inv, ny * inv, nz * inv
            px[x, y] = (
                int(round((nx * 0.5 + 0.5) * 255)),
                int(round((ny * 0.5 + 0.5) * 255)),
                int(round((nz * 0.5 + 0.5) * 255)),
                int(round(hmap[y][x] * 255)),
            )
    img.save(OUT_DIR / "sunvine_stone_nh.png")
    print("Saved sunvine_stone_nh.png")


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_lut()
    build_clouds()
    build_foliage_cards()
    build_stone_nh()
