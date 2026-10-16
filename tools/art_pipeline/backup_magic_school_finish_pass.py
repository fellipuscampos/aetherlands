"""Preserve the exact 24 inputs before editing them in Blender MCP."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT/'art_source/magic_schools_before_finish_pass'
catalog = json.loads((ROOT/'docs/magic_schools_validation.json').read_text(encoding='utf-8'))
manifest = []
for entry in catalog['assets']:
    source = ROOT/entry['folder']
    destination = BACKUP/entry['folder']
    if not destination.exists():
        shutil.copytree(source,destination)
    for path in destination.rglob('*'):
        if path.is_file():
            manifest.append({'path':path.relative_to(BACKUP).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
if not (BACKUP/'manifest.json').exists():
    (BACKUP/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps({'preserved_assets':24,'backup':str(BACKUP),'files':len(manifest)}))
