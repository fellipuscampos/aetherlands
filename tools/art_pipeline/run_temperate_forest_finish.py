"""Finish modular assets by sending Python to Blender MCP, never headless Blender."""
import argparse
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(); parser.add_argument('--assets',nargs='*'); args=parser.parse_args()
manifest=json.loads((ROOT/'assets/generated/nature/temperate_forest_v1/manifest.json').read_text(encoding='utf-8'))
review=ROOT/'art_source/temperate_forest_review'
for asset in manifest['assets']:
    name=asset['asset']
    if args.assets and name not in args.assets: continue
    journal=review/'completed.json'
    completed=json.loads(journal.read_text(encoding='utf-8')) if journal.exists() else []
    if any(r['asset']==name for r in completed): continue
    print('Finishing '+name,flush=True)
    code='FOREST_ASSET='+repr(name)+'\n'+(ROOT/'tools/art_pipeline/finish_temperate_forest_mcp.py').read_text(encoding='utf-8')
    captured=io.StringIO()
    try:
        with contextlib.redirect_stdout(captured): response=execute(code,timeout=1200)
    except Exception:
        print(captured.getvalue(),flush=True); raise
    print(json.dumps(response['result']),flush=True)
