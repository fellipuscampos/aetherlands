"""Apply anatomy V2 through the user's running Blender MCP."""
import argparse,json,shutil,hashlib
from orc_troop_assets import ASSETS,OUT,WORK,ROOT
from blender_mcp_client import execute
parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');parser.add_argument('--pilot',action='store_true');args=parser.parse_args()
frozen=WORK/'pose_correction/before_assets';frozen.mkdir(parents=True,exist_ok=True)
for row in ASSETS:
    target=frozen/row['stem']
    if not target.exists():shutil.copytree(OUT/row['stem'],target)
protected=json.loads((WORK/'protected_sources.json').read_text())
rows=[r for r in ASSETS if not args.only or r['stem'] in args.only]
for row in rows:
    print('POSE_FIX_START',row['stem'],flush=True)
    code=f'''import sys,importlib,importlib.util
sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import build_orc_troops,orc_anatomy_retarget
importlib.reload(build_orc_troops);importlib.reload(orc_anatomy_retarget)
spec=importlib.util.spec_from_file_location('orc_pose_fix',{str(ROOT/'tools/art_pipeline/correct_orc_poses.py')!r})
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
result=mod.fix({row!r},views={('three_quarter',) if args.pilot else ('front','three_quarter','back','game_top')!r},pose_views={args.pilot!r})
'''
    execute(code,timeout=1200);print('POSE_FIX_COMPLETE',row['stem'],flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
print('POSE_FIX_BATCH_COMPLETE',len(rows),flush=True)
