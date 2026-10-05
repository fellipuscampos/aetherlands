"""Evaluate the baked Minotaur actions: weights, loop seams, ground, hoof targets,
rigid labrys attachment, and surface crossings that do not already exist at rest.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['minotaur_animation']; scene=st['scene']; rig=st['rig']; meshes=st['meshes']; NAME=st['name']
objects={o.name.removeprefix(NAME+'_'):o for o in meshes}
for track in rig.animation_data.nla_tracks: track.mute=True
def evaluated(objs):
    deps=bpy.context.evaluated_depsgraph_get(); data={}
    for o in objs:
        ev=o.evaluated_get(deps); me=ev.to_mesh()
        data[o]=([ev.matrix_world@v.co for v in me.vertices],[list(p.vertices) for p in me.polygons]); ev.to_mesh_clear()
    return data
for obj in meshes:
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-6 for v in obj.data.vertices),obj.name
    assert len([m for m in obj.modifiers if m.type=='ARMATURE' and m.object==rig])==1
labrys=[n for n in objects if n.startswith('Labrys_')]
body_targets=[n for n in ['Head','Muzzle','Jaw','Chest','Abdomen','Shoulder_r','UpperArm_r','Ear_r','HornBase_r',
             'Horn_r0','Horn_r1','Horn_r2','Horn_r3','Thigh_l','Thigh_r','Shin_l','Shin_r','Hoof_l','Hoof_r',
             'Knee_l','Knee_r','LoinFront','Forearm_l','Hand_l','Bracer_l','Belt'] if n in objects]
pairs=[(a,b) for a in labrys for b in body_targets]
# The axe head must also clear its own (bent) arm.
pairs += [(a,b) for a in labrys if a.startswith(('Labrys_Blade','Labrys_Socket','Labrys_Cap'))
          for b in ('Forearm_r','Bracer_r','Hand_r') if b in objects]
for cloth in ('LoinFront','LoinBack','Tail','TailTuft'):
    pairs += [(cloth,t) for t in ('Thigh_l','Thigh_r','Knee_l','Knee_r') if t in objects]
pairs += [(j,h) for j in ('Jaw',) for h in ('Chest',)]
def overlaps(points):
    trees={n:BVHTree.FromPolygons(*points[objects[n]]) for n in set(x for p in pairs for x in p)}
    return {(a,b) for a,b in pairs if trees[a].overlap(trees[b])}
rig.animation_data.action=None; scene.frame_set(1)
for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
at_rest=overlaps(evaluated([objects[n] for n in set(x for p in pairs for x in p)]))
results={}; hits=[]; max_root_drift=0
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; first=last=None; clip_min=1e9; foot_error=0; weapon_error=0
    for f in range(1,data['end']+1):
        scene.frame_set(f); bpy.context.view_layer.update(); ev=evaluated(meshes)
        points=[p for pts,_ in ev.values() for p in pts]
        assert all(math.isfinite(c) for p in points for c in p)
        clip_min=min(clip_min,min(p.z for p in points))
        if f==1: first=points
        last=points
        for side in ('l','r'):
            foot_error=max(foot_error,(rig.pose.bones['foot_'+side].head-Vector(st['targets'][(name,f,side)])).length)
        max_root_drift=max(max_root_drift,rig.pose.bones['root'].location.length)
        hand=rig.pose.bones['hand_r']; weapon=rig.pose.bones['weapon']
        hm=hand.matrix@hand.bone.matrix_local.inverted(); wm=weapon.matrix@weapon.bone.matrix_local.inverted()
        weapon_error=max(weapon_error,max(abs(hm[i][j]-wm[i][j]) for i in range(4) for j in range(4)))
        for a,b in overlaps(ev)-at_rest: hits.append((name,f,a,b))
    seam=max((a-b).length for a,b in zip(first,last))
    results[name]={'frames':data['end'],'loop':data['loop'],'endpoints_max_vertex_delta_m':seam,
                   'minimum_vertex_z_m':clip_min,'foot_target_error_m':foot_error,'weapon_vs_hand_matrix_error':weapon_error}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
problems=[]
for name,r in results.items():
    if r['endpoints_max_vertex_delta_m']>1e-5: problems.append((name,'seam',r['endpoints_max_vertex_delta_m']))
    if r['minimum_vertex_z_m']<-1e-5: problems.append((name,'ground',r['minimum_vertex_z_m']))
    if r['foot_target_error_m']>1e-5: problems.append((name,'foot',r['foot_target_error_m']))
    if r['weapon_vs_hand_matrix_error']>1e-5: problems.append((name,'weapon',r['weapon_vs_hand_matrix_error']))
st['validation']={'clips':results,'all_vertices_normalized_weights':True,'root_drift_m':max_root_drift,
                  'rest_pose_contacts_excluded':sorted(map(list,at_rest)),'new_surface_crossings':len(hits),'problems':problems}
st['surface_contacts']=hits
(Path(st['out'])/'minotaur_blocky_v1_animation_validation.json').write_text(json.dumps(st['validation'],indent=2),encoding='utf-8')
summary={}
for clip,f,a,b in hits: summary.setdefault((clip,a,b),[]).append(f)
result={'problems':problems,'clips':results,'crossings':{f'{c}:{a}x{b}':[min(v),max(v),len(v)] for (c,a,b),v in summary.items()},
        'rest_contacts':sorted(map(list,at_rest))}
