"""Save the independent scene and start playback in the connected Blender."""
import bpy
import hashlib
from pathlib import Path

st = bpy.app.driver_namespace['seraph_summon']
scene, rig = st['scene'], st['rig']
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
bpy.context.window.scene = scene
for path, expected in st['protected'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == expected, path
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = st['action']
scene.frame_set(1)
scene.sync_mode = 'FRAME_DROP'
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
bpy.data.libraries.write(str(Path(st['out'])/'seraph_summon.blend'), {scene},
                         path_remap='RELATIVE', fake_user=True, compress=True)
bpy.ops.screen.animation_play()
result = dict(scene=scene.name, action=rig.animation_data.action.name,
              playing=bpy.context.screen.is_animation_playing,
              frame_range=[scene.frame_start, scene.frame_end], fps=scene.render.fps,
              other_manifestations_and_seraph_death_unchanged=True)
