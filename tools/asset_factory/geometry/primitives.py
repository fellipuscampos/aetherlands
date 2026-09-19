"""
Low-level parametric primitives, all built with Blender's built-in
`bmesh.ops` creators (create_cube / create_cone / create_uvsphere) so no
face is ever generated that those operators wouldn't already produce for
the requested resolution. Segment counts always come from the caller
(which reads them from a StyleDefinition) -- nothing in here invents its
own resolution.

Every primitive returns a plain, linked, flat-shaded bpy Object in world
space. Building at world-space coordinates (instead of local + object
transform) keeps every downstream step -- vertex groups, joining,
armature binding -- simple, since object transform stays identity.
"""

import bmesh
import bpy
from mathutils import Matrix, Vector

FRONT_UV = ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))


def finish_mesh(name, bm):
    """Turns a bmesh into a linked, flat-shaded Object. Public: shared by
    every geometry module (primitives.py and the V2 loft-based builders in
    geometry/meshops.py) so every generator produces objects the same way."""
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = False  # flat shading: strong silhouette, matches style
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


_finish = finish_mesh  # backwards-compatible alias for the rest of this module


def box(name, size, center):
    """Axis-aligned rectangular box. size=(sx,sy,sz) full dims, center=(x,y,z)."""
    bm = bmesh.new()
    mat = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
    return _finish(name, bm)


def sloped_wall(name, bottom_center_xy, bottom_size_xy, top_center_xy, top_size_xy, z_bottom, z_top):
    """A wall whose footprint (both size AND horizontal offset) can differ
    between its bottom and top edge -- a general single-piece frustum,
    unlike wedge() below (which only shrinks a shape's own WIDTH toward
    its fixed local center, it can't also shift that center outward/
    inward with height). Built for a flared skirt panel: when a boxy
    flare's OUTWARD offset jumps at one height (a narrow tier stacked on
    a wider one), the flat top face of the lower tier reads as a shelf/
    ring from a steep top-down camera. Sloping the offset continuously
    from bottom to top removes that flat step -- the outward face is a
    single slanted plane instead."""
    bm = bmesh.new()
    bcx, bcy = bottom_center_xy
    tcx, tcy = top_center_xy
    bsx, bsy = bottom_size_xy
    tsx, tsy = top_size_xy
    verts = [
        bm.verts.new((bcx - bsx / 2, bcy - bsy / 2, z_bottom)),
        bm.verts.new((bcx + bsx / 2, bcy - bsy / 2, z_bottom)),
        bm.verts.new((bcx + bsx / 2, bcy + bsy / 2, z_bottom)),
        bm.verts.new((bcx - bsx / 2, bcy + bsy / 2, z_bottom)),
        bm.verts.new((tcx - tsx / 2, tcy - tsy / 2, z_top)),
        bm.verts.new((tcx + tsx / 2, tcy - tsy / 2, z_top)),
        bm.verts.new((tcx + tsx / 2, tcy + tsy / 2, z_top)),
        bm.verts.new((tcx - tsx / 2, tcy + tsy / 2, z_top)),
    ]
    bm.verts.ensure_lookup_table()
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    return finish_mesh(name, bm)


def cone(name, radius1, radius2, depth, segments, base_center, cap_ends=True, direction=1):
    """Cylinder/prism/frustum. radius1 is always the radius AT base_center
    (proximal end), radius2 the radius at the far end (equal -> straight
    prism, 0 -> pointed cap). segments=6 gives a hexagon cross-section, etc.
    direction=1 grows the shape upward (+Z) from base_center (e.g. neck:
    chest -> head); direction=-1 grows it downward (e.g. every limb
    segment: shoulder/elbow/hip/knee -> the joint below it)."""
    bm = bmesh.new()
    half = depth / 2.0
    center_z = base_center[2] + direction * half
    mat = Matrix.Translation((base_center[0], base_center[1], center_z))
    # bmesh's cone always places radius1 at local -Z and radius2 at local
    # +Z; when growing downward that local -Z end lands at the FAR point,
    # not at base_center, so swap to keep radius1 anchored at base_center.
    r1, r2 = (radius1, radius2) if direction >= 0 else (radius2, radius1)
    bmesh.ops.create_cone(
        bm,
        cap_ends=cap_ends,
        cap_tris=False,
        segments=segments,
        radius1=r1,
        radius2=r2,
        depth=depth,
        matrix=mat,
    )
    return _finish(name, bm)


