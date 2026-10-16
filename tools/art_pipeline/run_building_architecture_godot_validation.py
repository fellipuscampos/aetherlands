"""Import revised GLBs in an isolated Godot project without game autoloads."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
GODOT=Path(r'C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe')
assert GODOT.is_file()
with tempfile.TemporaryDirectory(prefix='building_architecture_godot_') as temp:
    project=Path(temp).resolve()
    assert project.parent==Path(tempfile.gettempdir()).resolve()
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Building architecture validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    shutil.copyfile(ROOT/'tools/art_pipeline/verify_building_architecture_import.gd',project/'verify.gd')
    result=subprocess.run([str(GODOT),'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT)],timeout=300)
raise SystemExit(result.returncode)
