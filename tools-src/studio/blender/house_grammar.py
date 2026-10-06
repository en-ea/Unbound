"""Graphics S5 (studio plan GRAPHICS-STAGES-2026-10-04.md): an explicit grammar for houses and stalls over Enea's own
helpers, tools-src/blender/make_buildings.py and lowpoly.py, which it imports and never edits.

A house is a spec: plain data (a dict) naming its style and every part, with the numbers the part is built from.
build(spec) draws a spec with his helpers, part by part in a fixed order, drawing randomness from his module's own
`rnd` exactly as his functions do. So the preset specs of his houses (PRESETS) come out as his script makes them,
byte for byte when built in his order (cottage, then cabin, then round house, from his seed 9: preset_order()).

vary(style, seed) makes a new spec of a style by rules, and check(spec) checks how its parts join: nothing floats
(a chimney rises through the roof, a dormer sits on it, a porch roof meets the wall it covers), openings stay on their
wall and clear of each other, and the house stays within his footprint for its place. A variant draws its randomness
from its own seed, so the same seed is the same house.

Styles: "timber" (his cottage: plaster and timber framing, a tiered shingle roof), "log" (his cabin: round logs, a
slate roof, a porch), "round" (his round house: a plaster drum under a tall layered straw cone) and "stall" (a market
stall: posts, a counter, a striped awning, goods). Parts are tagged in the spec, so S1 can tell them apart later.

Run (Blender as the bpy module, in the background):
  ~/blender-venv/bin/python tools-src/studio/blender/house_grammar.py -- <out dir> presets|variants|stalls|all
"""
import copy
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HIS = os.path.abspath(os.path.join(HERE, "..", "..", "blender"))
sys.dont_write_bytecode = True               # (his folder carries his own .pyc files; never touch them)
sys.path.insert(0, HIS)

import bpy  # noqa: E402
import make_buildings as mb  # noqa: E402
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump, export  # noqa: E402
from make_buildings import V, box, beam, slab, tiered_roof, window, door, barrel, log, disc, paint  # noqa: E402

PALETTES = {"RED_ROOF": mb.RED_ROOF, "SLATE": mb.SLATE, "STRAW": mb.STRAW, "WOOD": mb.WOOD, "STONE": mb.STONE,
            "SHINGLE": mb.SHINGLE, "STRAW_SOFT": mb.STRAW_SOFT, "MOSS": mb.MOSS}
GARDEN = [(0.92, 0.4, 0.5), (0.98, 0.8, 0.3), (0.45, 0.66, 0.3), (0.62, 0.5, 0.9)]
PICKET = (0.93, 0.9, 0.84)


def _pal(name):
    return PALETTES[name]


def _col(c):
    """A colour in a spec: an RGB tuple, or [palette, index]."""
    return _pal(c[0])[c[1]] if isinstance(c, (list, tuple)) and isinstance(c[0], str) else tuple(c)


# --- timber (his cottage) ---------------------------------------------------------------------------------------

