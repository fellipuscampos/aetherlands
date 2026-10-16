"""Check every completed infrastructure GLB in an isolated Godot project."""
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
GODOT=Path(r'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
source=(ROOT/'tools/art_pipeline/verify_building_architecture_import.gd').read_text(encoding='utf-8')
source=source.replace('art_source/building_architecture_review/completed.json','art_source/infrastructure_buildings_review/completed.json').replace('docs/building_architecture_godot_validation.json','docs/infrastructure_buildings_godot_validation.json')
with tempfile.TemporaryDirectory(prefix='infrastructure_buildings_godot_') as temporary:
    project=Path(temporary).resolve()
    assert project.parent==Path(tempfile.gettempdir()).resolve()
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Infrastructure validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    (project/'verify.gd').write_text(source,encoding='utf-8')
    response=subprocess.run([str(GODOT),'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT)],timeout=300)
raise SystemExit(response.returncode)
