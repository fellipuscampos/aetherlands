"""Repair, paint, preview and save each existing landmark before the next."""
import argparse
import json
from pathlib import Path
from grand_military_assets import QUEUE, folder_name
from run_magic_school_batch import call

PIPELINE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--start',type=int,default=0)
parser.add_argument('--end',type=int,default=24)
parser.add_argument('--repair-only',action='store_true')
parser.add_argument('--indices',type=int,nargs='+')
args=parser.parse_args()
for i in (args.indices if args.indices is not None else range(args.start,args.end)):
    civ,role=QUEUE[i]
    folder=folder_name(civ,role)
    print(f'REPAIR {i+1}/24 {civ} {role}',flush=True)
    setup=f'ASSET_NAME={folder.title()!r}\nASSET_FOLDER={folder!r}\n'
    print(json.dumps(call(setup+(PIPELINE/'grand_military_repair.py').read_text(encoding='utf-8'))),flush=True)
    if not args.repair_only:
        print(json.dumps({'SAVED':call(setup+(PIPELINE/'grand_military_finish.py').read_text(encoding='utf-8'))}),flush=True)
print('REQUESTED_REPAIRS_SAVED',flush=True)
