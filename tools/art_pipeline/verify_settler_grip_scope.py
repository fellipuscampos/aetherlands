"""Verify snapshots, textures, and unaffected settlers after the grip repair."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
backup=ROOT/'art_source/settlers_before_grip_fix'
snapshot=json.loads((backup/'snapshot.json').read_text(encoding='utf-8'))
for row in snapshot['files']:
    assert hashlib.sha256((backup/row['path']).read_bytes()).hexdigest()==row['sha256'],('Snapshot changed',row['path'])
for row in snapshot['protected_files']:
    assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],('Unaffected settler changed',row['path'])
textures=[row for row in snapshot['files'] if row['path'].endswith('_albedo.png')]
for row in textures:
    assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],('Texture changed',row['path'])
report=dict(status='PASS',snapshot_files=len(snapshot['files']),human_and_dwarf_unchanged_files=len(snapshot['protected_files']),affected_atlases_unchanged=len(textures))
(ROOT/'docs/settlers_grip_scope_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
