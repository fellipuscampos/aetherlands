"""Import clips, build six shared Godot libraries, and exercise all variants."""
import argparse
import shutil
import subprocess
from pathlib import Path
from dwarf_troop_assets import ASSETS, ROOT, OUT, WORK

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--families', nargs='*')
args = parser.parse_args()
project = WORK/'godot_animations'; project.mkdir(parents=True, exist_ok=True)
(project/'.gdignore').touch()
(project/'project.godot').write_text('''config_version=5
[application]
config/name="Dwarf shared animations validation"
[filesystem]
import/blender/enabled=false
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
target = project/'assets/generated/dwarves'; target.mkdir(parents=True, exist_ok=True)
shutil.copy2(OUT/'dwarf_troops_manifest.json', target/'dwarf_troops_manifest.json')
for row in ASSETS:
    if args.families and row['family'] not in args.families: continue
    folder = target/row['stem']; folder.mkdir(exist_ok=True)
    path = OUT/row['stem']/(row['stem']+'.glb')
    shutil.copy2(path, folder/path.name)
shutil.copy2(Path(__file__).with_name('verify_dwarf_animations_import.gd'), project/'verify.gd')
for name in ('_dwarf_troop_models_review.gd', '_dwarf_troop_models_review.tscn'):
    shutil.copy2(ROOT/name, project/name)
command = [args.godot, '--headless', '--editor', '--path', str(project), '--import']
done = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=180)
(WORK/'animation_godot_import.log').write_text(done.stdout+'\n'+done.stderr, encoding='utf-8')
assert done.returncode == 0, done.stderr[-3000:]
command = [args.godot, '--headless', '--path', str(project), '--script', 'verify.gd', '--',
           str(ROOT/'docs/dwarf_troops_animation_godot_validation.json')]
if args.families: command += args.families
done = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=180)
(WORK/'animation_godot_validation.log').write_text(done.stdout+'\n'+done.stderr, encoding='utf-8')
print(done.stdout[-4500:]); print(done.stderr[-4500:])
assert done.returncode == 0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
for path in (target/'animations').glob('*.tres'):
    shutil.copy2(path, OUT/'animations'/path.name)
