"""Seat roof tusks on explicit iron sockets and the uppermost roof course."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME = REPAIR_FOLDER.title()
ASSET_FOLDER = REPAIR_FOLDER
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
NAME,scene,parts,groups,root = st['name'],st['scene'],st['parts'],st['groups'],st['root']
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for node in ast.parse((PIPELINE/'warrior_hall_hex_v1_model.py').read_text(encoding='utf-8')).body:
    if isinstance(node,ast.FunctionDef) and node.name in ('mesh','box'):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<support_primitives>','exec'))
if not scene.get('roof_tusk_support_repair',False):
    for horn in list(parts):
        label = horn['part']
        if '_Roof_Tusk_' in label:
            prefix,sign = label.rsplit('_Roof_Tusk_',1)
            sign = int(sign)
            courses = [obj for obj in parts if obj['part'].startswith(prefix+'_Course_')]
            upper = max(courses,key=lambda obj:max(v.co.z for v in obj.data.vertices))
            lo = Vector(tuple(min(v.co[i] for v in upper.data.vertices) for i in range(3)))
            hi = Vector(tuple(max(v.co[i] for v in upper.data.vertices) for i in range(3)))
            old_y = (min(v.co.y for v in horn.data.vertices)+max(v.co.y for v in horn.data.vertices))/2
            new_y = old_y if prefix=='Chapel' else (lo.y+hi.y)/2+sign*(hi.y-lo.y)*.30
            for vertex in horn.data.vertices:
                vertex.co.y += new_y-old_y
            horn.data.update()
            socket = box(prefix+'_Tusk_Socket_'+str(sign),((lo.x+hi.x)/2,new_y,hi.z+.012),
                         (.075,.066,.024),'iron','03_ROOFS')
            socket.parent = root
        elif label.startswith('Grove_Totem_Tusk_'):
            for vertex in horn.data.vertices:
                vertex.co.z -= .020
            horn.data.update()
    scene['roof_tusk_support_repair'] = True
st['parts'] = parts
exec((PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8'))
