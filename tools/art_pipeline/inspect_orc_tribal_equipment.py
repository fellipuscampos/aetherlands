"""Read the approved grip frames from editable models through Blender MCP."""
import bpy,json,sys,numpy as np
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import OUT,WORK,ASSETS
previous=bpy.context.scene
results={}
for key in ('squire','warrior','swordsman','weapon_master','blade_hero','archer','cavalier','griffon_rider','shadow_master'):
    row=next(r for r in ASSETS if r['key']==key)
    with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,loaded):loaded.scenes=source.scenes
    scene=loaded.scenes[0]
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    data={}
    for obj in scene.objects:
        if obj.type!='MESH' or obj.get('region') in (None,'studio'):continue
        name=obj['part'];bone=obj.get('rig_bone');v=np.array([tuple(p.co) for p in obj.data.vertices])
        m=np.array(rig.data.bones[bone].matrix_local) if bone else np.eye(4)
        local=(np.c_[v,np.ones(len(v))]@np.linalg.inv(m).T)[:,:3]
        data[name]=dict(region=obj['region'],bone=bone,vertices=v.tolist(),bone_local_bounds=[local.min(axis=0).tolist(),local.max(axis=0).tolist()])
    results[row['stem']]=data
    bpy.data.scenes.remove(scene)
dest=WORK/'tribal_equipment';dest.mkdir(parents=True,exist_ok=True)
(dest/'inspection.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
result=dict(status='PASS',models=len(results),report='art_source/orc_troops/tribal_equipment/inspection.json')