def _timber(b, s):
    W, D, H, F = s["W"], s["D"], s["H"], s["F"]
    fd = s["foundation"]
    nf, ns = fd["front_div"], fd["side_div"]
    for i in range(-(nf // 2), nf // 2 + 1):            # stone-block foundation
        for y in (-D / 2 - 0.05, D / 2 + 0.05):
            box(b, V((i * W / nf, y, F / 2 - 0.1)), (W / nf - 0.03, 0.3, F + 0.2), mb.rnd.choice(mb.STONE), 0.05)
    for i in range(-(ns // 2), ns // 2 + 1):
        for x in (-W / 2 - 0.05, W / 2 + 0.05):
            box(b, V((x, i * D / ns, F / 2 - 0.1)), (0.3, D / ns - 0.03, F + 0.2), mb.rnd.choice(mb.STONE), 0.05)
    box(b, V((0, 0, F + H / 2)), (W, D, H), _col(s["wall"]))
    for x in [sg * W / k for sg, k in s["posts"]]:      # timber framing: posts, beams, braces
        for y in (-D / 2 - 0.02, D / 2 + 0.02):
            beam(b, V((x, y, F)), V((x, y, F + H)), 0.09, _col(s["timber"]))
    for y in (-D / 2 - 0.03, D / 2 + 0.03):
        for z in (F + 0.05, F + H * 0.55, F + H):
            beam(b, V((-W / 2, y, z)), V((W / 2, y, z)), 0.08, _col(s["timber"]))
    for y in (-D / 2, D / 2):
        for x in (-W / 2 - 0.02, W / 2 + 0.02):
            beam(b, V((x, y, F)), V((x, y, F + H)), 0.1, _col(s["timber"]))
            beam(b, V((x, y * 0.3, F + H * 0.55)), V((x, y, F + H)), 0.06, _col(s["timber"]))
    door(b, s["door"]["x"], -D / 2, F)
    for w in s["windows"]:
        window(b, w["x"], F + w["z"], -D / 2, flowers=w["flowers"])
    r = s["roof"]
    tiered_roof(b, V((0, 0, F + H)), W, D, r["rise"], r["overhang"], r["rows"], _pal(r["palette"]), _col(s["timber"]),
                _col(s["wall"]))
    c = s.get("chimney")
    if c:                                               # stone chimney with a cap
        for i in range(c["n"]):
            box(b, V((c["x"], c["y"], F + H + c["base"] + i * 0.3)), (0.62, 0.62, 0.3), mb.rnd.choice(mb.STONE), 0.06)
        box(b, V((c["x"], c["y"], F + H + c["cap"])), (0.78, 0.78, 0.12), mb.STONE[3])
    p = s.get("porch")
    if p:                                               # a covered porch over the door
        for x in p["posts"]:
            beam(b, V((x, -D / 2 - p["depth"], 0)), V((x, -D / 2 - p["depth"], F + p["low"])), 0.08, _col(s["timber"]))
        slab(b, [V((p["x0"], -D / 2 - p["reach"], F + p["low"])), V((p["x1"], -D / 2 - p["reach"], F + p["low"])),
                 V((p["x1"], -D / 2, F + p["high"])), V((p["x0"], -D / 2, F + p["high"]))], 0.1, _col(p["color"]))
    d = s.get("dormer")
    if d:                                               # a roof dormer
        box(b, V((d["x"], d["y"], F + H + d["z"])), (0.9, 0.8, 0.8), _col(s["wall"]))
        window(b, d["x"], F + H + d["z"], d["front"], 0.45, 0.45)
        slab(b, [V((d["x0"], d["y0"], F + H + d["low"])), V((d["x1"], d["y0"], F + H + d["low"])),
                 V((d["x1"], d["y1"], F + H + d["high"])), V((d["x0"], d["y1"], F + H + d["high"]))], 0.08, _col(d["color"]))
    f = s.get("fence")
    if f:                                               # a picket fence across the front, open at the path
        sh = f.get("shift")                             # (a variant's gate follows its door)
        for i in range(-f["half"], f["half"] + 1):
            if abs(i) < f["gap"]:
                continue
            x = i * f["step"] if sh is None else i * f["step"] + sh
            box(b, V((x, -D / 2 - f["front"], 0.35)), (0.08, 0.06, 0.7), PICKET, 0.02)
        for y in f["rails"]:
            for sg in (-1, 1):
                x = sg * f["rail_x"] if sh is None else sg * f["rail_x"] + sh
                box(b, V((x, -D / 2 - f["rail_front"], y)), (f["rail_len"], 0.05, 0.06), PICKET, 0.02)
    g = s.get("garden")
    if g:                                               # a garden bed
        box(b, V((g["x"], -D / 2 - g["y"], 0.1)), (2.0, 0.9, 0.2), (0.4, 0.3, 0.22))
        for i in range(12):
            clump(b, V((g["x0"] + i * 0.16, -D / 2 - g["y"] + (i % 3 - 1) * 0.22, 0.28)), 0.1, 1, mb.rnd,
                  mb.rnd.choice(GARDEN), "Build", 1.0)
    t = s.get("leanto")
    if t:                                               # a lean-to with barrels and a crate
        lx = t["side"] * W / 2 + t["side"] * t["gap"] if t["side"] > 0 else -W / 2 - t["gap"]
        o = t["side"]                                   # (mirrored on the right: the low edge stays outside)
        for y in (-0.9, 0.9):
            beam(b, V((lx + o * 0.6, y, 0)), V((lx + o * 0.6, y, 1.9)), 0.08, _col(s["timber"]))
        slab(b, [V((lx + o * 0.9, -1.2, 1.95)), V((lx - o * 0.9, -1.2, 2.5)), V((lx - o * 0.9, 1.2, 2.5)),
                 V((lx + o * 0.9, 1.2, 1.95))] if o > 0 else
             [V((lx - 0.9, -1.2, 1.95)), V((lx + 0.9, -1.2, 2.5)), V((lx + 0.9, 1.2, 2.5)), V((lx - 0.9, 1.2, 1.95))],
             0.08, _col(t["color"]))
        barrel(b, V((lx - o * 0.1, -0.5, 0)) if o > 0 else V((lx - 0.1, -0.5, 0)))
        barrel(b, V((lx + o * 0.1, 0.25, 0)) if o > 0 else V((lx + 0.1, 0.25, 0)))
        box(b, V((lx - o * 0.1, -1.35, 0.25)) if o > 0 else V((lx - 0.1, -1.35, 0.25)), (0.5, 0.5, 0.5), mb.WOOD[2])


# --- log (his cabin) --------------------------------------------------------------------------------------------

def _log(b, s):
    W, D, H, F = s["W"], s["D"], s["H"], s["F"]
    trim = _col(s["trim"])
    box(b, V((0, 0, F / 2 - 0.05)), (W + 0.4, D + 0.4, F + 0.1), _col(s["plinth"]), 0.05)
    z = F + 0.15
    while z < F + H:                                    # round logs, ends crossing at the corners
        for y in (-D / 2, D / 2):
            log(b, V((-W / 2 - 0.3, y, z)), V((W / 2 + 0.3, y, z)))
        for x in (-W / 2, W / 2):
            log(b, V((x, -D / 2 - 0.3, z + 0.14)), V((x, D / 2 + 0.3, z + 0.14)))
        z += 0.28
    box(b, V((0, 0, F + H / 2)), (W - 0.1, D - 0.1, H), _col(s["core"]), 0.0)
    door(b, s["door"]["x"], -D / 2 - 0.1, F, frame=trim)
    for w in s["windows"]:
        window(b, w["x"], F + w["z"], -D / 2 - 0.12, frame=trim)
    r = s["roof"]
    tiered_roof(b, V((0, 0, F + H + 0.1)), W, D, r["rise"], r["overhang"], r["rows"], _pal(r["palette"]), trim,
                _col(s["core"]))
    c = s.get("chimney")
    if c:                                               # a stone chimney up one side
        for i in range(c["n"]):
            sh = 0.2 if i > c["step"] else 0.0
            box(b, V((c["side"] * W / 2 + c["side"] * 0.35 if c["side"] > 0 else -W / 2 - 0.35, c["y"], 0.25 + i * 0.32)),
                (0.7 - sh, 0.8 - sh, 0.32), mb.rnd.choice(mb.STONE), 0.06)
    p = s.get("porch")
    if p:                                               # plank porch, rails, steps and a slate porch roof
        for i in range(p["planks"]):
            y0 = -D / 2 - 0.15 - i * 0.2
            slab(b, [V((-W / 2, y0, F + 0.05)), V((W / 2, y0, F + 0.05)), V((W / 2, y0 - 0.18, F + 0.05)),
                     V((-W / 2, y0 - 0.18, F + 0.05))], 0.08, mb.rnd.choice(mb.WOOD))
        front = -D / 2 - p["front"]
        post = _col(p["post"])
        for x in p["posts"]:
            beam(b, V((x, front, 0)), V((x, front, F + 2.2)), 0.08, post)
        for x0, x1 in p["rails"]:
            beam(b, V((x0, front, F + 0.75)), V((x1, front, F + 0.75)), 0.05, post)
        for i in range(3):                              # steps
            box(b, V((p["steps_x"], front - 0.25 - i * 0.3, F - 0.1 - i * 0.14)), (1.3, 0.3, 0.12), mb.rnd.choice(mb.WOOD))
        slab(b, [V((-W / 2 - 0.2, front - 0.3, F + 2.25)), V((W / 2 + 0.2, front - 0.3, F + 2.25)),
                 V((W / 2 + 0.2, -D / 2, F + 2.7)), V((-W / 2 - 0.2, -D / 2, F + 2.7))], 0.1, _col(p["roof"]))
    lamp = s.get("lamp")
    if lamp:
        b.paint(b.new_faces(lambda: rk.blob(b.bm, V((lamp["x"], -D / 2 - 0.2, F + 1.95)), (0.11, 0.11, 0.15), 6, 4)),
                "Glow", (1.0, 0.72, 0.35))
    wp = s.get("woodpile")
    if wp:
        for row in range(3):
            for i in range(5 - row):
                q = V((wp["side"] * W / 2 + wp["side"] * 1.0 if wp["side"] > 0 else -W / 2 - 1.0,
                       -1.0 + i * 0.3 + row * 0.15, 0.15 + row * 0.26))
                log(b, q, q + V((0.7, 0, 0)), 0.13)


# --- round (his round house) --------------------------------------------------------------------------------------

def _round(b, s):
    R, H, F = s["R"], s["H"], s["F"]
    timber = _col(s["timber"])
    for i in range(s["stones"]):                        # a ring of footing stones
        a = i / s["stones"] * math.tau
        box(b, V((math.cos(a) * (R + 0.08), math.sin(a) * (R + 0.08), F / 2 - 0.1)), (0.62, 0.62, F + 0.2),
            mb.rnd.choice(mb.STONE), 0.06)
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, F)), V((0, 0, F + H))], [(R, R)] * 2, seg=14)), _col(s["wall"]), 0.02)
    for i in range(7):                                  # timber posts around the wall (none over the door)
        a = -math.pi / 2 + (i + 1) / 8 * math.tau
        q = V((math.cos(a) * (R + 0.03), math.sin(a) * (R + 0.03), 0))
        beam(b, q + V((0, 0, F)), q + V((0, 0, F + H)), 0.08, timber)
    for z in (F + 0.05, F + H - 0.05):                  # beams ringing the wall
        paint(b, b.new_faces(lambda z=z: rk.tube(b.bm, [V((0, 0, z - 0.06)), V((0, 0, z + 0.06))], [(R + 0.06, R + 0.06)] * 2, seg=14)), timber)
    straw = _pal(s["roof"]["palette"])
    top = F + H + s["roof"]["rise"]                     # layered cones, each tier ragged at the rim
    for r0, z0, r1 in [(R + 0.42, F + H - 0.05, R * 0.6), (R * 0.66 + 0.18, F + H + 1.0, R * 0.36), (R * 0.4 + 0.12, F + H + 2.0, 0.18)]:
        z1 = min(top, z0 + 1.45)
        faces = b.new_faces(lambda r0=r0, z0=z0, r1=r1, z1=z1: rk.tube(
            b.bm, [V((0, 0, z0)), V((0, 0, z0 + 0.22)), V((0, 0, z1))], [(r0, r0), (r0 * 0.96, r0 * 0.96), (r1, r1)], seg=16))
        for f in faces:
            for v in f.verts:
                if v.co.z < z0 + 0.05:
                    v.co.z -= mb.rnd.uniform(0.0, 0.12)
        for f in faces:
            b.paint([f], "Build", mb.rnd.choice(straw))
    paint(b, b.new_faces(lambda: rk.tube(b.bm, [V((0, 0, top - 0.5)), V((0, 0, top + 0.15))], [(0.3, 0.3), (0.04, 0.04)], seg=8)), straw[3])
    beam(b, V((0, 0, top - 0.1)), V((0, 0, top + 0.55)), 0.04, timber)
    clump(b, V((0, 0, top + 0.6)), 0.09, 1, mb.rnd, (0.85, 0.72, 0.4), "Build", 1.0)
    fy = -R - 0.02                                      # arched door with a stone step
    box(b, V((0, fy, F + 0.8)), (1.0, 0.12, 1.6), timber)
    disc(b, V((0, fy + 0.02, F + 1.6)), 0.5, 0.12, timber, 12)
    for i in range(3):
        box(b, V((-0.28 + i * 0.28, fy - 0.05, F + 0.78)), (0.26, 0.06, 1.5), mb.rnd.choice(mb.WOOD[:2]))
    disc(b, V((0, fy - 0.06, F + 1.6)), 0.4, 0.06, mb.WOOD[1], 12)
    box(b, V((0.28, fy - 0.12, F + 0.9)), (0.07, 0.05, 0.07), (0.85, 0.72, 0.4), 0.0)
    box(b, V((0, fy - 0.45, F - 0.12)), (1.4, 0.6, 0.2), mb.STONE[0])
    for w in s["windows"]:                              # round windows with flower boxes; lit ones glow warm
        a, lit = w["a"], w["lit"]
        out = V((math.cos(a), math.sin(a), 0))
        q = out * (R + 0.02) + V((0, 0, F + 1.35))
        paint(b, b.new_faces(lambda q=q, out=out: rk.tube(b.bm, [q - out * 0.02, q + out * 0.1], [(0.42, 0.42)] * 2, ref=V((0, 0, 1)), seg=10)), timber)
        glass = b.new_faces(lambda q=q, out=out: rk.tube(b.bm, [q + out * 0.08, q + out * 0.12], [(0.32, 0.32)] * 2, ref=V((0, 0, 1)), seg=10))
        if lit:
            b.paint(glass, "Glow", (1.0, 0.78, 0.42))
        else:
            paint(b, glass, mb.GLASS, 0.0)
        beam(b, q + out * 0.13 + V((0, 0, -0.32)), q + out * 0.13 + V((0, 0, 0.32)), 0.03, timber)
        box(b, q + out * 0.22 + V((0, 0, -0.46)), (0.55, 0.3, 0.12), (0.55, 0.38, 0.24))
        side = V((-out.y, out.x, 0))
        for k in range(4):
            clump(b, q + out * 0.24 + side * ((k - 1.5) * 0.12) + V((0, 0, -0.36)), 0.07, 1, mb.rnd,
                  mb.rnd.choice(mb.FLOWERS), "Build", 1.0)
    c = s.get("chimney")
    if c:                                               # a crooked stone chimney poking out of the straw
        for i in range(9):
            box(b, V((c["x"] + i * 0.035, c["y"] - i * 0.01, F + H + 0.5 + i * 0.3)), (0.55, 0.55, 0.3), mb.rnd.choice(mb.STONE), 0.06)
        box(b, V((c["cap_x"], c["cap_y"], F + H + 3.2)), (0.7, 0.7, 0.1), mb.STONE[3])
    e = s.get("extras")
    if e:                                               # a lantern by the door, a bench, two planted pots
        beam(b, V((0.75, fy - 0.02, F + 2.0)), V((0.75, fy - 0.4, F + 2.0)), 0.03, (0.2, 0.18, 0.18))
        b.paint(b.new_faces(lambda: rk.blob(b.bm, V((0.75, fy - 0.4, F + 1.8)), (0.1, 0.1, 0.14), 6, 4)), "Glow", (1.0, 0.72, 0.35))
        box(b, V((-1.35, fy - 0.35, 0.45)), (1.2, 0.36, 0.08), mb.WOOD[2])
        for x in (-1.8, -0.9):
            box(b, V((x, fy - 0.35, 0.22)), (0.1, 0.3, 0.44), mb.WOOD[1])
        for x, y in ((1.3, fy - 0.3), (1.65, fy - 0.1)):
            paint(b, b.new_faces(lambda x=x, y=y: rk.tube(b.bm, [V((x, y, 0)), V((x, y, 0.35))], [(0.16, 0.16), (0.2, 0.2)], seg=8)), (0.72, 0.42, 0.28))
            clump(b, V((x, y, 0.45)), 0.18, 1, mb.rnd, mb.rnd.choice(mb.MOSS), "Build", 0.9)


