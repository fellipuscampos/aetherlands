"""Extend the ram suspension chains into their roof anchors."""
import bpy
from pathlib import Path
st=bpy.app.driver_namespace['guardian_hall']
assert st['name']=='Orc_Grand_Arsenal_Hex_V1'
for obj in st['parts']:
    if obj['part'].startswith('Ram_Hanging_Chain_'):
        for v in obj.data.vertices:
            v.co.z=.49+(v.co.z-.49)*(.72-.49)/(.68-.49)
exec((Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
