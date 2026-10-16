"""Live MCP broad-phase attachment audit; floating magic is explicitly named."""
import bpy
import json
from pathlib import Path

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
FLOATING_MAGIC = {'Floating_Arcane_Prism','Practice_Focus','Elemental_Core'}

def bounds(obj):
    return (tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)),
            tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))

def detached(parts, tolerance=.0015):
    bb = [bounds(o) for o in parts]
    connected = {i for i,o in enumerate(parts) if o['part'].startswith('Hex_')}
    changing = True
    while changing:
        changing = False
        for i,(lo,hi) in enumerate(bb):
            if i in connected:
                continue
            if any(all(lo[k]<=bb[j][1][k]+tolerance and hi[k]>=bb[j][0][k]-tolerance for k in range(3)) for j in connected):
                connected.add(i)
                changing = True
    return [o for i,o in enumerate(parts) if i not in connected and o['part'] not in FLOATING_MAGIC]

if globals().get('AUDIT_RUN',True):
    rows = []
    for scene in bpy.data.scenes:
        if not scene.get('magic_school'):
            continue
        parts = [o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
        rows.append({'scene':scene.name,'polished':bool(scene.get('finish_pass_revision')),
                     'detached':[{'part':o['part'],'region':o['region'],'bounds':bounds(o)} for o in detached(parts)]})
    tag = globals().get('AUDIT_TAG','before')
    (ROOT/'docs'/('magic_school_attachment_audit_'+tag+'.json')).write_text(json.dumps(rows,indent=2),encoding='utf-8')
    result = {r['scene']:{'polished':r['polished'],'detached_count':len(r['detached']),
                         'examples':[x['part'] for x in r['detached'][:5]]} for r in rows}
