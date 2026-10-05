"""Gorilla knuckle-walking pose for the live Ancient Golem V2 (user request), keeping all
manual cuts of the open scene:
- the upper body (torso, pauldrons, head) pitches forward around the hips, as if its
  weight pulls it forward;
- the head is turned back up so it looks ahead, low between the shoulders;
- both arms are rebuilt with the same block sizes, reaching forward from the shoulders
  so the stone fists rest on the ground in front of the body;
- every former wood/root part (torso, pelvis, upper arms) becomes dark core stone, so the
  golem is entirely stone.
The transforms are baked into the vertices (identity objects), then the metric islands
(64 px/m) are rebuilt and the atlas repacked for ancient_golem_v2_paint_save.py.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

NAME='Ancient_Golem_V2'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
root=bpy.data.objects[NAME+'_ROOT']; mat=bpy.data.materials[NAME+'_PixelArt']
if scene.get('gorilla_pose'): raise RuntimeError('Gorilla pose already applied.')
def obj(n): return bpy.data.objects.get(NAME+'_'+n)
def about(pivot,deg):
    P=Vector(pivot); return Matrix.Translation(P)@Matrix.Rotation(math.radians(deg),4,'X')@Matrix.Translation(-P)
def apply(o,M):
    for v in o.data.vertices: v.co=M@v.co
    o['paint_up']=list((M.to_3x3()@Vector(o['paint_up'])).normalized()); o.data.update()
HIP=Vector((0,.12,1.10)); PITCH=28
body=about(HIP,PITCH)
upper=[n for n in ('Torso','Pauldron_L','Pauldron_R','PauldronTop_L','PauldronTop_R','BackPlate','ChestPlate') if obj(n)]
head=[n for n in ('Head','Brow','Eye_L','Eye_R','Jaw','Ferns') if obj(n)]
for n in upper+head: apply(obj(n),body)
neck=body@Vector((0,-.50,1.72)); look=about(neck,-PITCH-6)
for n in head: apply(obj(n),look)

# Arms: same block sizes, shoulder -> elbow -> fist planted ahead on the ground.
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def taper(a,b,w,h):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized(); a=a-axis*.03; b=b+axis*.03
    side=Vector((-axis.y,axis.x,0))
    if side.length<1e-6: side=Vector((1,0,0))
    side.normalize(); upv=side.cross(axis).normalized()
    if upv.z<0: upv=-upv
    return [c+side*x*w/2+upv*y*h/2 for c in (a,b) for y in (-1,1) for x in (-1,1)],axis
def make(name,verts,region,bone,collection,up):
    old=obj(name)
    if old: me=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.meshes.remove(me)
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata(verts,[],CUBE); me.update()
    o=bpy.data.objects.new(NAME+'_'+name,me); collection.objects.link(o); o.parent=root
    o['part']=name; o['region']=region; o['rig_bone']=bone; o['paint_up']=list(Vector(up).normalized())
    o['construction']='Cuboid; editable separate part (gorilla pose)'
    for p in me.polygons: p.use_smooth=False
    me.materials.append(mat)
arms=bpy.data.collections[NAME+'_03_ARMS']
shoulder_src=Vector((.92,-.12,1.96))
for s,tag in ((1,'L'),(-1,'R')):
    side=tag.lower()
    shoulder=body@Vector((s*shoulder_src.x,shoulder_src.y,shoulder_src.z))
    elbow=Vector((s*1.02,-.92,1.12)); wrist=Vector((s*1.04,-1.12,.52))
    v,a=taper(shoulder,elbow,.42,.46); make('UpperArm_'+tag,v,'stone_dark','upper_arm_'+side,arms,a)
    v,a=taper(elbow,wrist,.62,.66); make('Gauntlet_'+tag,v,'stone','forearm_'+side,arms,a)
    c=Vector((s*1.04,-1.20,.26)); hx,hy,hz=.35,.35,.26
    make('Fist_'+tag,[c+Vector((x*hx,y*hy,z*hz)) for z in (-1,1) for y in (-1,1) for x in (-1,1)],'stone','fist_'+side,arms,(0,0,1))
for n in ('Torso','Pelvis','UpperArm_L','UpperArm_R'):
    if obj(n): obj(n)['region']='stone_dark'
scene['gorilla_pose']=True

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
 'density':DENSITY,'pad':PAD,'out':str(OUT),'target':Vector((0,-.45,1.05))}
coords=[v.co for o in parts for v in o.data.vertices]
low={o['part']:round(min(v.co.z for v in o.data.vertices),3) for o in parts}
result={'parts':len(parts),'atlas':SIZE,'min_z':min(c.z for c in coords),'height':max(c.z for c in coords),
        'below_ground':[k for k,v in low.items() if v<-1e-4],'length':max(c.y for c in coords)-min(c.y for c in coords),
        'head_center':list(sum((v.co for v in obj('Head').data.vertices),Vector())/8)}
