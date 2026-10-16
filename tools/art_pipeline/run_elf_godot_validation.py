"""Validate the exported models and review UI in an isolated Godot project."""
import argparse
import shutil
import subprocess
import json
from elf_troop_assets import ROOT, OUT, WORK, ASSETS

parser=argparse.ArgumentParser(); parser.add_argument('--godot',required=True); parser.add_argument('--project',action='store_true'); args=parser.parse_args()
if args.project:
    done=subprocess.run([args.godot,'--headless','--editor','--path',str(ROOT),'--import'],capture_output=True,text=True,timeout=180)
    (WORK/'godot_project_import.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
    print('PROJECT_IMPORT',done.returncode,done.stdout[-600:],done.stderr[-600:],flush=True)
    assert done.returncode==0 and 'SCRIPT ERROR' not in done.stderr
    done=subprocess.run([args.godot,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/verify_elf_troops_import.gd','--',str(ROOT/'docs/elf_troops_project_validation.json')],capture_output=True,text=True,timeout=120)
    (WORK/'godot_project_validation.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
    print('PROJECT_VALIDATION',done.returncode,done.stdout[-1200:],done.stderr[-1600:],flush=True)
    assert done.returncode==0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
    raise SystemExit(0)
project=WORK/'godot_review'; project.mkdir(parents=True,exist_ok=True)
(project/'project.godot').write_text('''config_version=5
[application]
config/name="Elf troops validation"
[filesystem]
import/blender/enabled=false
[rendering]
renderer/rendering_method="gl_compatibility"
''',encoding='utf-8')
target=project/'assets/generated/elves'; target.mkdir(parents=True,exist_ok=True)
shutil.copy2(OUT/'elf_troops_manifest.json',target/'elf_troops_manifest.json')
completed_rows=json.loads((OUT/'elf_troops_manifest.json').read_text(encoding='utf-8'))
for row in completed_rows:
    folder=target/row['stem']; folder.mkdir(exist_ok=True)
    for suffix in ('.glb','_albedo.png','_report.json'):
        shutil.copy2(OUT/row['stem']/(row['stem']+suffix),folder/(row['stem']+suffix))
for row in (a for a in completed_rows if a['tier']==0):
    folder=project/'assets/generated/humans'/row['source_stem']; folder.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'assets/generated/humans'/row['source_stem']/(row['source_stem']+'.glb'),folder/(row['source_stem']+'.glb'))
shutil.copy2(ROOT/'tools/art_pipeline/verify_elf_troops_import.gd',project/'verify.gd')
for name in ('_elf_troop_models_review.gd','_elf_troop_models_review.tscn','_elf_siege_models_review.tscn'): shutil.copy2(ROOT/name,project/name)
for label,command in (
    ('import',[args.godot,'--headless','--editor','--path',str(project),'--import']),
    ('validate',[args.godot,'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT/'docs/elf_troops_godot_validation.json')])):
    done=subprocess.run(command,capture_output=True,text=True,timeout=180)
    (WORK/('godot_'+label+'.log')).write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
    print(label,done.returncode,done.stdout[-1600:],done.stderr[-1600:],flush=True)
    assert done.returncode==0 and 'SCRIPT ERROR' not in done.stderr and 'ERROR:' not in done.stderr
