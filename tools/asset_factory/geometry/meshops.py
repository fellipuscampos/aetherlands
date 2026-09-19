"""
V2 procedural-sculpt toolkit: build meshes as explicit stacked polygon
rings ("lofts") instead of gluing primitives together. This is how a
low-poly character artist actually blocks out a torso/limb/head by hand
-- a handful of deliberate cross-sections, stitched into quads, with a
controlled number of sides per ring. Every vertex here is placed on
purpose; nothing comes from a subdivision or bevel operator.

A "level" is one horizontal (locally: perpendicular to the loft's spine)
cross-section:
    {"z": float, "cx": float, "cy": float, "points": [(x, y), ...]}
        -- a ring, `points` are LOCAL offsets from (cx, cy) at height z.
    {"z": float, "cx": float, "cy": float, "apex": True}
        -- collapses the loft to a single point (a tip/crown), connected
           to its neighboring ring with a triangle fan.

All rings in one loft must share point count and point ORDER (index i in
one ring corresponds to index i in the next -- this is what lets callers
reason about "index 0 is the front vertex" when shaping a profile, see
`ellipse_points`).
"""

import math

import bmesh

from geometry.primitives import finish_mesh


def ellipse_points(sides, rx, ry, phase=math.pi / 2.0):
    """Regular n-gon ring, `sides` points. Default phase puts point 0 at
    +Y (the character's front), so callers can reliably index "front",
    "back", "left" (~sides*0.5), "right" (~sides*1.0/index 0 offset)
    vertices to sculpt a profile (chin, brow ridge, ear anchor, ...)."""
    pts = []
    for i in range(sides):
        angle = phase + 2.0 * math.pi * i / sides
        pts.append((rx * math.cos(angle), ry * math.sin(angle)))
    return pts


def arc_points(sides, rx, ry, start_deg, end_deg, phase_deg=90.0):
    """Open arc, `sides + 1` points, spanning [start_deg, end_deg] measured
    from the front (phase_deg=90 -> 0 deg = +Y/front, positive = toward
    +X/right). Used for open-face helmets: leave the front arc out."""
    pts = []
    for i in range(sides + 1):
        t = start_deg + (end_deg - start_deg) * i / sides
        angle = math.radians(phase_deg - t)
        pts.append((rx * math.cos(angle), ry * math.sin(angle)))
    return pts


def scale_points(points, sx, sy=None):
    sy = sx if sy is None else sy
    return [(x * sx, y * sy) for x, y in points]


def flatten_indices(points, indices, y):
    """Pulls a small run of ring vertices onto the same Y depth, turning a
    convex curve into a deliberate flat facet (e.g. a face plate for
    eyes/nose/mouth to sit flush on, instead of bulging off a sphere)."""
    out = list(points)
    n = len(out)
    for i in indices:
        x, _ = out[i % n]
        out[i % n] = (x, y)
    return out


def nudge_point(points, index, dx=0.0, dy=0.0):
    """Returns a COPY of points with one vertex offset -- the standard way
    to sculpt a ring (push out a chin, pinch a waist point, etc.)."""
    out = list(points)
    x, y = out[index % len(out)]
    out[index % len(out)] = (x + dx, y + dy)
    return out


def lerp(a, b, t):
    return a + (b - a) * t


def lerp3(p, q, t):
    return (lerp(p[0], q[0], t), lerp(p[1], q[1], t), lerp(p[2], q[2], t))


def ring_level(pos, rx, ry, sides, nudge=None):
    """Convenience: an ellipse ring level positioned at world point `pos`
    (x,y,z), optionally sculpted with `nudge=[(index, dx, dy), ...]`."""
    pts = ellipse_points(sides, rx, ry)
    if nudge:
        for index, dx, dy in nudge:
            pts = nudge_point(pts, index, dx, dy)
    return {"z": pos[2], "cx": pos[0], "cy": pos[1], "points": pts}


