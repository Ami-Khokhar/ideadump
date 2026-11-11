#!/usr/bin/env python3
"""Generate richer TapLog mark concepts.

Rules learned from the two failed rounds:
  1. Silhouette first, detail second: a solid organic mass, then leaves on top.
  2. Leaves must TILE the canopy (spacing ~ leaf width), or the flat mass shows
     through and the mark reads as a blob with sprinkles.
  3. The trunk has to be a tree, not a stump: tall, tapered, with thick branches
     that reach up into the canopy and disappear inside it.
  4. Depth from layered flat tones, never gradients. Keep the pale tone rare so
     the canopy does not wash out.
"""
import math
import random

MOSS = "#2F5D43"
FERN = "#5F7D62"
SAGE = "#6B8F71"
LICHEN = "#DDE7D7"
BARK = "#6B4F3A"
CLAY = "#B5836A"
MARIGOLD = "#D9A441"
ROSE = "#C0849A"
PAPER = "#F8F5EE"


def n(v):
    return f"{v:.1f}"


def leaf_path(cx, cy, length, width, angle_deg):
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    px, py = -dy, dx
    hx, hy = dx * length / 2, dy * length / 2
    bx, by = cx - hx, cy - hy
    tx, ty = cx + hx, cy + hy
    w = width / 2

    def pt(fx, fy):
        return f"{n(fx)} {n(fy)}"

    c1 = (bx + dx * length * 0.30 + px * w, by + dy * length * 0.30 + py * w)
    c2 = (tx - dx * length * 0.30 + px * w, ty - dy * length * 0.30 + py * w)
    c3 = (tx - dx * length * 0.30 - px * w, ty - dy * length * 0.30 - py * w)
    c4 = (bx + dx * length * 0.30 - px * w, by + dy * length * 0.30 - py * w)
    return (
        f"M {pt(bx, by)} C {pt(*c1)} {pt(*c2)} {pt(tx, ty)} "
        f"C {pt(*c3)} {pt(*c4)} {pt(bx, by)} Z"
    )


def vein(cx, cy, length, angle_deg):
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    hx, hy = dx * length * 0.30, dy * length * 0.30
    return f"M {n(cx-hx)} {n(cy-hy)} L {n(cx+hx)} {n(cy+hy)}"


def mass(cx, cy, r, fill, seed, lobes=10, opacity=1.0):
    rng = random.Random(seed)
    out = []
    for i in range(lobes):
        ang = i * (360 / lobes) + rng.uniform(-14, 14)
        rr = r * rng.uniform(0.58, 0.72)
        dist = r * rng.uniform(0.42, 0.56)
        x = cx + math.cos(math.radians(ang)) * dist
        y = cy + math.sin(math.radians(ang)) * dist
        out.append(f'  <circle cx="{n(x)}" cy="{n(y)}" r="{n(rr)}" fill="{fill}" opacity="{opacity}"/>')
    out.append(f'  <circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r*0.86)}" fill="{fill}" opacity="{opacity}"/>')
    return out


def foliage(cx, cy, r, seed, tones, spacing=14.0, len_range=(16, 26),
            vein_col=None, spread=1.0):
    """Leaves tiling the canopy, drawn back to front, lit from the top-left."""
    rng = random.Random(seed)
    deep, mid, lite, hi = tones
    steps = max(2, int(round(2 * r * spread / spacing)))
    leaves = []
    for i in range(steps):
        for j in range(steps):
            gx = cx - r * spread + (2 * r * spread) * (i + 0.5) / steps + rng.uniform(-5, 5)
            gy = cy - r * spread + (2 * r * spread) * (j + 0.5) / steps + rng.uniform(-5, 5)
            if math.hypot(gx - cx, gy - cy) > r * spread:
                continue
            ang = math.degrees(math.atan2(gy - cy, gx - cx)) + 90 + rng.uniform(-55, 55)
            L = rng.uniform(*len_range)
            W = L * rng.uniform(0.52, 0.66)
            lit = (cy - gy) / (2 * r) + (cx - gx) / (2 * r) * 0.45
            if lit > 0.34:
                fill = hi
            elif lit > 0.08:
                fill = lite
            elif lit > -0.20:
                fill = mid
            else:
                fill = deep
            leaves.append((gy, gx, L, W, ang, fill))

    leaves.sort(key=lambda t: t[0])
    out = []
    for (ly, lx, L, W, ang, fill) in leaves:
        out.append(f'  <path d="{leaf_path(lx, ly, L, W, ang)}" fill="{fill}"/>')
        if vein_col:
            out.append(
                f'  <path d="{vein(lx, ly, L*0.8, ang)}" fill="none" '
                f'stroke="{vein_col}" stroke-width="{n(max(0.9, L*0.055))}" '
                f'stroke-linecap="round" opacity="0.30"/>'
            )
    return out


