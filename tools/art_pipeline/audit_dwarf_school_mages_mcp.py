"""Check exposed coplanar faces and staff/arm separation in all six mages."""
import bpy, ast, math, json
from pathlib import Path
from collections import defaultdict
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/dwarf_school_mages_review'
assets=bpy.app.driver_namespace['dwarf_school_mage_assets_v1']
source=(ROOT/'tools/art_pipeline/audit_settler_surfaces_mcp.py').read_text(encoding='utf-8')
ns=dict(Vector=Vector,defaultdict=defaultdict,math=math)
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef): exec(compile(ast.get_source_segment(source,node),'<surface_audit>','exec'),ns)

def sat_intersects(a,b):
    points=[[vertex.co.copy() for vertex in obj.data.vertices] for obj in [a,b]]
    axes=[poly.normal for obj in [a,b] for poly in obj.data.polygons]
    edges=[[(obj.data.vertices[e.vertices[0]].co-obj.data.vertices[e.vertices[1]].co).normalized() for e in obj.data.edges] for obj in [a,b]]
    axes += [ea.cross(eb) for ea in edges[0] for eb in edges[1]]
    for axis in axes:
        if axis.length<1e-7: continue
        axis=axis.normalized()
        lo=[min(p.dot(axis) for p in group) for group in points]; hi=[max(p.dot(axis) for p in group) for group in points]
        if min(hi)-max(lo)<=.000001: return False
    return True

rows=[]
for asset in assets:
    issues,hidden=ns['audit'](asset['parts'])
    arm_intersection=sat_intersects(asset['staff'],asset['body']['Forearm_r'])
    hand_contact=sat_intersects(asset['staff'],asset['body']['Hand_r'])
    rows.append(dict(school=asset['report']['school'],exposed_coplanar_pairs=len(issues),hidden_coplanar_pairs=len(hidden),staff_forearm_intersection=arm_intersection,staff_hand_contact=hand_contact,issues=issues))
    asset['report']['surface_validation']=rows[-1]
    print(asset['report']['school'],len(issues),'staff/arm',arm_intersection,'hand',hand_contact,[(r['a'],r['b']) for r in issues])
bpy.app.driver_namespace['dwarf_school_mage_surface_audit_v1']=ns['audit']
bpy.app.driver_namespace['dwarf_school_mage_sat_v1']=sat_intersects
(WORK/'surface_audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
result=dict(models=len(rows),exposed_coplanar_pairs=sum(r['exposed_coplanar_pairs'] for r in rows),staff_arm_intersections=sum(r['staff_forearm_intersection'] for r in rows),staff_hand_contacts=sum(r['staff_hand_contact'] for r in rows))
