"""Import at the real res:// path, validate native skin/animations, copy its cache."""
import json, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STEM='mana_devourer_blocky_v3'
ASSET=Path('assets/generated/mana_devourers')/STEM
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
def run(project,args):
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    p=subprocess.run([str(GODOT),'--path',str(project),*args],capture_output=True,text=True,
        encoding='utf-8',errors='replace',startupinfo=startup,timeout=180)
    log=p.stdout+p.stderr
    if p.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in p.stderr: raise RuntimeError(log)
    return log
with tempfile.TemporaryDirectory(prefix='mana_blocky_v3_validation_') as temp:
    project=Path(temp); folder=project/ASSET; folder.mkdir(parents=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Mana Blocky Review"\n[display]\nwindow/size/viewport_width=800\nwindow/size/viewport_height=800\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
    for name in (STEM+'.glb','mana_devourer_blocky_import.gd'):
        shutil.copy2(ROOT/ASSET/name,folder/name)
    for p in (ROOT/ASSET).glob('*.uid'): shutil.copy2(p,folder/p.name)
    for p in (ROOT/ASSET).glob('*.png*'): shutil.copy2(p,folder/p.name)
    previous=ROOT/ASSET/(STEM+'.glb.import')
    if previous.exists(): shutil.copy2(previous,folder/previous.name)
    shutil.copy2(ROOT/'tools/art_pipeline/verify_mana_devourer_blocky_v3.gd',project/'verify.gd')
    run(project,['--headless','--editor','--import'])
    settings=folder/(STEM+'.glb.import')
    value=settings.read_text(encoding='utf-8')
    value=re.sub(r'^import_script/path=.*$',f'import_script/path="res://{ASSET.as_posix()}/mana_devourer_blocky_import.gd"',value,flags=re.M)
    value=re.sub(r'^animation/fps=.*$','animation/fps=24',value,flags=re.M)
    settings.write_text(value,encoding='utf-8')
    run(project,['--headless','--editor','--import'])
    log=run(project,['--script','res://verify.gd','--',str(ROOT/ASSET/'previews/godot_game_view.png')])
    lines=[line.split('MANA_BLOCKY_VALIDATION ',1)[1] for line in log.splitlines() if 'MANA_BLOCKY_VALIDATION ' in line]
    assert len(lines)==1,log
    report=json.loads(lines[0])
    (ROOT/ASSET/'godot_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    shutil.copy2(settings,ROOT/ASSET/settings.name)
    for p in folder.glob('*.uid'): shutil.copy2(p,ROOT/ASSET/p.name)
    for p in folder.glob('*.png*'): shutil.copy2(p,ROOT/ASSET/p.name)
    cache=ROOT/'.godot/imported'; cache.mkdir(exist_ok=True)
    for p in (project/'.godot/imported').glob(STEM+'*'): shutil.copy2(p,cache/p.name)
    print(json.dumps(report,indent=2))
