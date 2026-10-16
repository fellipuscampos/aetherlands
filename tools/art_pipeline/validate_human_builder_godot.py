"""Validate the derived builder skin and both inherited loops in isolated Godot."""
import argparse, hashlib, json, shutil, struct, subprocess, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--race',choices=['human','elf','orc','dwarf'],default='human')
RACE=parser.parse_args().race; FAMILY={'human':'humans','elf':'elves','orc':'orcs','dwarf':'dwarves'}[RACE]
STEM=RACE+'_builder_v1'; REL=Path(f'assets/generated/{FAMILY}/{STEM}'); OUT=ROOT/REL
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
IMPORT='tools/art_pipeline/settler_model_import.gd'
report=json.loads((OUT/(STEM+'_report.json')).read_text(encoding='utf-8'))
assert report['held_tools']==['hammer'] and report['hammer_alignment']['striking_face_forward']
assert hashlib.sha256((ROOT/report['source']).read_bytes()).hexdigest()==report['source_sha256']
raw=(OUT/(STEM+'.glb')).read_bytes(); length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length])
assert len(doc['meshes'])==len(doc['skins'])==len(doc['materials'])==len(doc['images'])==1
assert len(doc['skins'][0]['joints'])==16
assert sorted(a['name'] for a in doc['animations'])==['idle','walk','work']
assert len(doc['meshes'][0]['primitives'])==1
assert doc['accessors'][doc['meshes'][0]['primitives'][0]['indices']]['count']//3==report['triangles']
assert not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])

def run(folder,args):
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    proc=subprocess.run([str(GODOT),'--headless','--path',str(folder),*args],capture_output=True,text=True,
                        encoding='utf-8',errors='replace',startupinfo=startup,timeout=120)
    log=proc.stdout+proc.stderr
    if proc.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in log: raise RuntimeError(log)
    return log

with tempfile.TemporaryDirectory(prefix=RACE+'_builder_validation_') as temporary:
    folder=Path(temporary); target=folder/REL; target.mkdir(parents=True)
    shutil.copy2(OUT/(STEM+'.glb'),target/(STEM+'.glb'))
    (folder/IMPORT).parent.mkdir(parents=True); shutil.copy2(ROOT/IMPORT,folder/IMPORT)
    verification=(ROOT/'tools/art_pipeline/verify_settler_animations_import.gd').read_text(encoding='utf-8')
    verification=verification.replace('for clip: String in ["idle","walk"]:', 'for clip: String in ["idle","walk","work"]:')
    verification=verification.replace('var duration := 3.0 if clip=="idle" else 1.5', 'var duration := 1.5 if clip=="walk" else 3.0')
    verification=verification.replace('animation.loop_mode==Animation.LOOP_LINEAR', 'animation.loop_mode==(Animation.LOOP_NONE if clip=="work" else Animation.LOOP_LINEAR)')
    verification=verification.replace('"loop":true', '"loop":clip!="work"')
    verification=verification.replace('results.size()*2', 'results.size()*3').replace('results.size()*50','results.size()*75')
    (folder/'verify.gd').write_text(verification,encoding='utf-8')
    manifest={'assets':[{'stem':STEM,'race':RACE,'glb':(REL/(STEM+'.glb')).as_posix()}]}
    (folder/'settlers_manifest.json').write_text(json.dumps(manifest),encoding='utf-8')
    (folder/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Human Builder Validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    run(folder,['--editor','--import'])
    settings=target/(STEM+'.glb.import'); content=settings.read_text(encoding='utf-8')
    assert 'import_script/path=""' in content
    content=content.replace('import_script/path=""','import_script/path="res://'+IMPORT+'"')
    content='\n'.join('animation/fps=48' if line.startswith('animation/fps=') else line for line in content.splitlines())+'\n'
    settings.write_text(content,encoding='utf-8')
    # Force source reimport so rapid import-setting edits cannot reuse
    # a cache created before the looping/post-import script was enabled.
    (target/(STEM+'.glb')).touch()
    run(folder,['--editor','--import'])
    output=OUT/'godot_validation.json'; run(folder,['--script','res://verify.gd','--',str(output)])
    validation=json.loads(output.read_text(encoding='utf-8')); assert validation['status']=='PASS'
    assert validation['verified']==1 and validation['clips']==3
    shutil.copy2(settings,OUT/settings.name)
    (OUT/(STEM+'.glb')).touch()
    for texture in target.glob('*.png'): shutil.copy2(texture,OUT/texture.name)
    print(json.dumps(validation,indent=2))