def trunk(cx, base_y, top_y, w_base, w_top, branches, bark=BARK, grain=CLAY):
    out = [
        f'  <path d="M {n(cx-w_base/2)} {n(base_y)} '
        f'Q {n(cx-w_top*0.72)} {n((base_y+top_y)/2)} {n(cx-w_top/2)} {n(top_y)} '
        f'L {n(cx+w_top/2)} {n(top_y)} '
        f'Q {n(cx+w_top*0.72)} {n((base_y+top_y)/2)} {n(cx+w_base/2)} {n(base_y)} Z" '
        f'fill="{bark}"/>'
    ]
    for i in range(5):
        yy = top_y + (base_y - top_y) * (i + 1) / 6
        half = (w_top + (w_base - w_top) * (i + 1) / 6) / 2
        out.append(
            f'  <path d="M {n(cx-half*0.66)} {n(yy)} L {n(cx+half*0.66)} {n(yy)}" '
            f'fill="none" stroke="{grain}" stroke-width="2.4" opacity="0.45"/>'
        )
    for (by, ex, ey, wdt) in branches:
        out.append(
            f'  <path d="M {n(cx)} {n(by)} Q {n((cx+ex*1.6)/2.6)} {n(by-46)} {n(ex)} {n(ey)}" '
            f'fill="none" stroke="{bark}" stroke-width="{wdt}" stroke-linecap="round"/>'
        )
    return out


def svg_doc(title, body, size=512):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" '
        f'role="img">\n  <title>{title}</title>\n{body}\n</svg>\n'
    )


# --------------------------------------------------------------------------
# R1 — Grove Seal: a lone detailed tree inside a deep moss seal
# --------------------------------------------------------------------------
def grove_seal():
    parts = [
        f'  <circle cx="256" cy="256" r="248" fill="{MOSS}"/>',
        f'  <circle cx="256" cy="256" r="222" fill="none" stroke="{LICHEN}" '
        f'stroke-width="3" opacity="0.26"/>',
        f'  <path d="M 118 406 Q 256 380 394 406 L 394 424 Q 256 400 118 424 Z" '
        f'fill="{BARK}" opacity="0.45"/>',
    ]
    parts += trunk(256, 412, 250, 54, 32,
                   [(320, 372, 270, 18), (300, 176, 248, 16),
                    (284, 334, 210, 13), (268, 200, 200, 12)],
                   bark=CLAY, grain=BARK)
    parts += mass(262, 220, 134, MOSS, seed=31)
    parts += mass(254, 210, 130, FERN, seed=32)
    parts += mass(246, 200, 101, SAGE, seed=33)
    parts += foliage(252, 206, 132, 41, (MOSS, FERN, SAGE, LICHEN),
                     spacing=13.5, len_range=(15, 25), vein_col=MOSS)
    for (fx, fy) in [(206, 174), (300, 214), (256, 246), (330, 176), (188, 232)]:
        parts.append(f'  <circle cx="{fx}" cy="{fy}" r="7.5" fill="{MARIGOLD}"/>')
    for (fx, fy) in [(232, 252), (286, 180)]:
        parts.append(f'  <circle cx="{fx}" cy="{fy}" r="6" fill="{ROSE}"/>')
    return svg_doc("TapLog — Grove Seal", "\n".join(parts))