# --- stall (new: a market stall from his parts) -------------------------------------------------------------------

def _stall(b, s):
    W, D = s["W"], s["D"]
    post = _col(s["post"])
    for x in (-W / 2, W / 2):                           # four posts, the back pair taller: the awning slopes forward
        beam(b, V((x, -D / 2, 0)), V((x, -D / 2, 2.0)), 0.09, post)
        beam(b, V((x, D / 2, 0)), V((x, D / 2, 2.45)), 0.09, post)
    box(b, V((0, -D / 2 + 0.25, 0.85)), (W - 0.1, 0.5, 0.08), _col(s["counter"]))     # counter top and its front
    box(b, V((0, -D / 2 + 0.05, 0.42)), (W - 0.1, 0.06, 0.82), _col(s["front"]))
    n = s["stripes"]                                    # the striped awning: a slab per stripe, alternating colours
    for i in range(n):
        x0, x1 = -W / 2 - 0.15 + i * (W + 0.3) / n, -W / 2 - 0.15 + (i + 1) * (W + 0.3) / n
        slab(b, [V((x0, -D / 2 - 0.45, 1.95)), V((x1, -D / 2 - 0.45, 1.95)), V((x1, D / 2 + 0.1, 2.5)),
                 V((x0, D / 2 + 0.1, 2.5))], 0.06, _col(s["cloth"][i % 2]))
    for i in range(n):                                  # a scalloped valance along the front edge
        x = -W / 2 - 0.15 + (i + 0.5) * (W + 0.3) / n
        box(b, V((x, -D / 2 - 0.47, 1.83)), ((W + 0.3) / n - 0.04, 0.04, 0.2), _col(s["cloth"][i % 2]))
    for g in s["goods"]:                                # goods on the counter and crates and barrels about it
        k, x = g["kind"], g["x"]
        if k == "produce":
            for i in range(5):
                clump(b, V((x + (i - 2) * 0.13, -D / 2 + 0.2 + (i % 2) * 0.12, 0.98)), 0.08, 1, mb.rnd,
                      _col(g["color"]), "Build", 1.0)
        elif k == "crate":
            box(b, V((x, -D / 2 - 0.5, 0.25)), (0.5, 0.5, 0.5), mb.rnd.choice(mb.WOOD))
        elif k == "barrel":
            barrel(b, V((x, D / 2 - 0.2, 0)))
        elif k == "sacks":
            for i in range(3):
                clump(b, V((x + i * 0.32, -D / 2 - 0.45, 0.22)), 0.22, 1, mb.rnd, (0.82, 0.74, 0.58), "Build", 0.8)


