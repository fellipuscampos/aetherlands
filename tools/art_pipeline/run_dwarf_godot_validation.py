"""Import and validate the actual dwarf GLBs in a minimal Godot project."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path
from dwarf_troop_assets import ASSETS,ROOT,OUT,WORK

parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True)
args=parser.parse_args()
project=WORK/'godot_review'; project.mkdir(parents=True,exist_ok=True)
(project/'project.godot').write_text('''config_version=5
[application]
config/name="Dwarf static model validation"
[filesystem]
import/blender/enabled=false
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
target=project/'assets/generated/dwarves'; target.mkdir(parents=True,exist_ok=True)
shutil.copy2(OUT/'dwarf_troops_manifest.json',target/'dwarf_troops_manifest.json')
for row in ASSETS:
    folder=target/row['stem']; folder.mkdir(exist_ok=True)
    for suffix in ('.glb','_albedo.png','_report.json'):
        name=row['stem']+suffix
        shutil.copy2(OUT/row['stem']/name,folder/name)
shutil.copy2(Path(__file__).with_name('verify_dwarf_troops_import.gd'),project/'verify.gd')
for name in ('_dwarf_troop_models_review.gd','_dwarf_troop_models_review.tscn'):
    shutil.copy2(ROOT/name,project/name)
done=subprocess.run([args.godot,'--headless','--editor','--path',str(project),'--import'],capture_output=True,text=True,timeout=180)
(WORK/'godot_isolated_import.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
print('IMPORT_EXIT',done.returncode,flush=True)
assert done.returncode==0,done.stderr[-3000:]
done=subprocess.run([args.godot,'--headless','--path',str(project),'--script','verify.gd','--',
                     str(ROOT/'docs/dwarf_troops_godot_validation.json')],capture_output=True,text=True,timeout=120)
(WORK/'godot_isolated_validation.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
print(done.stdout[-2500:]); print(done.stderr[-2500:])
assert done.returncode==0
# Parse/run the review UI and all six classes without gameplay autoloads.
smoke=project/'smoke_review.gd'
smoke.write_text('''extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    var packed := load("res://_dwarf_troop_models_review.tscn") as PackedScene
    var scene := packed.instantiate()
    root.add_child(scene)
    for family in range(6):
        scene._select(family)
        await process_frame
    print("DWARF_REVIEW_SCENE_PASS: all six classes")
    quit()
''',encoding='utf-8')
done=subprocess.run([args.godot,'--headless','--path',str(project),'--script','smoke_review.gd'],capture_output=True,text=True,timeout=60)
(WORK/'godot_review_scene.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
print(done.stdout[-1500:]); print(done.stderr[-1500:])
assert done.returncode==0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
