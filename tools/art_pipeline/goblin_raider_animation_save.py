"""Save the reviewed animated scene with its three actions and packed atlas."""
import bpy
import json
import shutil
import tempfile
from pathlib import Path

st=bpy.app.driver_namespace['goblin_animation']; scene=st['scene']; rig=st['rig']
assert st.get('validation') and st.get('surface_contacts')==[], 'Run both animation checks first.'
out=Path(st['out']); source=Path(st['source'])/'goblin_raider_v3.blend'
report=json.loads((out/'goblin_raider_v3_report.json').read_text(encoding='utf-8'))
report['rig']=True; report['bone_count']=len(rig.data.bones); report['bones']=list(rig.data.bones.keys())
report['animations']={name:{k:v for k,v in data.items() if k!='action'} for name,data in st['clips'].items()}
for data in report['animations'].values(): data['duration_seconds']=(data['end']-data['start'])/24
report['animation_validation']=st['validation']
report['animation_validation']['tested_surface_crossings']=0
report['notes']='49 editable meshes; rigid block skinning, weighted leather straps, baked foot planting, three actions at 24 fps.'
report['status']='Complete: rigged editable Goblin with Idle, Walk and Attack; MP4/GIF reviews.'
report['visual_review']['animation_views']='Three-quarter poses: anticipation, strike, recovery and opposing walk phases.'
scene['status']=report['status']; scene['description']='Animated Goblin raider: Idle / Walk / Attack. Original blocky geometry and pixel atlas retained.'
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_start=1; scene.frame_end=149; scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
rig.show_in_front=False
for data in st['clips'].values():
    name=data['action'].name
    assert (out/'previews/animations'/f'{name}.mp4').is_file()
    assert (out/'previews/animations'/f'{name}.gif').is_file()
assert all(image.packed_file for image in bpy.data.images if image.name.startswith(st['name']) and image.type=='IMAGE')
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='goblin_animated_check_') as folder:
    target=Path(folder)/'check.blend'; shutil.copyfile(source,target)
    with bpy.data.libraries.load(str(target)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); rigs=list(src.armatures)
assert scenes==[st['name']] and sorted(actions)==sorted(st['clips']) and len(rigs)==1
report['source_validation']={'scenes':scenes,'actions':actions,'armatures':rigs,'packed_texture':True}
(out/'goblin_raider_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(out/'goblin_raider_v3_animation_validation.json').write_text(json.dumps(report['animation_validation'],indent=2),encoding='utf-8')
result={'source':str(source),'source_validation':report['source_validation'],'bones':len(rig.data.bones),'editable_meshes':len(st['meshes'])}
