"""Resolve the new live scene and primitive functions for small preview corrections."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st=bpy.app.driver_namespace['guardian_hall']
scene,NAME,parts,groups=st['scene'],st['name'],st['parts'],st['groups']
assert scene.get('grand_military')
TRIM={'human':'iron_light','orc':'iron','dwarf':'bronze','elf':'gold'}[scene['civilization']]
CIV,ROLE=scene['civilization'],scene['military_role']
POST='cutstone' if CIV=='dwarf' else 'timber'
BODY={'human':'plaster','orc':'door','dwarf':'stone','elf':'plaster'}[CIV]
PITCH={'human':.052,'orc':.050,'dwarf':.043,'elf':.061}[CIV]
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for file,names in (('warrior_hall_hex_v1_model.py',('mesh','box','hexagon','polygon_prism')),
                   ('war_stable_hex_v1_model.py',('vertical_prism',)),
                   ('magic_school_model.py',('beam',))):
    for node in ast.parse((PIPELINE/file).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<draft_correction>','exec'))
