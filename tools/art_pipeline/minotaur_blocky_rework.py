"""Rework pass on the user-edited Minotaur, in the live Blender via MCP.
1. Backs up the current (user-edited) scene to BACKUP (global, required).
2. Removes the generated rig/actions, keeping the user's geometry.
3. Applies object transforms (user-scaled blocks) into the meshes, so the
   metric UV is rebuilt at real size instead of stretching the texture.
4. Rebuilds the labrys with its bits in the swing plane (edge leads the chop)
   and a shorter head reach so it clears the ground in the bind pose.
5. Recomputes the metric 64 px/m islands for every part. Then run
   minotaur_blocky_paint_save.py to repaint the atlas.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Minotaur_Blocky_V1'; OUT=ROOT/'assets/generated/minotaurs/minotaur_blocky_v1'
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene; root=bpy.data.objects[NAME+'_ROOT']
bpy.data.libraries.write(BACKUP,{scene},path_remap='RELATIVE',fake_user=True,compress=True)
def short(o): return o.name.removeprefix(NAME+'_').split('.')[0]

rig=bpy.data.objects.get(NAME+'_Rig')
if rig:
    for o in [o for o in scene.objects if o.type=='MESH' and o.parent==rig]:
        mw=o.matrix_world.copy()
        for m in [m for m in o.modifiers if m.type=='ARMATURE']: o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root; o.matrix_world=mw
    arm=rig.data; bpy.data.objects.remove(rig); bpy.data.armatures.remove(arm)
    if NAME+'_06_RIG' in bpy.data.collections: bpy.data.collections.remove(bpy.data.collections[NAME+'_06_RIG'])
    for a in [a for a in bpy.data.actions if a.name.startswith('Minotaur_')]: bpy.data.actions.remove(a)
    for m in [m for m in scene.timeline_markers if m.name.startswith('Minotaur_')]: scene.timeline_markers.remove(m)
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
applied=[]
for o in parts:
    o.parent=root; o.matrix_parent_inverse=Matrix.Identity(4)
    if o.matrix_basis!=Matrix.Identity(4):
        o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4); applied.append(short(o))
    assert 'region' in o and 'paint_up' in o, o.name

# Labrys rebuilt around the unchanged fist channel (same grip and haft axis).
for o in [o for o in parts if short(o).startswith('Labrys_')]:
    me=o.data; parts.remove(o); bpy.data.objects.remove(o); bpy.data.meshes.remove(me)
labrys_col=bpy.data.collections[NAME+'_04_LABRYS']
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def mesh(name,verts,faces,region,up):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata([Vector(v) for v in verts],[],faces); me.update()
    obj=bpy.data.objects.new(NAME+'_'+name,me); labrys_col.objects.link(obj); obj.parent=root
    obj['part']=name; obj['region']=region; obj['paint_up']=list(Vector(up).normalized())
    obj['construction']='Flat cuboid or simple extruded prism; editable separate part'
    for p in me.polygons: p.use_smooth=False
    parts.append(obj); return obj
def beam(name,start,end,width,region):
    a,b=Vector(start),Vector(end); axis=(b-a).normalized()
    u=Vector((0,1,0)).cross(axis).normalized(); v=axis.cross(u).normalized()
    verts=[c+u*x*width/2+v*y*width/2 for c in (a,b) for y in (-1,1) for x in (-1,1)]
    return mesh(name,verts,CUBE,region,axis if axis.z>=0 else -axis)
def slab(name,origin,e1,e2,outline,thickness,region,up):
    o=Vector(origin); n=e1.cross(e2).normalized(); k=len(outline)
    verts=[o+e1*s+e2*t+n*off for off in (-thickness/2,thickness/2) for s,t in outline]
    faces=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
    return mesh(name,verts,faces,region,up)
GRIP=Vector((-.865,-.25,.92)); AXIS=Vector((0,-.60,-.80)).normalized()
U=Vector((1,0,0)); V=AXIS.cross(U).normalized()   # V lies in the swing (YZ) plane
beam('Labrys_Haft',GRIP-AXIS*.24,GRIP+AXIS*.90,.085,'wood')
beam('Labrys_Pommel',GRIP-AXIS*.31,GRIP-AXIS*.22,.12,'iron')
beam('Labrys_Cap',GRIP+AXIS*.88,GRIP+AXIS*.95,.11,'iron')
for start,end in [(.17,.23),(.26,.32)]:
    beam('Labrys_Wrap_%d'%round(start*100),GRIP+AXIS*start,GRIP+AXIS*end,.097,'wrap')
HEAD=GRIP+AXIS*.70
beam('Labrys_Socket',HEAD-AXIS*.13,HEAD+AXIS*.13,.135,'iron_dark')
bit=[(.05,-.08),(.14,-.11),(.26,-.19),(.32,-.18),(.32,.18),(.26,.19),(.14,.11),(.05,.08)]
for sign,suffix in [(1,'A'),(-1,'B')]:
    outline=[(sign*s,t) for s,t in bit]
    if sign<0: outline.reverse()
    blade=slab('Labrys_Blade_'+suffix,HEAD,V,AXIS,outline,.05,'blade',-AXIS)
    blade['edge_dir']=list(V*sign)

# Metric islands for every part, identical method to minotaur_blocky_model.py.
DENSITY=64; PAD=2; SIZE=512; islands=[]
for obj in parts:
    me=obj.data; bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    for p in me.polygons:
        normal=p.normal.normalized(); desired=Vector(obj['paint_up'])
        up=desired-normal*desired.dot(normal)
        if up.length<.001: up=Vector((0,1,0))-normal*normal.y
        if up.length<.001: up=Vector((1,0,0))-normal*normal.x
        up.normalize(); right=up.cross(normal).normalized()
        co=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        minimum=Vector((min(c.x for c in co),min(c.y for c in co))); co=[c-minimum for c in co]
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,'right':right,
                        'w':max(1,math.ceil(max(c.x for c in co)*DENSITY)),
                        'h':max(1,math.ceil(max(c.y for c in co)*DENSITY))})
x=y=PAD; row=0
for island in sorted(islands,key=lambda i:(-i['h'],-i['w'])):
    w,h=island['w']+2*PAD,island['h']+2*PAD
    if x+w>SIZE-PAD: x=PAD; y+=row; row=0
    assert y+h<=SIZE-PAD, 'Metric atlas exceeds 512; never shrink islands to fit.'
    island['x']=x+PAD; island['y']=y+PAD; x+=w; row=max(row,h)
bpy.app.driver_namespace['minotaur_blocky']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,
 'size':SIZE,'density':DENSITY,'pad':PAD,'out':str(OUT),'target':Vector((0,-.15,1.30))}
coords=[v.co for o in parts for v in o.data.vertices]
result={'backup':BACKUP,'parts':len(parts),'applied_transforms':applied,'islands':len(islands),
        'min_z':min(c.z for c in coords),'height':max(c.z for c in coords)-min(c.z for c in coords)}
