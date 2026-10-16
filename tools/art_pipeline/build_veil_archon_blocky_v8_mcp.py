"""Reference-inspired spectral sovereign with black crescent carapaces and an exposed azure cube core."""
import bpy,bmesh,math,json,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler,Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='veil_archon_blocky_v8'; NAME='Veil_Archon_Blocky_V8'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source/veil_archon_blocky_v8_review'
assert NAME not in bpy.data.scenes, 'Preserve previous work.'
OUT.mkdir(parents=True,exist_ok=True); REVIEW.mkdir(parents=True,exist_ok=True)
(REVIEW/'.gdignore').write_text('')
old_scenes=set(bpy.data.scenes.keys())
protected=[ROOT/'scripts/data/UnitDatabase.gd',ROOT/'assets/generated/magic/elder_lich/elder_lich.glb']
for stem in ['archdemon_blocky_v5_animated','seraph_blocky_v4_animated','elder_lich_blocky_v3_animated','elder_lich_blocky_v2']:
    folder=ROOT/'assets/generated/grand_manifestations'/stem
    protected.extend(folder/(stem+'.'+ext) for ext in ('glb','blend'))
protected.append(ROOT/'assets/generated/mana_devourers/mana_devourer_blocky_v3/mana_devourer_blocky_v3.glb')
for relative in [
    'assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1.glb',
    'assets/generated/humans/human_necromancer_v1/human_necromancer_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.glb',
    'assets/generated/grand_manifestations/elder_lich_blocky_v1/elder_lich_blocky_v1.blend']:
    protected.append(ROOT/relative)
protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v1'/('nature_avatar_blocky_v1.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/grand_manifestations'/'nature_avatar_blocky_v2'/('nature_avatar_blocky_v2.'+ext) for ext in ('glb','blend'))
for stem in ['nature_avatar_blocky_v3','nature_avatar_blocky_v4','nature_avatar_blocky_v5_animated']:
    protected.extend(ROOT/'assets/generated/grand_manifestations'/stem/(stem+'.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/humans/human_arcanist_v1'/('human_arcanist_v1.'+ext) for ext in ('glb','blend'))
if (ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v1/veil_archon_blocky_v1.glb').is_file():
    protected.append(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v1/veil_archon_blocky_v1.glb')
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v2'/('veil_archon_blocky_v2.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v3'/('veil_archon_blocky_v3.'+ext) for ext in ('glb','blend'))
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v4'/('veil_archon_blocky_v4.'+ext) for ext in ('glb','blend'))
protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v5'/('veil_archon_blocky_v5.'+ext)).is_file())
protected.extend(p for ext in ('glb','blend') if (p:=ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v6'/('veil_archon_blocky_v6.'+ext)).is_file())
protected.extend(ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v7'/('veil_archon_blocky_v7.'+ext) for ext in ('glb','blend'))
old_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
col=bpy.data.collections.new(NAME+'_Entity'); scene.collection.children.link(col)
studio=bpy.data.collections.new(NAME+'_Studio'); scene.collection.children.link(studio)
root=bpy.data.objects.new(NAME+'_ROOT',None); col.objects.link(root); root.empty_display_size=.2
parts=[]
def mesh_part(label,vertices,faces,bone,kind,R=None):
    R=R if R is not None else Matrix.Identity(3)
    me=bpy.data.meshes.new(NAME+'_'+label); me.from_pydata(vertices,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(me); bm.free(); me.update()
    o=bpy.data.objects.new(me.name,me); col.objects.link(o)
    o['rig_bone']=bone; o['kind']=kind; o['local_rotation']=list(R.to_euler('XYZ'))
    o['primitive']='closed planar sharp-edged prism; flat shaded; rigid pivot'
    parts.append(o); return o

def box(label,center,size,bone,kind='iron',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); s=Vector(size)*.5
    vs=[c+R@Vector((x*s.x,y*s.y,z*s.z)) for x,y,z in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_part(label,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],bone,kind,R)

def prism(label,profile,depth,center,bone,kind='iron',R=None):
    R=R if R is not None else Matrix.Identity(3); c=Vector(center); n=len(profile)
    vs=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for x,z in profile]
    fs=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    fs.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    return mesh_part(label,vs,fs,bone,kind,R)

def frame(label,center,width,height,rim,depth,bone,kind='edge',R=None):
    # One closed annulus with a real opening, not a black rectangle drawn onto a box.
    R=R if R is not None else Matrix.Identity(3); c=Vector(center)
    outline=[(-width/2,-height/2),(width/2,-height/2),(width/2,height/2),(-width/2,height/2)]
    inner=[(-width/2+rim,-height/2+rim),(width/2-rim,-height/2+rim),(width/2-rim,height/2-rim),(-width/2+rim,height/2-rim)]
    vs=[c+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for contour in (outline,inner) for x,z in contour]
    fs=[]
    for i in range(4):
        j=(i+1)%4
        fs.extend([(i,j,4+j,4+i),(8+i,12+i,12+j,8+j),(i,8+i,8+j,j),(4+i,4+j,12+j,12+i)])
    return mesh_part(label,vs,fs,bone,kind,R)

def beam(label,a,b,width,depth,bone,kind='iron'):
    a,b=Vector(a),Vector(b); R=(b-a).to_track_quat('Z','Y').to_matrix()
    return box(label,(a+b)/2,(width,depth,(b-a).length),bone,kind,R)

# Nonhumanoid fractured runic polyhedron, from the user's latest image.
C=Vector((0,0,1.70))
centers={'shell':C.copy(),'lattice':C.copy(),'core':C.copy(),'orbit':C.copy()}
parents={n:'root' for n in centers}

def orientation(normal,twist=0):
    n=Vector(normal).normalized();up=Vector((0,0,1))
    if abs(up.dot(n))>.95:up=Vector((0,1,0))
    up=(up-n*up.dot(n)).normalized();right=up.cross(n).normalized()
    R=Matrix((right,-n,up)).transposed()
    return R@Matrix.Rotation(math.radians(twist),3,'Y')

def tile(label,normal,radius,width,height,seed,offset=(0,0),twist=0,corner=False):
    n=Vector(normal).normalized();R=orientation(n,twist)
    c=C+n*radius+R@Vector((offset[0],0,offset[1]))
    bone='panel_'+str(seed).zfill(2);centers[bone]=c.copy();parents[bone]='shell'
    w=width/2;h=height/2;q=min(width,height)*.14
    if corner:
        # Triangular overall silhouette translated into right-angle steps.
        profile=[(-w,-h),(w,-h),(w,-h+q),(w-q,-h+q),(w-q,-h+2*q),
          (w-2*q,-h+2*q),(w-2*q,h-q),(q/2,h-q),(q/2,h),(-q/2,h),
          (-q/2,h-q),(-w+2*q,h-q),(-w+2*q,-h+2*q),(-w+q,-h+2*q),(-w+q,-h+q),(-w,-h+q)]
    else:
        # The square stone has two stepped clipped corners, never a rounded bevel.
        profile=[(-w,-h),(w-q,-h),(w-q,-h+q),(w,-h+q),
          (w,h),(-w+q,h),(-w+q,h-q),(-w,h-q)]
    o=prism(label,profile,.14 if not corner else .12,c,bone,'plate',R)
    o['rune_seed']=seed;o['rune_count']=2 if width>.80 else 1
    o['layer']='corner' if corner else 'edge' if len([x for x in normal if x])==2 else 'main'
    return o

seed=0
# The front has four individual plates around a broad cross-shaped aperture.
for x,z in [(-.370,.370),(.370,.370),(-.370,-.370),(.370,-.370)]:
    tile('Front_Runestone_'+str(seed),(0,-1,0),1.16,.60,.63,seed,(x,z),[3,-4,-2,4][seed]);seed+=1
# Other principal faces are split asymmetrically, rather than a repeating Rubik cube grid.
for normal in [(1,0,0),(-1,0,0),(0,1,0),(0,0,1),(0,0,-1)]:
    tile('Main_Upper_Runestone_'+str(seed),normal,1.16,1.12,.56,seed,(-.035,.340),3 if seed%2 else -3);seed+=1
    tile('Main_Lower_Runestone_'+str(seed),normal,1.19,1.04,.56,seed,(.035,-.340),-2 if seed%2 else 2);seed+=1
# Twelve oblique edge plates fill the next layer with a clear luminous gap between pieces.
for zero in range(3):
    active=[i for i in range(3) if i!=zero]
    for a in (-1,1):
        for b in (-1,1):
            n=[0,0,0];n[active[0]]=a;n[active[1]]=b
            tile('Oblique_Edge_Runestone_'+str(seed),n,1.525,.82,.80,seed,twist=(-3 if seed%2 else 3));seed+=1
# Eight stepped vertex shards complete a faceted orb, with a different plane orientation each.
for x in (-1,1):
    for y in (-1,1):
        for z in (-1,1):
            tile('Vertex_Runestone_'+str(seed),(x,y,z),1.57,.80,.76,seed,twist=(5 if seed%2 else -5),corner=True);seed+=1

# A luminous, open inner cage lets the cube remain visible through the actual openings.
Rinner=Euler((math.radians(8),math.radians(5),math.radians(12))).to_matrix()
r=.87
for axis in range(3):
    other=[i for i in range(3) if i!=axis]
    for a in (-1,1):
        for b in (-1,1):
            p=Vector((0,0,0));q=p.copy();p[axis]=-r;q[axis]=r
            p[other[0]]=q[other[0]]=a*r;p[other[1]]=q[other[1]]=b*r
            beam('Inner_Mana_Edge_'+str(axis)+'_'+str(a)+'_'+str(b),C+Rinner@p,C+Rinner@q,.075,.075,'lattice','lattice')
box('White_Violet_Mana_Core',C,(.96,.96,.96),'core','core',
    Euler((math.radians(18),math.radians(12),math.radians(22))).to_matrix())

# One thin broken angular orbit echoes the image's energy trail without a smooth torus.
Rorbit=Euler((math.radians(8),math.radians(-23),math.radians(13))).to_matrix()
loop=[(-1.47,0,-.65),(-1.08,0,-1.28),(.33,0,-1.50),(1.38,0,-.82),
      (1.50,0,.55),(.88,0,1.34),(-.40,0,1.49),(-1.40,0,.73)]
for i in [0,1,2,4,5,6]:
    a=C+Rorbit@Vector(loop[i]);b=C+Rorbit@Vector(loop[(i+1)%8])
    beam('Broken_Angular_Mana_Orbit_'+str(i),a,b,.027,.035,'orbit','orbit')

coords=[v.co for o in parts for v in o.data.vertices]
zmin=min(v.z for v in coords); zmax=max(v.z for v in coords); factor=3.0/(zmax-zmin)
GROUND=.35
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-zmin)*factor+GROUND))
for o in parts:
    for vtx in o.data.vertices: vtx.co=normalized(vtx.co)
    o.data.update()
centers={n:normalized(c) for n,c in centers.items()}

# Metric pixel atlas: black stone, spectral blue bone and azure mana, 64 pixels per meter.
DENSITY=64; PAD=2; islands=[]
for o in parts:
    me=o.data; me.uv_layers.new(name='Metric_Pixel_UV'); R=Euler(o['local_rotation'],'XYZ').to_matrix()
    for p in me.polygons:
        n=p.normal.normalized(); up=R@Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=R@Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        lo=Vector((min(v.x for v in coords),min(v.y for v in coords))); coords=[v-lo for v in coords]
        islands.append(dict(obj=o,polygon=p.index,normal=R.transposed()@n,coords=coords,
            w=max(1,math.ceil(max(v.x for v in coords)*DENSITY)),h=max(1,math.ceil(max(v.y for v in coords)*DENSITY))))
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it['x']=x+PAD; it['y']=y+PAD; x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (512,1024,2048) if pack(s))
# Hand-designed pixel glyphs and mineral inlays; no skull, face, fingers, or humanoid cues.
glyphs=[
 ["001010100","001010100","001010100","001010100","001010100","001010100","011010110","001111100","000010000"],
 ["000010000","000111000","001101100","011000110","110000011","011000110","001101100","000111000","000010000"],
 ["001111000","011001100","110000110","110000000","110000000","110000110","011001100","001111000","000010000"],
 ["110000000","011000000","001100000","000111100","001100000","011000000","110000000","000000110","000001100"],
 ["000010000","001010100","001111100","000010000","111111111","000010000","001111100","001010100","000010000"],
 ["011111110","010000010","010000010","000000010","000111110","000100000","000100000","000100010","000111110"],
 ["001001000","011011000","110110000","100100010","000000110","000001100","000011000","000110000","001100000"],
 ["001111000","011001100","110000110","000000110","000011100","000110000","001100000","001111110","000000000"],
 ["010000010","010010010","010010010","011111110","000010000","000010000","000010000","001111100","000010000"]]
palette={'plate':(25,20,42),'lattice':(174,170,232),'core':(186,191,238),'orbit':(106,84,188)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
def polygon_mask(it,w,h):
    yy,xx=np.indices((h,w));xx=xx+.5;yy=yy+.5;inside=np.zeros((h,w),dtype=bool)
    pts=[(c.x*DENSITY,c.y*DENSITY) for c in it['coords']]
    for (x0,y0),(x1,y1) in zip(pts,pts[1:]+pts[:1]):
        if abs(y1-y0)<1e-8:continue
        inside^=((y0>yy)!=(y1>yy))&(xx<(x1-x0)*(yy-y0)/(y1-y0)+x0)
    return inside
def paint_rune(rgb,emission,seed,cx,cy,scale):
    glyph=glyphs[seed%len(glyphs)];gh=len(glyph);gw=len(glyph[0]);ox=int(cx-gw*scale/2);oy=int(cy-gh*scale/2)
    for j,row in enumerate(glyph):
        for i,v in enumerate(row):
            if v!='1':continue
            x=ox+i*scale;y=oy+(gh-1-j)*scale
            if x<0 or y<0 or x+scale>rgb.shape[1] or y+scale>rgb.shape[0]:continue
            rgb[y:y+scale,x:x+scale]=[197,189,225]
            emission[y:y+scale,x:x+scale]=[.22,.205,.29]
            if scale>1:rgb[y+scale-1:y+scale,x:x+scale]=[231,221,247]
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(811070+index);yy,xx=np.indices((h,w))
    clusters=rng.integers(-3,4,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind=='plate':
        mask=polygon_mask(it,w,h);eroded=mask.copy()
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1),(2,0),(-2,0),(0,2),(0,-2)]:
            shifted=np.roll(mask,(dy,dx),(0,1))
            if dy>0:shifted[:dy]=False
            if dy<0:shifted[dy:]=False
            if dx>0:shifted[:,:dx]=False
            if dx<0:shifted[:,dx:]=False
            eroded&=shifted
        rim=mask&~eroded
        if n.y<-.80:
            rgb[rim]=[39,30,57]
            # A quiet thin etching, kept away from the main runes.
            if h>20 and w>22:
                rgb[(yy==4)&(xx>5)&(xx<w-5)]=[44,34,65]
                rgb[(yy==h-5)&(xx>5)&(xx<w-5)]=[44,34,65]
            seed=int(o['rune_seed']);count=int(o['rune_count'])
            if count==1:
                scale=max(1,min(3,(min(w,h)-10)//9))
                paint_rune(rgb,emission,seed,w*.5,h*.50,scale)
            else:
                scale=max(1,min(2,(h-9)//9))
                paint_rune(rgb,emission,seed,w*.30,h*.5,scale)
                paint_rune(rgb,emission,seed+3,w*.72,h*.5,scale)
            # Sparse beveled-paint accents at two clipped corners, still physically sharp.
            rgb[rim&(yy>=h-3)]=[74,60,96]
        else:
            rgb[rim]=[39,31,58]
    elif kind=='lattice':
        rgb[(xx==w//2)|(yy==h//2)]=[222,215,251]
        emission=rgb/255*.66
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[121,106,197]
        rgb[(xx>w*.22)&(xx<w*.78)&(yy>h*.22)&(yy<h*.78)]=[233,231,254]
        emission=rgb/255*.78
    else:
        rgb[(xx==w//2)|(yy==h//2)]=[177,157,235];emission=rgb/255*.38
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(data.reshape(-1)); im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'))
    im.file_format='PNG'; im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.new(NAME+'_Runic_Obsidian_White_Violet_Core'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.90
bsdf.inputs['Specular IOR Level'].default_value=.14
for im,socket in zip(images,['Base Color','Emission Color']):
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=im; node.interpolation='Closest'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
bsdf.inputs['Emission Strength'].default_value=.8
for o in parts: o.data.materials.append(mat)

# Only rigid pivots are prepared. No skin bending, NLA or animation is added at this model stage.
arm=bpy.data.armatures.new(NAME+'_Prepared_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); col.objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
b=arm.edit_bones.new('root'); b.head=(0,0,0); b.tail=(0,0,.2); b.use_deform=False
for n,c in centers.items():
    b=arm.edit_bones.new(n); b.head=c; b.tail=c+Vector((0,0,.15))
for n in centers: arm.edit_bones[n].parent=arm.edit_bones[parents[n]]
bpy.ops.object.mode_set(mode='OBJECT')
for o in parts:
    o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
    o.parent=rig; o.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig
rig['status']='Nonhumanoid suspended runic polyhedron: thirty-four dark violet runestones arranged in principal, oblique and vertex layers, white pixel glyphs, real luminous fissures, an open internal mana lattice, one central cubic white-violet nucleus and a broken angular orbital trail. Sharp closed blocky prisms with stepped clipped corners.'

def aim(o,p): o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(NAME+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.13,.18,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45; scene.world=world
for label,pos,power,color in [('Key',(-4,-6,8),850,(.94,.98,1)),('Fill',(5,-3,5),550,(.79,.88,1)),('Rim',(0,5,7),850,(.9,1,.96))]:
    data=bpy.data.lights.new(NAME+'_'+label,'AREA'); data.energy=power; data.size=5; data.color=color
    o=bpy.data.objects.new(data.name,data); studio.objects.link(o); o.location=pos; aim(o,(0,0,1.8))
me=bpy.data.meshes.new(NAME+'_StudioFloorMesh'); me.from_pydata([(-200,-200,-.01),(200,-200,-.01),(200,200,-.01),(-200,200,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(NAME+'_StudioFloor',me); studio.objects.link(floor)
gm=bpy.data.materials.new(NAME+'_Floor'); gm.use_nodes=True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.07,.09,.13,1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; me.materials.append(gm)
data=bpy.data.cameras.new(NAME+'_Camera'); camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera)
data.type='ORTHO'; data.ortho_scale=4.8; camera.location=(3,-11,4.0); aim(camera,(0,0,1.85)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.device='GPU'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.frame_start=1; scene.frame_end=1; scene.frame_set(1)
scene['description']='Nonhumanoid suspended runic polyhedron: thirty-four dark violet runestones arranged in principal, oblique and vertex layers, white pixel glyphs, real luminous fissures, an open internal mana lattice, one central cubic white-violet nucleus and a broken angular orbital trail. Sharp closed blocky prisms with stepped clipped corners.'
scene['stage']='Static model only; shared between civilizations.'
bpy.app.driver_namespace[STEM]=dict(name=NAME,stem=STEM,scene=scene,root=root,rig=rig,parts=parts,
    images=images,material=mat,atlas=SIZE,islands=islands,studio=studio,camera=camera,out=str(OUT),review=str(REVIEW),
    old_scenes=list(old_scenes),old_hashes=old_hashes)
(OUT/'previews').mkdir(exist_ok=True)
for o in parts: o.data.calc_loop_triangles()
scene.render.filepath=str(OUT/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'scene':NAME,'parts':len(parts),'triangles':sum(len(o.data.loop_triangles) for o in parts),
    'height_m':3.0,'prepared_bones':len(arm.bones),'animations':0,'atlas':SIZE,'previous_scenes':len(old_scenes)}