STYLES = {"timber": _timber, "log": _log, "round": _round, "stall": _stall}


def build(spec):
    """A spec drawn with his helpers. Randomness comes from his module's `rnd`; a spec with a seed gets its own."""
    if spec.get("seed") is not None:
        mb.rnd = random.Random(spec["seed"])
    b = Builder(["Build", "Glow"] if spec["style"] != "timber" else ["Build"])
    STYLES[spec["style"]](b, spec)
    return b


# --- presets: his houses as specs (his numbers, his order) ------------------------------------------------------

PRESETS = {
    "cottage": {"style": "timber", "name": "house_cottage", "seed": None,
                "W": 4.4, "D": 3.4, "H": 2.6, "F": 0.5, "wall": mb.PLASTER, "timber": mb.TIMBER,
                "foundation": {"front_div": 10, "side_div": 7},
                "posts": [(-1, 2), (-1, 6), (1, 6), (1, 2)],
                "door": {"x": 0.0},
                "windows": [{"x": -1.45, "z": 1.35, "flowers": True}, {"x": 1.45, "z": 1.35, "flowers": True}],
                "roof": {"rise": 2.0, "overhang": 0.5, "rows": 5, "palette": "RED_ROOF"},
                "chimney": {"x": 1.2, "y": 0.7, "base": 0.9, "n": 6, "cap": 2.75},
                "porch": {"posts": [-0.75, 0.75], "depth": 1.1, "low": 2.3, "high": 2.75, "x0": -1.0, "x1": 1.0,
                          "reach": 1.35, "color": ["RED_ROOF", 2]},
                "dormer": {"x": -1.2, "y": -0.55, "z": 0.75, "front": -0.95, "x0": -1.75, "x1": -0.65, "y0": -1.15,
                           "y1": -0.1, "low": 1.1, "high": 1.45, "color": ["RED_ROOF", 0]},
                "fence": {"half": 9, "gap": 2, "step": 0.34, "front": 2.6, "rail_front": 2.62, "rails": [0.2, 0.5],
                          "rail_x": 1.9, "rail_len": 2.4},
                "garden": {"x": -1.6, "y": 1.8, "x0": -2.5},
                "leanto": {"side": -1, "gap": 0.9, "color": ["RED_ROOF", 1]}},
    "cabin": {"style": "log", "name": "house_cabin", "seed": None,
              "W": 4.2, "D": 3.4, "H": 2.4, "F": 0.4, "plinth": ["STONE", 1], "core": ["WOOD", 0],
              "trim": (0.3, 0.2, 0.13),
              "door": {"x": 0.7}, "windows": [{"x": -1.1, "z": 1.3}],
              "roof": {"rise": 1.8, "overhang": 0.7, "rows": 5, "palette": "SLATE"},
              "chimney": {"side": 1, "y": 0.4, "n": 14, "step": 7},
              "porch": {"planks": 8, "front": 1.7, "post": (0.4, 0.27, 0.17), "posts": [-4.2 / 2 + 0.1, -0.3, 1.2, 4.2 / 2 - 0.1],
                        "rails": [(-4.2 / 2 + 0.1, -0.3), (1.2, 4.2 / 2 - 0.1)], "steps_x": 0.45, "roof": ["SLATE", 1]},
              "lamp": {"x": 1.55}, "woodpile": {"side": -1}},
    "round": {"style": "round", "name": "house_round", "seed": None,
              "R": 2.1, "H": 2.3, "F": 0.45, "wall": mb.WARM_PLASTER, "timber": mb.TIMBER, "stones": 18,
              "roof": {"rise": 3.3, "palette": "STRAW"},
              "windows": [{"a": -2.25, "lit": False}, {"a": -0.9, "lit": True}],
              "chimney": {"x": 1.05, "y": 0.8, "cap_x": 1.35, "cap_y": 0.72}, "extras": True},
}


