"""Ground the two carved arch ends identified in the final elf grove preview."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME='Elf_Druidic_Ritual_Hex_V1'
ASSET_FOLDER='elf_druidic_ritual_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
NAME,scene,parts,groups,root=st['name'],st['scene'],st['parts'],st['groups'],st['root']
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for node in ast.parse((PIPELINE/'warrior_hall_hex_v1_model.py').read_text(encoding='utf-8')).body:
    if isinstance(node,ast.FunctionDef) and node.name in ('mesh','box'):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<grove_footings>','exec'))
if not scene.get('carved_branch_footings'):
    for sign in (-1,1):
        obj=box('Ancestral_Carved_Branch_Foot_'+str(sign),(sign*.515,.02,.133),(.095,.091,.112),'timber','08_DETAILS')
        obj.parent=root
    scene['carved_branch_footings']=True
scope={'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
scene['physical_attachment_remaining']=[o['part'] for o in scope['detached'](parts)]
assert not scene['physical_attachment_remaining']
st['parts']=parts
bpy.app.driver_namespace['guardian_hall']=st
exec((PIPELINE/'grand_magic_finish.py').read_text(encoding='utf-8'))
