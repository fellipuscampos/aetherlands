"""Save the current Spider and its reviewed actions, isolated from other Blender scenes."""
import bpy
import json
import shutil
import tempfile
import hashlib
from pathlib import Path

st=bpy.app.driver_namespace['spider_animation']; scene=st['scene']; rig=st['rig']; out=Path(st['out'])
assert st['validation']['surface_crossings']==[]
image=bpy.data.images['Giant_Spider_V1_PixelAtlas']
assert bytes(image.packed_file.data)==(out/'giant_spider_v1_atlas.png').read_bytes()
pixels=list(image.pixels[:]); assert not any(pixels[k+1]>pixels[k]*1.25 and pixels[k+1]>pixels[k+2]*1.5 and pixels[k+1]>.2 for k in range(0,len(pixels),4))
for n in st['clips']:
    assert (out/'previews/animations'/f'{n}.mp4').exists()
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=False
scene.frame_start=1; scene.frame_end=167; scene.frame_set(1); rig.show_in_front=False
scene.camera.data.ortho_scale=4.1
scene['description']='Edited Giant Spider: no green texture; 31 editable parts; Spider_Idle, Spider_Walk, Spider_Attack.'
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
source=out/'giant_spider_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='spider_animation_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); armatures=list(src.armatures)
assert scenes==[st['name']] and sorted(actions)==sorted(st['clips']) and len(armatures)==1
triangles=0
for o in st['meshes']: o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
report={'status':'Reviewed animations saved in editable Blender source',
 'parts':len(st['meshes']),'triangles':triangles,'bones':len(rig.data.bones),'fps':24,
 'clips':{n:{k:v for k,v in data.items() if k!='action'} for n,data in st['clips'].items()},
 'validation':st['validation'],'source_validation':{'scenes':scenes,'actions':actions,'armatures':armatures},
 'texture':'Packed atlas matches PNG; no green texels; texture untouched by animation work',
 'geometry':'User deletions preserved; 31 editable parts, original UVs',
 'glb':'Previous static export; this delivery updates Blender and animation previews only.'}
(out/'animation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source':str(source),'parts':len(st['meshes']),'triangles':triangles,'bones':len(rig.data.bones),'source_validation':report['source_validation']}