def preset_order():
    """His order and his seed: rnd starts at 9 for the cottage and runs on through the cabin and the round house."""
    mb.rnd = random.Random(9)
    return [PRESETS["cottage"], PRESETS["cabin"], PRESETS["round"]]


# --- variants: rules, and checks on how the parts join -----------------------------------------------------------

WALLS = [mb.PLASTER, mb.WARM_PLASTER, mb.CREAM, (0.9, 0.86, 0.8), (0.82, 0.86, 0.88), (0.93, 0.8, 0.58)]
TIMBERS = [mb.TIMBER, mb.TRIM, (0.29, 0.2, 0.15)]
CLOTHS = [((0.86, 0.25, 0.22), (0.96, 0.93, 0.86)), ((0.3, 0.46, 0.62), (0.96, 0.93, 0.86)),
          ((0.42, 0.58, 0.34), (0.95, 0.85, 0.4)), ((0.86, 0.62, 0.22), (0.62, 0.28, 0.2))]
PRODUCE = [(0.86, 0.25, 0.22), (0.95, 0.8, 0.3), (0.45, 0.66, 0.3), (0.62, 0.5, 0.9), (0.95, 0.55, 0.2)]
# His footprint for each style's place in the village (world/village.gd HOUSES size), the walls a variant may fill.
LIMIT = {"timber": (4.6, 3.6), "log": (4.4, 3.6), "round": (2.2, 2.2)}


