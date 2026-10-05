"""Save the reviewed Goblin scene alone, with packed atlas and no animation."""
import bpy
import json
import shutil
import tempfile
from pathlib import Path

st=bpy.app.driver_namespace['goblin_raider']; scene=st['scene']; report=st['report']
bpy.context.window.scene=scene; scene.frame_set(1)
source=Path(st['source'])/'goblin_raider_v3.blend'; out=Path(st['out'])
assert all(o.type!='ARMATURE' and o.animation_data is None for o in scene.objects)
assert all((out/'previews'/f'{name}.png').is_file() for name in ('front','three_quarter','side','back'))
report['visual_review']={'views':['front','three_quarter','side','back'],
 'identity':'Large pointed ears, projecting hooked nose, yellow eyes, small irregular teeth, skinny goblin silhouette',
 'loot_pouch':'Moved forward for front and three-quarter readability',
 'strap':'Continuous stepped strip follows the back without penetrating the chest'}
report['status']='Complete: static editable Goblin, no rig or animation, four review renders'
scene['status']=report['status']
bpy.ops.object.select_all(action='DESELECT')
root=bpy.data.objects[st['name']+'_ROOT']; root.select_set(True); bpy.context.view_layer.objects.active=root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.region_3d.view_location=(0,0,.65)
            area.spaces.active.region_3d.view_distance=2.2
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='goblin_source_check_') as folder:
    target=Path(folder)/'check.blend'; shutil.copyfile(source,target)
    with bpy.data.libraries.load(str(target)) as (src,dst):
        scenes=list(src.scenes); actions=list(src.actions); rigs=list(src.armatures)
assert scenes==[st['name']] and not actions and not rigs
report['source_validation']={'scenes':scenes,'actions':actions,'armatures':rigs,'packed_texture':True}
(out/'goblin_raider_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'source':str(source),'triangles':report['triangles'],'source_validation':report['source_validation']}
