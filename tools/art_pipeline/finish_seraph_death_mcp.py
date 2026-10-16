"""Validate, export and render the live Seraph death review (via Blender MCP)."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

st = bpy.app.driver_namespace['seraph_death']
scene, rig, parts = st['scene'], st['rig'], st['parts']
OUT = Path(st['out'])
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
assert len(parts) == 36
for name, digest in st['protected'].items():
    assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest

# Check the actual deformed geometry, including half frames and the starting Idle pose.
rest = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
wing_parts = [o for o in parts if o.get('kind') == 'wing_feather']
def tree(obj, transform):
    return BVHTree.FromPolygons([transform@v.co for v in obj.data.vertices],
                               [tuple(p.vertices) for p in obj.data.polygons])
baseline = {o.name: tree(o, Matrix.Identity(4)) for o in wing_parts}
baseline_pairs = {(a.name, b.name) for i, a in enumerate(wing_parts) for b in wing_parts[i+1:]
                  if baseline[a.name].overlap(baseline[b.name])}
low = Vector((1e9,)*3)
high = Vector((-1e9,)*3)
collisions = []
max_step = 0.
previous = None
first = None
for half in range(169):
    f = 1+half/2
    scene.frame_set(int(f), subframe=f%1)
    matrices = {b.name: b.matrix@rest[b.name] for b in rig.pose.bones}
    assert all(abs(matrices['root'][i][j]-float(i == j)) < 1e-6
               for i in range(4) for j in range(4))
    points = [matrices[o['rig_bone']]@v.co for o in parts for v in o.data.vertices]
    assert all(math.isfinite(x) for p in points for x in p)
    for p in points:
        for k in range(3):
            low[k] = min(low[k], p[k])
            high[k] = max(high[k], p[k])
    if first is None:
        first = [p.copy() for p in points]
    if previous:
        max_step = max(max_step, max((a-b).length for a, b in zip(previous, points)))
    previous = points
    if f <= 66:  # Check the wings before they finish contracting.
        trees = {o.name: tree(o, matrices[o['rig_bone']]) for o in wing_parts}
        for i, a in enumerate(wing_parts):
            for b in wing_parts[i+1:]:
                if (a.name, b.name) not in baseline_pairs and trees[a.name].overlap(trees[b.name]):
                    collisions.append((f, a.name, b.name))
final = [p.copy() for p in points]
rig.animation_data.action = st['idle']
scene.frame_set(1)
matrices = {b.name: b.matrix@rest[b.name] for b in rig.pose.bones}
idle_points = [matrices[o['rig_bone']]@v.co for o in parts for v in o.data.vertices]
seam = max((a-b).length for a, b in zip(first, idle_points))
rig.animation_data.action = st['action']
assert seam < 1e-5, seam
assert low.z > .02, low.z
assert max((a-b).length for a in final for b in final) < .001
assert not collisions, collisions[:5]

# Export one rigid skinned model, preserving the approved UVs and materials.
temporary = bpy.data.collections.new('Seraph_Death_Export')
scene.collection.children.link(temporary)
vertices, faces, uvrows, groups = [], [], [], {}
for obj in parts:
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in obj.data.vertices)
    groups.setdefault(obj['rig_bone'], []).extend(range(offset, len(vertices)))
    for p in obj.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uvrows.extend(tuple(obj.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
mesh = bpy.data.meshes.new('Seraph_Death_ExportMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metric_Pixel_UV')
for i, row in enumerate(uvrows):
    uv.data[i].uv = row
mesh.materials.append(parts[0].data.materials[0])
model = bpy.data.objects.new('Seraph', mesh)
temporary.objects.link(model)
model.parent = rig
for name, indices in groups.items():
    model.vertex_groups.new(name=name).add(indices, 1, 'REPLACE')
model.modifiers.new('Rigid_Pivots', 'ARMATURE').object = rig
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
death_track = next((t for t in rig.animation_data.nla_tracks if t.name == 'Death'), None)
if death_track is not None:
    rig.animation_data.nla_tracks.remove(death_track)
death_track = rig.animation_data.nla_tracks.new()
death_track.name = 'Death'
death_track.strips.new('Death', 1, st['action']).extrapolation = 'NOTHING'
scene.frame_set(1)
try:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig.parent, rig, model]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    kwargs = dict(filepath=str(OUT/'seraph_death.glb'), export_format='GLB',
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

raw = (OUT/'seraph_death.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
clips = {a['name']: max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])
         for a in doc['animations']}
assert set(clips) == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon', 'Death'}, clips
assert abs(clips['Death']-3.5) < 1e-5
assert abs(clips['Summon']-4) < 1e-5
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 11
report = dict(status='PASS', via='Blender MCP live', duration_s=3.5, fps=24,
              frames=85, sampled_poses=169, root_motion=False,
              initial_to_idle_vertex_delta_m=seam, bounds_min=list(low), bounds_max=list(high),
              new_wing_intersections_before_extinction=len(collisions),
              maximum_half_frame_vertex_step_m=max_step,
              original_game_files_unchanged=True, export_clips=clips,
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
bpy.data.libraries.write(str(OUT/'seraph_death.blend'), {scene},
                         path_remap='RELATIVE', fake_user=True, compress=True)
result = report