def _r(rng, lo, hi, step=0.05):
    return round(rng.uniform(lo, hi) / step) * step


def roof_at(spec, y):
    """Height of a pitched roof's surface above the wall top at depth y (timber and log)."""
    r = spec["roof"]
    d = spec["D"] / 2 + r["overhang"]
    return r["rise"] * max(0.0, 1.0 - abs(y) / d)


def check(spec):
    """How the parts join. Returns the problems found (none: it stands)."""
    p = []
    st = spec["style"]
    if st in ("timber", "log"):
        W, D = spec["W"], spec["D"]
        lw, ld = LIMIT[st]
        if W > lw + 1e-6 or D > ld + 1e-6:
            p.append("walls %.2f x %.2f beyond his footprint %.2f x %.2f" % (W, D, lw, ld))
        dx = spec["door"]["x"]
        if abs(dx) + 0.6 > W / 2:
            p.append("door off its wall")
        xs = sorted(w["x"] for w in spec["windows"])
        for w in spec["windows"]:
            if abs(w["x"]) + 0.3 + 0.36 > W / 2:
                p.append("window at %.2f off its wall (shutters)" % w["x"])
            if abs(w["x"] - dx) < 0.58 + 0.66:
                p.append("window at %.2f over the door" % w["x"])
        if any(b - a < 1.5 for a, b in zip(xs, xs[1:])):
            p.append("windows' shutters overlap")
        c = spec.get("chimney")
        if c and st == "timber":
            if abs(c["x"]) + 0.31 > W / 2 or abs(c["y"]) + 0.31 > D / 2:
                p.append("chimney outside the roof's walls")
            if c["base"] > roof_at(spec, abs(c["y"]) + 0.31) - 0.1:
                p.append("chimney floats above the roof")
            if c["base"] + c["n"] * 0.3 < roof_at(spec, abs(c["y"]) - 0.31) + 0.4:
                p.append("chimney does not clear the roof")
        d = spec.get("dormer")
        if d:
            if abs(d["x"]) + 0.6 > W / 2:
                p.append("dormer off the roof")
            if d["z"] - 0.4 > roof_at(spec, abs(d["y"])):
                p.append("dormer floats above the roof")
            if c and abs(d["x"] - c["x"]) < 1.0 and abs(d["y"] - c["y"]) < 1.0:
                p.append("dormer into the chimney")
        po = spec.get("porch")
        if po and st == "timber":
            if po["high"] > spec["H"] + 0.3:
                p.append("porch roof above the eaves")
            if not (po["x0"] < dx < po["x1"]):
                p.append("porch not over the door")
        f = spec.get("fence")
        if f and abs(f.get("shift", 0.0) - dx) > 0.01:
            p.append("fence gate not at the door")
        t = spec.get("leanto")
        if t and st == "timber" and c and c["x"] * t["side"] > W / 2 - 0.9:
            p.append("lean-to under the chimney")
    elif st == "round":
        if spec["R"] > LIMIT["round"][0] + 1e-6:
            p.append("walls beyond his footprint")
        angles = sorted(w["a"] for w in spec["windows"])
        for a in angles:
            if abs(a - (-math.pi / 2)) < 0.6:
                p.append("window over the door")
        if any(b - a < 0.8 for a, b in zip(angles, angles[1:])):
            p.append("windows overlap")
        c = spec.get("chimney")
        if c and math.hypot(c["x"], c["y"]) > spec["R"] * 0.72:
            p.append("chimney beyond the straw")
    elif st == "stall":
        xs = sorted(g["x"] for g in spec["goods"] if g["kind"] in ("crate", "sacks"))
        if any(b - a < 0.6 for a, b in zip(xs, xs[1:])):
            p.append("goods on top of each other")
    return p


