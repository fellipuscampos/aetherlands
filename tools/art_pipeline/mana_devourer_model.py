"""Mana Devourer: native block/prism modeling, metric pixel atlas and simple rig.
Run inside the connected Blender through blender_mcp_client.py. No scene replacement.
"""
import bpy
import bmesh
import math
import random
import json
from pathlib import Path
from mathutils import Vector, Euler, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Mana_Devourer_V1'; OUT=ROOT/'assets/generated/mana_devourers/mana_devourer_v1'
OUT.mkdir(parents=True,exist_ok=True)
assert NAME not in bpy.data.scenes,'Existing scene: preserve edits.'
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
collections={}
for label in ('01_CORE','02_ORBITALS','03_RIG','04_STUDIO'):
    c=bpy.data.collections.new(NAME+'_'+label); scene.collection.children.link(c); collections[label]=c
root=bpy.data.objects.new(NAME+'_ROOT',None); scene.collection.objects.link(root); root.empty_display_size=.22
parts=[]; bonecenters={}
def mesh(name,vertices,faces,region,bone,collection):
    me=bpy.data.meshes.new(NAME+'_'+name+'_Mesh'); me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(NAME+'_'+name,me); collections[collection].objects.link(o)
    o['part']=name; o['region']=region; o['rig_bone']=bone; o.parent=root
    for p in me.polygons: p.use_smooth=False
    parts.append(o); return o
def stone(name,outline,center,depth,rot,region,bone,collection):
    # Three polygonal sections form one solid, faceted prism: no interior blocks.
    R=Euler(rot,'XYZ').to_matrix(); c=Vector(center); n=len(outline)
    verts=[c+R@Vector((x*scale,y,z*scale)) for y,scale in [(-depth*.5,.86),(0,1),(depth*.5,.78)] for x,z in outline]
    faces=[tuple(reversed(range(n))),tuple(2*n+i for i in range(n))]
    for j in range(2): faces.extend([(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n)])
    o=mesh(name,verts,faces,region,bone,collection); o['local_rotation']=list(rot); bonecenters[bone]=c
    return o

# An irregular, broad crown contracts into a long torn lower point. The front is
# one large planar face for the vertical feeding rift, not a pair of cartoon eyes.
outline=[(-.48,-.32),(-.60,.05),(-.56,.45),(-.34,.69),(-.09,.69),
         (.11,.79),(.42,.55),(.55,.24),(.49,-.18),(.25,-.46),(.06,-.72),(-.17,-.47)]
stone('Obsidian_Core',outline,(0,0,1.48),.91,(0,0,0),'core','core','01_CORE')
shard=[(-.16,-.22),(-.23,.22),(-.10,.43),(.14,.30),(.21,-.05),(.055,-.42)]
for index,(center,scale,rot) in enumerate([
    ((-.94,-.06,2.08),.85,(.14,-.34,-.12)),
    ((-1.02,-.12,.94),.73,(-.13,.39,.16)),
    ((1.00,.12,1.74),1.02,(.05,.25,-.18)),
    ((.65,-.25,.62),.65,(-.16,-.39,.24))],1):
    stone(f'Orbit_Shard_{index:02}',[(x*scale,z*scale) for x,z in shard],center,.34*scale,rot,
          'shard',f'orbit_{index:02}','02_ORBITALS')

def arc(name,angles,bone):
    # A broken octagonal orbital band, tilted backward. Four corners per cross-section.
    verts=[]
    for angle in angles:
        a=math.radians(angle)
        for r,d in [(1.10,-.07),(1.24,-.07),(1.24,.07),(1.10,.07)]:
            x=r*math.cos(a); z=1.48+r*math.sin(a)
            verts.append((x,.43+.17*x+d,z))
    faces=[(3,2,1,0)]
    for j in range(len(angles)-1): faces.extend([(4*j+i,4*j+(i+1)%4,4*(j+1)+(i+1)%4,4*(j+1)+i) for i in range(4)])
    faces.append(tuple(4*(len(angles)-1)+i for i in range(4)))
    mesh(name,verts,faces,'arc',bone,'02_ORBITALS'); bonecenters[bone]=Vector((0,.43,1.48))
