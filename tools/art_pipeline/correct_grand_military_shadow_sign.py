"""Move the orc hood sign ahead of its eave and add a wooden mounting bracket."""
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER='Orc_Rogue_Mastery_Hex_V1','orc_rogue_mastery_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
exec((PIPELINE/'grand_military_draft_parts.py').read_text(encoding='utf-8'))
for obj in parts:
    if obj['part'].startswith('Sneak_Hood'):
        for v in obj.data.vertices:
            v.co.y-=.09
box('Sneak_Sign_Bracket',(-.19,-.075,.605),(.14,.16,.19),'timber','07_FACTION')
exec((PIPELINE/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
