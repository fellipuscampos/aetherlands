import bpy,math
from mathutils import Vector,Matrix,Euler
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['nature_avatar_blocky_v4']
core=next(o for o in st['parts'] if o['rig_bone']=='core'); c=st['rig'].data.bones['core'].head_local
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in st['parts'] if o!=core]
results=[]
for scale in (1.0,.94,.90):
    for offset in (.06,.12,.18,.24,.30,.36):
        count=0; names=set()
        for i in range(24):
            R=Matrix.Rotation(math.tau*i/24,3,'Z')
            vs=[c+Vector((0,-offset,0))+R@(v.co-c)*scale for v in core.data.vertices]
            tree=BVHTree.FromPolygons(vs,[tuple(p.vertices) for p in core.data.polygons])
            for o,t in targets:
                if tree.overlap(t): count+=1; names.add(o.name.removeprefix(st['name']+'_'))
        results.append(dict(scale=scale,forward_m=offset,collision_samples=count,parts=sorted(names)))
        if count==0: break
result={'sweep':results}
