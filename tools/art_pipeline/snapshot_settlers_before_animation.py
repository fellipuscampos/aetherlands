"""Preserve the approved static settlers before the requested arm/animation edit."""
import json,hashlib,shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'art_source/settlers_review'
OUT=ROOT/'art_source/settlers_before_idle_walk'
assert not (OUT/'snapshot.json').exists(),'A previous snapshot exists; preserve it'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'.gdignore').touch()
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
files=[]
for row in manifest['assets']:
    files.extend(p for p in (ROOT/row['blend']).parent.rglob('*') if p.is_file() and p.suffix not in ('.import','.uid'))
files.extend(p for p in WORK.iterdir() if p.is_file() and p.name not in ('.gdignore','current_stage.json'))
files.extend(p for p in (ROOT/'docs').glob('settlers*validation.json'))
records=[]
for path in files:
    relative=path.relative_to(ROOT); target=OUT/relative
    target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,target)
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest==hashlib.sha256(target.read_bytes()).hexdigest()
    records.append(dict(path=relative.as_posix(),sha256=digest))
(OUT/'snapshot.json').write_text(json.dumps(dict(files=records),indent=2),encoding='utf-8')
print(json.dumps(dict(status='PASS',files=len(records),snapshot=str(OUT))))
