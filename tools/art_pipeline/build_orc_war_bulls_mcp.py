import sys,json,importlib
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_war_bulls
importlib.reload(build_orc_war_bulls)
from orc_troop_assets import ASSETS,WORK
selection=WORK/'war_bulls/selection.json'
selected=json.loads(selection.read_text()) if selection.exists() else build_orc_war_bulls.KEYS
result={'assets':[build_orc_war_bulls.build(r) for r in ASSETS if r['key'] in selected]}
