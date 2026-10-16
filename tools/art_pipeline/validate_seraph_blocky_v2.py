"""Validate the static GLB and its review scene in native Godot, at their real URI."""
import json, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STEM = 'seraph_blocky_v2'
ASSET = Path('assets/generated/grand_manifestations') / STEM
GODOT = Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')

def run(project, args):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    p = subprocess.run([str(GODOT), '--path', str(project), *args], capture_output=True,
        text=True, encoding='utf-8', errors='replace', startupinfo=startup, timeout=180)
    log = p.stdout + p.stderr
    if p.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in p.stderr:
        raise RuntimeError(log)
    return log

with tempfile.TemporaryDirectory(prefix='seraph_static_validation_') as temp:
    project = Path(temp)
    folder = project / ASSET
    folder.mkdir(parents=True)
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Seraph Model Review"\n[display]\nwindow/size/viewport_width=1000\nwindow/size/viewport_height=1000\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[filesystem]\nimport/blender/enabled=false\n', encoding='utf-8')
    for name in [STEM + '.glb', STEM + '_report.json', *(p.name for p in (ROOT/ASSET).glob('*.png*'))]:
        shutil.copy2(ROOT / ASSET / name, folder / name)
    previous = ROOT / ASSET / (STEM + '.glb.import')
    if previous.exists():
        shutil.copy2(previous, folder / previous.name)
    for rel in ['scripts/art_review/SeraphModelV2Review.gd', 'scenes/art_review/SeraphModelV2Review.tscn']:
        target = project / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        uid = Path(str(ROOT / rel) + '.uid')
        if uid.exists():
            shutil.copy2(uid, Path(str(target) + '.uid'))
    shutil.copy2(ROOT / 'tools/art_pipeline/verify_seraph_blocky_v2.gd', project / 'verify.gd')
    run(project, ['--headless', '--editor', '--import'])
    log = run(project, ['--script', 'res://verify.gd', '--', str(ROOT / ASSET / 'previews')])
    lines = [line.split('SERAPH_MODEL_VALIDATION ', 1)[1] for line in log.splitlines() if 'SERAPH_MODEL_VALIDATION ' in line]
    assert len(lines) == 1, log
    report = json.loads(lines[0])
    source = json.loads((ROOT / ASSET / (STEM+'_report.json')).read_text(encoding='utf-8'))
    assert report['triangles'] == source['triangles'] and report['animations'] == 0
    (ROOT / ASSET / 'godot_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    for p in folder.glob('*.png*'):
        shutil.copy2(p, ROOT / ASSET / p.name)
    shutil.copy2(folder / (STEM+'.glb.import'), ROOT / ASSET / (STEM+'.glb.import'))
    uid = project / 'scripts/art_review/SeraphModelV2Review.gd.uid'
    shutil.copy2(uid, ROOT / 'scripts/art_review/SeraphModelV2Review.gd.uid')
    cache = ROOT / '.godot/imported'
    cache.mkdir(exist_ok=True)
    for p in (project / '.godot/imported').glob(STEM+'*'):
        shutil.copy2(p, cache / p.name)
    print(json.dumps(report, indent=2))
