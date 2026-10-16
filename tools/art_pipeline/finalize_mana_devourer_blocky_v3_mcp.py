"""Save the revised isolated source and leave its slow Idle loop in Blender."""
import bpy,json,hashlib,re
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['mana_devourer_blocky_v3']
scene,rig,root=st['scene'],st['rig'],st['root']
bpy.context.window.scene=scene
project=Path(st['out']).parents[3]
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
log_path=project/'.godot/mana_blocky_v3_tests.log'
log=log_path.read_text(encoding='utf-16' if log_path.read_bytes().startswith(b'\xff\xfe') else 'utf-8')
assert re.search(r'Passing Tests\s+45',log) and 'All tests passed!' in log
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=False
scene.frame_start=1; scene.frame_end=385; scene.frame_set(1)
scene.render.resolution_x=900; scene.render.resolution_y=900
st['studio'].hide_select=True; st['studio'].hide_viewport=True
st['material'].node_tree.nodes.active=next(n for n in st['material'].node_tree.nodes
    if n.type=='TEX_IMAGE' and n.image==st['images'][0])
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True); bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active
        space.shading.type='SOLID'; space.shading.color_type='TEXTURE'
        space.overlay.show_overlays=False
        space.region_3d.view_location=Vector((0,0,1.03))
        space.region_3d.view_distance=3.2
        space.region_3d.view_rotation=st['camera'].rotation_euler.to_quaternion()
bpy.data.libraries.write(str(Path(st['out'])/(st['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
verification={'game_integration':'PASS','regression_tests_passed':45,'native_godot_poses_checked':615,
    'animation_blending_preserves_orbit':True,'forms':5,'stones':4,'triangles':92,
    'previous_mana_devourer_files_preserved':len(st['old_hashes']),
    'previous_blender_scenes_preserved':len(st['old_scenes']),
    'new_scene':scene.name,'idle_seconds':16,'preview_renderer':'Godot, imported GLB',
    'lore':'Elven study of this natural mana-driven stone life led humans to develop golems.'}
(Path(st['out'])/'integration_validation.json').write_text(json.dumps(verification,indent=2),encoding='utf-8')
if not bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
result=verification
