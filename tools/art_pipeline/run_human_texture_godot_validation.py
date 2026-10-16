"""Validate the staged repair using identical project import settings in isolation."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

from human_texture_glb import read_glb

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'art_source/human_texture_repair'
parser = argparse.ArgumentParser()
parser.add_argument('--godot',required=True)
args = parser.parse_args()
project = WORK/'godot_review'
project.mkdir(parents=True,exist_ok=True)
(project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Human texture review"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
shutil.copy2(Path(__file__).with_name('verify_human_texture_repair.gd'),project/'verify.gd')
manifest = []
for row in json.loads((WORK/'native_audit.json').read_text(encoding='utf-8')):
    unit = row['unit']
    folder = ROOT/'assets/generated/humans'/unit
    target = project/'assets/generated/humans'/unit
    target.mkdir(parents=True,exist_ok=True)
    for file in folder.iterdir():
        if file.suffix in ('.gd','.uid','.png') or file.name.endswith('.glb.import'):
            shutil.copy2(file,target/file.name)
    legacy = row.get('legacy',False)
    glb = next(folder.glob('*.glb')) if legacy else WORK/'staged'/unit/(unit+'.glb')
    shutil.copy2(glb,target/glb.name)
    if not legacy:
        albedo = WORK/'staged'/unit/(unit+'_albedo.png')
        shutil.copy2(albedo,target/albedo.name)
        duplicate = target/(unit+'_'+albedo.name)
        if duplicate.exists():
            shutil.copy2(albedo,duplicate)
    doc,binary = read_glb(glb.read_bytes())
    clips = {a['name']: max(doc['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in doc.get('animations',[])}
    report = json.loads((folder/(unit+'_report.json')).read_text(encoding='utf-8')) if not legacy else {}
    loops = {name:clip['loop'] for name,clip in report.get('animations',{}).items()} if not legacy else {}
    manifest.append({'unit':unit,'path':'res://assets/generated/humans/'+unit+'/'+glb.name,
                     'legacy':legacy,'bones':len(doc['skins'][0]['joints']),'clips':clips,'loops':loops,
                     'albedo':'res://assets/generated/humans/'+unit+'/'+unit+'_albedo.png'})
(project/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
done = subprocess.run([args.godot,'--headless','--editor','--path',str(project),'--import'],capture_output=True,text=True,timeout=180)
(WORK/'godot_isolated_import.log').write_text(done.stdout+'\n'+done.stderr,encoding='utf-8')
print('IMPORT_EXIT',done.returncode,flush=True)
if done.returncode:
    print(done.stderr[-4000:]); raise SystemExit(done.returncode)
output = ROOT/'docs/human_texture_repair_godot_validation.json'
done = subprocess.run([args.godot,'--headless','--path',str(project),'--script','verify.gd','--',str(output)],capture_output=True,text=True,timeout=180)
print(done.stdout[-3500:]); print(done.stderr[-3500:])
raise SystemExit(done.returncode)
