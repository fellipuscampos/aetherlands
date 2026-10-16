"""Probe safe orc staff carrying angles without changing approved geometry."""
import bpy,sys,importlib,ast,numpy as np
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
import school_mage_motion as m; importlib.reload(m)
source=(ROOT/'tools/art_pipeline/animate_school_mage_mcp.py').read_text(encoding='utf-8')
for n in ast.parse(source).body:
    if isinstance(n,ast.FunctionDef) and n.name in ('box_intersects','coordinates'): exec(compile(ast.get_source_segment(source,n),'<collision_probe>','exec'),globals())
a=bpy.app.driver_namespace['orc_school_mage_assets_v1'][0]
by={o['part']:o for o in a['parts']}; checks=[]
for pitch in (-2,-4,-6,-8,-10,-12):
    m.STYLE['orc']['walk_staff_pitch']=pitch; hits=0; floor=999
    for i in range(73):
        d=m.pose('orc','walk',i/72,a['bones'],a['chains'])
        pts=coordinates(a['staff'],d['hand_r']); floor=min(floor,float(pts[:,2].min()))
        hits+=int(box_intersects(pts,coordinates(by['Forearm_r'],d['forearm_r'])))
    checks.append(dict(pitch=pitch,intersections=hits,staff_floor=floor))
hits=[]
for i in range(145):
    d=m.pose('orc','spell',i/144,a['bones'],a['chains'])
    if box_intersects(coordinates(a['staff'],d['hand_r']),coordinates(by['Forearm_r'],d['forearm_r'])): hits.append(i)
result=dict(walk=checks,spell_intersections=hits)
