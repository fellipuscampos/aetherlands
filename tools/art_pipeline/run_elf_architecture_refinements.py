"""Finish the roof details of the three early elven revisions via Blender MCP."""
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

ROOT = Path(__file__).resolve().parents[2]
script = (ROOT/'tools/art_pipeline/refine_elf_roof_architecture_mcp.py').read_text(encoding='utf-8')
for folder in ('elf_war_stable_hex_v1', 'elf_guardian_hall_hex_v1', 'elf_warrior_hall_hex_v1'):
    print('REFINE '+folder, flush=True)
    captured = io.StringIO()
    try:
        with contextlib.redirect_stdout(captured):
            response = execute('TOUCHUP_FOLDER='+repr(folder)+'\n'+script, timeout=1200)
    except Exception:
        print(captured.getvalue(), flush=True)
        raise
    print(json.dumps(response['result'], ensure_ascii=False), flush=True)
print('ELF_REFINEMENTS_COMPLETE', flush=True)
