"""Validate and export the Avatar death through the connected Blender."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

st = bpy.app.driver_namespace['nature_avatar_death']
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
    rows = {o.name: [matrices[o.vertex_groups[v.groups[0].group].name]@v.co
                     for v in o.data.vertices] for o in parts}
    return matrices, rows


def bounds(points):
    return tuple(min(p[i] for p in points) for i in range(3)), tuple(max(p[i] for p in points) for i in range(3))


rig.animation_data.action = st['idle']
scene.frame_set(1)
_, idle = geometry()
rig.animation_data.action = st['action']
low, high = Vector((1e9,)*3), Vector((-1e9,)*3)
first = previous = None
max_step = 0.
ground_rest = {}
wood_held_error = 0.
core_gone_extent = 0.
core = next(o for o in parts if o['rig_bone'] == 'core')
for half in range(241):
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
    if f <= 97:
        assert all(abs(s-1.) < 1e-5 for b in rig.pose.bones if b.name.startswith('assemble_') for s in b.scale)
    if f <= 26:
        wood_held_error = max(wood_held_error, max((p-q).length
            for o in parts if o != core for p,q in zip(rows[o.name], idle[o.name])))
    if f >= 23:
        core_gone_extent = max(core_gone_extent,
            (Vector(bounds(rows[core.name])[1])-Vector(bounds(rows[core.name])[0])).length)
    if f in (73., 97.):
        wood = [p for o in parts if o['rig_bone'] != 'core' for p in rows[o.name]]
        bottom, top = bounds(wood)
        assert -.015 < bottom[2] < .05, (f, bottom)
        assert top[2] < 1.45, (f, top)
        assert top[0]-bottom[0] < 2.95 and top[1]-bottom[1] < 2.70, (f, bottom, top)
        ground_rest[(f-1)/24] = dict(minimum=list(bottom), maximum=list(top))
    if first is None:
        first = [p.copy() for p in points]
    if previous is not None:
        max_step = max(max_step, max((a-b).length for a,b in zip(previous, points)))
    previous = points
join_error = max((p-q).length for p,q in zip(first, [p for o in parts for p in idle[o.name]]))
final_extent = max((Vector(bounds(rows[o.name])[1])-Vector(bounds(rows[o.name])[0])).length for o in parts)
assert join_error < 1e-5, join_error
assert low.z > -.015, low.z
assert max_step < .30, max_step
assert final_extent < .001, final_extent
assert wood_held_error < 1e-5, wood_held_error
assert core_gone_extent < .001, core_gone_extent
assert scene.rigidbody_world is None
assert not any('Nature_FallProxy' in o.name or 'Nature_Death_' in o.name for o in scene.objects)

# Join a temporary export mesh, preserving every original UV and rigid binding.
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
mesh = bpy.data.meshes.new('Nature_Avatar_Death_ExportMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metric_Pixel_UV')
for i, row in enumerate(uvrows):
    uv.data[i].uv = row
mesh.materials.append(parts[0].data.materials[0])
model = bpy.data.objects.new('Nature_Avatar', mesh)
scene.collection.objects.link(model)
model.parent = rig
for name, indices in groups.items():
    model.vertex_groups.new(name=name).add(indices, 1, 'REPLACE')
model.modifiers.new('Approved_Pivots', 'ARMATURE').object = rig
rig.animation_data.action = None
old = next((t for t in rig.animation_data.nla_tracks if t.name == 'Death'), None)
if old is not None:
    rig.animation_data.nla_tracks.remove(old)
track = rig.animation_data.nla_tracks.new()
track.name = 'Death'
track.strips.new('Death', 1, st['action']).extrapolation = 'NOTHING'
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_set(1)
try:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (rig.parent, rig, model):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'nature_avatar_death.glb'), export_format='GLB',
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
raw = (OUT/'nature_avatar_death.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
assert {a['name'] for a in doc['animations']} == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon', 'Death'}
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 103
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives']) == 2060
report = dict(status='PASS', via='Blender MCP live', duration_s=5, frames=121, samples=241,
              fps=24, parts=86, bones=103, particles_included=False, root_motion=False,
              simulation=st['simulation'], initial_to_idle_vertex_error_m=join_error,
              minimum_z_m=low.z, bounds_min=list(low), bounds_max=list(high),
              maximum_half_frame_step_m=max_step, ground_rest_samples=ground_rest,
              full_size_wood_until_s=4., core_disappearance_starts_s=.18,
              core_completely_gone_s=.90, wood_held_until_s=1.05,
              wood_hold_vertex_error_m=wood_held_error, gone_core_extent_m=core_gone_extent,
              core_falls=False,
              wood_disappearance_starts_s=4., final_maximum_piece_extent_m=final_extent,
              physics_helpers_exported=False, original_asset_files_unchanged=True)
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
bpy.data.libraries.write(str(OUT/'nature_avatar_death.blend'), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
result = report
