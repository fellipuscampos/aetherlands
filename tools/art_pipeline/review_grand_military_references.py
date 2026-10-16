"""Read-only source snapshot and contact sheets for the 24 basic military buildings."""
import hashlib
import json
from pathlib import Path
from grand_military_assets import CIVS, RECIPES, reference_folder
from verify_magic_school_batch import sheet

ROOT = Path(__file__).resolve().parents[2]
baseline = ROOT / 'docs/grand_military_source_baseline.json'
if not baseline.exists():
    files = []
    for plural, _ in CIVS.values():
        files.extend(p for p in (ROOT/'assets/generated'/plural/'buildings').rglob('*')
                     if p.is_file() and p.suffix != '.import')
    files.extend(ROOT/p for p in ('scripts/data/BuildingDatabase.gd', 'scripts/data/BuildingData.gd',
                                'scripts/city/Building.gd', 'scripts/city/City.gd'))
    baseline.write_text(json.dumps([{'path': p.relative_to(ROOT).as_posix(),
                                   'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                                  for p in sorted(set(files))], indent=2), encoding='utf-8')
for civ, (plural, label) in CIVS.items():
    entries = []
    for role, recipe in RECIPES.items():
        folder = reference_folder(civ, role)
        out = ROOT/'assets/generated'/plural/'buildings'/folder
        report = json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
        entries.append({'folder': out.relative_to(ROOT).as_posix(), 'label': recipe[3]})
        print(civ, role, report.get('design_note', report.get('design', '')))
    print(sheet(civ, entries, 'three_quarter', 'grand_military_references', 'Referências militares básicas'))
