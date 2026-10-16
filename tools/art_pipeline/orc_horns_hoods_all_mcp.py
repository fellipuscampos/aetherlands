import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_horns_hoods
importlib.reload(build_orc_horns_hoods)
from orc_troop_assets import ASSETS,WORK
results=[]
for key in build_orc_horns_hoods.KEYS:
    results.append(build_orc_horns_hoods.build(next(r for r in ASSETS if r['key']==key)))
    (WORK/'horns_and_hoods/build_progress.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result={'status':'PASS','models':len(results),'assets':results}