def _vary_timber(rng):
    W, D = _r(rng, 3.8, 4.6, 0.1), _r(rng, 3.0, 3.6, 0.1)
    H, F = _r(rng, 2.3, 2.8), rng.choice([0.4, 0.5])
    dx = rng.choice([0.0, 0.0, -round(W / 4, 2), round(W / 4, 2)])
    edge = round(W / 2 - 0.75, 2)
    windows = [{"x": x, "z": 1.35, "flowers": rng.random() < 0.7} for x in (-edge, edge, 0.0)
               if abs(x - dx) >= 1.3 and rng.random() < 0.9]
    roof = {"rise": _r(rng, 1.7, 2.3), "overhang": _r(rng, 0.4, 0.55), "rows": rng.choice([4, 5, 6]),
            "palette": rng.choice(["RED_ROOF", "SLATE", "SHINGLE", "STRAW"])}
    s = {"style": "timber", "W": W, "D": D, "H": H, "F": F, "wall": rng.choice(WALLS), "timber": rng.choice(TIMBERS),
         "foundation": {"front_div": int(round(W / 0.44)), "side_div": 7}, "posts": [(-1, 2), (-1, 6), (1, 6), (1, 2)],
         "door": {"x": dx}, "windows": windows, "roof": roof}
    if rng.random() < 0.85:
        cy = _r(rng, -0.8, 0.8)
        n = rng.choice([5, 6, 7])
        s["chimney"] = {"x": rng.choice([-1, 1]) * _r(rng, 0.6, W / 2 - 0.45), "y": cy, "n": n}
        base = round(roof_at(s, abs(cy) + 0.31) - 0.25, 2)
        s["chimney"].update({"base": base, "cap": round(base + n * 0.3 + 0.05, 2)})
    if rng.random() < 0.7:
        hi = min(2.75, round(H + 0.15, 2))
        s["porch"] = {"posts": [dx - 0.75, dx + 0.75], "depth": 1.1, "low": round(hi - 0.45, 2), "high": hi,
                      "x0": dx - 1.0, "x1": dx + 1.0, "reach": 1.35, "color": [roof["palette"], 2]}
    if rng.random() < 0.5 and roof["rise"] >= 1.9:
        x = rng.choice([-1, 1]) * _r(rng, 0.8, W / 2 - 0.7)
        s["dormer"] = {"x": x, "y": -0.55, "z": 0.75, "front": -0.95, "x0": x - 0.55, "x1": x + 0.55, "y0": -1.15,
                       "y1": -0.1, "low": 1.1, "high": 1.45, "color": [roof["palette"], 0]}
    if rng.random() < 0.6:
        s["fence"] = {"half": 9, "gap": 2, "step": 0.34, "front": 2.6, "rail_front": 2.62, "rails": [0.2, 0.5],
                      "rail_x": 1.9, "rail_len": 2.4, "shift": dx}
    if rng.random() < 0.6:
        gx = -1.6 if dx >= 0 else 1.6
        s["garden"] = {"x": gx, "y": 1.8, "x0": gx - 0.9}
    if rng.random() < 0.6:
        s["leanto"] = {"side": rng.choice([-1, 1]), "gap": 0.9, "color": [roof["palette"], 1]}
    return s


def _vary_log(rng):
    W, D = _r(rng, 3.8, 4.4, 0.1), _r(rng, 3.2, 3.6, 0.1)
    H, F = _r(rng, 2.2, 2.6), 0.4
    dx = rng.choice([0.7, -0.7, 0.0])
    windows = [{"x": x, "z": 1.3} for x in (-1.1, 1.1) if abs(x - dx) >= 1.3]
    roof = {"rise": _r(rng, 1.6, 2.0), "overhang": _r(rng, 0.55, 0.75), "rows": rng.choice([4, 5]),
            "palette": rng.choice(["SLATE", "RED_ROOF", "SHINGLE"])}
    side = rng.choice([-1, 1])
    s = {"style": "log", "W": W, "D": D, "H": H, "F": F, "plinth": ["STONE", rng.randrange(4)], "core": ["WOOD", 0],
         "trim": rng.choice([(0.3, 0.2, 0.13), mb.TRIM, (0.24, 0.17, 0.12)]), "door": {"x": dx}, "windows": windows,
         "roof": roof, "chimney": {"side": side, "y": 0.4, "n": int(math.ceil((F + H + roof["rise"]) / 0.32)) + 1, "step": 7}}
    if rng.random() < 0.75:
        s["porch"] = {"planks": 8, "front": 1.7, "post": (0.4, 0.27, 0.17),
                      "posts": [-W / 2 + 0.1, dx - 1.0, dx + 0.5, W / 2 - 0.1],
                      "rails": [(-W / 2 + 0.1, dx - 1.0), (dx + 0.5, W / 2 - 0.1)], "steps_x": dx - 0.25,
                      "roof": [roof["palette"], 1]}
    if rng.random() < 0.8:
        s["lamp"] = {"x": dx + 0.85 if dx < W / 2 - 1.0 else dx - 0.85}
    if rng.random() < 0.7:
        s["woodpile"] = {"side": -side}
    return s


