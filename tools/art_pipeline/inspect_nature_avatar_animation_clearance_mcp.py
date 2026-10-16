import bpy,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['nature_avatar_blocky_v5_animated']; rig=st['rig']; scene=st['scene']; parts=st['parts']
bpy.context.window.scene=scene
for track in rig.animation_data.nla_tracks: track.mute=True
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
core=next(o for o in parts if o['rig_bone']=='core')
def bounds(points): return [Vector(tuple(fn(v[i] for v in points) for i in range(3))) for fn in (min,max)]
def intersects(a,b): return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
results={}
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; hits={extra:[] for extra in (0,.04,.08,.12,.16,.20)}
    for frame in range(1,data['end_frame']+1,4):
        scene.frame_set(frame); matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        posed={o.name:[matrices[o['rig_bone']]@v.co for v in o.data.vertices] for o in parts}
        boxes={o.name:bounds(posed[o.name]) for o in parts if o!=core}; trees={}
        for extra in hits:
            shift=matrices['chest'].to_3x3()@Vector((0,-extra,0)); points=[p+shift for p in posed[core.name]]
            box=bounds(points); tree=None
            for o in parts:
                if o==core or not intersects(box,boxes[o.name]): continue
                if tree is None: tree=BVHTree.FromPolygons(points,[tuple(p.vertices) for p in core.data.polygons])
                if o.name not in trees: trees[o.name]=BVHTree.FromPolygons(posed[o.name],[tuple(p.vertices) for p in o.data.polygons])
                if tree.overlap(trees[o.name]): hits[extra].append([frame,o.name.removeprefix(st['name']+'_')])
    results[name]={str(extra):dict(count=len(v),examples=v[:3]) for extra,v in hits.items()}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
result={'clearance_sweep':results}
