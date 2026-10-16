"""Finish small source details without emitting large Blender export logs."""
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

ROOT=Path(__file__).resolve().parents[2]
code=(ROOT/'tools/art_pipeline/refine_infrastructure_pennants_mcp.py').read_text(encoding='utf-8')
captured=io.StringIO()
try:
    with contextlib.redirect_stdout(captured):
        response=execute(code,timeout=1200)
except Exception:
    print(captured.getvalue(),flush=True)
    raise
print(json.dumps(response['result']),flush=True)