def _vary_round(rng):
    R = _r(rng, 1.9, 2.2)
    cand = [-2.6, -2.25, -1.95, -1.2, -0.9, -0.6, 0.3, 0.9, 2.2, 2.8]
    rng.shuffle(cand)
    windows = []
    for a in cand:
        if len(windows) < rng.choice([2, 3]) and abs(a + math.pi / 2) >= 0.6 and all(abs(a - w["a"]) >= 0.8 for w in windows):
            windows.append({"a": a, "lit": rng.random() < 0.45})
    s = {"style": "round", "R": R, "H": _r(rng, 2.1, 2.5), "F": 0.45, "wall": rng.choice(WALLS),
         "timber": rng.choice(TIMBERS), "stones": rng.choice([16, 18, 20]),
         "roof": {"rise": _r(rng, 2.9, 3.6), "palette": rng.choice(["STRAW", "STRAW", "MOSS"])}, "windows": windows,
         "extras": rng.random() < 0.75}
    if rng.random() < 0.8:
        a = rng.uniform(0.2, 1.2)
        rr = R * 0.55
        s["chimney"] = {"x": round(math.cos(a) * rr, 2), "y": round(math.sin(a) * rr, 2)}
        s["chimney"].update({"cap_x": round(s["chimney"]["x"] + 0.3, 2), "cap_y": round(s["chimney"]["y"] - 0.08, 2)})
    return s


def _vary_stall(rng):
    W, D = _r(rng, 2.0, 3.0, 0.1), _r(rng, 1.2, 1.6, 0.1)
    goods = [{"kind": "produce", "x": round(x, 2), "color": rng.choice(PRODUCE)}
             for x in (-W / 4, W / 4) if rng.random() < 0.85]
    xs = [-W / 2 + 0.3, 0.0, W / 2 - 0.3]
    rng.shuffle(xs)
    for k in ("crate", "barrel", "sacks"):
        if rng.random() < 0.7 and xs:
            goods.append({"kind": k, "x": round(xs.pop(), 2)})
    return {"style": "stall", "W": W, "D": D, "post": rng.choice(TIMBERS), "counter": rng.choice(mb.WOOD),
            "front": rng.choice([mb.WOOD[1], mb.TRIM]), "stripes": rng.choice([5, 6, 7, 8]),
            "cloth": list(rng.choice(CLOTHS)), "goods": goods}


# His village houses the grammar has a style for, and where they stand (world/village.gd HOUSES): a variant each,
# seeded by its place.
VILLAGE = [("house_cottage", "timber", (-5.5, 11.5)), ("house_cabin", "log", (10.5, 13.0)), ("house_round", "round", (-9.0, 23.0))]

VARY = {"timber": _vary_timber, "log": _vary_log, "round": _vary_round, "stall": _vary_stall}


def vary(style, seed):
    """A seeded spec of a style whose parts join (check() finds nothing); the same seed is the same spec."""
    for k in range(200):
        rng = random.Random("%s:%d:%d" % (style, seed, k))
        spec = VARY[style](rng)
        spec.update({"name": "%s_%d" % (style, seed), "seed": seed * 1000 + k, "tries": k + 1})
        if not check(spec):
            return spec
    raise RuntimeError("no %s for seed %d stands" % (style, seed))


def start_blender():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rk.make_materials({"Build": (1, 1, 1), "Glow": (1, 1, 1)}, roughness=0.9)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if args else os.path.join(HERE, "out")
    what = args[1] if len(args) > 1 else "presets"
    os.makedirs(out, exist_ok=True)
    start_blender()
    if what in ("presets", "all"):
        for spec in preset_order():
            export(spec["name"], build(spec), out)       # (his names: the same file, byte for byte)
            print("GRAMMAR preset", spec["name"], "problems", check(spec))
    if what in ("variants", "all"):
        for style in ("timber", "log", "round", "stall"):
            for seed in range(1, 11):
                spec = vary(style, seed)
                export(spec["name"], build(spec), out)
                print("GRAMMAR variant", spec["name"], "tries", spec["tries"])
    if what == "game":                                  # what the game's switch draws (assets/studio/houses/)
        for spec in preset_order():
            export("preset_" + spec["name"], build(spec), out)
            print("GRAMMAR game preset", spec["name"])
        for name, style, at in VILLAGE:
            seed = int(abs(at[0]) * 10) * 1000 + int(abs(at[1]) * 10)
            spec = vary(style, seed)
            export("variety_" + name, build(spec), out)
            print("GRAMMAR game variety", name, style, seed, "tries", spec["tries"])
    if what.startswith("village"):                      # the village's own: a variant per house, seeded by its place
        import json
        for name, style, seed in json.loads(what.split(":", 1)[1]):
            spec = vary(style, seed)
            export(name, build(spec), out)
            print("GRAMMAR village", name, spec["name"], "tries", spec["tries"])
