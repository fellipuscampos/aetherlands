import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_open_skull
importlib.reload(build_orc_open_skull)
from orc_troop_assets import ASSETS
result=build_orc_open_skull.build(next(r for r in ASSETS if r['key']=='griffon_rider'))
