"""Author the missing dwarf skills through the user's open Blender MCP."""
import argparse
import hashlib
import json
import io
from contextlib import redirect_stdout
from blender_mcp_client import execute
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT, WORK

parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
for row in ASSETS:
    if args.only and row['stem'] not in args.only:continue
    print('LIVE_MCP_DWARF_SKILLS',row['stem'],flush=True)
    captured=io.StringIO()
    try:
        with redirect_stdout(captured):
            response=execute(f'''import sys,importlib.util
if {str(ROOT/'tools/art_pipeline')!r} not in sys.path:sys.path.insert(0,{str(ROOT/'tools/art_pipeline')!r})
import animate_dwarf_troops
importlib.reload(animate_dwarf_troops)
import dwarf_skill_contract,dwarf_skill_motion
importlib.reload(dwarf_skill_contract);importlib.reload(dwarf_skill_motion)
spec=importlib.util.spec_from_file_location('dwarf_skill_builder',{str(ROOT/'tools/art_pipeline/build_dwarf_skills.py')!r})
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
result=module.build({row!r})
''',timeout=600)
    except Exception:
        print(captured.getvalue(),flush=True)
        raise
    print(json.dumps(response['result'],ensure_ascii=True),flush=True)
protected=json.loads((WORK/'protected_assets.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in protected.items())
print('DWARF_SKILLS_COMPLETE',flush=True)
