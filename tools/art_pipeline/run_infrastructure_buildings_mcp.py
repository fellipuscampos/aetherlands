"""Create 20 civilization-specific infrastructure models sequentially via MCP."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import time
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/'art_source/infrastructure_buildings_review'
ROLES=('market','farm','workshop','university','arcane_shrine')
CIVS=('human','elf','dwarf','orc')
def targets():
    return [(civ,role) for role in ROLES for civ in CIVS]

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--limit',type=int)
    args=parser.parse_args()
    REVIEW.mkdir(parents=True,exist_ok=True)
    (REVIEW/'.gdignore').touch(exist_ok=True)
    progress=REVIEW/'completed.json'
    completed=json.loads(progress.read_text(encoding='utf-8')) if progress.exists() else []
    queue=targets()
    if args.limit: queue=queue[:args.limit]
    for civ,role in queue:
        if any(e['civilization']==civ and e['role']==role for e in completed):
            print('SKIP '+civ+' '+role,flush=True); continue
        print('BUILD '+civ+' '+role,flush=True)
        started=time.monotonic()
        code=(ROOT/'tools/art_pipeline/infrastructure_building_model_mcp.py').read_text(encoding='utf-8')
        captured=io.StringIO()
        try:
            with contextlib.redirect_stdout(captured):
                response=execute('INFRA_CIV='+repr(civ)+'\nINFRA_ROLE='+repr(role)+'\n'+code,timeout=1200)
        except Exception:
            (REVIEW/(civ+'_'+role+'_error.txt')).write_text(captured.getvalue(),encoding='utf-8')
            print(captured.getvalue(),flush=True)
            raise
        entry=response['result']; entry['seconds']=round(time.monotonic()-started,1)
        completed.append(entry)
        progress.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(entry),flush=True)
    print('INFRASTRUCTURE_BATCH_COMPLETE',flush=True)
