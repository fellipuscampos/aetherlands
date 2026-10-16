"""Import the real animated GLBs in isolated Godot and retain loop settings."""
import json,shutil,subprocess,tempfile,argparse
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/settlers_review'
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
IMPORT_SCRIPT='tools/art_pipeline/settler_model_import.gd'
parser=argparse.ArgumentParser(); parser.add_argument('--keep-import-settings',action='store_true'); args=parser.parse_args()
with tempfile.TemporaryDirectory(prefix='settler_idle_walk_validation_') as temporary:
    project=Path(temporary).resolve(); assert project.parent==Path(tempfile.gettempdir()).resolve()
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Four Settlers Animation Validation"\n[filesystem]\nimport/blender/enabled=false\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    (project/'settlers_manifest.json').write_text(json.dumps(manifest),encoding='utf-8')
    (project/IMPORT_SCRIPT).parent.mkdir(parents=True)
    shutil.copy2(ROOT/IMPORT_SCRIPT,project/IMPORT_SCRIPT)
    shutil.copy2(ROOT/'tools/art_pipeline/verify_settler_animations_import.gd',project/'verify.gd')
    for row in manifest['assets']:
        target=project/row['glb']; target.parent.mkdir(parents=True)
        shutil.copy2(ROOT/row['glb'],target)
    logs=[]
    def run(arguments):
        result=subprocess.run([str(GODOT),'--headless','--path',str(project),*arguments],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
        logs.append(result.stdout+'\n'+result.stderr)
        (WORK/'animation_godot_validation.log').write_text('\n'.join(logs),encoding='utf-8')
        assert result.returncode==0 and 'SCRIPT ERROR' not in result.stdout+result.stderr and 'ERROR:' not in result.stderr,result.stdout+'\n'+result.stderr
        return result
    run(['--editor','--import'])
    for row in manifest['assets']:
        path=(project/row['glb']).with_suffix('.glb.import'); text=path.read_text(encoding='utf-8')
        assert 'import_script/path=""' in text
        text=text.replace('import_script/path=""','import_script/path="res://'+IMPORT_SCRIPT+'"')
        assert 'animation/fps=' in text
        text='\n'.join('animation/fps=48' if line.startswith('animation/fps=') else line for line in text.splitlines())+'\n'
        path.write_text(text,encoding='utf-8')
    run(['--editor','--import'])
    output=ROOT/'docs/settlers_animation_godot_validation.json'
    result=run(['--script','res://verify.gd','--',str(output)])
    report=json.loads(output.read_text(encoding='utf-8')); assert report['status']=='PASS' and report['verified']==4 and report['clips']==8
    for row in manifest['assets']:
        target=(ROOT/row['glb']).parent; source=(project/row['glb']).parent
        if args.keep_import_settings:
            existing=(ROOT/row['glb']).with_suffix('.glb.import').read_text(encoding='utf-8')
            assert 'import_script/path="res://'+IMPORT_SCRIPT+'"' in existing and 'animation/fps=48' in existing
        else: shutil.copy2((project/row['glb']).with_suffix('.glb.import'),(ROOT/row['glb']).with_suffix('.glb.import'))
        for path in source.glob('*.png'):
            destination=target/path.name
            if destination.exists(): assert path.read_bytes()==destination.read_bytes(),'Existing texture differs from imported texture'
            else: shutil.copy2(path,destination)
    uid=(project/IMPORT_SCRIPT).with_suffix('.gd.uid')
    if uid.exists() and not (ROOT/IMPORT_SCRIPT).with_suffix('.gd.uid').exists(): shutil.copy2(uid,(ROOT/IMPORT_SCRIPT).with_suffix('.gd.uid'))
    print(json.dumps({k:v for k,v in report.items() if k!='assets'}))
