"""Check the saved native sources and final live review without appending scenes."""
import bpy,json
from pathlib import Path

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
assets=bpy.app.driver_namespace['settlers_v1_assets']
animated=all(a['report'].get('animations')==2 for a in assets)
files=[a['folder']/(a['root'].name+'.blend') for a in assets]
files.append(ROOT/'art_source/settlers_review/settlers_four_civilizations_review.blend')
checks=[]
for path in files:
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):
        is_review=path.name=='settlers_four_civilizations_review.blend'
        expected_rigs=(4 if is_review else 1) if animated else 0
        expected_actions=(8 if is_review else 2) if animated else 0
        assert len(src.scenes)==1 and len(src.armatures)==expected_rigs and len(src.actions)==expected_actions,path.name
        checks.append(dict(file=path.name,scenes=len(src.scenes),armatures=len(src.armatures),actions=len(src.actions),images=len(src.images)))
scene=bpy.context.scene
assert scene.name=='Settlers_V1_Four_Civilizations_Review'
roots=sorted([o for o in scene.objects if o.type=='EMPTY' and o.get('asset_stage')=='static_settler_review'],key=lambda o:o.location.x)
assert [o.get('race') for o in roots]==['human','elf','dwarf','orc']
if animated:
    rigs=[o for o in scene.objects if o.type=='ARMATURE']
    assert len(rigs)==4
    assert all({t.name for t in rig.animation_data.nla_tracks}=={'idle','walk'} for rig in rigs)
else:
    assert all(o.animation_data is None for o in scene.objects)
    assert all(not o.modifiers for o in scene.objects if o.type=='MESH')
    assert not any(o.type=='ARMATURE' for o in scene.objects)
assert not any('StaticExport_TEMP' in o.name for o in bpy.data.objects)
result=dict(status='PASS',files=checks,active_scene=scene.name,left_to_right=[o.get('race') for o in roots],animations=8 if animated else 0)
(ROOT/'docs/settlers_source_file_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
