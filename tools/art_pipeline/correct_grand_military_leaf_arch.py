"""Lower the elven approach arch so the master's shield remains fully readable."""
from pathlib import Path
PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
ASSET_NAME,ASSET_FOLDER='Elf_Guardian_Mastery_Hex_V1','elf_guardian_mastery_hex_v1'
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
for obj in st['parts']:
    if obj['part'].startswith(('Living_Approach_-1_','Living_Approach_1_')):
        for v in obj.data.vertices:
            v.co.z=.10+(v.co.z-.10)*(.52-.10)/(.69-.10)
    elif obj['part'].startswith('Living_Arch_'):
        for v in obj.data.vertices:
            v.co.z=.50+(v.co.z-.67)*(.63-.50)/(.86-.67)
exec((PIPELINE/'resume_grand_military_draft.py').read_text(encoding='utf-8'))
