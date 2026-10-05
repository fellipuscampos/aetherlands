"""Validate the baked Ancient Golem V2 clips: loops close, nothing goes under the ground,
weights are rigid, planted fists/feet really touch the ground (Idle: always; Walk: at
least one fist and one foot on the ground every frame; Attack: both fists on the ground
at the impact frame)."""
import bpy
st=bpy.app.driver_namespace['ancient_golem']; scene=st['scene']; rig=st['rig']; parts=st['parts']
problems=[]; lowest=9.0; contacts={}
for o in parts:
    for v in o.data.vertices:
        if len(v.groups)!=1 or abs(v.groups[0].weight-1)>1e-6: problems.append(('weights',o.name)); break
for t in rig.animation_data.nla_tracks: t.mute=True
loops={}
try:
    for name,data in st['clips'].items():
        rig.animation_data.action=data['action']; snaps={}; touch=[]
        for f in range(data['start'],data['end']+1):
            scene.frame_set(f); dep=bpy.context.evaluated_depsgraph_get(); snap={}; low={}
            for o in parts:
                ev=o.evaluated_get(dep); me=ev.to_mesh(); pts=[ev.matrix_world@v.co for v in me.vertices]; ev.to_mesh_clear()
                snap[o.name]=pts; low[o['part']]=min(p.z for p in pts); lowest=min(lowest,low[o['part']])
            snaps[f]=snap
            fists=sum(low[k]<.01 for k in ('Fist_L','Fist_R')); feet=sum(low[k]<.01 for k in ('Foot_L','Foot_R'))
            touch.append((f,fists,feet))
            if name=='Golem_Idle' and (fists<2 or feet<2): problems.append(('idle_contact',f,fists,feet))
            if name=='Golem_Walk' and (fists<1 or feet<1): problems.append(('walk_contact',f,fists,feet))
            if name=='Golem_Attack' and f==data.get('impact_frame') and fists<2: problems.append(('impact_contact',f,fists))
        err=max((p-q).length for n in snaps[data['start']] for p,q in zip(snaps[data['start']][n],snaps[data['end']][n]))
        loops[name]=err
        if data['loop'] and err>1e-4: problems.append(('loop',name,err))
        contacts[name]={'frames_with_both_fists':sum(1 for _,a,_ in touch if a==2),'frames_with_both_feet':sum(1 for _,_,b in touch if b==2),'frames':len(touch)}
finally:
    rig.animation_data.action=None
    for t in rig.animation_data.nla_tracks: t.mute=False
    scene.frame_set(1)
if lowest<-.005: problems.append(('below_ground',lowest))
st['animation_validation']={'problems':problems,'lowest_z':lowest,'loop_error':loops,'contacts':contacts}
result={'problems':problems[:12],'problem_count':len(problems),'lowest_z':lowest,'loop_error':loops,'contacts':contacts}
