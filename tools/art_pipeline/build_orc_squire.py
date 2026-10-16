"""Build one 2 m orc directly from the approved editable elf squire via MCP."""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector,Matrix

sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_elf_troops import BODY,FACES,pixels,reset_pose,export_glb
from elf_troop_paint import map_front,noise_color
from orc_clothing_paint import finish as finish_clothing
from orc_rig_helpers import relax_right_arm,enlarge_shield

ROOT=Path(__file__).resolve().parents[2]
STEM='orc_squire_v1'; OUT=ROOT/'assets/generated/orcs'/STEM
SOURCE=ROOT/'assets/generated/elves/elf_squire_v1/elf_squire_v1.blend'
SKIN=(91,111,63); SKIN_DARK=(70,87,48); HAIR=(34,34,29)
IRON=(77,80,73); LEATHER=(78,52,34); CLOTH=(91,69,43); WOOD=(92,69,43)
IVORY=(177,167,132)


def cuboid_axes(obj):
    vertices=np.array([list(v.co) for v in obj.data.vertices])
    axes=np.stack([vertices[i]-vertices[0] for i in (1,2,4)],axis=1)
    assert np.max(np.abs((axes/np.linalg.norm(axes,axis=0)).T@(axes/np.linalg.norm(axes,axis=0))-np.eye(3)))<.00003,obj.name
    return vertices,axes


def resize(obj,factors):
    vertices,axes=cuboid_axes(obj); center=vertices.mean(axis=0)
    frame=axes/np.linalg.norm(axes,axis=0)
    updated=((vertices-center)@frame*np.array(factors))@frame.T+center
    for vertex,position in zip(obj.data.vertices,updated): vertex.co=position
    obj.data.update()


def move(obj,offset):
    for vertex in obj.data.vertices: vertex.co+=Vector(offset)
    obj.data.update()


def broaden_stance(rig,parts):
    """Move each rigid limb branch and its rest bones by the same offset.

    The inherited rig has independent root children. Keeping each branch's
    offset constant preserves its original movement and shield attachment.
    """
    offsets={}
    for side,sign in (('l',1),('r',-1)):
        for name in ('upper_arm','forearm','hand'): offsets[name+'_'+side]=[sign*.15,0,0]
        for name in ('thigh','shin','foot'): offsets[name+'_'+side]=[sign*.055,0,0]
    for obj in parts:
        bone=obj.get('rig_bone')
        if bone in offsets: move(obj,offsets[bone])
        elif obj['part'].startswith('Shoulder'):
            move(obj,(.15 if obj['part'].endswith('_l') else -.15,0,0))
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
    bpy.context.view_layer.objects.active=rig; bpy.ops.object.mode_set(mode='EDIT')
    for name,offset in offsets.items():
        bone=rig.data.edit_bones[name]
        assert bone.parent.name=='root'
        bone.head+=Vector(offset); bone.tail+=Vector(offset)
    bpy.ops.object.mode_set(mode='OBJECT')
    return offsets


def rectangle(obj,poly,width,height):
    uv=np.array([list(obj.data.uv_layers.active.data[i].uv) for i in poly.loop_indices])
    lo=np.rint(uv.min(axis=0)*[width,height]).astype(int)
    hi=np.rint(uv.max(axis=0)*[width,height]).astype(int)
    coords=np.array([list(obj.data.vertices[obj.data.loops[i].vertex_index].co) for i in poly.loop_indices])
    yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
    unit=np.stack([(xx+.5)/width,(yy+.5)/height],axis=-1)
    basis=np.stack([uv[1]-uv[0],uv[-1]-uv[0]],axis=1)
    local=(unit-uv[0])@np.linalg.inv(basis).T
    position=coords[0]+local[...,0,None]*(coords[1]-coords[0])+local[...,1,None]*(coords[-1]-coords[0])
    vertices,axes=cuboid_axes(obj)
    frac=(position-vertices[0])@np.linalg.inv(axes).T
    return lo,hi,frac


