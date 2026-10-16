"""Put the ossuary rack bars at the shelf edges so the skull faces remain visible."""
import bpy
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_FOLDER = 'orc_necromancy_ossuary_hex_v1'
ASSET_NAME = ASSET_FOLDER.title()
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
scene, parts = st['scene'], st['parts']
if not scene.get('bone_rack_edges_seated'):
    for obj in parts:
        if obj['part'].startswith('Finish_Orc_Bone_Rack_'):
            sign = int(obj['part'].rsplit('_', 1)[-1])
            for vertex in obj.data.vertices:
                vertex.co.x += sign * .078
            obj.data.update()
    scene['bone_rack_edges_seated'] = True
AUDIT_RUN = False
exec((PIPELINE / 'magic_school_attachment_audit.py').read_text(encoding='utf-8'))
scene['finish_pass_attachment_remaining'] = [o['part'] for o in detached(parts)]
assert not scene['finish_pass_attachment_remaining']
st['parts'] = parts
bpy.app.driver_namespace['guardian_hall'] = st
exec((PIPELINE / 'magic_school_finish.py').read_text(encoding='utf-8'))
