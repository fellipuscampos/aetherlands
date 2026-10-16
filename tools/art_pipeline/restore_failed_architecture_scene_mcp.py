"""Restore only an unexported failed building from its preserved input."""
import bpy
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
matches=list((ROOT/'assets/generated').glob('*/buildings/'+RESTORE_FOLDER+'/'+RESTORE_FOLDER+'_report.json'))
assert len(matches)==1
out=matches[0].parent
report=json.loads(matches[0].read_text(encoding='utf-8'))
assert not report.get('architecture_revision'), 'An exported revision must not be discarded'
name=report['name']; failed=bpy.data.scenes[name]
objects=list(failed.objects); collections=list(failed.collection.children)
assert all(obj.users==1 for obj in objects), 'Shared objects need individual recovery'
bpy.context.window.scene=bpy.data.scenes['War_Stable_Hex_V1']
exclusive_data={obj.data for obj in objects if obj.data and obj.data.users==1}
bpy.data.batch_remove(ids={failed,*collections,*objects,*exclusive_data})
source=ROOT/'art_source/buildings_before_architecture_revision'/out.relative_to(ROOT/'assets/generated')/(RESTORE_FOLDER+'.blend')
with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
    assert name in available.scenes
    loaded.scenes=[name]
scene=loaded.scenes[0]
assert scene.name==name and not scene.get('architecture_revision')
bpy.context.window.scene=scene
result={'restored_input':RESTORE_FOLDER,'source':str(source),'other_scenes_preserved':True}
