"""Keep the complete, original 24 military assets before localized repairs."""
import hashlib
import json
import shutil
from pathlib import Path
from grand_military_assets import CIVS, QUEUE, folder_name

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'art_source/grand_military_before_finish_pass'
manifest = DEST / 'manifest.json'
if manifest.exists():
    rows = json.loads(manifest.read_text(encoding='utf-8'))
    assert all(hashlib.sha256((DEST/r['backup']).read_bytes()).hexdigest() == r['sha256'] for r in rows)
else:
    rows = []
    for civ, role in QUEUE:
        folder = folder_name(civ, role)
        source = ROOT/'assets/generated'/CIVS[civ][0]/'buildings'/folder
        files = [p for p in source.rglob('*') if p.is_file() and not p.name.endswith('.import')]
        assert len(files) == 10, (folder, len(files))
        for p in files:
            rel = Path(CIVS[civ][0])/folder/p.relative_to(source)
            target = DEST/rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
            rows.append({'source':p.relative_to(ROOT).as_posix(), 'backup':rel.as_posix(),
                         'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    manifest.write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(json.dumps({'original_files_preserved':len(rows), 'backup':str(DEST)}))
