"""Audit physical connections and geometry uniqueness in the live MCP editor."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
scope={'AUDIT_RUN':False}
exec((ROOT/'tools/art_pipeline/magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
rows=[]
for scene in bpy.data.scenes:
    if not scene.get('grand_military'):
        continue
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')]
    floating=[o['part'] for o in scope['detached'](parts)]
    coordinates=sorted((tuple(tuple(round(float(c),6) for c in v.co) for v in o.data.vertices),
                        tuple(tuple(p.vertices) for p in o.data.polygons)) for o in parts)
    digest=hashlib.sha256(json.dumps(coordinates,separators=(',',':')).encode()).hexdigest()
    rows.append({'scene':scene.name,'civilization':scene['civilization'],'role':scene['military_role'],
                 'physical_attachment_remaining':floating,'geometry_sha256':digest})
assert len(rows)==24,len(rows)
assert not any(r['physical_attachment_remaining'] for r in rows),rows
assert len({r['geometry_sha256'] for r in rows})==24
(ROOT/'docs/grand_military_attachment_audit.json').write_text(json.dumps({'verified':24,'remaining_physical_adornments':0,
    'unique_geometries':24,'method':'AABB connectivity, 0.0015 tolerance, and manual preview review; geometry hashes exclude labels/materials',
    'scenes':rows},ensure_ascii=False,indent=2),encoding='utf-8')
result={'verified':24,'remaining_physical_adornments':0,'unique_geometries':24}
