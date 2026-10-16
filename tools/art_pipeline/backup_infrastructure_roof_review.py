"""Preserve the approved infrastructure before the focused native roof review."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'art_source/infrastructure_before_roof_review'
RACES={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
if (DEST/'manifest.json').exists():
    manifest=json.loads((DEST/'manifest.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((DEST/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in manifest['files'])
    print('Existing immutable backup verified.')
else:
    DEST.mkdir(exist_ok=True)
    (DEST/'.gdignore').write_text('',encoding='utf-8')
    files=[]
    for entry in entries:
        source=ROOT/'assets/generated'/RACES[entry['civilization']]/'buildings'/entry['asset']
        target=DEST/RACES[entry['civilization']]/entry['asset']
        assert not target.exists(),target
        shutil.copytree(source,target)
        for path in sorted(target.rglob('*')):
            if path.is_file(): files.append({'path':path.relative_to(DEST).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    shutil.copy2(ROOT/'art_source/infrastructure_buildings_review/all_infrastructure.jpg',DEST/'all_infrastructure.jpg')
    (DEST/'manifest.json').write_text(json.dumps({'assets':entries,'files':files},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Preserved {len(entries)} assets and {len(files)} files.')
