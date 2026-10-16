import bpy,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
st=bpy.app.driver_namespace['veil_archon_blocky_v2']
core=next(o for o in st['parts'] if o['rig_bone']=='core'); c=st['rig'].data.bones['core'].head_local
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in st['parts'] if o!=core]
rows=[]
for upward in (0,.035,.065):
    for forward in (0,.035,.065,.10):
        shift=Vector((0,-forward,upward)); names=set(); count=0
        for i in range(48):
            R=Matrix.Rotation(math.tau*i/48,3,'Z')
            tree=BVHTree.FromPolygons([c+shift+R@(v.co-c) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
            for o,t in targets:
                if tree.overlap(t): count+=1; names.add(o.name.removeprefix(st['name']+'_'))
        rows.append(dict(upward=upward,forward=forward,hits=count,parts=sorted(names)))
        if count==0: break
result={'clearance':rows}