arc('Broken_Arc_Upper',[28,52,78,104],'arc_upper')
arc('Broken_Arc_Lower',[192,218,244,267],'arc_lower')

# Per-face orthonormal UVs: preserve metric proportions, 64 texels per meter.
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data; me.update(); uv=me.uv_layers.new(name='Metric_Pixel_UV')
    R=Euler(o.get('local_rotation',(0,0,0)),'XYZ').to_matrix()
    for p in me.polygons:
        n=p.normal.normalized(); up=R@Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=Vector((0,1,0))-n*n.y
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords))); coords=[v-lo for v in coords]
        islands.append({'obj':o,'polygon':p.index,'normal':n,'local_normal':R.transposed()@n,'coords':coords,
                        'w':max(1,math.ceil(max(v.x for v in coords)*DENSITY)),
                        'h':max(1,math.ceil(max(v.y for v in coords)*DENSITY))})
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it['x']=x+PAD; it['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (256,512,1024) if pack(s))

# Pixel clusters and discrete light bands follow each face's actual dimensions.
STONE=[(23,26,39),(28,31,46),(34,36,53),(41,40,59),(48,47,68)]
RIM=(76,83,108); DARK=(9,11,21); CYAN=(67,221,235); HOT=(181,255,246)
TEAL=(28,117,151); PURPLE=(113,66,188)
def paint(it,index):
    w,h=it['w'],it['h']; region=it['obj']['region']; n=it['local_normal']; rng=random.Random(9024+index)
    cluster={}; tile=[]; emission=[[ (0,0,0) for x in range(w)] for y in range(h)]
    for y in range(h):
        row=[]
        for x in range(w):
            key=(x//3,y//3)
            if key not in cluster: cluster[key]=rng.choices(STONE,[2,4,4,2,1])[0]
            c=cluster[key]
            if y<2: c=RIM if y==0 else STONE[4]
            if y>h-3: c=STONE[0]
            row.append(c)
        tile.append(row)
    def put(x,y,c,emit=False):
        if 0<=x<w and 0<=y<h:
            tile[y][x]=c
            emission[y][x]=c if emit else (0,0,0)
    def rect(x,y,ww,hh,c,emit=False):
        for yy in range(y,y+hh):
            for xx in range(x,x+ww): put(xx,yy,c,emit)
    # Sparse straight mineral veins, not high-frequency random noise.
    for j in range(max(1,w*h//260)):
        x=rng.randrange(w); y=rng.randrange(h)
        rect(x,y,min(5,w-x),1,STONE[0]); rect(x,y+1,min(3,w-x),1,STONE[3])
    front=n.y<-.82; back=n.y>.82
    if region=='core' and front:
        # A jagged vertical aperture: dark negative center, hot broken lip and cyan halo.
        for y in range(max(3,int(h*.15)),int(h*.88)):
            t=y/h; cx=w//2+(2 if .25<t<.45 else -2 if .60<t<.76 else 0)
            half=2 if t<.27 or t>.78 else 5
            rect(cx-half-3,y,2*half+7,1,TEAL)
            rect(cx-half-1,y,2*half+3,1,CYAN,True)
            rect(cx-half+1,y,max(1,2*half-1),1,DARK)
            if (y//5)%3!=1: put(cx-half,y,HOT,True)
        # Block-stepped branches converge on the feeding fissure, including its upper crown.
        for sign,start in [(-1,.39),(1,.57),(-1,.73)]:
            for step in range(max(3,w//4)):
                x=w//2+sign*(4+step); y=int(h*start)-step//3
                put(x,y,TEAL); put(x,y+1,CYAN,True)
                if step%5==0: put(x,y+2,PURPLE,True)
    elif region=='core':
        # Smaller fissures remain readable from gameplay's high camera and from behind.
        if n.z>.2 or abs(n.x)>.5 or back:
            for y in range(max(2,h//6),max(3,h*4//5)):
                x=w//2+((y//5)%3-1)*2
                put(x,y,TEAL); put(x+1,y,CYAN,True)
                if y%7<3: put(x+2,y,PURPLE,True)
    elif region=='shard':
        if front or n.z>.4:
            for y in range(max(2,h//5),h*4//5):
                x=w//2+(1 if (y//6)%2 else -1)
                put(x,y,CYAN,True); put(x+1,y,TEAL)
            rect(max(1,w//2-2),max(2,h//3),min(4,w-2),2,HOT,True)
    elif region=='arc':
        # An interrupted runic channel; the mass stays dark and the band remains broken.
        if abs(n.y)>.5:
            for y in range(2,max(3,h-2)):
                if (y//4)%3!=2: put(w//2,y,PURPLE,True)
        if max(w,h)<12: rect(w//3,h//3,max(1,w//3),max(1,h//3),CYAN,True)
    return tile,emission

albedo=[c/255 for c in STONE[0]]+[1]; black=[0,0,0,1]
pixels=albedo*(SIZE*SIZE); energy=black*(SIZE*SIZE)
for index,it in enumerate(islands):
    t,e=paint(it,index); w,h=it['w'],it['h']; ox,oy=it['x'],it['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            xx=max(0,min(w-1,x)); yy=h-1-max(0,min(h-1,y)); k=((oy+y)*SIZE+ox+x)*4
            pixels[k:k+4]=[v/255 for v in t[yy][xx]]+[1]; energy[k:k+4]=[v/255 for v in e[yy][xx]]+[1]
    uv=it['obj'].data.uv_layers.active.data
    for li,co in zip(it['obj'].data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((ox+co.x*DENSITY)/SIZE,(oy+co.y*DENSITY)/SIZE)
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True); im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'mana_devourer_v1_{suffix}.png'); im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Obsidian_PixelArt'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.78
bsdf.inputs['Metallic'].default_value=0; bsdf.inputs['Specular IOR Level'].default_value=.22
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'; node.extension='EXTEND'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=1.6
for o in parts: o.data.materials.append(mat)

# Root + body controller + independent orbit controls, ready for future keys.
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collections['03_RIG'].objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.3); b.use_deform=False
for name,center in bonecenters.items():
    b=arm.edit_bones.new(name); b.head=center; b.tail=center+Vector((0,0,.24)); b.parent=arm.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'; rig.show_in_front=False
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Rigid_Arcane_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='root at ground projection; core and six orbit controllers. Rigid skin; no animations yet.'

# Studio is excluded from the export.
studio=collections['04_STUDIO']; world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.18,1); world.node_tree.nodes['Background'].inputs[1].default_value=.55; scene.world=world
def aim(o,t): o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
for label,pos,power,size,color in [('Key',(-4,-5,7),1050,5,(.85,.92,1)),('Fill',(5,-2,4),850,5,(.83,.77,1)),('Rim',(0,4,6),1400,4,(.59,.91,1))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.4))
me=bpy.data.meshes.new(NAME+'_Ground_Mesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioGround',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Ground'); gm.diffuse_color=(.105,.12,.14,1); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.105,.12,.14,1); gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(NAME+'_Camera',data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=3.6; camera.location=(4,-9,4.3); aim(camera,(0,0,1.4)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_set(1)
scene['description']='Devorador de Mana: floating obsidian feeding rift, four shards, two broken orbital arcs. No humanoid anatomy.'
bpy.app.driver_namespace['mana_devourer']={'name':NAME,'scene':scene,'parts':parts,'rig':rig,'root':root,'out':str(OUT),
 'islands':islands,'size':SIZE,'density':DENSITY,'images':images,'material':mat,'studio':studio}
result={'scene':NAME,'parts':len(parts),'bones':len(arm.bones),'atlas':SIZE,'uv_islands':len(islands)}
