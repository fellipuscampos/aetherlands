"""Finish native MCP refinements, review layout, disk audit and Godot validation."""
import subprocess
import sys
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PIPE=ROOT/'tools/art_pipeline'
GODOT=Path('C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')

# Preserve the completed animation stage when the existing finish command is
# used again. Static validators intentionally reject rigs and animation data.
reports=list((ROOT/'assets/generated/dwarves').glob('dwarf_*/*_report.json'))
if len(reports)==24 and all(json.loads(p.read_text(encoding='utf-8')).get('stage')=='animated_troops' for p in reports):
    subprocess.run([sys.executable,str(PIPE/'finish_dwarf_animations.py')],cwd=ROOT,check=True)
    sys.exit(0)

steps=[
    ('MCP source verification and review',[sys.executable,str(PIPE/'blender_mcp_client.py'),str(PIPE/'review_dwarf_troops_live.py')]),
    ('Disk validation',[sys.executable,str(PIPE/'audit_dwarf_troops.py')]),
    ('Review documentation',[sys.executable,str(PIPE/'document_dwarf_troops.py')]),
    ('Godot validation',[sys.executable,str(PIPE/'run_dwarf_godot_validation.py'),'--godot',str(GODOT)]),
]
for label,command in steps:
    print('DWARF_REVIEW_STEP '+label,flush=True)
    subprocess.run(command,cwd=ROOT,check=True)
print('DWARF_REVIEW_FINISHED',flush=True)
