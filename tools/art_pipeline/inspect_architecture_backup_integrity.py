"""Identify editor-generated changes to backup import sidecars."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
manifest=json.loads((ROOT/'art_source/buildings_before_architecture_revision/manifest.json').read_text(encoding='utf-8'))
changed=[]
for entry in manifest:
    for relative,digest in entry['files'].items():
        path=ROOT/entry['backup']/relative
        if hashlib.sha256(path.read_bytes()).hexdigest()==digest:
            continue
        active=ROOT/'assets/generated'/Path(entry['backup']).relative_to('art_source/buildings_before_architecture_revision')/relative
        changed.append({'backup':str(path.relative_to(ROOT)),'expected':digest,'active_matches_original':hashlib.sha256(active.read_bytes()).hexdigest()==digest,'active':str(active.relative_to(ROOT))})
(ROOT/'art_source/building_architecture_review/backup_import_metadata_changes.json').write_text(json.dumps(changed,indent=2),encoding='utf-8')
print(json.dumps({'changed':len(changed),'all_import_sidecars':all(x['backup'].endswith('.import') for x in changed),'recoverable_from_active':sum(x['active_matches_original'] for x in changed),'examples':changed[:4]}))
