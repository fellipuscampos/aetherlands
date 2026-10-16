"""Fasten the orc scaffold sign to the upper deck with two iron hangers."""
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
exec((PIPELINE/'grand_military_draft_parts.py').read_text(encoding='utf-8'))
assert NAME=='Orc_Ranger_Mastery_Hex_V1'
for sx in (-1,1):
    box('Hunt_Sign_Hanger_'+str(sx),(.02+sx*.083,-.089,1.19),(.024,.034,.13),'iron','07_FACTION')
exec((PIPELINE/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
