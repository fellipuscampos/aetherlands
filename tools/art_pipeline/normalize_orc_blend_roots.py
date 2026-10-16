"""Match editable root/rig hierarchy to the equivalent corrected GLBs."""
import bpy,sys,json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo');sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import ASSETS,OUT
previous=bpy.context.scene; fixed=[]
for row in ASSETS:
    if row['key'] not in ('sentinel','guardian_champion','rogue','saboteur','assassin','shadow_master'): continue
    path=OUT/row['stem']/(row['stem']+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.scenes=src.scenes
    scene=dst.scenes[0]; bpy.context.window.scene=scene
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    bpy.context.view_layer.update(); before=rig.matrix_world.copy()
    rig.location.z+=root.location.z/root.scale.z; root.location.z=0
    bpy.context.view_layer.update()
    assert max(abs(before[i][j]-rig.matrix_world[i][j]) for i in range(4) for j in range(4))<.000001
    bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    fixed.append(row['stem'])
    bpy.context.window.scene=previous; bpy.data.scenes.remove(scene)
result=dict(status='PASS',normalized_models=len(fixed))
