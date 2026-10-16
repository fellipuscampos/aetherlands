"""Read-only focus UV inspection for the remaining school mage models."""
import bpy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
result = {}
for race, folder in [('human','humans'),('elf','elves'),('orc','orcs'),('dwarf','dwarves')]:
    for school in ['infernal_warlock','necromancer','druid','arcanist','elementalist']:
        name = f'{race}_{school}_v1'
        path = root / 'assets/generated' / folder / name / (name + '.blend')
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(path), link=False) as (source, target):
            target.objects = source.objects
        objects = [o for o in target.objects if o is not None and o.type == 'MESH']
        priority = {
            'infernal_warlock':['Cinder_flame'],
            'necromancer':['Skull_rune','Ivory_memory_focus','Skull_focus','Crypt_reliquary'],
            'druid':['Druid_staff_knot','Living_staff_leaf_1','Branch_leaf_0','Druid_focus','Leaf_cluster_upper_1','Leaf_cluster_1'],
            'arcanist':['Arcane_focus'],
            'elementalist':['Element_core','Element_hub','Element_focus_wind'],
        }[school]
        core = next((o for part in priority for o in objects if o.get('part') == part), None)
        if core is None:
            print('MISSING_FOCUS',name,[(o.name,o.get('part')) for o in objects if 'staff' in o.name.lower() or 'focus' in o.name.lower() or 'leaf' in o.name.lower()])
            continue
        result[name] = {'part':core.get('part'),'uvs':[list(v.uv) for v in core.data.uv_layers.active.data]}
(root / 'art_source/school_focus_uv.json').write_text(json.dumps(result, indent=2))
print('SCHOOL_FOCI',len(result))
