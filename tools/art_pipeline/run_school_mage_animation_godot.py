"""Import and verify animated mages; exactly one hidden native preview session."""
import argparse,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/school_mages_animation_review'
GODOT=r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
parser=argparse.ArgumentParser(); parser.add_argument('stage',choices=['import','validate','native']); args=parser.parse_args()
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
if args.stage=='import':
    for row in manifest['assets']:
        path=(ROOT/row['glb']).with_suffix('.glb.import')
        text=path.read_text(encoding='utf-8')
        text=re.sub(r'^animation/import=.*$', 'animation/import=true',text,flags=re.M)
        text=re.sub(r'^animation/fps=.*$', 'animation/fps=48',text,flags=re.M)
        text=re.sub(r'^nodes/root_scale=.*$', 'nodes/root_scale=1.0',text,flags=re.M)
        text=re.sub(r'^import_script/path=.*$', 'import_script/path="res://tools/art_pipeline/school_mage_animation_import.gd"',text,flags=re.M)
        path.write_text(text,encoding='utf-8')
    command=[GODOT,'--headless','--path',str(ROOT),'--import']
elif args.stage=='validate':
    command=[GODOT,'--headless','--path',str(ROOT),'--script','res://tools/art_pipeline/verify_school_mage_animations_import.gd']
else:
    marker=WORK/'native_session_started.json'
    assert not marker.exists(), 'Native preview was already launched for this task.'
    marker.write_text(json.dumps({'stage':'started','models':24,'clips':72}),encoding='utf-8')
    command=[GODOT,'--path',str(ROOT),'--windowed','--resolution','1200x720','--position','-2500,-1500','--script','res://tools/art_pipeline/school_mage_animation_review_bootstrap.gd']
startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
run=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',startupinfo=startup,timeout=900)
log=run.stdout+'\n'+run.stderr
(WORK/('godot_animation_'+args.stage+'.log')).write_text(log,encoding='utf-8')
assert run.returncode==0 and 'SCRIPT ERROR:' not in log and 'ERROR:' not in run.stderr,log[-10000:]
if args.stage!='import':
    report=json.loads((ROOT/'docs'/('school_mages_animation_godot_'+('import_validation' if args.stage=='validate' else 'native_validation')+'.json')).read_text(encoding='utf-8'))
    assert report['status']=='PASS' and report['verified']==24
    if args.stage=='native': marker.write_text(json.dumps(dict(stage='completed',status='PASS',models=24,clips=72,native_session_count=1)),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='assets'}))
else: print('All 24 animated mage GLBs imported.')
