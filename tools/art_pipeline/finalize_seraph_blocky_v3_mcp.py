"""Save only this revised source and leave the requested core/orbit study playing."""
import bpy, hashlib, json
from pathlib import Path
from mathutils import Vector

st = bpy.app.driver_namespace['seraph_blocky_v3']
scene, rig, root = st['scene'], st['rig'], st['root']
OUT = Path(st['out'])
project = OUT.parents[3]
assert json.loads((OUT / 'godot_validation.json').read_text(encoding='utf-8'))['status'] == 'PASS'
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
for name, digest in st['old_hashes'].items():
    assert hashlib.sha256((project / name).read_bytes()).hexdigest() == digest, name
assert rig.animation_data is not None and len(rig.animation_data.nla_tracks) == 1
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
scene.frame_start = 1
scene.frame_end = st['rotation_frames']
scene.render.fps = 24
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
scene.frame_set(1)
st['studio'].hide_select = True
st['studio'].hide_viewport = True
st['material'].node_tree.nodes.active = next(n for n in st['material'].node_tree.nodes
    if n.type == 'TEX_IMAGE' and n.image == st['images'][0])
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'SOLID'
        space.shading.color_type = 'TEXTURE'
        space.overlay.show_overlays = False
        space.region_3d.view_location = Vector((0, 0, 1.72))
        space.region_3d.view_distance = 6.5
        space.region_3d.view_rotation = st['camera'].rotation_euler.to_quaternion()
bpy.data.libraries.write(str(OUT / (st['stem'] + '.blend')), {scene},
    path_remap='RELATIVE', fake_user=True, compress=True)
result = {'scene': scene.name, 'height_m': 3, 'animations': 1, 'rotation_seconds': 24,
          'native_godot_validation': 'PASS', 'previous_scenes_preserved': len(st['old_scenes']),
          'protected_files_unchanged': len(st['old_hashes']), 'model_ready_for_review': True}

if not bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
