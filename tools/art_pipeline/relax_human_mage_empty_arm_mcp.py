"""Use the approved human's hanging arm silhouette, with no presentation pose."""
import bpy,ast,math,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8'); ns=dict(np=np,Vector=Vector,Matrix=Matrix)
node=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='reframe')
exec(compile(ast.get_source_segment(source,node),'<reframe>','exec'),ns)
for a in bpy.app.driver_namespace['human_school_mage_assets_v1']:
    pivot=Vector((0,0,1.012)); torso=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(a['report']['elderly_posture']['torso_forward_degrees']),4,'X')@Matrix.Translation(-pivot)
    s=torso@Vector((.277,-.009,1.313)); s.z-=.022
    upper,fore,hand=[a['body'][p+'_l'] for p in ['UpperArm','Forearm','Hand']]
    lengths=[(o.data.vertices[4].co-o.data.vertices[0].co).length for o in [upper,fore,hand]]
    direction=Vector((.16,-.12,-1)).normalized(); e=s+direction*lengths[0]; w=e+direction*(lengths[1]+.0005)
    for obj,center in [(upper,(s+e)/2),(fore,e+direction*(lengths[1]/2+.0005)),(hand,w+direction*(lengths[2]/2+.0005))]:
        ns['reframe'](obj,center,-direction)
    a['report']['style_validation']['offhand_pose']='hanging_at_side'
result=dict(status='PASS',models=6,offhand_pose='hanging_at_side')
