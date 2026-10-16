"""Import and exercise the animated elder lich in native Godot at its real URI."""
import json, re, shutil, subprocess, tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
STEM='elder_lich_blocky_v3_animated'
ASSET=Path('assets/generated/grand_manifestations')/STEM
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')

def run(project,args):
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    process=subprocess.run([str(GODOT),'--path',str(project),*args],capture_output=True,text=True,
        encoding='utf-8',errors='replace',startupinfo=startup,timeout=180)
    log=process.stdout+process.stderr
    if process.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in process.stderr: raise RuntimeError(log)
    return log

folder_real=ROOT/ASSET
previews=folder_real/'previews'; previews.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='elder_lich_animations_') as temp:
    project=Path(temp); folder=project/ASSET; folder.mkdir(parents=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Elder Lich Animation Review"\n[display]\nwindow/size/viewport_width=1000\nwindow/size/viewport_height=1000\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n',encoding='utf-8')
    for name in [STEM+'.glb','animation_report.json','elder_lich_animation_import.gd',*(p.name for p in folder_real.glob('*.png*'))]:
        shutil.copy2(folder_real/name,folder/name)
    old_import=folder_real/(STEM+'.glb.import')
    if old_import.exists(): shutil.copy2(old_import,folder/old_import.name)
    for rel in ['scripts/art_review/ElderLichAnimationReview.gd','scenes/art_review/ElderLichAnimationReview.tscn']:
        target=project/rel; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/rel,target)
        uid=Path(str(ROOT/rel)+'.uid')
        if uid.exists(): shutil.copy2(uid,Path(str(target)+'.uid'))
    shutil.copy2(ROOT/'tools/art_pipeline/verify_elder_lich_animations.gd',project/'verify.gd')
    run(project,['--headless','--editor','--import'])
    settings=folder/(STEM+'.glb.import'); value=settings.read_text(encoding='utf-8')
    for key,replacement in [('import_script/path',f'"res://{ASSET.as_posix()}/elder_lich_animation_import.gd"'),
                            ('animation/fps','24'),('animation/remove_immutable_tracks','false')]:
        value,count=re.subn('^'+re.escape(key)+r'=.*$',key+'='+replacement,value,flags=re.M)
        assert count==1,(key,value)
    settings.write_text(value,encoding='utf-8')
    for p in (project/'.godot/imported').glob(STEM+'.glb-*'): p.unlink()
    for p in (project/'.godot/editor').glob('filesystem_cache*'): p.unlink()
    run(project,['--headless','--editor','--import'])
    log=run(project,['--script','res://verify.gd','--',str(previews),str(ROOT/'art_source/elder_lich_blocky_v3_animated_review/native_frames')])
    lines=[line.split('ELDER_LICH_ANIMATION_VALIDATION ',1)[1] for line in log.splitlines() if 'ELDER_LICH_ANIMATION_VALIDATION ' in line]
    assert len(lines)==1,log
    report=json.loads(lines[0]); assert report['status']=='PASS' and set(report['clips'])=={'Idle','Walk','Attack','Spell'}
    (folder_real/'godot_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    for p in folder.glob('*.png*'): shutil.copy2(p,folder_real/p.name)
    shutil.copy2(settings,folder_real/settings.name)
    for rel in ['scripts/art_review/ElderLichAnimationReview.gd.uid',str(ASSET/'elder_lich_animation_import.gd.uid')]:
        shutil.copy2(project/rel,ROOT/rel)
    cache=ROOT/'.godot/imported'; cache.mkdir(exist_ok=True)
    for p in (project/'.godot/imported').glob(STEM+'*'): shutil.copy2(p,cache/p.name)
    print(json.dumps(report,indent=2))
