"""Sequential live-MCP production. Finish/save each asset before building next."""
import argparse
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

PIPELINE = Path(__file__).resolve().parent
SCHOOLS = ('sacred','infernal','necromancy','druidism','arcanism','elementalism')
QUEUE = [(c,s) for c in ('human','orc','dwarf','elf') for s in SCHOOLS]

def call(code):
    log = io.StringIO()
    try:
        with contextlib.redirect_stdout(log):
            response = execute(code, timeout=900)
    except Exception:
        print(log.getvalue(),flush=True)
        raise
    return response.get('result',{})

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--end',type=int,default=24)
    args = parser.parse_args()
    model = (PIPELINE/'magic_school_model.py').read_text(encoding='utf-8')
    finish = (PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8')
    for i in range(args.start,args.end):
        civ,school = QUEUE[i]
        print(f'BUILD {i+1}/24 {civ} {school}',flush=True)
        print(json.dumps(call(f'MAGIC_CIV={civ!r}\nMAGIC_SCHOOL={school!r}\n'+model)),flush=True)
        print(json.dumps({'DONE':call(finish)}),flush=True)
    print('REQUESTED_RANGE_SAVED',flush=True)
