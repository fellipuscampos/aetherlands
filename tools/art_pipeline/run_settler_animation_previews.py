import argparse,contextlib,io,json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--views',nargs='*',default=['stills','idle','walk']); parser.add_argument('--races',nargs='+',choices=('human','elf','dwarf','orc'),default=['human','elf','dwarf','orc']); args=parser.parse_args()
for view in args.views:
    print('Rendering settlers '+view,flush=True)
    code='SETTLER_PREVIEW='+repr(view)+'\nSETTLER_PREVIEW_RACES='+repr(args.races)+'\n'+(ROOT/'tools/art_pipeline/preview_settler_animations_mcp.py').read_text(encoding='utf-8')
    captured=io.StringIO()
    try:
        with contextlib.redirect_stdout(captured): result=execute(code,timeout=1200)
    except Exception:
        print(captured.getvalue()); raise
    print(json.dumps(result['result']),flush=True)
