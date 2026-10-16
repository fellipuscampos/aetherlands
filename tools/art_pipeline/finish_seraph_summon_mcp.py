"""Validate, export and render the live Seraph summon review (via Blender MCP)."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

st = bpy.app.driver_namespace['seraph_summon']
scene, rig, parts = st['scene'], st['rig'], st['parts']
OUT = Path(st['out'])
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
assert len(parts) == 36
for path, digest in st['protected'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest, path

# Check the actual deformed geometry, including half frames and the Idle join.
rest = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
wing_parts = [o for o in parts if o.get('kind') == 'wing_feather']
def positions(obj, matrices):
    return [sum((matrices[obj.vertex_groups[g.group].name]@v.co*g.weight for g in v.groups), Vector())
            for v in obj.data.vertices]
def tree(obj, points):
    return BVHTree.FromPolygons(points,
                               [tuple(p.vertices) for p in obj.data.polygons])
baseline = {o.name: tree(o, [v.co for v in o.data.vertices]) for o in wing_parts}
baseline_pairs = {(a.name, b.name) for i, a in enumerate(wing_parts) for b in wing_parts[i+1:]
                  if baseline[a.name].overlap(baseline[b.name])}
low = Vector((1e9,)*3)
high = Vector((-1e9,)*3)
collisions = []
max_step = 0.
previous = None
first_diameters, core_only_diameters = {}, {}
for half in range(241):
    f = 1+half/2
    scene.frame_set(int(f), subframe=f%1)
    matrices = {b.name: b.matrix@rest[b.name] for b in rig.pose.bones}
    assert all(abs(matrices['root'][i][j]-float(i == j)) < 1e-6
               for i in range(4) for j in range(4))
    rows = {o.name: positions(o, matrices) for o in parts}
    points = [p for o in parts for p in rows[o.name]]
    if half in (0, 36):
        diameters = {o.name: max((p-q).length for p in rows[o.name] for q in rows[o.name]) for o in parts}
        if half == 0:
            first_diameters = diameters
        else:
            core_only_diameters = diameters
    assert all(math.isfinite(x) for p in points for x in p)
    for p in points:
        for k in range(3):
            low[k] = min(low[k], p[k])
            high[k] = max(high[k], p[k])
    if previous:
        max_step = max(max_step, max((a-b).length for a, b in zip(previous, points)))
    previous = points
    if f >= 86:  # Wings have grown; check the entire unfurl and recovery.
        trees = {o.name: tree(o, rows[o.name]) for o in wing_parts}
        for i, a in enumerate(wing_parts):
            for b in wing_parts[i+1:]:
                if (a.name, b.name) not in baseline_pairs and trees[a.name].overlap(trees[b.name]):
                    collisions.append((f, a.name, b.name))
final = [p.copy() for p in points]
rig.animation_data.action = st['idle']
scene.frame_set(1)
matrices = {b.name: b.matrix@rest[b.name] for b in rig.pose.bones}
idle_points = [p for o in parts for p in positions(o, matrices)]
seam = max((a-b).length for a, b in zip(final, idle_points))
rig.animation_data.action = st['action']
assert seam < 1e-5, seam
assert low.z > .09, low.z
assert not collisions, collisions[:5]
assert max(first_diameters.values()) < .0001, first_diameters
energy = next(o for o in parts if o.get('kind') == 'light')
assert core_only_diameters[energy.name] > .5
assert max(value for name, value in core_only_diameters.items() if name != energy.name) < .0001

# Export one rigid skinned model, preserving the approved UVs and materials.
temporary = bpy.data.collections.new('Seraph_Summon_Export')
scene.collection.children.link(temporary)
vertices, faces, uvrows, groups = [], [], [], {}
for obj in parts:
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in obj.data.vertices)
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            groups.setdefault(obj.vertex_groups[group.group].name, []).append((offset+vertex.index, group.weight))
    for p in obj.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uvrows.extend(tuple(obj.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
mesh = bpy.data.meshes.new('Seraph_Summon_ExportMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metric_Pixel_UV')
for i, row in enumerate(uvrows):
    uv.data[i].uv = row
mesh.materials.append(parts[0].data.materials[0])
model = bpy.data.objects.new('Seraph', mesh)
temporary.objects.link(model)
model.parent = rig
for name, entries in groups.items():
    group = model.vertex_groups.new(name=name)
    for index, weight in entries:
        group.add([index], weight, 'REPLACE')
model.modifiers.new('Rigid_Pivots', 'ARMATURE').object = rig
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
summon_track = next((t for t in rig.animation_data.nla_tracks if t.name == 'Summon'), None)
if summon_track is not None:
    rig.animation_data.nla_tracks.remove(summon_track)
summon_track = rig.animation_data.nla_tracks.new()
summon_track.name = 'Summon'
summon_track.strips.new('Summon', 1, st['action']).extrapolation = 'NOTHING'
scene.frame_set(1)
try:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig.parent, rig, model]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    kwargs = dict(filepath=str(OUT/'seraph_summon.glb'), export_format='GLB',
                  use_selection=True, use_active_scene=True, export_animations=True,
                  export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
                  export_force_sampling=True, export_frame_range=False,
                  export_skins=True, export_def_bones=False, export_yup=True,
                  export_cameras=False, export_lights=False)
    if 'export_optimize_animation_size' in bpy.ops.export_scene.gltf.get_rna_type().properties:
        kwargs['export_optimize_animation_size'] = False
    bpy.ops.export_scene.gltf(**kwargs)
finally:
    bpy.data.objects.remove(model, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(temporary)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = st['action']

raw = (OUT/'seraph_summon.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
clips = {a['name']: max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])
         for a in doc['animations']}
assert set(clips) == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon'}, clips
assert abs(clips['Summon']-5) < 1e-5
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 56
report = dict(status='PASS', via='Blender MCP live', duration_s=5, fps=24,
              frames=121, sampled_poses=241, root_motion=False,
              final_to_idle_vertex_delta_m=seam, bounds_min=list(low), bounds_max=list(high),
              new_wing_intersections_after_materialization=len(collisions),
              maximum_half_frame_vertex_step_m=max_step,
              original_game_files_unchanged=True, export_clips=clips,
              original_clip_deformed_vertex_error_m=st['original_clip_vertex_error'],
              initially_hidden=True, core_alone_until_s=.9, individual_assembly_controls=27,
              wing_flow_controls=18, bones=56,
              particles_included=False, vfx_meshes=0)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
st['report'] = report

# Present the animated model in camera view, ready for Space to play.
bpy.ops.object.select_all(action='DESELECT')
rig.parent.select_set(True)
bpy.context.view_layer.objects.active = rig.parent
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        space.shading.use_scene_world = True
        space.shading.use_scene_lights = True
        space.overlay.show_overlays = False
        space.region_3d.view_perspective = 'CAMERA'
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/'seraph_summon.blend'), {scene},
                         path_remap='RELATIVE', fake_user=True, compress=True)
result = report
