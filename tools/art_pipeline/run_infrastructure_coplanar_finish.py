"""Finish verified joints one asset at a time in the running Blender editor."""
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
review=ROOT/'art_source/infrastructure_roof_review'
rows=json.loads((review/'face_repairs.json').read_text(encoding='utf-8'))
for row in rows:
    completed=json.loads((review/'faces_completed.json').read_text(encoding='utf-8')) if (review/'faces_completed.json').exists() else []
    if any(e['asset']==row['asset'] for e in completed): continue
    print('Finishing face repairs '+row['asset'],flush=True)
    code='FACE_ASSET='+repr(row['asset'])+'\n'+(ROOT/'tools/art_pipeline/finish_infrastructure_coplanar_mcp.py').read_text(encoding='utf-8')
    captured=io.StringIO()
    try:
        with contextlib.redirect_stdout(captured): response=execute(code,timeout=1200)
    except Exception:
        print(captured.getvalue(),flush=True)
        raise
    print(json.dumps(response['result']),flush=True)
