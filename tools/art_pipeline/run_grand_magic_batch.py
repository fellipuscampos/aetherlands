"""Sequential grand magic production through Blender MCP, one saved scene at a time."""
import argparse
import json
from run_magic_school_batch import PIPELINE,call
from grand_magic_assets import QUEUE,folder_name

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--end',type=int,default=24)
    parser.add_argument('--finish-only',action='store_true')
    args=parser.parse_args()
    for i in range(args.start,args.end):
        civ,school=QUEUE[i]
        folder=folder_name(civ,school)
        print(f'GRAND {i+1}/24 {folder}',flush=True)
        # Read each script afresh so preview corrections reach future assets.
        if not args.finish_only:
            print(json.dumps(call(f'GRAND_CIV={civ!r}\nGRAND_SCHOOL={school!r}\n'+(PIPELINE/'grand_magic_model.py').read_text(encoding='utf-8'))),flush=True)
        else:
            setup=f"from pathlib import Path\nASSET_NAME={folder.title()!r}\nASSET_FOLDER={folder!r}\nexec((Path({str(PIPELINE)!r})/'guardian_hall_state.py').read_text(encoding='utf-8'))"
            call(setup)
        print(json.dumps({'SAVED':call((PIPELINE/'grand_magic_finish.py').read_text(encoding='utf-8'))}),flush=True)
    print('REQUESTED_GRAND_RANGE_SAVED',flush=True)
