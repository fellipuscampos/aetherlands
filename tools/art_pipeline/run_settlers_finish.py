"""Send each finishing stage to the open Blender MCP editor."""
import argparse, contextlib, io, json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--assets',nargs='*',default=['human','elf','dwarf','orc','review']); args=parser.parse_args()
for race in args.assets:
    print('Finishing settler '+race,flush=True)
    code='SETTLER_FINISH='+repr(race)+'\n'+(ROOT/'tools/art_pipeline/finish_settlers_mcp.py').read_text(encoding='utf-8')
    captured=io.StringIO()
    try:
        with contextlib.redirect_stdout(captured): reply=execute(code,timeout=1200)
    except Exception:
        print(captured.getvalue(),flush=True); raise
    print(json.dumps(reply['result']),flush=True)