def uv_sphere(name, radius, segments, rings, center):
    """Low-resolution UV sphere. segments=longitude, rings=latitude.
    radius may be a float (perfect sphere) or an (rx,ry,rz) tuple to
    squash/stretch it into an ellipsoid (heads are rarely perfectly round)."""
    bm = bmesh.new()
    if isinstance(radius, (tuple, list)):
        mat = Matrix.Translation(center) @ Matrix.Diagonal((*radius, 1.0))
        r = 1.0
    else:
        mat = Matrix.Translation(center)
        r = radius
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=r, matrix=mat)
    return _finish(name, bm)


def hex_prism(name, radius, thickness, center, segments=6, radius2=None):
    """Flat plate that reads as a single hexagon (shields, plates, insignia).
    Extends along +Y (thickness is depth-wise, prism axis is Y). Pass
    radius2=0 for a pyramid (e.g. a shield boss) instead of a straight
    prism."""
    radius2 = radius if radius2 is None else radius2
    bm = bmesh.new()
    mat = (
        Matrix.Translation(center)
        @ Matrix.Rotation(1.5707963, 4, "X")
        @ Matrix.Translation((0, 0, -thickness / 2.0))
    )
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius,
        radius2=radius2,
        depth=thickness,
        matrix=mat,
    )
    return _finish(name, bm)


def wedge(name, size, center, taper=0.4):
    """Box tapered along +Z toward the top (blade/spike shapes). taper=1.0
    keeps full width at top, 0.0 comes to an edge."""
    bm = bmesh.new()
    sx, sy, sz = size
    verts = [
        bm.verts.new((-sx / 2, -sy / 2, -sz / 2)),
        bm.verts.new((sx / 2, -sy / 2, -sz / 2)),
        bm.verts.new((sx / 2, sy / 2, -sz / 2)),
        bm.verts.new((-sx / 2, sy / 2, -sz / 2)),
        bm.verts.new((-sx / 2 * taper, -sy / 2 * taper, sz / 2)),
        bm.verts.new((sx / 2 * taper, -sy / 2 * taper, sz / 2)),
        bm.verts.new((sx / 2 * taper, sy / 2 * taper, sz / 2)),
        bm.verts.new((-sx / 2 * taper, sy / 2 * taper, sz / 2)),
    ]
    bm.verts.ensure_lookup_table()
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(center))
    return _finish(name, bm)


def strap(name, p1, p2, width, depth):
    """A box connecting two arbitrary 3D points -- p1 to p2 becomes the
    box's own length axis, `width`/`depth` its cross-section
    perpendicular to that. Every other primitive here is axis-aligned
    (box/wedge/sloped_wall all build along a fixed local Z); a diagonal
    accessory across the torso (a shoulder-to-hip sash/baldric) needs an
    actual tilted box, which none of them can produce without this."""
    p1v, p2v = Vector(p1), Vector(p2)
    axis = p2v - p1v
    length = axis.length
    axis_n = axis.normalized()
    # Any vector not parallel to axis_n works as a reference to build a
    # perpendicular basis from -- fall back to a different reference if
    # axis_n is too close to the usual +Z one (a near-vertical strap).
    up_ref = Vector((0.0, 0.0, 1.0)) if abs(axis_n.z) < 0.99 else Vector((1.0, 0.0, 0.0))
    right = axis_n.cross(up_ref).normalized()
    depth_dir = right.cross(axis_n).normalized()
    center = (p1v + p2v) / 2.0
    hw_, hd_, hl_ = width / 2.0, depth / 2.0, length / 2.0

    bm = bmesh.new()
    verts = []
    for sl in (-1, 1):
        base = center + axis_n * (sl * hl_)
        for sr, sd in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            verts.append(bm.verts.new(base + right * (sr * hw_) + depth_dir * (sd * hd_)))
    bm.verts.ensure_lookup_table()
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    return _finish(name, bm)


