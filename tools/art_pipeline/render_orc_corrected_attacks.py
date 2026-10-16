"""Preview actual exported attack poses in the user's open Blender MCP."""
import bpy,sys,json
from pathlib import Path
from mathutils import Matrix
import numpy as np

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import ASSETS,OUT
from glb_pose_math import PoseModel

previous=bpy.context.scene
dest=ROOT/'docs/previews/orc_troops/attacks';dest.mkdir(parents=True,exist_ok=True)
conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
results=[]
for key in ('blade_hero','legend_hunter','griffon_rider','shadow_master'):
    row=next(r for r in ASSETS if r['key']==key)
    folder=OUT/row['stem'];model=PoseModel(folder/(row['stem']+'.glb'))
    with bpy.data.libraries.load(str(folder/(row['stem']+'.blend')),link=False) as (source,loaded):loaded.scenes=source.scenes
    scene=loaded.scenes[0];bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    clip=next(name for name in model.clips if name.endswith('_Attack'))
    duration=max(float(times[-1]) for _,_,times,_ in model.clips[clip])
    time=duration*.35;worlds=model.worlds(clip,time)
    rig_world=worlds[model.parent[model.by_name['root']]]
    rig_inverse=np.linalg.inv(rig_world)
    # Use the actual exported animation, avoiding library-append pose caches.
    for name in ['root']+[n for n in model.names if n!='root']:
        rig.pose.bones[name].matrix=conversion@Matrix((rig_inverse@worlds[model.by_name[name]]).tolist())
    bpy.context.view_layer.update()
    scene.render.resolution_x=512;scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.filepath=str(dest/(row['stem']+'.png'))
    bpy.ops.render.render(write_still=True)
    results.append(dict(stem=row['stem'],clip=clip,time=time,source='exported_glb'))
    bpy.context.window.scene=previous;bpy.data.scenes.remove(scene)
(dest/'poses.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result=dict(status='PASS',rendered=len(results),source='actual_exported_animation')
