"""Refresh base validation, then validate and open the complete roster."""
from pathlib import Path
pipeline=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
exec(compile((pipeline/'verify_orc_squire_blender.py').read_text(encoding='utf-8'),str(pipeline/'verify_orc_squire_blender.py'),'exec'))
exec(compile((pipeline/'review_orc_troops_blender.py').read_text(encoding='utf-8'),str(pipeline/'review_orc_troops_blender.py'),'exec'))
exec(compile((pipeline/'finish_orc_roster_review.py').read_text(encoding='utf-8'),str(pipeline/'finish_orc_roster_review.py'),'exec'))
