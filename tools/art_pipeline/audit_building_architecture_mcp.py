"""Read-only inspection of the building sources through the open Blender MCP."""
import bpy
import json
from pathlib import Path
from collections import Counter

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
audit = []
for civ in ('humans','elves','dwarves','orcs'):
    for file in sorted((ROOT/'assets/generated'/civ/'buildings').glob('*/*_report.json')):
        report = json.loads(file.read_text(encoding='utf-8'))
        name = report['name']
        if name not in bpy.data.scenes:
            with bpy.data.libraries.load(str(file.parent/(file.parent.name+'.blend')),link=False) as (src,dst):
                dst.scenes = [name]
        scene = bpy.data.scenes[name]
        items = []
        for obj in scene.objects:
            if obj.type!='MESH' or not obj.get('part') or obj.get('region')=='studio' or obj.get('preview_only'): continue
            lo = [round(min(v.co[i] for v in obj.data.vertices),5) for i in range(3)]
            hi = [round(max(v.co[i] for v in obj.data.vertices),5) for i in range(3)]
            group = next((c.name[len(name)+1:] for c in obj.users_collection if c.name.startswith(name+'_')), '')
            items.append({'part':obj['part'],'region':obj['region'],'group':group,'min':lo,'max':hi})
        audit.append({'folder':file.parent.name,'civilization':civ,'scene':name,'relative':file.parent.relative_to(ROOT).as_posix(),
                      'regions':dict(Counter(o['region'] for o in items)), 'parts':items,
                      'metadata':{k:str(scene[k]) for k in scene.keys() if k!='palette_overrides'}})
out = ROOT/'art_source/building_architecture_review'
out.mkdir(parents=True,exist_ok=True)
(out/'audit_before.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
result = {'buildings_reviewed':len(audit),'output':str(out/'audit_before.json')}
