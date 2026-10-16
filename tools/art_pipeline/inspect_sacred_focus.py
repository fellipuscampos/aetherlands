"""Read-only Blender inspection of the four existing sacred staff crystals."""
import bpy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
result = {}
for race, folder in [('human', 'humans'), ('elf', 'elves'), ('orc', 'orcs'), ('dwarf', 'dwarves')]:
    name = race + '_sacred_cleric_v1'
    path = root / 'assets/generated' / folder / name / (name + '.blend')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        target.objects = source.objects
    cores = [o for o in target.objects if o is not None and o.type == 'MESH' and o.get('part') in ('Sun_staff_core', 'Sun_leaf_focus')]
    if not cores:
        print('FOCUS_CANDIDATES', name, [(o.name, o.get('part')) for o in target.objects if o is not None and o.type == 'MESH' and ('Sun' in o.name or 'staff' in o.name.lower())])
    core = cores[0]
    layer = core.data.uv_layers.active
    uv = [tuple(v.uv) for v in layer.data]
    result[name] = {'uvs': uv}
out = root / 'art_source/sacred_focus_uv.json'
out.write_text(json.dumps(result, indent=2))
print('SACRED_FOCUS_UV:', out)
