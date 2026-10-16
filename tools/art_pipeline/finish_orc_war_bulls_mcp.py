import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import finish_orc_war_bulls
importlib.reload(finish_orc_war_bulls)
from orc_troop_assets import ASSETS,WORK
p=WORK/'war_bull_finish/selection.json'
selected=json.loads(p.read_text()) if p.exists() else finish_orc_war_bulls.KEYS
result={'assets':[finish_orc_war_bulls.build(r) for r in ASSETS if r['key'] in selected]}
