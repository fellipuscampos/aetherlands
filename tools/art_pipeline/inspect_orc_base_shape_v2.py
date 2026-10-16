import bpy,json,numpy as np
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
folder=ROOT/'assets/generated/orcs/orc_squire_v1'
report=json.loads((folder/'orc_squire_v1_report.json').read_text(encoding='utf-8'))
loaded=[]
for path in (ROOT/'art_source/orc_squire/approved_before_roster/orc_squire_v1.blend',folder/'orc_squire_v1.blend'):
    with bpy.data.libraries.load(str(path),link=False) as (source,destination):destination.scenes=source.scenes
    loaded.append(destination.scenes[0])
by=[{o.get('part'):o for o in scene.objects if o.type=='MESH'} for scene in loaded]
result={}
for name in report['geometry']['body_parts']:
    old=np.array([tuple(v.co) for v in by[0][name].data.vertices]);new=np.array([tuple(v.co) for v in by[1][name].data.vertices])
    if name in ('Forearm_r','Hand_r'):old=(np.c_[old,np.ones(len(old))]@np.array(report['relaxed_right_arm']['transform']).T)[:,:3]
    if name=='Head':old[:,2]+=report['rig']['retarget']['head_rest_raise']
    result[name]={'maximum_error':float(np.abs(old-new).max()),'old_center':old.mean(axis=0).tolist(),'new_center':new.mean(axis=0).tolist()}
for scene in loaded:bpy.data.scenes.remove(scene)
