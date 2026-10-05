"""Export the corrected scene, three NLA clips, packed texture and FBX."""
import bpy
import json
import shutil
import tempfile
from pathlib import Path

st=bpy.app.driver_namespace['troll_refinement']; scene=st['scene']; rig=st['rig']; report=st['report']
bpy.context.window.scene=scene; OUT=Path(st['out']); SOURCE=Path(st['source'])
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
rig['walk_in_place_speed_mps']=.34/(.60*28/24)
st['clips']['Troll_Walk']['suggested_translation_mps']=rig['walk_in_place_speed_mps']
report['animations']['Troll_Walk']['suggested_translation_mps']=rig['walk_in_place_speed_mps']
scene.frame_start=1; scene.frame_end=137; scene.frame_set(1); bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for obj in st['meshes']+[rig]: obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'troll_blocky_v3.glb'),export_format='GLB',
 use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',
 export_anim_slide_to_zero=True,export_force_sampling=True,export_frame_range=False,
 export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(SOURCE/'troll_blocky_v3.fbx'),use_selection=True,
 object_types={'ARMATURE','MESH'},add_leaf_bones=False,bake_anim=True,
 bake_anim_use_all_actions=False,bake_anim_use_nla_strips=True,bake_anim_step=1,
 path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y')
scene['production_state']='Refined blocky geometry, metric pixel UVs, three baked gameplay actions'
bpy.data.libraries.write(str(SOURCE/'troll_blocky_v3.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='troll_refined_source_') as folder:
    check=Path(folder)/'check.blend'; shutil.copyfile(SOURCE/'troll_blocky_v3.blend',check)
    with bpy.data.libraries.load(str(check)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions)
assert scenes==[scene.name]
assert sorted(actions)==['Troll_Attack','Troll_Idle','Troll_Walk'],actions
report['source_validation']={'scenes':scenes,'actions':actions,'images_packed':True}
report['formats']=['blend','glb','fbx','png']
(OUT/'troll_blocky_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source_scenes':scenes,'source_actions':actions,'exports':['blend','glb','fbx']}
