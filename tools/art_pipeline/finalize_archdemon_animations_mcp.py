"""Leave the independent animated seraph scene playing its idle loop."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['archdemon_blocky_v4_animated']
scene,rig,root=st['scene'],st['rig'],st['root']; OUT=Path(st['out']); ROOT=OUT.parents[3]
assert json.loads((OUT/'godot_validation.json').read_text(encoding='utf-8'))['status']=='PASS'
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_start=1; scene.frame_end=st['clips']['Idle']['end_frame']; scene.render.fps=24; scene.frame_set(1)
st['studio'].hide_select=True; st['studio'].hide_viewport=True
st['material'].node_tree.nodes.active=next(n for n in st['material'].node_tree.nodes if n.type=='TEX_IMAGE' and 'albedo' in n.image.name)
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active; space.shading.type='SOLID'; space.shading.color_type='TEXTURE'; space.overlay.show_overlays=False
        space.region_3d.view_location=Vector((0,0,1.8)); space.region_3d.view_distance=5.
        space.region_3d.view_rotation=st['camera'].rotation_euler.to_quaternion()
bpy.data.libraries.write(str(OUT/(st['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with bpy.data.libraries.load(str(OUT/(st['stem']+'.blend'))) as (source,destination):
    assert source.scenes==[st['name']] and len(source.actions)==4
if not bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
result={'scene':scene.name,'clips':list(st['clips']),'native_validation':'PASS',
        'previous_scenes_preserved':len(st['old_scenes']),'protected_files_unchanged':len(st['old_hashes'])}
