"""Export the animated Goblin source blend to the GLB used in game.

Standalone (no MCP session needed). Run headless with Blender 5.2:

    blender.exe -b --factory-startup art_source/goblin_raider_v3/goblin_raider_v3.blend \
        --python tools/art_pipeline/goblin_raider_export.py

Same export settings as troll_refine_export.py: one glTF animation per NLA
track (Goblin_Idle / Goblin_Walk / Goblin_Attack), slid to start at 0.
"""
import bpy
from pathlib import Path

NAME = 'Goblin_Raider_V3'
PROJECT = Path(bpy.data.filepath).resolve().parents[2]
OUT = PROJECT / 'assets/generated/goblins/goblin_raider_v3/goblin_raider_v3.glb'

scene = bpy.data.scenes[NAME]
bpy.context.window.scene = scene
root = bpy.data.objects[f'{NAME}_ROOT']
rig = bpy.data.objects[f'{NAME}_Rig']
meshes = [o for o in rig.children if o.type == 'MESH']
assert len(meshes) == 49, len(meshes)
assert sorted(t.name for t in rig.animation_data.nla_tracks) == ['Goblin_Attack', 'Goblin_Idle', 'Goblin_Walk']

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_start = 1
scene.frame_end = 149
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
