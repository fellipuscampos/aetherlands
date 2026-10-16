"""Leave the reviewed source selected and save only its isolated Blender scene."""
import bpy,hashlib,json
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['archdemon_blocky_v1']
scene,rig,root=st['scene'],st['rig'],st['root']; OUT=Path(st['out']); project=OUT.parents[3]
assert json.loads((OUT/'godot_validation.json').read_text(encoding='utf-8'))['status']=='PASS'
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
assert rig.animation_data is None
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
st['studio'].hide_select=True; st['studio'].hide_viewport=True
st['material'].node_tree.nodes.active=next(n for n in st['material'].node_tree.nodes if n.type=='TEX_IMAGE' and n.image==st['images'][0])
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active; space.shading.type='SOLID'; space.shading.color_type='TEXTURE'
        space.overlay.show_overlays=False; space.region_3d.view_location=Vector((0,.15,1.53))
        space.region_3d.view_distance=5.8; space.region_3d.view_rotation=st['camera'].rotation_euler.to_quaternion()
        space.region_3d.view_perspective='ORTHO'
bpy.data.libraries.write(str(OUT/(st['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'scene':scene.name,'height_m':3,'animations':0,'native_godot_validation':'PASS',
    'previous_scenes_preserved':len(st['old_scenes']),'protected_files_unchanged':len(st['old_hashes']),
    'model_ready_for_review':True}
