"""Move the first prototype's tree clear of all six standing stones via MCP."""
import bpy
from pathlib import Path

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER = 'Druidic_Circle_Hex_V1','druidic_circle_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene = st['scene']
if not scene.get('tree_layout_repair',False):
    for obj in st['parts']:
        if obj['part'].startswith('Sacred_Grove_Tree'):
            for vertex in obj.data.vertices:
                vertex.co.x = vertex.co.x * (.32/.41) - .31
                vertex.co.y = (vertex.co.y-.45) * (.32/.41) + .46
            obj.data.update()
    scene['tree_layout_repair'] = True
exec((PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8'))
