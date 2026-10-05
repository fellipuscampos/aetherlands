"""Trim the hidden bottom of both shins of the live Ancient Golem V2 (it sat inside the
foot block, z .10-.20, and dipped under the ground when the shin tilts in Walk/Attack):
the bottom face goes up to z .185 (still 1.5 cm inside the foot). Then the metric islands
(64 px/m) are rebuilt for every current part and the atlas repacked; run
ancient_golem_v2_paint_save.py next. Works on the rigged scene (armature modifiers kept).
"""
import bpy
import bmesh
import math
from mathutils import Vector
st=bpy.app.driver_namespace['ancient_golem']; NAME=st['name']; scene=bpy.data.scenes[NAME]
for t in ('L','R'):
    me=bpy.data.objects[NAME+'_Shin_'+t].data; moved=0
    for v in me.vertices:
        if v.co.z<.184: v.co.z=.185; moved+=1
    assert moved in (0,4); me.update()
parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data
    for p in me.polygons:
        normal=p.normal.normalized(); desired=Vector(o['paint_up'])
        up=desired-normal*desired.dot(normal)
        if up.length<.001: up=Vector((0,1,0))-normal*normal.y
        if up.length<.001: up=Vector((1,0,0))-normal*normal.x
        up.normalize(); right=up.cross(normal).normalized()
        co=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        minimum=Vector((min(c.x for c in co),min(c.y for c in co))); co=[c-minimum for c in co]
        islands.append({'obj':o,'polygon':p.index,'coords':co,'normal':normal,'right':right,'up':up,
                        'minimum':minimum,'offset':p.center.dot(normal),'center':p.center.copy(),
                        'w':max(1,math.ceil(max(c.x for c in co)*DENSITY)),
                        'h':max(1,math.ceil(max(c.y for c in co)*DENSITY))})
def pack(size):
    x=y=PAD; row=0
    for island in sorted(islands,key=lambda i:(-i['h'],-i['w'])):
        w,h=island['w']+2*PAD,island['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        island['x']=x+PAD; island['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (256,512,1024,2048) if pack(s))
st.update({'parts':parts,'islands':islands,'size':SIZE,'scene':scene})
result={'parts':len(parts),'islands':len(islands),'atlas':SIZE}
