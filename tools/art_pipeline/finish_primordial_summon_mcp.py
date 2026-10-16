"""Validate and export the Primordial summon in the connected Blender."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st = bpy.app.driver_namespace['primordial_summon']
scene, rig, parts = st['scene'], st['rig'], st['parts']
OUT = Path(st['out'])
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
for path, digest in st['protected'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest, path
for track in rig.animation_data.nla_tracks:
    track.mute = True
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}


def geometry():
    matrices = {b.name: b.matrix@inverse[b.name] for b in rig.pose.bones}
    return matrices, {o.name: [matrices[o.vertex_groups[v.groups[0].group].name]@v.co
                     for v in o.data.vertices] for o in parts}


def bounds(points):
    return tuple(min(p[i] for p in points) for i in range(3)), tuple(max(p[i] for p in points) for i in range(3))


rig.animation_data.action = st['idle']
scene.frame_set(1)
_, idle = geometry()
rig.animation_data.action = st['action']
low, high = Vector((1e9,)*3), Vector((-1e9,)*3)
previous = None
max_step = initial_extent = 0.
core_parts = [o for o in parts if o['rig_bone'] == 'core']
others = [o for o in parts if o not in core_parts]
core_only = False
collision_checks = 0
for half in range(301):
    f = 1+half/2
    scene.frame_set(int(f), subframe=f%1)
    matrices, rows = geometry()
    assert all(abs(matrices['root'][i][j]-float(i == j)) < 1e-6 for i in range(4) for j in range(4))
    points = [p for o in parts for p in rows[o.name]]
    assert all(math.isfinite(x) for p in points for x in p)
    for p in points:
        for i in range(3):
            low[i] = min(low[i], p[i])
            high[i] = max(high[i], p[i])
    if half == 0:
        initial_extent = max((Vector(bounds(rows[o.name])[1])-Vector(bounds(rows[o.name])[0])).length for o in parts)
    if f == 19:
        assert max((Vector(bounds(rows[o.name])[1])-Vector(bounds(rows[o.name])[0])).length for o in others) < .001
        core_only = True
    if half%3 == 0 and f >= 21:
        vertices, faces = [], []
        for obj in core_parts:
            offset = len(vertices)
            vertices.extend(rows[obj.name])
            faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
        a = bounds(vertices)
        core_tree = BVHTree.FromPolygons(vertices, faces)
        for obj in others:
            b = bounds(rows[obj.name])
            if not all(a[0][i] <= b[1][i] and b[0][i] <= a[1][i] for i in range(3)):
                continue
            tree = BVHTree.FromPolygons(rows[obj.name], [tuple(p.vertices) for p in obj.data.polygons])
            assert not core_tree.overlap(tree), ('core intersection', f, obj.name)
            collision_checks += 1
    if previous is not None:
        max_step = max(max_step, max((a-b).length for a,b in zip(previous, points)))
    previous = points
join_error = max((p-q).length for o in parts for p,q in zip(rows[o.name], idle[o.name]))
assert initial_extent < .001, initial_extent
assert core_only
assert low.z > .07, low.z
assert join_error < 1e-5, join_error
assert max_step < .30, max_step

# Preserve every original vertex binding and UV while joining only a temporary export mesh.
vertices, faces, uvrows, groups = [], [], [], {}
for obj in parts:
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in obj.data.vertices)
    for v in obj.data.vertices:
        assert len(v.groups) == 1
        groups.setdefault(obj.vertex_groups[v.groups[0].group].name, []).append(offset+v.index)
    for p in obj.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uvrows.extend(tuple(obj.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
mesh = bpy.data.meshes.new('Primordial_Summon_ExportMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metric_Pixel_UV')
for i, row in enumerate(uvrows):
    uv.data[i].uv = row
mesh.materials.append(parts[0].data.materials[0])
model = bpy.data.objects.new('Primordial', mesh)
scene.collection.objects.link(model)
model.parent = rig
for name, indices in groups.items():
    model.vertex_groups.new(name=name).add(indices, 1, 'REPLACE')
model.modifiers.new('Approved_Pivots', 'ARMATURE').object = rig
rig.animation_data.action = None
old = next((t for t in rig.animation_data.nla_tracks if t.name == 'Summon'), None)
if old is not None:
    rig.animation_data.nla_tracks.remove(old)
track = rig.animation_data.nla_tracks.new()
track.name = 'Summon'
track.strips.new('Summon', 1, st['action']).extrapolation = 'NOTHING'
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_set(1)
try:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (rig.parent, rig, model):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'primordial_summon.glb'), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=True,
        export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
        export_force_sampling=True, export_frame_range=False, export_skins=True,
        export_def_bones=False, export_yup=True, export_cameras=False, export_lights=False,
        export_optimize_animation_size=False)
finally:
    bpy.data.objects.remove(model, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = st['action']
raw = (OUT/'primordial_summon.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
assert {a['name'] for a in doc['animations']} == {'idle', 'walk', 'attack', 'spell', 'Summon'}
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 91
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives']) == 1738
report = dict(status='PASS', via='Blender MCP live', duration_s=5, frames=151, samples=301,
              fps=30, parts=125, bones=91, particles_included=False, root_motion=False,
              style='core first; continuous serpent forms from head to tail',
              initial_maximum_piece_extent_m=initial_extent, minimum_ground_clearance_m=low.z,
              core_only_at_0_6_seconds=core_only, continuous_body=True,
              bounds_min=list(low), bounds_max=list(high), final_to_idle_vertex_error_m=join_error,
              maximum_half_frame_step_m=max_step, core_collision_checks=collision_checks,
              core_intersections=0, original_asset_files_unchanged=True)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
st['report'] = report
bpy.ops.object.select_all(action='DESELECT')
rig.parent.select_set(True)
bpy.context.view_layer.objects.active = rig.parent
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        space.shading.use_scene_world = space.shading.use_scene_lights = True
        space.overlay.show_overlays = False
        space.region_3d.view_perspective = 'CAMERA'
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/'primordial_summon.blend'), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
result = report
