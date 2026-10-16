"""Inspect only the new saved Blender libraries and final live scene."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/elf_school_mages_review'
assets=bpy.app.driver_namespace['elf_school_mage_assets_v1']; review=bpy.app.driver_namespace['elf_school_mage_review_v1']; rows=[]
for asset in assets:
    path=asset['folder']/(asset['report']['stem']+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):
        assert len(src.scenes)==1 and not src.armatures and not src.actions and len(src.images)==2
        assert len(src.meshes)==len(asset['parts']) and len(src.materials)==1
        rows.append(dict(file=path.relative_to(ROOT).as_posix(),scenes=1,editable_meshes=len(src.meshes),images=2,materials=1,armatures=0,actions=0))
with bpy.data.libraries.load(str(WORK/'elf_school_mages_six_schools_review.blend'),link=False) as (src,dst):
    assert len(src.scenes)==1 and not src.armatures and not src.actions and len(src.images)==12
assert bpy.context.scene==review['scene']
assert [r.get('school') for r in review['roots']]==['sacred','infernal','necromancy','druidism','arcanism','elementalism']
assert all(r.scale==__import__('mathutils').Vector((1,1,1)) for r in review['roots'])
assert not any(o.name.endswith('_Export_TEMP') for o in bpy.data.objects)
result=dict(status='PASS',files=rows,active_scene=review['scene'].name,review_models=6,animations=0)
(ROOT/'docs/elf_school_mages_source_file_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
