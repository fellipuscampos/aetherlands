import sys,json,importlib
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_war_boars
importlib.reload(build_orc_war_boars)
from orc_troop_assets import ASSETS
selected=json.loads((Path(r'C:\Users\felipe campos\Documents\jogo')/'art_source/orc_troops/war_boars/selection.json').read_text())
result={'assets':[build_orc_war_boars.build(r) for r in ASSETS if r['key'] in selected]}
