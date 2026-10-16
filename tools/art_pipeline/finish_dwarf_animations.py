"""Validate animated assets, refresh previews/review, and verify real Godot UI."""
import subprocess
import argparse
import sys
from pathlib import Path
from dwarf_troop_assets import ROOT, WORK

PIPE = ROOT/'tools/art_pipeline'
GODOT = Path('C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
parser = argparse.ArgumentParser()
parser.add_argument('--families', nargs='*', help='Regenerate videos only for changed families; validate all families.')
args = parser.parse_args()
video_selection = ['--families', *args.families] if args.families else []

steps = [
    ('Shared Godot libraries', [sys.executable, str(PIPE/'run_dwarf_animation_validation.py'), '--godot', str(GODOT)]),
    ('Approved bind geometry / shared clips', [sys.executable, str(PIPE/'audit_dwarf_animations.py')]),
    ('Asset audit', [sys.executable, str(PIPE/'audit_dwarf_troops.py')]),
    ('Individual MP4 previews', [sys.executable, str(PIPE/'run_dwarf_animation_videos.py'), *video_selection]),
    ('Animation gallery previews', [sys.executable, str(PIPE/'run_dwarf_animation_previews.py'), '--assemble-only']),
    ('Gallery', [sys.executable, str(PIPE/'document_dwarf_animations.py')]),
]
for label, command in steps:
    print('DWARF_ANIMATION_STEP '+label, flush=True)
    subprocess.run(command, cwd=ROOT, check=True)
done = subprocess.run([str(GODOT), '--headless', '--editor', '--path', str(ROOT), '--import'],
    capture_output=True, text=True, encoding='utf-8', timeout=180)
(WORK/'animation_project_import.log').write_text(done.stdout+'\n'+done.stderr, encoding='utf-8')
assert done.returncode == 0, done.stderr[-3000:]
done = subprocess.run([str(GODOT), '--headless', '--path', str(ROOT), '--script',
    'res://tools/art_pipeline/verify_dwarf_animations_project.gd', '--',
    str(ROOT/'docs/dwarf_troops_animation_project_validation.json')],
    capture_output=True, text=True, encoding='utf-8', timeout=90)
(WORK/'animation_project_validation.log').write_text(done.stdout+'\n'+done.stderr, encoding='utf-8')
print(done.stdout[-2000:]); print(done.stderr[-2000:])
assert done.returncode == 0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
subprocess.run([sys.executable, str(PIPE/'blender_mcp_client.py'), str(PIPE/'review_dwarf_animations_live.py')], cwd=ROOT, check=True)
print('DWARF_ANIMATIONS_FINISHED', flush=True)
