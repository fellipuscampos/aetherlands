import bpy
import json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
exec((ROOT/'tools/art_pipeline/grand_military_geometry_audit.py').read_text(encoding='utf-8'))
rows=[]
for scene in bpy.data.scenes:
    if not scene.get('grand_military'):
        continue
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')]
    rows.append({'scene':scene.name,**geometry_audit(parts,scene)})
tag=globals().get('AUDIT_TAG','before')
(ROOT/'docs'/('grand_military_geometry_'+tag+'.json')).write_text(json.dumps(rows,indent=2),encoding='utf-8')
result={'assets':[{'scene':r['scene'],'coplanar':len(r['coplanar_faces']),'masts':len(r['mast_roof_intersections']),
         'doors':[(d['prefix'],d['blockers']) for d in r['entrances']],
         'passages':[(d['name'],d['blockers']) for d in r['open_passages'] if d['blockers']]} for r in rows]}
