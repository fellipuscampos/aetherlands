"""Create and completely save each military asset before starting the next."""
import argparse
import json
from run_magic_school_batch import PIPELINE, call
from grand_military_assets import QUEUE, folder_name

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--end',type=int,default=24)
    parser.add_argument('--finish-only',action='store_true')
    args=parser.parse_args()
    for i in range(args.start,args.end):
        civ,role=QUEUE[i]
        folder=folder_name(civ,role)
        print(f'MILITARY {i+1}/24 {folder}',flush=True)
        if not args.finish_only:
            print(json.dumps(call(f'MILITARY_CIV={civ!r}\nMILITARY_ROLE={role!r}\n'+(PIPELINE/'grand_military_model.py').read_text(encoding='utf-8'))),flush=True)
        else:
            call(f"from pathlib import Path\nASSET_NAME={folder.title()!r}\nASSET_FOLDER={folder!r}\nexec((Path({str(PIPELINE)!r})/'guardian_hall_state.py').read_text(encoding='utf-8'))")
        print(json.dumps({'SAVED':call((PIPELINE/'grand_military_finish.py').read_text(encoding='utf-8'))}),flush=True)
    print('REQUESTED_MILITARY_RANGE_SAVED',flush=True)
