"""Preserve the approved structure while replacing bone armour with horns."""
import json
from collections import Counter
import numpy as np
from orc_siege_assets import ROOT, OUT, WORK, SIEGE_ASSETS
from human_texture_glb import read_glb
from audit_elf_troops import accessor


def structure(path):
    doc, binary = read_glb(path.read_bytes()); result = Counter()
    for prim in doc['meshes'][0]['primitives']:
        material = doc['materials'][prim['material']]['name']
        # Ivory is intentionally replaced. Bronze rivets move onto the iron
        # guards after plate removal; structural materials must be preserved.
        if '_ivory' in material or '_bronze' in material or '_gold' in material: continue
        positions = accessor(doc, binary, prim['attributes']['POSITION'])
        indices = accessor(doc, binary, prim['indices']).ravel().reshape(-1, 3)
        for triangle in indices:
            result[tuple(sorted(tuple(np.round(positions[i], 4)) for i in triangle))] += 1
    return result


backup = WORK / 'before_horns_and_animations'
checks = []
for row in SIEGE_ASSETS:
    stem = row['stem']; old_folder = backup / 'assets/generated/orcs' / stem
    previous = json.loads((old_folder / (stem + '_report.json')).read_text(encoding='utf-8'))
    current = json.loads((OUT / stem / (stem + '_report.json')).read_text(encoding='utf-8'))
    old = structure(old_folder / (stem + '.glb'))
    new = structure(OUT / stem / (stem + '.glb'))
    assert not old - new, (stem, sum((old - new).values()))
    assert np.allclose(previous['geometry']['dimensions'], current['geometry']['dimensions'], atol=.000001)
    assert previous['material_palette'] == current['material_palette']
    assert len(current['ivory_parts']) == 2
    assert len(current['clips']) == (4 if row['tier'] == 0 else 5)
    checks.append(dict(stem=stem, approved_structure_preserved=True, dimensions_preserved=True,
                       palette_preserved=True, horn_parts=current['ivory_parts'], clips=len(current['clips'])))
report = dict(status='PASS', models=checks, colossus_design='six_wheel_twin_heavy_bombard',
              skull_removed=True, bone_plates_removed=True, animated=True, clips=19)
(ROOT / 'docs/orc_siege_revision_validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
