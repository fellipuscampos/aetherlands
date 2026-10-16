"""Keep the approved animated sources before this small grip repair."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2]
backup=ROOT/'art_source/settlers_before_grip_fix'
assert not backup.exists(),'Snapshot already exists; never overwrite the approved state'
backup.mkdir(); (backup/'.gdignore').write_text('',encoding='utf-8')
files=[]; protected=[]
for race,folder in [('elf','elves'),('orc','orcs'),('human','humans'),('dwarf','dwarves')]:
    for path in (ROOT/'assets/generated'/folder/(race+'_settler_v1')).rglob('*'):
        if not path.is_file(): continue
        relative=path.relative_to(ROOT); sha=hashlib.sha256(path.read_bytes()).hexdigest()
        if race in ('human','dwarf'): protected.append(dict(path=relative.as_posix(),sha256=sha)); continue
        destination=backup/relative; destination.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,destination)
        files.append(dict(path=relative.as_posix(),sha256=sha))
work=ROOT/'art_source/settlers_review'
for path in [*work.glob('*.blend'),work/'manifest.json',work/'README.md',work/'index.html']:
    relative=path.relative_to(ROOT); destination=backup/relative; destination.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(path,destination)
    files.append(dict(path=relative.as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(backup/'snapshot.json').write_text(json.dumps(dict(files=files,protected_files=protected),indent=2),encoding='utf-8')
print(json.dumps(dict(status='PASS',snapshot_files=len(files),protected_files=len(protected))))
