"""Export only the final scene and its currently assigned validation animation."""
import bpy
import json
import shutil
import tempfile
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); NAME='Troll_Blocky_V3'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene; scene.frame_set(1)
SOURCE=ROOT/'art_source/troll_blocky_v3'; OUT=ROOT/'assets/generated/trolls/troll_blocky_v3'
bpy.ops.object.select_all(action='DESELECT')
for name in ('Body','Club','Rig'): bpy.data.objects[NAME+'_'+name].select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects[NAME+'_Rig']
bpy.ops.export_scene.gltf(filepath=str(OUT/'troll_blocky_v3.glb'),export_format='GLB',
 use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',
 export_nla_strips_merged_animation_name='Blocky_Rig_Validation',export_force_sampling=True,
 export_frame_range=True,export_skins=True,export_def_bones=False,export_yup=True,
 export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(SOURCE/'troll_blocky_v3.fbx'),use_selection=True,
 object_types={'ARMATURE','MESH'},add_leaf_bones=False,bake_anim=True,
 bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,path_mode='COPY',
 embed_textures=True,axis_forward='-Z',axis_up='Y')
# Scene-only source prevents rejected drafts, default cubes or unrelated actions
# from leaking into the deliverable. Pixel image remains packed.
bpy.data.libraries.write(str(SOURCE/'troll_blocky_v3.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='troll_source_check_') as check_dir:
    check_path=Path(check_dir)/'source_check.blend'
    shutil.copyfile(SOURCE/'troll_blocky_v3.blend',check_path)
    with bpy.data.libraries.load(str(check_path)) as (data_from,data_to):
        saved_scenes=list(data_from.scenes)
        saved_actions=list(data_from.actions)
assert saved_scenes==[NAME] and saved_actions==['Blocky_Rig_Validation']
result={'source_scenes':saved_scenes,'source_actions':saved_actions,'exports':['blend','glb','fbx']}
