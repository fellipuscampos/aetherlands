"""Read native roofs and snapshot all approved non-roof geometry through MCP."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
REVIEW=ROOT/'art_source/infrastructure_roof_review'
REVIEW.mkdir(exist_ok=True)
(REVIEW/'.gdignore').write_text('',encoding='utf-8')
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
rows=[]
for entry in entries:
    plural={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}[entry['civilization']]
    report=json.loads((ROOT/'assets/generated'/plural/'buildings'/entry['asset']/(entry['asset']+'_report.json')).read_text(encoding='utf-8'))
    scene=bpy.data.scenes[report['name']]
    geometry={}
    roofs={}
    for obj in scene.objects:
        part=obj.get('part')
        if obj.type!='MESH' or not part or obj.get('region')=='studio' or obj.get('preview_only'): continue
        data={'vertices':[[round(float(c),7) for c in v.co] for v in obj.data.vertices],'faces':[list(f.vertices) for f in obj.data.polygons]}
        geometry[part]={'sha256':hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest(),'region':obj.get('region')}
        if '_Tile_Course_' in part:
            prefix=part.split('_Tile_Course_')[0]
            roofs.setdefault(prefix,[]).append({'part':part,'vertices':len(obj.data.vertices),'min':[min(v.co[i] for v in obj.data.vertices) for i in range(3)],'max':[max(v.co[i] for v in obj.data.vertices) for i in range(3)]})
    rows.append({'asset':entry['asset'],'civilization':entry['civilization'],'role':entry['role'],'scene':scene.name,'geometry':geometry,'roofs':roofs})
snapshot=REVIEW/'source_before.json'
assert not snapshot.exists(),'Preserve the original source snapshot.'
snapshot.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
result={'assets':len(rows),'rectangular_roofs':sum(len(r['roofs']) for r in rows),'scenes':len(bpy.data.scenes),'roofs':[{'asset':r['asset'],'names':list(r['roofs'])} for r in rows]}
