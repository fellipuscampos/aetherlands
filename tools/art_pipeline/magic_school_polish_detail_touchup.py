"""Two small first-preview corrections, without changing the existing building."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_FOLDER,ASSET_NAME=TOUCHUP_FOLDER,TOUCHUP_FOLDER.title()
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
NAME,scene,parts,groups,root=st['name'],st['scene'],st['parts'],st['groups'],st['root']
TRIM={'human':'gold','orc':'iron','dwarf':'bronze','elf':'gold'}[scene['civilization']]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (('warrior_hall_hex_v1_model.py',('mesh','box')),('magic_school_model.py',('beam',))):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<touchup_primitives>','exec'))
if not scene.get('finish_detail_touchup'):
    if scene['magic_school']=='sacred':
        backing=next(o for o in parts if o['part']=='Finish_Solar_Crest_Backing')
        for v in backing.data.vertices:
            v.co.y+=.022
        backing.data.update()
        beam('Finish_Solar_Cross_Stem',(.045,-.249,.760),(.045,-.223,.760),.014,TRIM,'04_FOCUS')
    elif scene['magic_school']=='necromancy':
        box('Finish_Crypt_Crossbone_Binding',(0,-.125,.544),(.032,.046,.033),TRIM,'04_FOCUS')
    for obj in parts:
        obj.parent=root
    AUDIT_RUN=False
    exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
    scene['finish_pass_attachment_remaining']=[o['part'] for o in detached(parts)]
    scene['finish_detail_touchup']=True
st['parts']=parts
bpy.app.driver_namespace['guardian_hall']=st
exec((PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8'))
