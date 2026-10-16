"""Seat facade foliage on its carved branches; keep the existing elf architecture."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_FOLDER, ASSET_NAME = TOUCHUP_FOLDER, TOUCHUP_FOLDER.title()
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
scene, parts, groups, root = st['scene'], st['parts'], st['groups'], st['root']
NAME, TRIM = ASSET_NAME, 'gold'
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename, names in (('warrior_hall_hex_v1_model.py', ('mesh',)), ('magic_school_model.py', ('beam',))):
    for node in ast.parse((PIPELINE / filename).read_text(encoding='utf-8')).body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), '<elf_touchup>', 'exec'))
if not scene.get('facade_leaves_seated'):
    hex_body = next((o for o in parts if o['part'] in ('Conclave_Hex_Tower', 'Observation_Tower')), None)
    center_x = (min(v.co.x for v in hex_body.data.vertices)+max(v.co.x for v in hex_body.data.vertices))/2 if hex_body else 0
    for obj in parts:
        delta = .014 if obj['part'].startswith('Finish_Elf_Facade_Leaf_') else (
            .008 if obj['part'].startswith('Finish_Elf_Branch_Post_') else (
            .020 if obj['part'].startswith('Finish_Elf_Branch_Brace_') else 0))
        if delta:
            for vertex in obj.data.vertices:
                vertex.co.y += delta + (abs(vertex.co.x-center_x)/math.sqrt(3) if hex_body else 0)
            obj.data.update()
            if hex_body:
                bm=bmesh.new();bm.from_mesh(obj.data)
                bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
                bm.to_mesh(obj.data);bm.free()
    if scene['magic_school'] == 'infernal':
        for sign in (-1, 1):
            beam('Finish_Infernal_Binding_Leaf_Mount_'+str(sign), (sign*.44,-.038,.86),
                 (sign*.44,.05,.86), .022, 'gold', '08_DETAILS')
    scene['facade_leaves_seated'] = True
for obj in parts:
    obj.parent = root
AUDIT_RUN = False
exec((PIPELINE / 'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
scene['finish_pass_attachment_remaining'] = [o['part'] for o in detached(parts)]
assert not scene['finish_pass_attachment_remaining'], list(scene['finish_pass_attachment_remaining'])
st['parts'] = parts
bpy.app.driver_namespace['guardian_hall'] = st
exec((PIPELINE / 'magic_school_finish.py').read_text(encoding='utf-8'))