def jagged_hem(points, drop, start_low=True):
    """Turns a flat ring into a per-vertex 3-tuple (x, y, dz) list, dropping
    alternating vertices by `drop` -- the classic low-poly "handkerchief
    hem" zigzag on a skirt/tabard, without needing a second ring."""
    out = []
    for i, (x, y) in enumerate(points):
        low = (i % 2 == 0) if start_low else (i % 2 == 1)
        out.append((x, y, -drop if low else 0.0))
    return out


def build_loft(name, levels, closed=True, cap_bottom=False, cap_top=False):
    """Stitches consecutive levels into quads (or triangle fans against an
    apex level). See module docstring for the level dict shapes. A ring's
    points may be (x, y) or (x, y, dz) -- the optional dz offsets that
    vertex from the ring's shared z, e.g. for a jagged hem (see
    jagged_hem above).

    A level may also carry `"weights": {bone_name: weight, ...}` -- every
    vertex in that ring is added to those vertex groups at those weights
    (weights across the dict should sum to ~1.0). This is what lets one
    continuous mesh span several bones with a smoothly BLENDED weight
    through the joint (e.g. 70/30 then 30/70 across a couple of rings at
    the elbow) instead of a hard rigid cut -- the object is a single
    watertight surface, so there is no seam to separate during animation,
    and the joint actually bends instead of hinging as two rigid blocks."""
    bm = bmesh.new()
    level_verts = []
    level_ranges = []
    cursor = 0

    for lvl in levels:
        if lvl.get("apex"):
            v = bm.verts.new((lvl["cx"], lvl["cy"], lvl["z"]))
            level_verts.append([v])
            level_ranges.append((cursor, cursor + 1))
            cursor += 1
        else:
            verts = []
            for p in lvl["points"]:
                px, py, pz = (p[0], p[1], p[2]) if len(p) == 3 else (p[0], p[1], 0.0)
                verts.append(bm.verts.new((lvl["cx"] + px, lvl["cy"] + py, lvl["z"] + pz)))
            level_verts.append(verts)
            level_ranges.append((cursor, cursor + len(verts)))
            cursor += len(verts)

    for a, b in zip(level_verts, level_verts[1:]):
        if len(a) > 1 and len(b) > 1:
            n = len(a)
            span = n if closed else n - 1
            for i in range(span):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[j], b[i]))
        elif len(a) > 1 and len(b) == 1:
            n = len(a)
            span = n if closed else n - 1
            for i in range(span):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[0]))
        elif len(a) == 1 and len(b) > 1:
            n = len(b)
            span = n if closed else n - 1
            for i in range(span):
                j = (i + 1) % n
                bm.faces.new((b[j], b[i], a[0]))
        # apex-to-apex (len==1 both) never happens in practice; skip

    if cap_bottom and len(level_verts[0]) > 1:
        bm.faces.new(level_verts[0])
    if cap_top and len(level_verts[-1]) > 1:
        bm.faces.new(list(reversed(level_verts[-1])))

    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    obj = finish_mesh(name, bm)

    if any("weights" in lvl for lvl in levels):
        for lvl, (start, end) in zip(levels, level_ranges):
            weights = lvl.get("weights")
            if not weights:
                continue
            idx = list(range(start, end))
            for bone, weight in weights.items():
                vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                vg.add(idx, weight, "REPLACE")

    return obj


def build_strip(name, level_a_points_3d, level_b_points_3d, closed=True):
    """Single quad strip between two EXPLICIT lists of already-placed 3D
    points (x,y,z) -- an escape hatch for one-off connector geometry
    (e.g. a cheek-guard hanging off an arc ring) that doesn't fit the
    single-spine build_loft model."""
    bm = bmesh.new()
    a = [bm.verts.new(p) for p in level_a_points_3d]
    b = [bm.verts.new(p) for p in level_b_points_3d]
    n = len(a)
    span = n if closed else n - 1
    for i in range(span):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return finish_mesh(name, bm)
