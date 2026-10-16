"""Final support audit inside the live Blender MCP, scoped to new landmarks only."""
import bpy
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
scope={'AUDIT_RUN':False}
exec((ROOT/'tools/art_pipeline/magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
floating={'Infernal_Rift_Core','Veil_Core','Primordial_Core'}
rows=[]
for scene in bpy.data.scenes:
    if not scene.get('grand_magic'):
        continue
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
    unattached=[o['part'] for o in scope['detached'](parts) if o['part'] not in floating]
    rows.append({'scene':scene.name,'civilization':scene['civilization'],'school':scene['magic_school'],
        'physical_attachment_remaining':unattached,'intentional_levitation':list(scene['intentional_levitation'])})
assert len(rows)==24,len(rows)
assert not any(row['physical_attachment_remaining'] for row in rows),rows
(ROOT/'docs/grand_magic_attachment_audit.json').write_text(json.dumps({'method':'AABB connectivity, 0.0015 tolerance, plus manual preview review',
    'verified':24,'remaining_physical_adornments':0,'scenes':rows},ensure_ascii=False,indent=2),encoding='utf-8')
result={'verified':24,'remaining_physical_adornments':0}
