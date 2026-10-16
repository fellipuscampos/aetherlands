"""Record the anatomical head corners for measuring the imported runtime body."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
for race,family in [('human','humans'),('elf','elves'),('orc','orcs'),('dwarf','dwarves')]:
    scene=bpy.data.scenes[race.title()+'_Builder_V1']
    head=next(o for o in scene.objects if o.type=='MESH' and o.get('part')=='Head')
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    path=ROOT/f'assets/generated/{family}/{race}_builder_v1/{race}_builder_v1_report.json'
    report=json.loads(path.read_text(encoding='utf-8'))
    report['body_sizing']['head_bind_vertices_gltf']=[[v.co.x*rig.scale.x,v.co.z*rig.scale.x,-v.co.y*rig.scale.x] for v in head.data.vertices]
    path.write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'status':'PASS','assets':4}
