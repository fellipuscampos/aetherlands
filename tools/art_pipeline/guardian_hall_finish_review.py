"""Finish review: ensure facade shield clears roof, refresh renders and export.
This adjustment is also recorded in guardian_hall_model.py for clean rebuilds.
"""
import bpy
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
scene = st['scene']
bpy.context.window.scene = scene
panel = next(o for o in st['parts'] if o['part'] == 'Hall_Crest_Wood')
if abs(panel['shield_center'][1] - .52) < .001:
    for obj in st['parts']:
        if obj['part'].startswith('Hall_Crest') or obj['part'] == 'Heraldic_Backing':
            for vertex in obj.data.vertices:
                vertex.co.y -= .18
            obj.data.update()
            if 'shield_center' in obj:
                center = list(obj['shield_center'])
                center[1] -= .18
                obj['shield_center'] = center
assert abs(panel['shield_center'][1] - .34) < .001
# Same UVs: shifting only depth leaves the panel's pixel design unchanged.
assert max(v.co.y for v in panel.data.vertices) < .40
scene.render.resolution_x = scene.render.resolution_y = 1100
scene.cycles.samples = 16
VIEWS = ['three_quarter', 'game_top', 'front', 'side', 'back', 'courtyard_detail']
exec((PIPELINE / 'guardian_hall_previews.py').read_text(encoding='utf-8'))
exec((PIPELINE / 'guardian_hall_scale_preview.py').read_text(encoding='utf-8'))
# Restore quality settings for the editable deliverable.
exec((PIPELINE / 'guardian_hall_state.py').read_text(encoding='utf-8'))
st['scene'].render.resolution_x = st['scene'].render.resolution_y = 1400
st['scene'].cycles.samples = 32
exec((PIPELINE / 'guardian_hall_export.py').read_text(encoding='utf-8'))
result['review'] = 'Facade emblem clear of roof; seven final review images'
