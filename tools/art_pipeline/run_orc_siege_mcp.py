"""Build only the new orc machines in the user's open Blender through MCP."""
import argparse
import hashlib
import json
from blender_mcp_client import execute
from orc_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS

parser = argparse.ArgumentParser()
parser.add_argument('--only', nargs='+', choices=[row['stem'] for row in SIEGE_ASSETS])
args = parser.parse_args()
WORK.mkdir(parents=True, exist_ok=True); (WORK / '.gdignore').touch()
baseline = WORK / 'protected_assets.json'
if not baseline.exists():
    protected = {}
    targets = {row['stem'] for row in SIEGE_ASSETS}
    for race in ('humans', 'elves', 'dwarves', 'orcs'):
        for folder in (ROOT / 'assets/generated' / race).iterdir():
            if folder.is_dir() and folder.name not in targets and folder.name not in ('buildings', 'animations'):
                for path in folder.iterdir():
                    if path.suffix in ('.blend', '.glb', '.png', '.json'):
                        protected[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    baseline.write_text(json.dumps(protected, indent=2), encoding='utf-8')
protected = json.loads(baseline.read_text(encoding='utf-8'))
for row in SIEGE_ASSETS:
    if args.only and row['stem'] not in args.only: continue
    print('OPEN_BLENDER_MCP_BUILD', row['stem'], flush=True)
    execute(f'''import sys, importlib.util
if {str(ROOT / 'tools/art_pipeline')!r} not in sys.path: sys.path.insert(0, {str(ROOT / 'tools/art_pipeline')!r})
spec = importlib.util.spec_from_file_location('orc_siege_builder', {str(ROOT / 'tools/art_pipeline/build_orc_siege.py')!r})
builder = importlib.util.module_from_spec(spec); spec.loader.exec_module(builder)
result = builder.build({row!r})
''', timeout=1200)
assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == sha for path, sha in protected.items())
if all((OUT / row['stem'] / (row['stem'] + '.glb')).exists() for row in SIEGE_ASSETS):
    (OUT / 'orc_siege_manifest.json').write_text(json.dumps(SIEGE_ASSETS, ensure_ascii=False, indent=2), encoding='utf-8')
print('ORC_SIEGE_ANIMATED_COMPLETE', flush=True)
