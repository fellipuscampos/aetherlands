import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_horns_hoods
importlib.reload(build_orc_horns_hoods)
from orc_troop_assets import ASSETS,WORK
results=[build_orc_horns_hoods.build(next(r for r in ASSETS if r['key']==k)) for k in ('griffon_rider','archer')]
result={'status':'PASS','assets':results}
(WORK/'horns_and_hoods/pilot_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
