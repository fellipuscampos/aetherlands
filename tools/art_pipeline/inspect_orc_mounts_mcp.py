import bpy,json,sys
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo');sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import WORK
review=next(s for s in bpy.data.scenes if s.name=='Orc_Troops_20_Review.006')
results=[]
for rig in (o for o in review.objects if o.type=='ARMATURE' and o.parent.get('family')=='cavalry'):
    parts=[o for o in review.objects if o.type=='MESH' and o.parent==rig]
    results.append(dict(tier=rig.parent['tier'],root_scale=list(rig.parent.scale),rig_local=[list(v) for v in rig.matrix_local],
        parts={o['part']:dict(vertices=[list(v.co) for v in o.data.vertices],bone=o['rig_bone'],region=o['region'],
            uv=[list(loop.uv) for loop in o.data.uv_layers.active.data]) for o in parts},
        bones={b.name:dict(head=list(b.head_local),tail=list(b.tail_local),parent=b.parent.name if b.parent else None) for b in rig.data.bones}))
(WORK/'war_boars/inspection.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result={'status':'PASS','mounted_models':len(results),'mount_parts':[n for n in results[0]['parts'] if n.startswith(('Horse','Saddle','Rein','Stirrup'))]}