# --------------------------------------------------------------------------
# R2 — Ledger Grove: one tree on paper, canopy of logged entries
# --------------------------------------------------------------------------
def ledger_grove():
    parts = [f'  <rect width="512" height="512" fill="{PAPER}"/>']
    parts.append(f'  <circle cx="256" cy="256" r="232" fill="none" stroke="{MOSS}" stroke-width="15"/>')
    parts.append(f'  <circle cx="256" cy="256" r="210" fill="none" stroke="{FERN}" stroke-width="2.5" opacity="0.4"/>')
    parts.append(f'  <path d="M 112 402 Q 256 376 400 402 L 400 414 Q 256 390 112 414 Z" fill="{LICHEN}"/>')
    parts += trunk(256, 406, 244, 56, 34,
                   [(322, 376, 272, 19), (302, 174, 250, 17),
                    (286, 338, 212, 14), (270, 202, 202, 13)])
    parts += mass(262, 218, 136, FERN, seed=51)
    parts += mass(254, 208, 132, SAGE, seed=52)
    parts += mass(244, 198, 100, LICHEN, seed=53, opacity=0.75)
    parts += foliage(252, 204, 134, 61, (MOSS, FERN, SAGE, LICHEN),
                     spacing=13.5, len_range=(15, 26), vein_col=LICHEN)
    for (fx, fy) in [(204, 170), (302, 212), (256, 248), (332, 170), (190, 226)]:
        parts.append(f'  <circle cx="{fx}" cy="{fy}" r="8" fill="{MARIGOLD}"/>')
    for (fx, fy, ang, col) in [(146, 306, -24, SAGE), (372, 272, 32, FERN),
                               (126, 356, 10, FERN), (388, 336, -16, SAGE)]:
        parts.append(f'  <path d="{leaf_path(fx, fy, 30, 16, ang)}" fill="{col}" opacity="0.9"/>')
        parts.append(f'  <path d="{vein(fx, fy, 24, ang)}" fill="none" stroke="{LICHEN}" stroke-width="1.3" opacity="0.6"/>')
    return svg_doc("TapLog — Ledger Grove", "\n".join(parts))


# --------------------------------------------------------------------------
# R3 — Ripple Bloom: layered ripples around a detailed sprig
# --------------------------------------------------------------------------
def ripple_bloom():
    parts = [f'  <rect width="512" height="512" fill="{PAPER}"/>']
    for (r, col, w, op) in [(236, MOSS, 20, 1.0), (196, FERN, 15, 0.95), (160, SAGE, 11, 0.9)]:
        parts.append(f'  <circle cx="256" cy="256" r="{r}" fill="none" stroke="{col}" stroke-width="{w}" opacity="{op}"/>')
    parts.append(f'  <circle cx="256" cy="256" r="132" fill="{LICHEN}" opacity="0.55"/>')

    parts.append(f'  <path d="M 256 344 L 256 172" fill="none" stroke="{FERN}" stroke-width="14" stroke-linecap="round"/>')
    for (px, py, ang, L, W, col) in [
        (214, 308, -38, 70, 34, MOSS), (298, 308, 38, 70, 34, MOSS),
        (220, 262, -32, 62, 31, FERN), (292, 262, 32, 62, 31, FERN),
        (228, 220, -26, 52, 27, SAGE), (284, 220, 26, 52, 27, SAGE),
    ]:
        parts.append(f'  <path d="{leaf_path(px, py, L, W, ang)}" fill="{col}"/>')
        parts.append(f'  <path d="{vein(px, py, L*0.84, ang)}" fill="none" stroke="{LICHEN}" stroke-width="1.7" opacity="0.55"/>')

    for k in range(6):
        ang = -90 + k * 60
        px = 256 + math.cos(math.radians(ang)) * 25
        py = 166 + math.sin(math.radians(ang)) * 25
        parts.append(f'  <ellipse cx="{n(px)}" cy="{n(py)}" rx="16" ry="23" fill="{ROSE}" transform="rotate({ang} {n(px)} {n(py)})"/>')
    parts.append(f'  <circle cx="256" cy="166" r="13" fill="{MARIGOLD}"/>')
    parts.append(f'  <circle cx="256" cy="166" r="5" fill="{BARK}" opacity="0.5"/>')
    return svg_doc("TapLog — Ripple Bloom", "\n".join(parts))


if __name__ == "__main__":
    for name, doc in {
        "rich-grove-seal.svg": grove_seal(),
        "rich-ledger-grove.svg": ledger_grove(),
        "rich-ripple-bloom.svg": ripple_bloom(),
    }.items():
        with open(name, "w", encoding="utf-8") as fh:
            fh.write(doc)
        print(f"wrote {name}  ({len(doc)} bytes)")
