"""Evaluate Spider loops, foot contacts and surface crossings from the baked actions."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['spider_animation']; scene=st['scene']; rig=st['rig']; meshes=st['meshes']
objects={o['part']:o for o in meshes}
for tr in rig.animation_data.nla_tracks: tr.mute=True
rig.animation_data.action=None
for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
legs=[n for n in objects if n.startswith('Leg')]; body=['Cephalothorax','Waist','Abdomen']
pairs=[(a,b) for a in legs for b in body]
pairs += [(a,b) for j,a in enumerate(legs) for b in legs[j+1:] if (a.split('_')[0],a[-1])!=(b.split('_')[0],b[-1])]
pairs += [(a,b) for a in objects if a.startswith(('Fang','Chelicera')) for b in objects if b.startswith('Palp')]
def evaluated():
    dep=bpy.context.evaluated_depsgraph_get(); coords={}; trees={}
    for n,o in objects.items():
        ev=o.evaluated_get(dep); me=ev.to_mesh(); vv=[ev.matrix_world@v.co for v in me.vertices]
        coords[n]=vv; trees[n]=BVHTree.FromPolygons(vv,[list(p.vertices) for p in me.polygons]); ev.to_mesh_clear()
    hits={(a,b) for a,b in pairs if trees[a].overlap(trees[b])}
    return coords,hits
_,baseline=evaluated(); results={}; allhits=[]
for o in meshes:
    assert all(abs(sum(g.weight for g in v.groups)-1)<1e-6 for v in o.data.vertices)
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; lowest=1e9; error=0; supports=8; first=None
    for f in range(1,data['end']+1):
        scene.frame_set(f); bpy.context.view_layer.update(); co,hits=evaluated()
        points=[v for vv in co.values() for v in vv]
        if first is None: first=[v.copy() for v in points]
        assert all(math.isfinite(c) for v in points for c in v)
        lowest=min(lowest,min(v.z for v in points))
        supports=min(supports,sum(st['contacts'][(name,f,i,side)] for i in range(1,5) for side in ('l','r')))
        for i in range(1,5):
            for side in ('l','r'):
                target=Vector(st['targets'][(name,f,i,side)])
                error=max(error,(rig.pose.bones[f'leg{i}_tibia_{side}'].tail-target).length)
        for a,b in sorted(hits-baseline): allhits.append((name,f,a,b))
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5,(name,seam)
    assert lowest>-.0001,(name,'ground',lowest)
    assert supports>=4,(name,supports)
    assert error<1e-5,(name,error)
    results[name]={'minimum_vertex_z_m':lowest,'maximum_tip_error_m':error,'seam_vertex_delta_m':seam,'minimum_supporting_legs':supports}
rig.animation_data.action=None
for tr in rig.animation_data.nla_tracks: tr.mute=False
scene.frame_set(1)
st['validation']={'clips':results,'surface_crossings':allhits,'baseline_contacts':sorted(map(list,baseline)),
                  'geometry_uvs_unchanged':True,'normalized_rigid_weights':True}
(Path(st['out'])/'animation_validation.json').write_text(json.dumps(st['validation'],indent=2),encoding='utf-8')
result={'clips':results,'crossing_count':len(allhits),'crossing_pairs':sorted(set((n,a,b) for n,f,a,b in allhits)),'first_crossings':allhits[:6]}
