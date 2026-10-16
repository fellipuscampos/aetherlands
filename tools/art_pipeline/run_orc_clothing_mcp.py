import argparse
from blender_mcp_client import execute
from orc_troop_assets import ROOT,ASSETS
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');parser.add_argument('--pilot',action='store_true');args=parser.parse_args()
for row in ASSETS:
    if args.only and row['key'] not in args.only:continue
    print('CLOTHING_START',row['stem'],flush=True)
    code=f'''import sys,importlib
sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import orc_refined_clothing_paint,build_orc_refined_clothing
importlib.reload(orc_refined_clothing_paint);importlib.reload(build_orc_refined_clothing)
result=build_orc_refined_clothing.build({row!r},views={('front','three_quarter','back') if args.pilot else ('front','three_quarter','back','game_top')!r})
'''
    execute(code,timeout=1200)
    print('CLOTHING_COMPLETE',row['stem'],flush=True)
print('CLOTHING_BATCH_COMPLETE',flush=True)
