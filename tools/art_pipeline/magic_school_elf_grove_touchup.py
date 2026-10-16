"""Mount elf grove glyphs and vines on the actual rotated narrow stone faces."""
import bpy
import math
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_FOLDER = 'elf_druidic_circle_hex_v1'
ASSET_NAME = ASSET_FOLDER.title()
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
scene, parts = st['scene'], st['parts']
if not scene.get('grove_face_ornaments_seated'):
    for i in range(6):
        a = math.radians(30 + i*60)
        x, y = .50*math.cos(a), -.025 + .50*math.sin(a)
        labels = {
            'Stone_Rune_Vertical_'+str(i): .009,
            'Stone_Rune_Cross_'+str(i): .009,
            **{'Finish_Grove_Vine_%s_%s'%(i,j): .016 for j in range(2)},
            **{'Finish_Grove_Vine_Stem_%s_%s'%(i,j): .011 for j in range(2)},
        }
        for obj in parts:
            if obj['part'] not in labels:
                continue
            for vertex in obj.data.vertices:
                dx, dy = vertex.co.x-x, vertex.co.y-y+labels[obj['part']]
                vertex.co.x = x + dx*math.cos(a) - dy*math.sin(a)
                vertex.co.y = y + dx*math.sin(a) + dy*math.cos(a)
            obj.data.update()
    scene['grove_face_ornaments_seated'] = True
AUDIT_RUN = False
exec((PIPELINE / 'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
scene['finish_pass_attachment_remaining'] = [o['part'] for o in detached(parts)]
assert not scene['finish_pass_attachment_remaining'], list(scene['finish_pass_attachment_remaining'])
st['parts'] = parts
bpy.app.driver_namespace['guardian_hall'] = st
exec((PIPELINE / 'magic_school_finish.py').read_text(encoding='utf-8'))
