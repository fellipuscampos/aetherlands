"""Finish all four colonizers using the already running Blender MCP."""
import json,io,contextlib,argparse
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--races',nargs='+',choices=('human','elf','dwarf','orc'),default=['human','elf','dwarf','orc']); args=parser.parse_args()
for race in args.races:
    print('Exporting '+race+' idle / walk',flush=True)
    code='SETTLER_RACE='+repr(race)+'\n'+(ROOT/'tools/art_pipeline/finish_settler_animations_mcp.py').read_text(encoding='utf-8')
    output=io.StringIO()
    try:
        with contextlib.redirect_stdout(output): response=execute(code,timeout=1200)
    except Exception:
        print(output.getvalue()); raise
    print(json.dumps(response['result']),flush=True)
