"""Seat the small orc font rivets against the basin, then save the existing asset."""
import bpy
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_FOLDER = 'orc_sacred_temple_hex_v1'
ASSET_NAME = ASSET_FOLDER.title()
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
scene, parts = st['scene'], st['parts']
if not scene.get('font_rivets_seated'):
    for obj in parts:
        if obj['part'].startswith('Finish_Font_Iron_Rivets_'):
            for vertex in obj.data.vertices:
                vertex.co.y += .007
            obj.data.update()
    scene['font_rivets_seated'] = True
AUDIT_RUN = False
exec((PIPELINE / 'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
scene['finish_pass_attachment_remaining'] = [o['part'] for o in detached(parts)]
assert not scene['finish_pass_attachment_remaining']
st['parts'] = parts
bpy.app.driver_namespace['guardian_hall'] = st
exec((PIPELINE / 'magic_school_finish.py').read_text(encoding='utf-8'))
