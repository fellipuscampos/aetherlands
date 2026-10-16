import sys,importlib,json
from pathlib import Path
sys.path.insert(0,str(Path(r'C:\Users\felipe campos\Documents\jogo')/'tools/art_pipeline'))
import build_orc_closed_bone_armor
importlib.reload(build_orc_closed_bone_armor)
from orc_troop_assets import ASSETS,WORK
results=[]
for key in ('guardian_champion','sentinel','guardian','armored_cavalier','griffon_rider'):
    results.append(build_orc_closed_bone_armor.build(next(r for r in ASSETS if r['key']==key)))
    (WORK/'bone_armor_refinement/build_progress.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result={'status':'PASS','models':len(results),'assets':results}
