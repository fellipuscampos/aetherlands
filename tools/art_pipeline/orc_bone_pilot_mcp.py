import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_closed_bone_armor
importlib.reload(build_orc_closed_bone_armor)
from orc_troop_assets import ASSETS
result=build_orc_closed_bone_armor.build(next(r for r in ASSETS if r['key']=='guardian_champion'))
