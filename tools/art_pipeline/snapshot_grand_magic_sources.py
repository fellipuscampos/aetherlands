"""Capture the current approved schools and user runtime files without changing them."""
import hashlib
import json
from pathlib import Path
from grand_magic_assets import CIVS, RECIPES

ROOT=Path(__file__).resolve().parents[2]
target=ROOT/'docs/grand_magic_source_baseline.json'
if not target.exists():
    paths=[ROOT/p for p in ('scripts/data/BuildingDatabase.gd','scripts/data/BuildingData.gd',
        'scripts/city/Building.gd','scripts/city/City.gd')]
    for civ,(plural,_) in CIVS.items():
        for _,_,_,previous in RECIPES.values():
            folder=('' if civ=='human' else civ+'_')+previous+'_hex_v1'
            out=ROOT/'assets/generated'/plural/'buildings'/folder
            paths += sorted(p for p in out.rglob('*') if p.is_file())
    rows=[{'path':p.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
    target.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'preserved_source_files':len(rows)}))
else:
    print('Existing source snapshot preserved.')
