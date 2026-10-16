"""Run the direct asset importer in a temporary project without game autoloads."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

PIPELINE = Path(__file__).resolve().parent
ROOT = PIPELINE.parents[1]

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    parser.add_argument('--civ',choices=('human','orc','dwarf','elf'))
    parser.add_argument('--grand',action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='magic_school_godot_') as temp:
        project = Path(temp).resolve()
        assert project.parent == Path(tempfile.gettempdir()).resolve()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Magic asset validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        shutil.copyfile(PIPELINE/'verify_magic_school_import.gd',project/'verify.gd')
        cmd = [args.godot,'--headless','--path',str(project),'--script','verify.gd','--',str(ROOT)]
        if args.civ or args.grand:
            cmd.append(args.civ or 'all')
        if args.grand:
            cmd.append('grand')
        done = subprocess.run(cmd,timeout=240)
    raise SystemExit(done.returncode)
