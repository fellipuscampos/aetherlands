"""Revise existing equipment through the open Blender, preserving the grips."""
import argparse,hashlib,json,shutil
from blender_mcp_client import execute
from orc_troop_assets import ROOT,OUT,WORK,ASSETS

parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+')
parser.add_argument('--pilot',action='store_true');args=parser.parse_args()
frozen=WORK/'tribal_equipment/before_assets';frozen.mkdir(parents=True,exist_ok=True)
for row in ASSETS:
    target=frozen/row['stem']
    if not target.exists():shutil.copytree(OUT/row['stem'],target)
protected=json.loads((WORK/'protected_sources.json').read_text())
rows=[r for r in ASSETS if not args.only or r['stem'] in args.only]
for row in rows:
    print('TRIBAL_START',row['stem'],flush=True)
    code=f'''import sys,importlib
sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import orc_tribal_paint,build_orc_tribal_equipment
importlib.reload(orc_tribal_paint);importlib.reload(build_orc_tribal_equipment)
result=build_orc_tribal_equipment.build({row!r},views={('front','three_quarter') if args.pilot else ('front','three_quarter','back','game_top')!r},attack_view={args.pilot!r})
'''
    execute(code,timeout=1200)
    print('TRIBAL_COMPLETE',row['stem'],flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
print('TRIBAL_BATCH_COMPLETE',len(rows),flush=True)
