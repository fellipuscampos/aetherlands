"""Author shared dwarf actions through the already running Blender MCP."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from blender_mcp_client import execute
from dwarf_troop_assets import ASSETS, OUT, ROOT, WORK

parser = argparse.ArgumentParser()
parser.add_argument('--families', nargs='*')
parser.add_argument('--rebuild', action='store_true')
args = parser.parse_args()
backup = WORK / 'approved_static_before_animation_v1'
if not backup.exists():
    backup.mkdir(parents=True)
    (backup / '.gdignore').touch()
    baseline = {}
    for row in ASSETS:
        folder = OUT / row['stem']
        target = backup / row['stem']
        target.mkdir()
        for suffix in ('.blend', '.glb', '_albedo.png', '_report.json'):
            path = folder / (row['stem'] + suffix)
            shutil.copy2(path, target / path.name)
            baseline[str(path.relative_to(ROOT)).replace('\\', '/')] = hashlib.sha256(path.read_bytes()).hexdigest()
    (backup / 'baseline.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
families = list(dict.fromkeys(r['family'] for r in ASSETS))
for family in families:
    if args.families and family not in args.families:
        continue
    source = ROOT / 'tools/art_pipeline/animate_dwarf_troops.py'
    execute(f'''import sys
from pathlib import Path
source=Path({str(source)!r})
sys.path.insert(0,str(source.parent))
ns={{'__file__':str(source),'__name__':'dwarf_animation_mcp'}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
ns['build_family']({family!r},rebuild={args.rebuild!r})
result={{'family':{family!r},'animations':3,'variants':4,'mcp':'live'}}
''')
    print('DWARF_ANIMATION_FAMILY_DONE ' + family, flush=True)