def assign_material(obj, material, extra_materials=None):
    obj.data.materials.append(material)
    if extra_materials:
        for m in extra_materials:
            obj.data.materials.append(m)


def tag_front_face(obj, material, front_dir=(0.0, 1.0, 0.0), up_dir=(0.0, 0.0, 1.0)):
    """Finds the polygon whose normal points closest to `front_dir` (a box
    always has exactly one), gives it its own material slot, and maps its
    4 corners to the 0-1 UV square by PROJECTING each corner onto the
    given `up_dir`/right axes -- not by assuming a fixed loop winding
    order. A bmesh cube's loop order for a given face isn't guaranteed
    against world axes, so a hardcoded UV-per-loop-index mapping can
    silently come out rotated (e.g. two eyes painted side by side ending
    up stacked vertically instead) depending on how that face happened to
    be wound. Projecting onto explicit world axes is orientation-safe
    regardless of winding."""
    mesh = obj.data
    mesh.materials.append(material)
    new_slot = len(mesh.materials) - 1

    front = Vector(front_dir).normalized()
    up = Vector(up_dir).normalized()
    right = front.cross(up).normalized()

    best_poly, best_dot = None, -2.0
    for poly in mesh.polygons:
        d = poly.normal.dot(front)
        if d > best_dot:
            best_dot, best_poly = d, poly

    best_poly.material_index = new_slot

    coords = [mesh.vertices[mesh.loops[li].vertex_index].co for li in best_poly.loop_indices]
    us = [c.dot(right) for c in coords]
    vs = [c.dot(up) for c in coords]
    umin, umax = min(us), max(us)
    vmin, vmax = min(vs), max(vs)

    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers[0]
    for loop_index, u, v in zip(best_poly.loop_indices, us, vs):
        uu = (u - umin) / (umax - umin) if umax > umin else 0.5
        vv = (v - vmin) / (vmax - vmin) if vmax > vmin else 0.5
        uv_layer.data[loop_index].uv = (uu, vv)

    return new_slot


def apply_tiled_material(obj, material, tile_size=0.05, extra_materials=None):
    """Assigns a REPEATING UV to EVERY face of a box-like object (not just
    one, unlike tag_front_face), in world units per tile -- so a small
    tileable texture (chainmail, leather grain, cloth weave, wood grain,
    brushed metal; see style/textures.py) reads at a consistent physical
    scale no matter how big or small this particular box is. For each
    face, projects onto the two world axes least aligned with its normal
    (cheap and exact for the axis-aligned boxes this whole pipeline
    builds) -- seams at box edges are expected and fine at this low-poly
    scale, this is not a full unwrap."""
    mesh = obj.data
    mesh.materials.append(material)
    new_slot = len(mesh.materials) - 1
    if extra_materials:
        for m in extra_materials:
            mesh.materials.append(m)

    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv_layer = mesh.uv_layers[0]

    world_axes = (Vector((1.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0)))
    for poly in mesh.polygons:
        poly.material_index = new_slot
        n = poly.normal
        axes = sorted(world_axes, key=lambda a: abs(n.dot(a)))
        u_axis, v_axis = axes[0], axes[1]
        for loop_index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = (co.dot(u_axis) / tile_size, co.dot(v_axis) / tile_size)

    return new_slot


def assign_vertex_group(obj, bone_name, weight=1.0):
    """Rigid skin: every vertex of this part gets 100% weight to one bone."""
    vg = obj.vertex_groups.new(name=bone_name)
    all_idx = [v.index for v in obj.data.vertices]
    vg.add(all_idx, weight, "REPLACE")
    return vg
