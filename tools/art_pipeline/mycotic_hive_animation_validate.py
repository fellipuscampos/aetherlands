"""Validate the baked Mycotic Hive Idle: closed loop, nothing under the ground, rigid
weights, and no two blocks of the orb ever sharing a face plane (no z-fighting)."""
import bpy
from mathutils import Vector
st=bpy.app.driver_namespace['mycotic_hive']; scene=st['scene']; rig=st['rig']; parts=st['parts']
problems=[]; lowest=9.0; frames={}
for o in parts:
    for v in o.data.vertices:
        if len(v.groups)!=1 or abs(v.groups[0].weight-1)>1e-6: problems.append(('weights',o.name)); break
for t in rig.animation_data.nla_tracks: t.mute=True
try:
    for name,data in st['clips'].items():
        rig.animation_data.action=data['action']
        for f in range(data['start'],data['end']+1):
            scene.frame_set(f); dep=bpy.context.evaluated_depsgraph_get(); snap={}
            for o in parts:
                ev=o.evaluated_get(dep); me=ev.to_mesh()
                pts=[ev.matrix_world@v.co for v in me.vertices]; snap[o.name]=pts
                lowest=min(lowest,min(p.z for p in pts)); ev.to_mesh_clear()
            frames[f]=snap
            orb=[n for n in snap if '_Orb_' in n]
            for i,a in enumerate(orb):
                for b in orb[i+1:]:
                    for axis in range(3):
                        A=sorted({round(p[axis],4) for p in snap[a]}); B=sorted({round(p[axis],4) for p in snap[b]})
                        if any(abs(x-y)<.004 for x in A for y in B): problems.append(('coplanar',name,f,a,b,axis))
        loop_error=max((p-q).length for n in frames[data['start']] for p,q in zip(frames[data['start']][n],frames[data['end']][n]))
        if data['loop'] and loop_error>1e-4: problems.append(('loop',name,loop_error))
        data['loop_error']=loop_error
finally:
    rig.animation_data.action=None
    for t in rig.animation_data.nla_tracks: t.mute=False
    scene.frame_set(1)
if lowest<-1e-4: problems.append(('below_ground',lowest))
st['animation_validation']={'problems':problems,'lowest_z':lowest,'loop_error':{n:d['loop_error'] for n,d in st['clips'].items()}}
result=st['animation_validation']|{'problems':problems[:10],'problem_count':len(problems)}
