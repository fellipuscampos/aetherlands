"""Make both arms of the live Ancient Golem V2 identical (user request), keeping every
manual edit of the open scene: the bare root left arm is replaced by an exact mirror
(X -> -X) of the stone right arm (root upper arm, stone gauntlet, stone fist). Then the
metric islands (64 px/m) are rebuilt from the CURRENT parts and the atlas is repacked,
refreshing the MCP state for ancient_golem_v2_paint_save.py. No other part is touched.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

NAME='Ancient_Golem_V2'; scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
root=bpy.data.objects[NAME+'_ROOT']
mat=bpy.data.materials[NAME+'_PixelArt']
def part(n): return bpy.data.objects.get(NAME+'_'+n)
for n in ('UpperArm_L','Forearm_L','RootClaws_L','RootStrands_L','Gauntlet_L','Fist_L'):
    o=part(n)
    if o: me=o.data; bpy.data.objects.remove(o,do_unlink=True); bpy.data.meshes.remove(me)
mirrored=[]
for src,dst,bone in (('UpperArm_R','UpperArm_L','upper_arm_l'),('Gauntlet_R','Gauntlet_L','forearm_l'),('Fist_R','Fist_L','fist_l')):
    s=part(src); assert s is not None and s.matrix_basis.is_identity, src
    me=s.data.copy(); me.name=NAME+'_'+dst+'_Mesh'
    for v in me.vertices: v.co.x=-v.co.x
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.reverse_faces(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(NAME+'_'+dst,me)
    for c in s.users_collection: c.objects.link(o)
    for k in ('region','construction'): o[k]=s[k]
    up=Vector(s['paint_up']); o['paint_up']=[-up.x,up.y,up.z]; o['part']=dst; o['rig_bone']=bone
    o.parent=root; me.materials.clear(); me.materials.append(mat); mirrored.append(dst)

parts=sorted([o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')],key=lambda o:o.name)
DENSITY=64; PAD=2; islands=[]
for obj in parts:
    assert not obj.modifiers and obj.matrix_basis.is_identity, obj.name
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
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,'right':right,'up':up,
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
 'density':DENSITY,'pad':PAD,'out':str(OUT),'target':Vector((0,-.25,1.30))}
coords=[v.co for o in parts for v in o.data.vertices]
result={'mirrored':mirrored,'parts':len(parts),'islands':len(islands),'atlas':SIZE,'min_z':min(c.z for c in coords),
        'width':max(c.x for c in coords)-min(c.x for c in coords),'names':sorted(o['part'] for o in parts)}
