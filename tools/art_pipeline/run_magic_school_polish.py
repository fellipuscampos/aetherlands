"""Adjust and save each of the 24 existing schools sequentially through MCP."""
import argparse
import json
from pathlib import Path
from run_magic_school_batch import QUEUE,PIPELINE,call
from verify_magic_school_batch import RECIPES

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--end',type=int,default=24)
    parser.add_argument('--finish-only',action='store_true')
    args=parser.parse_args()
    polish=(PIPELINE/'magic_school_polish.py').read_text(encoding='utf-8')
    finish=(PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8')
    for i in range(args.start,args.end):
        civ,school=QUEUE[i]
        stem=RECIPES[school][0]
        folder=('' if civ=='human' else civ+'_')+stem+'_hex_v1'
        print(f'POLISH {i+1}/24 {folder}',flush=True)
        if not args.finish_only:
            print(json.dumps(call(f'POLISH_FOLDER={folder!r}\n'+polish)),flush=True)
        setup=f"from pathlib import Path\nASSET_NAME={folder.title()!r}\nASSET_FOLDER={folder!r}\nexec((Path({str(PIPELINE)!r})/'guardian_hall_state.py').read_text(encoding='utf-8'))\n"
        print(json.dumps({'SAVED':call(setup+finish)}),flush=True)
    print('REQUESTED_POLISH_RANGE_SAVED',flush=True)
