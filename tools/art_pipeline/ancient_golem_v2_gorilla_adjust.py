"""Refine the gorilla stance of the live Ancient Golem V2 (after ancient_golem_v2_gorilla_pose.py):
legs moved back under the hips so the arms clearly carry the front, fists planted further
ahead, pauldrons levelled back towards horizontal. Then the metric islands are rebuilt.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix

NAME='Ancient_Golem_V2'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
assert scene.get('gorilla_pose') and not scene.get('gorilla_adjust'), 'Run once, after the gorilla pose.'
root=bpy.data.objects[NAME+'_ROOT']; mat=bpy.data.materials[NAME+'_PixelArt']
def obj(n): return bpy.data.objects.get(NAME+'_'+n)
def apply(o,M):
    for v in o.data.vertices: v.co=M@v.co
    o['paint_up']=list((M.to_3x3()@Vector(o['paint_up'])).normalized()); o.data.update()
def center(o): return sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
for n in ('Thigh_L','Thigh_R','Shin_L','Shin_R','Foot_L','Foot_R'):
    if obj(n): apply(obj(n),Matrix.Translation((0,.36,0)))
for n in ('Pauldron_L','Pauldron_R'):
    o=obj(n); c=center(o); apply(o,Matrix.Translation(c)@Matrix.Rotation(math.radians(-22),4,'X')@Matrix.Translation(-c))
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def taper(a,b,w,h):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); a=a-axis*.03; b=b+axis*.03
    side=Vector((-axis.y,axis.x,0)); side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return [c+side*x*w/2+upv*y*h/2 for c in (a,b) for y in (-1,1) for x in (-1,1)],axis
def replace(name,verts,up):
    o=obj(name); me=o.data
    bm=bmesh.new(); [bm.verts.new(v) for v in verts]; bm.verts.ensure_lookup_table()
    for f in CUBE: bm.faces.new([bm.verts[i] for i in f])
    bm.to_mesh(me); bm.free(); me.update(); o['paint_up']=list(Vector(up).normalized())
    for p in me.polygons: p.use_smooth=False
for s,tag in ((1,'L'),(-1,'R')):
    shoulder=Vector((s*.92,-.46,1.78))
    elbow=Vector((s*1.02,-1.06,1.10)); wrist=Vector((s*1.04,-1.30,.52))
    v,a=taper(shoulder,elbow,.42,.46); replace('UpperArm_'+tag,v,a)
    v,a=taper(elbow,wrist,.62,.66); replace('Gauntlet_'+tag,v,a)
    c=Vector((s*1.04,-1.40,.26)); replace('Fist_'+tag,[c+Vector((x*.35,y*.35,z*.26)) for z in (-1,1) for y in (-1,1) for x in (-1,1)],(0,0,1))
scene['gorilla_adjust']=True

parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
DENSITY=64; PAD=2; islands=[]
for o in parts:
    assert not o.modifiers and o.matrix_basis.is_identity, o.name
    me=o.data; bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
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
OUT=Path(r'C:\Users\felipe campos\Documents\jogo\assets\generated\ancient_golems\ancient_golem_v2')
bpy.app.driver_namespace['ancient_golem']={'name':NAME,'scene':scene,'parts':parts,'islands':islands,'size':SIZE,
 'density':DENSITY,'pad':PAD,'out':str(OUT),'target':Vector((0,-.40,1.05))}
coords=[v.co for o in parts for v in o.data.vertices]
result={'parts':len(parts),'min_z':min(c.z for c in coords),'length':max(c.y for c in coords)-min(c.y for c in coords),
        'below_ground':[o['part'] for o in parts if min(v.co.z for v in o.data.vertices)<-1e-4]}
