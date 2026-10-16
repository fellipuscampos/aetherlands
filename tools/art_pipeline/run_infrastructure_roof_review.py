"""Submit each focused revision to the running Blender MCP editor."""
import argparse
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--assets',nargs='*')
args=parser.parse_args()
review=ROOT/'art_source/infrastructure_roof_review'
entries=json.loads((review/'source_before.json').read_text(encoding='utf-8'))
for row in entries:
    if not row['roofs'] or (args.assets and row['asset'] not in args.assets): continue
    completed=json.loads((review/'completed.json').read_text(encoding='utf-8')) if (review/'completed.json').exists() else []
    if any(r['asset']==row['asset'] for r in completed): continue
    print('Reviewing '+row['asset'],flush=True)
    code='ROOF_ASSET='+repr(row['asset'])+'\n'+(ROOT/'tools/art_pipeline/refine_infrastructure_roofs_mcp.py').read_text(encoding='utf-8')
    captured=io.StringIO()
    try:
        with contextlib.redirect_stdout(captured): response=execute(code,timeout=1200)
    except Exception:
        print(captured.getvalue(),flush=True)
        raise
    print(json.dumps(response['result']),flush=True)
