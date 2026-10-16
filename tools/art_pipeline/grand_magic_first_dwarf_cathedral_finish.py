"""Seat the two copper plaques caught by the pre-export cathedral support audit."""
import bpy
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st=bpy.app.driver_namespace['guardian_hall']
scene=st['scene']
assert scene.name=='Dwarf_Sacred_Ritual_Hex_V1' and scene.get('grand_magic')
if not scene.get('tower_copper_plaques_seated'):
    for obj in st['parts']:
        if obj['part'].startswith('Cathedral_Tower_Rune_'):
            for vertex in obj.data.vertices:
                vertex.co.y+=.013
            obj.data.update()
    scene['tower_copper_plaques_seated']=True
scope={'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'),scope)
scene['physical_attachment_remaining']=[o['part'] for o in scope['detached'](st['parts'])]
assert not scene['physical_attachment_remaining']
exec((PIPELINE/'grand_magic_finish.py').read_text(encoding='utf-8'))
