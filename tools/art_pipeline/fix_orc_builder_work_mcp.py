"""Repair the work swing with anatomical hinges and a rigid wrist/tool grip."""
import shutil
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/orcs/orc_builder_v1'
BACKUP=ROOT/'art_source/orc_builder_review/before_hinge_fix'
BACKUP.mkdir(parents=True,exist_ok=True)
for name in ['orc_builder_v1.blend','orc_builder_v1.glb','orc_builder_v1_report.json']:
    if not (BACKUP/name).exists(): shutil.copy2(OUT/name,BACKUP/name)
BUILDER_CONFIG={'race':'orc','family':'orcs','preserve_carry_clips':True}
try:
    exec((ROOT/'tools/art_pipeline/animate_human_builder_mcp.py').read_text(encoding='utf-8'),globals())
finally:
    globals().pop('BUILDER_CONFIG',None)
