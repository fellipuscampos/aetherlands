"""Validate and export the Nature Avatar's Summon through the live Blender."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st = bpy.app.driver_namespace['nature_avatar_summon']
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
previous = None
max_step = joint_gap = wrist_angle = anchor_error = 0.
initial_max_extent = 0.
ground_clearance = 1e9
core_only_verified = False
core = next(o for o in parts if o['rig_bone'] == 'core')
others = [o for o in parts if o != core]
collision_checks = 0
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
    if half == 0:
        initial_max_extent = max((Vector(bounds(rows[o.name])[1])-Vector(bounds(rows[o.name])[0])).length for o in parts)
    if f == 16:
        assert abs(rig.pose.bones['core'].scale.x-1.) < 1e-5
        assert all(rig.pose.bones[d['bone']].scale.x < .00002 for d in st['bindings'].values())
        core_only_verified = True
    ground_clearance = min(ground_clearance, min(p.z for p in points))
    for side in ('L', 'R'):
        joints = [rig.data.bones[n+'_'+side].head_local for n in ('upper_arm', 'forearm', 'hand')]
        for p, a, b in [(joints[0], 'chest', 'upper_arm_'+side),
                         (joints[1], 'upper_arm_'+side, 'forearm_'+side),
                         (joints[2], 'forearm_'+side, 'hand_'+side)]:
            joint_gap = max(joint_gap, (matrices[a]@p-matrices[b]@p).length)
        wrist_angle = max(wrist_angle, math.degrees(rig.pose.bones['hand_'+side].rotation_quaternion.angle))
    if f >= 105:
        for data in st['bindings'].values():
            anchor_error = max(anchor_error, max((a-b).length for a, b in
                zip(matrices[data['bone']], matrices[data['parent']])))
    if half % 3 == 0:
        a = bounds(rows[core.name])
        core_tree = BVHTree.FromPolygons(rows[core.name], [tuple(p.vertices) for p in core.data.polygons])
        for obj in others:
            b = bounds(rows[obj.name])
            if not all(a[0][i] <= b[1][i] and b[0][i] <= a[1][i] for i in range(3)):
                continue
            tree = BVHTree.FromPolygons(rows[obj.name], [tuple(p.vertices) for p in obj.data.polygons])
            assert not core_tree.overlap(tree), ('core collision', f, obj.name)
            collision_checks += 1
    if previous is not None:
        max_step = max(max_step, max((a-b).length for a, b in zip(previous, points)))
    previous = points
join_error = max((p-q).length for o in parts for p, q in zip(rows[o.name], idle[o.name]))
assert initial_max_extent < .001, initial_max_extent
assert core_only_verified
assert ground_clearance > .01, ground_clearance
assert join_error < 1e-5, join_error
assert joint_gap < 1e-5 and anchor_error < 1e-5
assert wrist_angle < 12.01
assert max_step < .20, max_step

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
mesh = bpy.data.meshes.new('Nature_Avatar_Summon_ExportMesh')
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
    bpy.ops.export_scene.gltf(filepath=str(OUT/'nature_avatar_summon.glb'), export_format='GLB',
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
raw = (OUT/'nature_avatar_summon.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
assert {a['name'] for a in doc['animations']} == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon'}
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 103
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives']) == 2060
report = dict(status='PASS', via='Blender MCP live', duration_s=5, frames=121, samples=241,
              fps=24, parts=86, bones=103, original_bones=18, assembly_bones=85,
              particles_included=False, root_motion=False, style='core first, wood assembly',
              initial_maximum_piece_extent_m=initial_max_extent, core_only_at_0_625_seconds=core_only_verified,
              minimum_ground_clearance_m=ground_clearance, final_to_idle_vertex_error_m=join_error,
              maximum_half_frame_step_m=max_step, joint_gap_m=joint_gap,
              maximum_wrist_angle_deg=wrist_angle, assembled_binding_error_m=anchor_error,
              core_bark_collision_checks=collision_checks, core_bark_intersections=0,
              original_clip_vertex_error_m=st['original_clip_vertex_error'],
              original_asset_files_unchanged=True)
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
bpy.data.libraries.write(str(OUT/'nature_avatar_summon.blend'), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
result = report
