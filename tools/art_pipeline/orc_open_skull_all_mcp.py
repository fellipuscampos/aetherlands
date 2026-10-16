import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_open_skull
importlib.reload(build_orc_open_skull)
from orc_troop_assets import ASSETS,WORK
results=[]
for key in ('griffon_rider','sentinel','guardian_champion','armored_cavalier'):
    results.append(build_orc_open_skull.build(next(r for r in ASSETS if r['key']==key)))
    (WORK/'open_skull/build_progress.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result={'status':'PASS','models':len(results),'assets':results}