def paint_head(canvas,obj,poly,lo,hi,frac):
    x0,y0=lo; x1,y1=hi; w=x1-x0; h=y1-y0
    tile=noise_color(SKIN,(h,w),140+poly.index,2)
    audit=None
    if poly.normal.y<-.6:
        nx=len(np.unique(np.round(frac[...,0],5))); nz=len(np.unique(np.round(frac[...,2],5)))
        front=np.empty((nz,nx,3),dtype=np.int16)
        half=noise_color(SKIN,(nz,(nx+1)//2),181,2)
        front[:,:half.shape[1]]=half; front[:,nx//2:]=half[:,:((nx+1)//2)][:,::-1]
        # Hair, brows, pupils, nose and mouth all remain on the one head cuboid.
        # Short central strip of hair, shaved temples, broad olive jaw.
        top=max(2,round(nz*.15)); hx=round(nx*.35)
        front[-top:,hx:nx-hx]=HAIR
        front[:round(nz*.17),:]=np.array(SKIN)-[7,8,5]
        front[round(nz*.35):round(nz*.51),:max(1,round(nx*.13))]=SKIN_DARK
        front[round(nz*.35):round(nz*.51),-max(1,round(nx*.13)):]=SKIN_DARK
        ey=round(nz*.55); ex=max(2,round(nx*.17)); ew=max(2,round(nx*.20))
        for dx in range(ew):
            for x in (ex+dx,nx-1-ex-dx):
                front[ey,x]=(173,151,83)
                front[max(0,ey-1),x]=(156,139,82)
        front[ey,ex+ew-1]=(39,42,24); front[ey,nx-ex-ew]=(39,42,24)
        front[max(0,ey-1),ex+ew-1]=(39,42,24); front[max(0,ey-1),nx-ex-ew]=(39,42,24)
        cols=[nx//2] if nx%2 else [nx//2-1,nx//2]
        for x in cols: front[max(1,ey-3):ey-1,x]=SKIN_DARK
        mouth_y=max(2,round(nz*.20)); border=max(3,round(nx*.22))
        front[mouth_y,border:nx-border]=(42,57,30)
        front[max(0,mouth_y-1),border+1:nx-border-1]=(70,79,44)
        tile=map_front(front,frac)
        assert np.array_equal(front[ey,:nx//2],front[ey,-(nx//2):][::-1])
        vx=np.unique(np.round(frac[...,0],5)); vz=np.unique(np.round(frac[...,2],5))
        ix=np.searchsorted(vx,np.round(frac[...,0],5)); iz=np.searchsorted(vz,np.round(frac[...,2],5))
        samples=[]
        for side in (0,1):
            points=[]
            for dx in range(ew):
                col=ex+dx if side==0 else nx-1-ex-dx
                y,x=np.argwhere((ix==col)&(iz==ey))[0]; points.append([int(x+x0),int(y+y0)])
            samples.append(points)
        audit=dict(mode='bare_orc_face',eyes_mirrored=True,eye_width_px=ew,
                   eye_atlas_pixels=samples,uv_bounds=[int(x0),int(y0),int(x1),int(y1)],
                   eye_height_fraction=float(vz[ey]))
    elif poly.normal.z>.6:
        tile[(frac[...,0]>.34)&(frac[...,0]<.66)]=HAIR
    elif poly.normal.y>.6:
        tile[(frac[...,0]>.34)&(frac[...,0]<.66)&(frac[...,2]>.38)]=HAIR
    elif abs(poly.normal.x)>.6:
        tile[frac[...,2]>.62]=noise_color(tuple(np.array(SKIN)-[10,12,7]),(h,w),44,2)[frac[...,2]>.62]
    canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)
    return audit




def paint_surface(canvas,obj,poly,lo,hi,frac):
    """Quiet material detail, asymmetrical working gear, no heroic X harness."""
    part=obj['part']; x0,y0=lo; x1,y1=hi; w=x1-x0; h=y1-y0
    fx,fy,fz=(frac[...,i] for i in range(3)); yy,xx=np.mgrid[:h,:w]
    edge=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy])
    front=poly.index in (2,3)
    seed=2100+poly.index+sum(ord(c) for c in part)
    rng=np.random.default_rng(seed)
    qx=np.floor(fx*24).astype(int); qz=np.floor(fz*24).astype(int)
    def skin():
        return noise_color(SKIN,(h,w),seed,2)
    def leather(base=LEATHER):
        tex=noise_color(base,(h,w),seed,4)
        tex[(qx+qz*3)%11==0]=np.array(base)-[6,5,3]
        tex[edge==0]=np.array(base)-[18,15,10]
        tex[(edge==1)&((xx+yy)%3!=0)]=np.array(base)+[12,10,6]
        tex[(rng.random((h,w))<.028)&(edge>2)]=np.array(base)+[17,13,8]
        return tex
    if part.startswith('ElfEar'):
        tile=skin(); kind='skin'
        if poly.normal.y<-.5: tile[(fx>.22)&(fx<.78)&(fz>.22)&(fz<.76)]=SKIN_DARK
    elif part in ('Chest','Belly') or part.startswith(('UpperArm','Hand','Thigh')) or part=='Shoulder_r':
        tile=skin(); kind='skin'
        if part=='Chest':
            if front:
                tile[(fz>.3)&(fz<.78)&(abs(fx-.5)>.12)&(abs(fx-.5)<.43)]=np.array(SKIN)+[4,5,3]
                tile[(fz<.20)&(abs(fx-.5)<.38)]=np.array(SKIN)-[5,6,3]
                tile[(abs(fx-.5)<.023)&(fz<.76)]=np.array(SKIN)-[9,10,5]
            # One wide strap carries the shield-side shoulder guard.
            line=.29+.43*fz; distance=abs(fx-line)
            strap=distance<.078 if front else (fx>.77)
            tex=leather(); tile[strap]=tex[strap]
            tile[strap&(distance>.060)]=np.array(LEATHER)-[16,12,8]
            stitches=strap&(distance>.048)&(distance<.061)&(qz%3==0)
            tile[stitches]=(119,99,65)
            if front:
                buckle=strap&(fz>.67)&(fz<.81)&(distance<.070)
                border=buckle&((fz<.70)|(fz>.78)|(distance>.048))
                tile[border]=IRON
        elif part=='Belly':
            if front:
                tile[(abs(fx-.5)<.025)&(fz>.32)]=np.array(SKIN)-[7,8,4]
                tile[(fz>.54)&(fz<.61)&(abs(fx-.5)<.32)]=np.array(SKIN)-[4,5,2]
            strap=(fz>.74)&(abs(fx-(.23+.12*fz))<.070)&front
            tile[strap]=LEATHER
        elif part.startswith('Thigh'):
            # Unequal solid hide panels; bare thighs below, no ragged cloth.
            hem=.63 if part.endswith('_l') else .72
            panel=(fz>hem)&front
            tex=leather((84,55,33)); tile[panel]=tex[panel]
            tile[panel&(abs(fx-.82)<.04)]=(47,34,23)
        elif part.startswith('UpperArm'):
            tile[(fx>.24)&(fx<.77)&(fz>.24)&(fz<.69)]=np.array(SKIN)+[3,4,2]
            if part.endswith('_r'):
                band=(fz>.81)&(fz<.94); tex=leather()
                tile[band]=tex[band]
        elif part=='Shoulder_r':
            # The second shoulder is exposed, with the arm strap at its base.
            band=fz<.18; tex=leather(); tile[band]=tex[band]
        elif part.startswith('Hand') and front:
            tile[(fz>.81)&(abs(fx-.5)<.34)]=np.array(SKIN)-[8,9,5]
    elif part=='Pelvis':
        tile=leather((71,47,29)); kind='belt_and_hide'
        belt=fz>.56
        tile[belt]=leather((47,35,25))[belt]
        tile[abs(fz-.57)<.04]=(110,80,47)
        if front:
            seams=(abs(fx-.22)<.03)|(abs(fx-.73)<.03)
            tile[seams&~belt]=(42,31,22)
            rivets=(fz>.72)&(fz<.82)&((abs(fx-.14)<.025)|(abs(fx-.85)<.025))
            tile[rivets]=IRON
    elif part.startswith(('Shoulder','Forearm','Shin','Foot')) or part=='ShieldGrip':
        tile=leather(); kind='leather'
        if part=='Shoulder_l':
            tile=leather((70,49,33))
            # A weathered slab in the existing shoulder, bound with rawhide.
            bone=(fx>.14)&(fx<.88)&(fz>.28)&(fz<.89)
            if poly.normal.z>.5: bone=(fx>.14)&(fx<.88)&(fy>.14)&(fy<.87)
            bone&=~(((qx<6)&(qz>18))|((qx>19)&(qz<9)))
            ivory=noise_color(IVORY,(h,w),seed,5); tile[bone]=ivory[bone]
            crack=bone&((abs(fx-(.33+.10*fz))<.022)&(fz>.60))
            tile[crack]=(120,115,92)
            bindings=(abs(fx-.12)<.035)|(abs(fx-.90)<.035)
            tile[bindings]=(48,36,25)
        elif part.startswith('Forearm'):
            bands=(abs(fz-.18)<.055)|(abs(fz-.78)<.055)
            tile[bands]=(43,33,23)
            if front:
                # Bone reinforcement only on one wrist, dark hide on the other.
                if part.endswith('_l'):
                    bone=(fx>.30)&(fx<.65)&(fz>.28)&(fz<.68)
                    tile[bone]=noise_color(IVORY,(h,w),seed,4)[bone]
                rivets=bands&((abs(fx-.19)<.035)|(abs(fx-.81)<.035))
                tile[rivets]=(112,110,93)
        elif part.startswith('Shin'):
            tile=leather((66,46,30))
            exposed=fz>.79; tile[exposed]=skin()[exposed]
            bindings=(abs(fz-.19)<.050)|(abs(fz-.67)<.050)
            tile[bindings]=(41,32,23)
            if front:
                seam=(abs(fx-.74)<.025)&(fz>.27)&(fz<.58)
                tile[seam]=(104,79,47)
        elif part.startswith('Foot'):
            tile=leather((54,41,28))
            tile[fz<.18]=(33,31,24)
            toe=(fy<.21)&(fz>.18); tile[toe]=np.array(LEATHER)-[10,6,2]
    elif part in ('Buckle','ShieldBoss'):
        kind='iron'; tile=noise_color(IRON,(h,w),seed,5)
        tile[edge==0]=(43,46,42); tile[edge==1]=(106,106,91)
        tile[(rng.random((h,w))<.045)&(edge>1)]=(100,70,42)
    elif part.startswith('Shield'):
        kind='wood'; vertices,axes=cuboid_axes(obj)
        pos=frac@axes.T+vertices[0]
        # Grain follows actual boards across all three stepped shield blocks.
        gx=(pos[...,0]-.247297+.290)/.580
        gz=(pos[...,2]-.758919)/.584
        board=np.floor(gx*5).astype(int)
        tile=noise_color(WOOD,(h,w),seed,3)
        shifts=np.array([-8,3,-4,7,-2]); tile+=shifts[np.clip(board,0,4)][...,None]
        seam=abs(gx*5-np.round(gx*5))<.055
        tile[seam]=(43,34,23)
        grain=((np.floor(gx*57).astype(int)+np.floor(gz*9).astype(int)//3)%13==0)
        tile[grain]=np.array(WOOD)-[15,12,8]
        # Narrow worn lashings instead of a bright furniture-like frame.
        bands=(abs(gz-.21)<.037)|(abs(gz-.80)<.037)
        tile[bands]=(55,56,48)
        scratches=bands&((qx+qz)%9==0); tile[scratches]=(108,103,82)
        if front:
            nails=bands&((abs(gx-.12)<.025)|(abs(gx-.88)<.025))
            tile[nails]=(128,122,100)
        if abs(poly.normal.x)>.6 or abs(poly.normal.z)>.6: tile=leather((60,43,27))
    else: raise AssertionError(part)
    vertices,axes=cuboid_axes(obj)
    kind_new=finish_clothing(obj,poly,frac,tile,frac@axes.T+vertices[0])
    if kind_new: kind=kind_new
    canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)
    return kind


def add_tusks(head,rig,parts,canvas):
    verts=np.array([list(v.co) for v in head.data.vertices]); lo=verts.min(axis=0); hi=verts.max(axis=0)
    collection=head.users_collection[0]; created=[]
    for side,s in (('l',1),('r',-1)):
        for step,size in enumerate(((.025,.028,.030),(.017,.021,.024))):
            center=Vector((s*((hi[0]-lo[0])*.22+step*.005),lo[1]-.010-step*.004,
                           lo[2]+(hi[2]-lo[2])*.18+step*.022))
            vertices=[center+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2))
                for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
            name='Tusk_'+side+'_'+str(step); mesh=bpy.data.meshes.new(STEM+'_'+name)
            mesh.from_pydata(vertices,[],FACES); mesh.update()
            obj=bpy.data.objects.new(STEM+'_'+name,mesh); collection.objects.link(obj)
            obj.parent=rig; obj['part']=name; obj['region']='tusk'; obj['rig_bone']='head'
            obj.vertex_groups.new(name='head').add(list(range(8)),1,'REPLACE')
            modifier=obj.modifiers.new('Orc_Tusk_Rig','ARMATURE'); modifier.object=rig
            uv=mesh.uv_layers.new(name='UVMap')
            for poly in mesh.polygons:
                index=len(created)*6+poly.index; x=4+index%16*12; y=canvas.shape[0]*3//4+index//16*12
                canvas[y:y+10,x:x+10,:3]=IVORY
                canvas[y:y+10,x,:3]=(168,160,126)
                for loop,p in zip(poly.loop_indices,((x+2,y+2),(x+8,y+2),(x+8,y+8),(x+2,y+8))):
                    uv.data[loop].uv=(p[0]/canvas.shape[1],p[1]/canvas.shape[0])
            parts.append(obj); created.append(name)
    return created


def add_brows(head,rig,parts,canvas,head_audit):
    """Two projecting cuboids, like the dwarves, lowered toward the nose."""
    v=np.array([list(vertex.co) for vertex in head.data.vertices])
    lo=v.min(axis=0); hi=v.max(axis=0); collection=head.users_collection[0]
    created=[]
    eye_z=lo[2]+head_audit['eye_height_fraction']*(hi[2]-lo[2])
    for side,sign in (('l',1),('r',-1)):
        name='Brow_'+side
        center=Vector((sign*(hi[0]-lo[0])*.265,lo[1]-.012,eye_z+.031))
        size=(.107,.033,.027); rotation=Matrix.Rotation(math.radians(-sign*12),3,'Y')
        vertices=[center+rotation@Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2))
                  for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
        mesh=bpy.data.meshes.new(STEM+'_'+name); mesh.from_pydata(vertices,[],FACES); mesh.update()
        obj=bpy.data.objects.new(STEM+'_'+name,mesh); collection.objects.link(obj)
        obj.parent=rig; obj['part']=name; obj['region']='eyebrow'; obj['rig_bone']='head'
        obj.vertex_groups.new(name='head').add(list(range(8)),1,'REPLACE')
        obj.modifiers.new('Brow_Rig','ARMATURE').object=rig
        uv=mesh.uv_layers.new(name='UVMap')
        for poly in mesh.polygons:
            index=len(created)*6+poly.index; x=4+index*12; y=canvas.shape[0]*13//16
            shade=np.array(HAIR)+([10,9,7] if poly.index==1 else [0,0,0])
            canvas[y:y+10,x:x+10,:3]=shade
            for loop,p in zip(poly.loop_indices,((x+2,y+2),(x+8,y+2),(x+8,y+8),(x+2,y+8))):
                uv.data[loop].uv=(p[0]/canvas.shape[1],p[1]/canvas.shape[0])
        parts.append(obj); created.append(name)
    return created




def save_atlas(canvas):
    # Pixel values below are authored in sRGB. Save raw channels, then load them
    # as a color texture, avoiding an extra transfer-function conversion.
    image=bpy.data.images.new(STEM+'_albedo',width=canvas.shape[1],height=canvas.shape[0],alpha=True)
    image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set((canvas.astype(np.float32)/255).ravel())
    image.filepath_raw=str(OUT/(STEM+'_albedo.png')); image.file_format='PNG'; image.save()
    image.colorspace_settings.name='sRGB'; image.reload(); image.pack()
    return image


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
    with bpy.data.libraries.load(str(SOURCE),link=False) as (source,loaded): loaded.scenes=source.scenes
    scene=loaded.scenes[0]; scene.name='Orc_Squire_Base_2m'; bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    rig.data=rig.data.copy()
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts: obj.data=obj.data.copy()
    reset_pose(rig,scene)
    by={obj['part']:obj for obj in parts}; removed=[]
    for part in ('HatBrim','HatCap','HatDome'):
        obj=by[part]; parts.remove(obj); removed.append(part); bpy.data.objects.remove(obj,do_unlink=True)
    head=by['Head']; original_head_edge=max(v.co.x for v in head.data.vertices)
    scales={'Head':(1.20,1.15,1),'Chest':(1.65,1.40,1),'Belly':(1.62,1.40,1),
            'Pelvis':(1.40,1.35,1)}
    for label,factors in (('Shoulder',(1.40,1.40,1)),('UpperArm',(1.85,1.65,1)),
        ('Forearm',(1.65,1.60,1)),('Hand',(1.60,1.45,1.06)),
        ('Thigh',(1.55,1.45,1)),('Shin',(1.40,1.35,1)),('Foot',(1.40,1.28,1))):
        for side in ('l','r'): scales[label+'_'+side]=factors
    for part,factors in scales.items(): resize(by[part],factors)
    bone_offsets=broaden_stance(rig,parts)
    edge_delta=max(v.co.x for v in head.data.vertices)-original_head_edge
    ear_source={}
    for obj in parts:
        if obj['part'].startswith('ElfEar'):
            ear_source[obj['part']]=[list(v.co) for v in obj.data.vertices]
            sign=1 if '_l_' in obj['part'] else -1
            for vertex in obj.data.vertices: vertex.co.x+=sign*edge_delta
    image=next(node.image for node in parts[0].data.materials[0].node_tree.nodes
               if node.type=='TEX_IMAGE' and node.image and 'albedo' in node.image.name)
    canvas=pixels(image).repeat(2,axis=0).repeat(2,axis=1); head_audit=None; materials={}
    for obj in parts:
        for poly in obj.data.polygons:
            lo,hi,frac=rectangle(obj,poly,canvas.shape[1],canvas.shape[0])
            if obj==head:
                audit=paint_head(canvas,obj,poly,lo,hi,frac)
                if audit: head_audit=audit
            else: materials[obj['part']]=paint_surface(canvas,obj,poly,lo,hi,frac)
            x0,y0=lo; x1,y1=hi
            # Adjacent atlas padding must carry the new orc colors too.
            if x0>0: canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
            if x1<canvas.shape[1]: canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
            if y0>0: canvas[y0-1,max(0,x0-1):min(canvas.shape[1],x1+1)]=canvas[y0,max(0,x0-1):min(canvas.shape[1],x1+1)]
            if y1<canvas.shape[0]: canvas[y1,max(0,x0-1):min(canvas.shape[1],x1+1)]=canvas[y1-1,max(0,x0-1):min(canvas.shape[1],x1+1)]
    # The user explicitly approved the shield: retain its exact pixel regions,
    # including grip/boss and padding, independently of clothing paint changes.
    approved_path=ROOT/'art_source/orc_squire/before_brows_clothing_refinement'/ (STEM+'_albedo.png')
    approved_image=bpy.data.images.load(str(approved_path),check_existing=False)
    approved_image.colorspace_settings.name='Non-Color'; approved_image.reload()
    approved_pixels=pixels(approved_image); assert approved_pixels.shape==canvas.shape
    shield_regions=[]
    for obj in parts:
        if not obj['part'].startswith('Shield'): continue
        for poly in obj.data.polygons:
            lo,hi,_=rectangle(obj,poly,canvas.shape[1],canvas.shape[0])
            x0,y0=np.maximum(lo-1,0); x1,y1=np.minimum(hi+1,[canvas.shape[1],canvas.shape[0]])
            canvas[y0:y1,x0:x1]=approved_pixels[y0:y1,x0:x1]
            shield_regions.append(dict(part=obj['part'],face=poly.index,bounds=[int(x0),int(y0),int(x1),int(y1)],
                sha256=hashlib.sha256(canvas[y0:y1,x0:x1].tobytes()).hexdigest()))
    bpy.data.images.remove(approved_image)
    relaxed_arm=relax_right_arm(scene,rig,parts)
    enlarged_shield=enlarge_shield(parts)
    tusks=add_tusks(head,rig,parts,canvas)
    brows=add_brows(head,rig,parts,canvas,head_audit)
    bone_details=[]
    atlas=save_atlas(canvas)
    mat=bpy.data.materials.new(STEM+'_Painted_Materials'); mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.88
    texture=mat.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=atlas; texture.interpolation='Closest'
    mat.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    for obj in parts:
        obj.data.materials.clear(); obj.data.materials.append(mat)
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),obj.name; bm.free()
    root.scale=(2/max(v.co.z for v in head.data.vertices),)*3
    root['race']='orc'; root['family']='guardian'; root['tier']=0; root['height_m']=2.0
    for obj in scene.objects:
        obj.name=STEM+'_'+obj.name
    bpy.context.view_layer.update()
    lo=[min((obj.matrix_world@v.co)[i] for obj in parts for v in obj.data.vertices) for i in range(3)]
    hi=[max((obj.matrix_world@v.co)[i] for obj in parts for v in obj.data.vertices) for i in range(3)]
    assert abs(hi[2]-2)<.00001 and abs(lo[2])<.00001
    assert len([obj for obj in parts if obj['part']=='Head'])==1
    assert all(len(by[part].data.vertices)==8 and len(by[part].data.polygons)==6 for part in BODY)
    # Preserve the base elf's exact native clip names and all action curves.
    clips={track.name:(track.strips[0].action_frame_end-track.strips[0].action_frame_start)/scene.render.fps
           for track in rig.animation_data.nla_tracks}
    geometry=dict(body_parts=BODY,head_blocks=1,ear_cuboids=6,tusk_cuboids=4,editable_parts=len(parts),
        flat_shading=True,nonmanifold_edges=0,bounds_min=lo,bounds_max=hi,dimensions=[hi[i]-lo[i] for i in range(3)],
        root_scale=list(root.scale),cuboid_resizes=scales,ear_edge_translation_m=edge_delta)
    geometry['bone_accessory_cuboids']=len(bone_details)
    geometry['eyebrow_cuboids']=len(brows)
    target=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,(lo[2]+hi[2])/2)); camera=scene.camera
    camera.data.type='ORTHO'; camera.data.ortho_scale=2.8
    scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=640; scene.render.resolution_y=640
    scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
    preview=OUT/'previews'; preview.mkdir(exist_ok=True)
    for name,offset in {'three_quarter':(6,-12,5.6),'front':(0,-12,1.2),'back':(-6,12,5),'game_top':(5,-7,11)}.items():
        camera.location=target+Vector(offset); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(preview/(name+'.png')); bpy.ops.render.render(write_still=True)
    for obj in parts:
        if obj['part'].startswith('Shield'): obj.hide_render=True
    camera.location=target+Vector((0,-12,1.2)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(preview/'body_front.png'); bpy.ops.render.render(write_still=True)
    for obj in parts: obj.hide_render=False
    # Inspect the wrap and facial accessories without the shield hiding them.
    for obj in parts:
        if obj['part'].startswith('Shield'): obj.hide_render=True
    camera.location=target+Vector((-12,-6,3.8)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(preview/'body_side.png'); bpy.ops.render.render(write_still=True)
    face_target=Vector((0,-.07,1.84)); camera.data.ortho_scale=.67
    camera.location=face_target+Vector((3,-12,2.0)); camera.rotation_euler=(face_target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(preview/'face_closeup.png'); bpy.ops.render.render(write_still=True)
    for obj in parts: obj.hide_render=False
    camera.data.ortho_scale=2.8
    camera.location=target+Vector((6,-12,5.6)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    exported=export_glb(dict(stem=STEM),scene,parts,rig,root,OUT)
    actual={a['name']:max(exported['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in exported['animations']}
    assert actual.keys()==clips.keys() and all(abs(actual[name]-clips[name])<.00001 for name in actual)
    for track in rig.animation_data.nla_tracks: track.mute=False; track.is_solo=False
    scene.timeline_markers.clear()
    for track in rig.animation_data.nla_tracks: scene.timeline_markers.new(track.name,frame=round(track.strips[0].frame_start))
    scene.frame_start=1; scene.frame_end=269; scene.frame_set(1)
    scene['description']='Orc squire, 2.00 m, unchanged bulky proportions and approved shield. Two angry projecting 3D brows, continuous leather baldric, complete sewn hide skirt, bound bone shoulder, stitched bracers and boots.'
    bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report=dict(stem=STEM,name='Escudeiro Orc Base',family='guardian',tier=0,character_height_m=2.0,
        status='PASS',pipeline='Open Blender MCP localhost:9876',source=str(SOURCE.relative_to(ROOT)),
        source_blend_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),geometry=geometry,
        texture=dict(size=[canvas.shape[1],canvas.shape[0]],filter='NEAREST',head_audit=head_audit,
                     painted_materials=materials,palette=dict(skin=SKIN,hair=HAIR,iron=IRON,leather=LEATHER,cloth=CLOTH,wood=WOOD,ivory=IVORY),
                     preserved_shield_regions=shield_regions,clothing_revision='continuous_wrapped_materials_v3'),
        rig=dict(bones=list(rig.data.bones.keys()),rigid_weights=True,ear_bone='head',tusk_bone='head',rest_bone_offsets=bone_offsets),
        clips=actual,inherited_animation_curves=True,removed_headwear=removed,tusks=tusks,
        source_ear_geometry=ear_source,body_armor_painted=True,head_hair_painted=True,bone_details=bone_details,
        brows=brows,brow_bone='head',brow_reference='tools/art_pipeline/build_dwarf_troops.py:130',
        relaxed_right_arm=relaxed_arm,enlarged_shield=enlarged_shield,
        refinement='Two angled 3D brows. Leather seams and bindings redesigned across every face; approved shield pixels and all 18 body cuboids preserved.')
    (OUT/(STEM+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.overlay.show_overlays=False
    bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
    scene.use_preview_range=True; scene.frame_preview_start=91; scene.frame_preview_end=118; scene.frame_set(91)
    bpy.ops.screen.animation_play()
    return dict(status='PASS',asset=STEM,height_m=hi[2],editable_parts=len(parts),clips=len(actual),scene=scene.name)
