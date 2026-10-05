"""Evaluate the baked actions: feet, seam closure, rigid attachments and weights."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['goblin_animation']; scene=st['scene']; rig=st['rig']; meshes=st['meshes']
for track in rig.animation_data.nla_tracks: track.mute=True
errors=[]; results={}; min_z=1e9; max_foot_error=0; max_root_drift=0
def coordinates():
    deps=bpy.context.evaluated_depsgraph_get(); result=[]
    for o in meshes:
        ev=o.evaluated_get(deps); me=ev.to_mesh()
        result.extend(ev.matrix_world@v.co for v in me.vertices); ev.to_mesh_clear()
    return result
for obj in meshes:
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-6 for v in obj.data.vertices),obj.name
    assert len([m for m in obj.modifiers if m.type=='ARMATURE' and m.object==rig])==1
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; first=None; last=None; clip_min=1e9; foot_error=0
    for f in range(1,data['end']+1):
        scene.frame_set(f); bpy.context.view_layer.update(); points=coordinates()
        assert all(math.isfinite(c) for p in points for c in p)
        clip_min=min(clip_min,min(p.z for p in points))
        if f==1: first=points
        last=points
        for side in ('l','r'):
            distance=(rig.pose.bones['foot_'+side].head-Vector(st['targets'][(name,f,side)])).length
            foot_error=max(foot_error,distance)
        max_root_drift=max(max_root_drift,rig.pose.bones['root'].location.length)
        # Both fist and all three dagger parts use the same rigid transformation.
        hand=rig.pose.bones['hand_r']; weapon=rig.pose.bones['weapon']
        hm=hand.matrix@hand.bone.matrix_local.inverted(); wm=weapon.matrix@weapon.bone.matrix_local.inverted()
        assert max(abs(hm[i][j]-wm[i][j]) for i in range(4) for j in range(4))<1e-5
    seam=max((a-b).length for a,b in zip(first,last))
    assert seam<1e-5,(name,seam)
    assert clip_min>-.00001,(name,'ground penetration',clip_min)
    assert foot_error<1e-5,(name,foot_error)
    results[name]={'endpoints_max_vertex_delta_m':seam,'minimum_vertex_z_m':clip_min,'foot_target_error_m':foot_error,
                   'frames':data['end'],'loop':data['loop']}
    min_z=min(min_z,clip_min); max_foot_error=max(max_foot_error,foot_error)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
st['validation']={'clips':results,'all_vertices_normalized_weights':True,'dagger_follows_fist':True,
                  'minimum_vertex_z_m':min_z,'max_foot_target_error_m':max_foot_error,'root_drift_m':max_root_drift}
(Path(st['out'])/'goblin_raider_v3_animation_validation.json').write_text(json.dumps(st['validation'],indent=2),encoding='utf-8')
result=st['validation']
