"""Restore only original import sidecars, checking each byte hash first."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
changes=json.loads((ROOT/'art_source/building_architecture_review/backup_import_metadata_changes.json').read_text(encoding='utf-8'))
for item in changes:
    assert item['backup'].endswith('.import') and item['active_matches_original']
    content=(ROOT/item['active']).read_bytes()
    assert hashlib.sha256(content).hexdigest()==item['expected']
    (ROOT/item['backup']).write_bytes(content)
extras=[]
manifest=json.loads((ROOT/'art_source/buildings_before_architecture_revision/manifest.json').read_text(encoding='utf-8'))
for entry in manifest:
    directory=ROOT/entry['backup']
    extras.extend(str(path.relative_to(ROOT)) for path in directory.rglob('*') if path.is_file() and path.relative_to(directory).as_posix() not in entry['files'])
print(json.dumps({'sidecars_restored':len(changes),'extra_generated_files':extras}))
