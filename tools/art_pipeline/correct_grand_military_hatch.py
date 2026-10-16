"""Lower the human draft hatch and its hinges onto the paving."""
import bpy
from pathlib import Path
st=bpy.app.driver_namespace['guardian_hall']
assert st['name']=='Rogue_Mastery_Hex_V1'
for obj in st['parts']:
    if obj['part']=='Shadow_Cellar_Hatch' or obj['part'].startswith('Hatch_Iron_'):
        for v in obj.data.vertices:
            v.co.z-=.005
exec((Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
