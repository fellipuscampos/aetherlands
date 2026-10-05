"""Export the animated Giant Spider source blend to the GLB used in game.

Standalone (no MCP session needed). Run headless with Blender 5.2:

    blender.exe -b --factory-startup assets/generated/spiders/giant_spider_v1/giant_spider_v1.blend \
        --python tools/art_pipeline/spider_export.py

Same export settings as goblin_raider_export.py: one glTF animation per NLA
track (Spider_Idle / Spider_Walk / Spider_Attack), slid to start at 0.
"""
import bpy
from pathlib import Path

NAME = 'Giant_Spider_V1'
OUT = Path(bpy.data.filepath).resolve().parent / 'giant_spider_v1.glb'

scene = bpy.data.scenes[NAME]
bpy.context.window.scene = scene
root = bpy.data.objects[f'{NAME}_ROOT']
rig = bpy.data.objects[f'{NAME}_Rig']
meshes = [o for o in rig.children if o.type == 'MESH']
assert len(meshes) == 31, len(meshes)
assert sorted(t.name for t in rig.animation_data.nla_tracks) == ['Spider_Attack', 'Spider_Idle', 'Spider_Walk']
# O atlas embutido tem que ser o PNG sem verde (ver spider_animation_save.py).
image = bpy.data.images[f'{NAME}_PixelAtlas']
assert bytes(image.packed_file.data) == (OUT.parent / 'giant_spider_v1_atlas.png').read_bytes()

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_start = 1
scene.frame_end = 167
scene.frame_set(1)
bpy.context.view_layer.update()

bpy.ops.object.select_all(action='DESELECT')
for obj in meshes + [rig, root]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB',
    use_selection=True, use_active_scene=True, export_animations=True, export_animation_mode='NLA_TRACKS',
    export_anim_slide_to_zero=True, export_force_sampling=True, export_frame_range=False,
    export_skins=True, export_def_bones=False, export_yup=True, export_cameras=False, export_lights=False)
print('EXPORTED', OUT)
