"""Seat the orc draft horses on the stable floor and the horns in their sockets."""
import bpy
from pathlib import Path
st=bpy.app.driver_namespace['guardian_hall']
assert st['name']=='Orc_Cavalry_Mastery_Hex_V1'
for obj in st['parts']:
    dz=-.006 if obj['part'].startswith('Clan_Mount_') else -.005 if obj['part'].startswith('Roost_Tusk_') and 'Socket' not in obj['part'] else 0
    for v in obj.data.vertices:
        v.co.z+=dz
exec((Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
