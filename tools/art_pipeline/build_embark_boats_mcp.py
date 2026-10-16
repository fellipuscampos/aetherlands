"""Four small faction boats. Execute in the user's running Blender via MCP.

Existing scenes are retained. Sources are editable; game exports are consolidated.
Blender +Y bow becomes Godot -Z. The root is centered at the waterline.
"""
import bpy, bmesh, math, json, hashlib, struct
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
REVIEW = ROOT / 'art_source/embark_boats_review'
REVIEW.mkdir(parents=True, exist_ok=True)
(REVIEW / '.gdignore').touch()
PREFIX = 'Embark_Boats_V1'
RACES = {
    'human': dict(folder='humans', label='Barco Humano', length=2.8, width=1.12,
        wood=(128,86,48), wood_light=(166,119,68), wood_dark=(83,55,34),
        cloth=(49,83,143), cloth_light=(202,191,153), trim=(183,149,71),
        metal=(88,104,115), bone=(223,211,176)),
    'orc': dict(folder='orcs', label='Barco Orc', length=2.85, width=1.3,
        wood=(89,57,34), wood_light=(123,80,44), wood_dark=(55,40,28),
        cloth=(141,56,36), cloth_light=(173,130,86), trim=(111,121,105),
        metal=(51,66,68), bone=(219,204,163)),
    'elf': dict(folder='elves', label='Barco Elfo', length=3.0, width=.98,
        wood=(123,107,64), wood_light=(173,158,101), wood_dark=(77,73,43),
        cloth=(47,119,83), cloth_light=(221,217,172), trim=(205,181,98),
        metal=(124,147,127), bone=(215,213,177)),
    'dwarf': dict(folder='dwarves', label='Barco Anão', length=2.55, width=1.42,
        wood=(112,76,46), wood_light=(148,105,63), wood_dark=(66,48,36),
        cloth=(62,87,108), cloth_light=(177,114,61), trim=(183,117,62),
        metal=(65,80,89), bone=(196,193,167)),
}
REGIONS = ['wood','wood_light','wood_dark','cloth','cloth_light','trim','metal','bone','rope','linen','iron_light','shadow']
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
prior = {'scene': bpy.context.scene.name, 'filepath': bpy.data.filepath,
         'scene_names': [s.name for s in bpy.data.scenes]}
(REVIEW/'session_before.json').write_text(json.dumps(prior,ensure_ascii=False,indent=2),encoding='utf-8')
assert PREFIX+'_Review' not in bpy.data.scenes, 'Preserve previous boats.'
for race,p in RACES.items():
    assert not (ROOT/'assets/generated'/p['folder']/(race+'_embark_boat_v1')/(race+'_embark_boat_v1.glb')).exists(), 'Preserve previous export.'
boats = []
scene = root = mat = None
parts = []
groups = {}

def checkpoint(race, stage):
    (REVIEW/'current_stage.json').write_text(json.dumps(dict(race=race,stage=stage)),encoding='utf-8')

def mesh(name, vertices, faces, region, group='Hull'):
    data = bpy.data.meshes.new(root.name+'_'+name+'_Mesh')
    data.from_pydata(vertices,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), name+' has open edges'
    assert bm.calc_volume(signed=True)>1e-9, name+' has invalid volume'
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(root.name+'_'+name,data)
    groups[group].objects.link(obj); obj.parent=root
    obj['part']=name; obj['surface']=region
    data.materials.append(mat)
    uv=data.uv_layers.new(name='Pixel_UV')
    tile=REGIONS.index(region); tx=(tile%4)*128; ty=(tile//4)*128
    for poly in data.polygons:
        normal=poly.normal; drop=max(range(3),key=lambda i:abs(normal[i]))
        axes=[i for i in range(3) if i!=drop]
        values=[Vector((data.vertices[i].co[axes[0]], data.vertices[i].co[axes[1]])) for i in poly.vertices]
        low=Vector((min(v.x for v in values),min(v.y for v in values)))
        span=Vector((max(v.x for v in values),max(v.y for v in values)))-low
        density=min(64,112/max(span.x,span.y,.01))
        for li,v in zip(poly.loop_indices,values):
            uv.data[li].uv=((tx+8+(v.x-low.x)*density)/512,(ty+8+(v.y-low.y)*density)/512)
        poly.use_smooth=False
    parts.append(obj); return obj

def box(name, center, size, region, group='Details', frame=None):
    c=Vector(center); frame=frame or Matrix.Identity(3)
    return mesh(name,[c+frame@Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2))
        for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)],CUBE,region,group)

def beam(name,a,b,width,region,group='Rig',depth=None):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized()
    side=axis.cross(Vector((0,0,1)))
    if side.length<.01: side=Vector((1,0,0))
    side.normalize(); forward=axis.cross(side).normalized()
    return box(name,(a+b)/2,(width,depth or width,(b-a).length),region,group,Matrix((side,forward,axis)).transposed())

def prism(name, outline, z0,z1,region,group='Hull'):
    n=len(outline)
    return mesh(name,[(x,y,z) for z in (z0,z1) for x,y in outline],
        [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],region,group)

def tapered(name, points, radii, region, group='Details', sides=4):
    verts=[]
    for p,r in zip(points,radii):
        verts.extend([(p[0]+r*math.cos(2*math.pi*i/sides+math.pi/4),p[1]+r*math.sin(2*math.pi*i/sides+math.pi/4),p[2]) for i in range(sides)])
    faces=[tuple(reversed(range(sides))),tuple(range(len(verts)-sides,len(verts)))]
    for j in range(len(points)-1):
        faces.extend([(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i) for i in range(sides)])
    return mesh(name,verts,faces,region,group)

def atlas(race,p,out):
    colors=dict(p); colors.update(rope=(166,139,90),linen=(220,210,172),iron_light=(146,158,157),shadow=(47,49,42))
    pixels=np.ones((512,512,4),dtype=np.float32); pixels[:,:,:3]=.15
    orm=np.ones((512,512,4),dtype=np.float32); orm[:,:,2]=0
    for i,reg in enumerate(REGIONS):
        rng=np.random.default_rng(7611+list(RACES).index(race)*103+i)
        y,x=np.mgrid[0:120,0:120]
        noise=rng.integers(-4,5,(40,40)).repeat(3,0).repeat(3,1)
        tile=np.zeros((120,120,3)); tile[:]=colors[reg]; tile+=noise[:,:,None]
        if reg.startswith('wood'):
            grain=(((y//3)*19+x//17*7)%23)<3
            tile[grain]-=12; tile[(y%23==0)&(x%43<30)]-=19
            tile[(y%23==1)&(x%43<30)]+=9
            tile[((x//3*7+y//2*3)%157)<2]-=14
        elif reg in ('cloth','cloth_light','linen'):
            tile[((x%4==0)&(y%4==0))]-=8
            tile[(x+y)%8==0]+=3
        elif reg in ('metal','trim','iron_light'):
            tile[(((x//4)*13+(y//4)*7)%43)<2]+=12
        elif reg=='bone': tile[(x//3+y//11)%13==0]-=9
        padded=np.pad(np.clip(tile/255,0,1),((4,4),(4,4),(0,0)),mode='edge')
        xx,yy=(i%4)*128,(i//4)*128
        pixels[yy:yy+128,xx:xx+128,:3]=padded
        metallic=.72 if reg in ('metal','trim','iron_light') else 0
        roughness=.58 if metallic else .93
        orm[yy:yy+128,xx:xx+128,:3]=(1,roughness,metallic)
    images=[]
    for label,array,space in [('albedo',pixels,'sRGB'),('orm',orm,'Non-Color')]:
        im=bpy.data.images.new(race+'_embark_boat_v1_'+label,width=512,height=512,alpha=False)
        im.colorspace_settings.name=space; im.pixels.foreach_set(array.ravel())
        im.filepath_raw=str(out/(out.name+'_'+label+'.png')); im.file_format='PNG'; im.save(); im.pack(); images.append(im)
    material=bpy.data.materials.new(race+'_Embark_Pixel_Material'); material.use_nodes=True; material.use_backface_culling=True
    bsdf=material.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Specular IOR Level'].default_value=.22
    for im in images:
        tex=material.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
        if im==images[0]: material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        else:
            sep=material.node_tree.nodes.new('ShaderNodeSeparateColor'); sep.mode='RGB'; material.node_tree.links.new(tex.outputs['Color'],sep.inputs[0])
            material.node_tree.links.new(sep.outputs['Green'],bsdf.inputs['Roughness']); material.node_tree.links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])
    return material,images

def hull(race,p):
    L,W=p['length'],p['width']
    fractions=[-.5,-.34,-.13,.12,.31,.43,.5]
    widths=([.61,.92,1,1,.85,.46,.11] if race=='dwarf' else
            [.38,.85,1,1,.78,.43,.055] if race!='elf' else [.06,.64,.94,1,.69,.32,.035])
    profile=[(L*y,W*w/2) for y,w in zip(fractions,widths)]
    outline=[(w,y) for y,w in profile]+[(-w,y) for y,w in reversed(profile)]
    n=len(outline); verts=[]
    for layer in range(5):
        for x,y in outline:
            rise=max(0,(y/L-.23))*.48+max(0,(-y/L-.33))*.25
            if layer==0: point=(x*.46,y*.82,-.28)
            elif layer==1: point=(x*.79,y*.94,.035)
            elif layer==2: point=(x,y,.58+rise)
            elif layer==3: point=(x*.84,y*.94,.58+rise)
            else: point=(x*.56,y*.86,.235)
            verts.append(point)
    faces=[tuple(reversed(range(n)))]
    for layer in range(4):
        faces.extend([(layer*n+i,layer*n+(i+1)%n,(layer+1)*n+(i+1)%n,(layer+1)*n+i) for i in range(n)])
    faces.append(tuple(range(4*n,5*n)))
    mesh('Hollow_Planked_Hull',verts,faces,'wood')
    rail='trim' if race=='elf' else 'wood_dark'
    for sign in (-1,1):
        for i in range(len(profile)-1):
            a,b=profile[i],profile[i+1]
            z=lambda y:.59+max(0,(y/L-.23))*.48+max(0,(-y/L-.33))*.25
            beam('Gunwale_%s_%d'%(sign,i),(sign*a[1],a[0],z(a[0])),(sign*b[1],b[0],z(b[0])),.065,rail,'Hull')
            # Two dark rubbing strakes make the hull's planking readable on the map.
            for j,t in enumerate((.24,.65)):
                f=.79+(.21*t); zz=.035+(.545*t)
                beam('Strake_%s_%d_%d'%(sign,i,j),(sign*a[1]*f,a[0]*(.94+.06*t),zz),
                     (sign*b[1]*f,b[0]*(.94+.06*t),zz),.025,'wood_dark','Hull')
    def width_at(y):
        return float(np.interp(y,[a[0]*.86 for a in profile],[a[1]*.56 for a in profile]))
    for i in range(13):
        ya=-L*.415+i*L*.064; yb=ya+L*.060
        if yb>L*.415: continue
        a,b=width_at(ya)*.99,width_at(yb)*.99
        prism('Floor_Plank_%02d'%i,[(-a,ya),(a,ya),(b,yb),(-b,yb)],.239,.268,'wood_light','Deck')
    for i,y in enumerate((-.59,.54)):
        width=float(np.interp(y,[a[0] for a in profile],[a[1] for a in profile]))*1.55
        box('Thwart_Bench_%d'%i,(0,y,.49),(width,.19,.075),'wood_light','Deck')
        for sign in (-1,1): box('Bench_Support_%d_%d'%(i,sign),(sign*width*.37,y,.39),(.065,.12,.20),'wood_dark','Deck')
    beam('Keel', (0,-L*.39,-.30),(0,L*.42,-.30),.09,'wood_dark','Hull')
    # Rudder blade is small and remains within the compact boat footprint.
    box('Rudder', (0,-L*.49,-.025),(.055,.22,.41),'wood_dark','Rig')
    beam('Tiller',(0,-L*.49,.49),(0,-L*.29,.66),.06,'wood_light','Rig')
    return profile

def sail_grid(name,left,right,bottom,top,y,region,bulge=.15,torn=False):
    # Closed thin cloth volume, gently faceted. Never one-sided planes.
    nx,nz=6,5; verts=[]
    def point(u,v,side):
        w=(right-left)*(1-.13*(1-v))
        x=(left+right)/2+(u-.5)*w
        z=bottom+(top-bottom)*v
        if torn and v==0: z+=(.09 if round(u*nx)%2 else -.015)
        return (x,y-bulge*math.sin(math.pi*u)*math.sin(math.pi*v)+side*.012,z)
    for side in (-1,1):
        for j in range(nz+1):
            for i in range(nx+1): verts.append(point(i/nx,j/nz,side))
    N=(nx+1)*(nz+1); faces=[]
    for j in range(nz):
        for i in range(nx):
            k=j*(nx+1)+i
            faces.append((k,k+1,k+nx+2,k+nx+1)); faces.append((N+k,N+k+nx+1,N+k+nx+2,N+k+1))
    boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,nz+1)]+list(range(nz*(nx+1)+nx-1,nz*(nx+1)-1,-1))+[j*(nx+1) for j in range(nz-1,0,-1)]
    faces.extend([(a,b,N+b,N+a) for a,b in zip(boundary,boundary[1:]+boundary[:1])])
    mesh(name,verts,faces,region,'Sail')
    return lambda x,z:y-bulge*math.sin(math.pi*((x-(left+right)/2)/((right-left)*(1-.13*(1-(z-bottom)/(top-bottom))))+.5))*math.sin(math.pi*(z-bottom)/(top-bottom))+.032

def emblem_box(name,c,size,region='cloth_light'):
    return box(name,c,size,region,'Sail')

def rig(race,p):
    mast_y=.04 if race=='elf' else -.13; top={'human':2.67,'orc':2.49,'elf':2.83,'dwarf':2.28}[race]
    box('Mast_Step',(0,mast_y,.34),(.21,.23,.18),'metal' if race=='dwarf' else 'wood_dark','Rig')
    beam('Mast',(0,mast_y,.39),(0,mast_y,top),.09 if race!='orc' else .115,'wood_dark','Rig')
    for z in (.64,.77): box('Mast_Binding_'+str(z),(0,mast_y,z),(.125,.14,.045),'trim' if race in ('elf','dwarf') else 'rope','Rig')
    for sign in (-1,1):
        beam('Standing_Rigging_'+str(sign),(0,mast_y,top-.12),(sign*p['width']*.39,-.45,.59),.017,'rope','Rig')
    if race=='elf':
        # Broad leaf/lateen sail with angular contour and a visible central vein.
        outline=[(-.025,2.70),(.45,2.46),(.79,1.99),(.80,1.41),(.55,1.04),(-.025,.94)]
        verts=[(x,.085+side*.012,z) for side in (-1,1) for x,z in outline]; n=len(outline)
        mesh('Leaf_Lateen_Sail',verts,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],'cloth','Sail')
        for i in range(n):
            a,b=outline[i],outline[(i+1)%n]
            beam('Sail_Golden_Edge_'+str(i),(a[0],.106,a[1]),(b[0],.106,b[1]),.032,'trim','Sail')
        beam('Leaf_Vein',(0,.122,1.02),(.50,.122,2.30),.038,'cloth_light','Sail')
        for i,(a,b) in enumerate([((.18,1.47),(.66,1.43)),((.32,1.83),(.73,1.87)),((.32,1.83),(.12,2.21))]):
            beam('Leaf_Vein_Branch_'+str(i),(a[0],.122,a[1]),(b[0],.122,b[1]),.025,'cloth_light','Sail')
        beam('Sloping_Yard',(-.03,.045,2.73),(.84,.045,1.40),.056,'wood_light','Rig')
        beam('Sail_Sheet',(.56,.08,1.035),(.38,-.48,.59),.017,'rope','Rig')
        # Tall narrow forked prow, kept blocky like the elven buildings.
        for sign in (-1,1):
            tapered('Leaf_Prow_'+str(sign),[(sign*.055,1.36,.57),(sign*.095,1.49,.80),(sign*.075,1.52,1.00)], [.055,.065,.008],'trim','Hull')
        box('Stern_Green_Cushion',(0,-.85,.55),(.37,.22,.06),'cloth','Deck')
    else:
        half={'human':.77,'orc':.82,'dwarf':.75}[race]; low={'human':1.17,'orc':1.05,'dwarf':1.03}[race]
        high=top-.20
        surface=sail_grid('Square_Sail',-half,half,low,high,.11,'cloth',.12,race=='orc')
        beam('Yard',(-half-.08,.075,high+.045),(half+.08,.075,high+.045),.068 if race!='orc' else .09,'wood_light','Rig')
        beam('Yard_Mast_Support',(0,mast_y,high+.045),(0,.075,high+.045),.07,'wood_dark','Rig')
        for sign in (-1,1):
            beam('Sail_Sheet_'+str(sign),(sign*half*.87,.1,low+.03),(sign*p['width']*.4,-.42,.59),.018,'rope','Rig')
            box('Yard_Lashing_'+str(sign),(sign*half*.90,.075,high+.045),(.055,.10,.105),'rope','Rig')
        if race=='human':
            # Cream side panels and a simple gold sun. Emblem sits on cloth surface.
            for sign in (-1,1):
                sail_grid('Cream_Border_'+str(sign),sign*.62-.05,sign*.62+.05,low+.015,high-.015,.12,'cloth_light',0)
            mid=(low+high)/2
            for x,z,w,h in [(0,mid,.24,.24),(0,mid+.19,.07,.12),(0,mid-.19,.07,.12),(-.19,mid,.12,.07),(.19,mid,.12,.07)]:
                emblem_box('Sun_'+str(x)+'_'+str(z),(x,surface(x,z),z),(w,.024,h),'trim')
            box('Stern_Locker',(0,-.95,.42),(.52,.35,.27),'wood_light','Deck')
            box('Locker_Lid',(0,-.95,.575),(.56,.38,.045),'wood_dark','Deck')
            box('Locker_Latch',(0,-.76,.48),(.065,.022,.095),'trim','Deck')
            tapered('Prow_Post',[(0,1.35,.57),(0,1.47,.85)],[.065,.052],'wood_dark','Hull')
            box('Prow_Cap',(0,1.47,.875),(.14,.14,.055),'trim','Hull')
            beam('Pennant_Pole',(0,mast_y,top),(0,mast_y,top+.16),.035,'wood_dark','Rig')
            # Banner prism in XZ plane, closed with thickness.
            verts=[(x,y,z) for y in (mast_y-.015,mast_y+.015) for x,z in [(0,top+.14),(.30,top+.11),(.19,top+.03),(0,top+.035)]]
            mesh('Blue_Pennant',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'cloth','Rig')
        elif race=='orc':
            mid=(low+high)/2
            for i in range(7):
                z=mid-.23+i*.075
                for sign in (-1,1):
                    x=sign*(-.21+i*.07)
                    emblem_box('Bone_Sigil_%s_%d'%(sign,i),(x,surface(x,z),z),(.105,.024,.085),'bone')
            for x,z in [(-.56,1.33),(.51,1.98)]:
                emblem_box('Sail_Patch_'+str(x),(x,surface(x,z)+.008,z),(.18,.026,.15),'cloth_light')
            for sign in (-1,1):
                tapered('Prow_Tusk_'+str(sign),[(sign*.18,1.17,.56),(sign*.27,1.36,.87),(sign*.23,1.46,1.10),(sign*.17,1.49,1.23)], [.105,.077,.04,.008],'bone','Hull')
                # Chunky shield on each flank, with iron center and ivory slash.
                box('Side_Shield_'+str(sign),(sign*.625,-.22,.42),(.10,.39,.38),'wood_dark','Details')
                box('Shield_Iron_Boss_'+str(sign),(sign*.686,-.22,.42),(.055,.12,.13),'metal','Details')
                for y in (-.35,-.09): box('Shield_Bone_'+str(sign)+str(y),(sign*.689,y,.42),(.025,.045,.29),'bone','Details')
                for y in (-.72,.38):
                    box('Hull_Iron_Band_'+str(sign)+str(y),(sign*.55,y,.38),(.08,.09,.42),'metal','Hull')
            box('Cargo_Bundle',(0,-.98,.43),(.45,.28,.24),'cloth_light','Deck')
            for x in (-.14,.14): box('Cargo_Rope_'+str(x),(x,-.98,.555),(.026,.29,.022),'rope','Deck')
        else:
            # Copper-colored hammer on a slate-blue sail.
            mid=(low+high)/2
            for x,z,w,h in [(0,mid-.10,.085,.40),(0,mid+.14,.42,.15),(-.14,mid+.19,.14,.065),(.14,mid+.19,.14,.065)]:
                emblem_box('Hammer_'+str(x)+str(z),(x,surface(x,z),z),(w,.024,h),'cloth_light')
            for sign in (-1,1):
                sail_grid('Copper_Hem_'+str(sign),sign*.62-.035,sign*.62+.035,low+.01,high-.01,.128,'cloth_light',0)
            # Reinforced flat stem and large forged straps, not a warship superstructure.
            box('Copper_Stem',(0,1.20,.45),(.32,.16,.55),'trim','Hull')
            box('Copper_Stem_Cap',(0,1.20,.75),(.38,.20,.065),'trim','Hull')
            for sign in (-1,1):
                for i,y in enumerate((-.67,-.16,.36)):
                    x=sign*float(np.interp(y,[-1.27,-.87,-.33,.31,.79,1.10,1.275],[.433,.653,.71,.71,.604,.327,.078]))
                    box('Armor_Plate_%s_%d'%(sign,i),(x,y,.36),(.085,.41,.30),'metal','Hull')
                    box('Copper_Strap_%s_%d'%(sign,i),(x+sign*.012,y,.38),(.092,.075,.47),'trim','Hull')
                    for z in (.24,.53):
                        box('Rivet_%s_%d_%s'%(sign,i,z),(x+sign*.062,y,z),(.035,.05,.045),'iron_light','Details')
            box('Supply_Chest',(0,-.82,.44),(.56,.32,.28),'wood_dark','Deck')
            box('Chest_Lid',(0,-.82,.60),(.58,.34,.06),'metal','Deck')
            for x in (-.20,.20): box('Chest_Band_'+str(x),(x,-.82,.62),(.055,.36,.027),'trim','Deck')
            # Compact copper bollards for the stout workboat.
            for sign in (-1,1):
                box('Bollard_'+str(sign),(sign*.47,-.93,.69),(.08,.08,.17),'metal','Details')
                box('Bollard_Cap_'+str(sign),(sign*.47,-.93,.79),(.14,.10,.04),'trim','Details')

def studio(sc,name,scale=4.15):
    world=bpy.data.worlds.new(name+'_World'); world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.23,.29,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.7; sc.world=world
    target=Vector((0,0,1.13))
    for label,pos,power,size,color in [('Key',(3,4,7),650,5,(1,.94,.83)),('Fill',(-4,2,4),420,4,(.78,.87,1)),('Rim',(0,-4,5),600,3,(.84,.94,1))]:
        data=bpy.data.lights.new(name+'_'+label,'AREA'); data.energy=power; data.size=size; data.color=color
        obj=bpy.data.objects.new(data.name,data); sc.collection.objects.link(obj); obj.location=pos
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new(name+'_Camera'); camera=bpy.data.objects.new(data.name,data); sc.collection.objects.link(camera)
    data.type='ORTHO'; data.ortho_scale=scale; camera.location=(4.4,6.4,4.2)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); sc.camera=camera
    sc.render.engine='CYCLES'; sc.cycles.samples=20; sc.cycles.use_denoising=True
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.get_devices()
        if any(d.use and d.type in ('CUDA','OPTIX') for d in prefs.devices): sc.cycles.device='GPU'
    except Exception: pass
    sc.render.resolution_x=sc.render.resolution_y=800; sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'; sc.render.film_transparent=True
    sc.view_settings.view_transform='Standard'
    return camera,target

def export_game(out, race):
    # Four logical mesh groups; source objects remain individually editable.
    export_scene=bpy.data.scenes.new(out.name+'_Export_Temporary'); ids={export_scene}
    eroot=bpy.data.objects.new(out.name,None); export_scene.collection.objects.link(eroot); ids.add(eroot)
    eroot['race']=race; eroot['waterline']=0.0; eroot['forward']='Godot -Z'; eroot['purpose']='one embarked unit'
    try:
        for label in ('Hull','Deck','Rig','Sail','Details'):
            sources=[o for o in parts if o in groups[label].objects[:]]
            if not sources: continue
            verts=[];faces=[];uvs=[]
            for obj in sources:
                offset=len(verts); verts.extend(tuple(v.co) for v in obj.data.vertices)
                faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
                uvs.extend(tuple(v.uv) for v in obj.data.uv_layers.active.data)
            data=bpy.data.meshes.new(out.name+'_'+label+'_Export'); data.from_pydata(verts,[],faces); data.update()
            uv=data.uv_layers.new(name='Pixel_UV')
            for loop,value in zip(uv.data,uvs): loop.uv=value
            data.materials.append(mat); ids.add(data)
            obj=bpy.data.objects.new(label,data); export_scene.collection.objects.link(obj); obj.parent=eroot; ids.add(obj)
        bpy.context.window.scene=export_scene
        for obj in export_scene.objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=eroot
        bpy.ops.export_scene.gltf(filepath=str(out/(out.name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
            export_yup=True,export_cameras=False,export_lights=False,export_animations=False,export_skins=False,export_extras=True)
    finally:
        bpy.context.window.scene=scene; bpy.data.batch_remove(ids=ids)

for race,p in RACES.items():
    checkpoint(race,'model')
    stem=race+'_embark_boat_v1'; out=ROOT/'assets/generated'/p['folder']/stem
    out.mkdir(parents=True,exist_ok=True); (out/'previews').mkdir(exist_ok=True)
    scene=bpy.data.scenes.new(PREFIX+'_'+race.title()); bpy.context.window.scene=scene
    root=bpy.data.objects.new(stem+'_ROOT',None); scene.collection.objects.link(root)
    root['race']=race; root['purpose']='one embarked unit'; root['bow_axis']='+Y'; root['waterline_z']=0.0
    root['recommended_map_scale']=.52
    parts=[]; groups={}
    for label in ('Hull','Deck','Rig','Sail','Details'):
        collection=bpy.data.collections.new(stem+'_'+label); scene.collection.children.link(collection); groups[label]=collection
    mat,images=atlas(race,p,out)
    hull(race,p); rig(race,p)
    camera,target=studio(scene,stem)
    # Render-only dark water is separate from the exported asset.
    floor_data=bpy.data.meshes.new(stem+'_Preview_Water'); floor_data.from_pydata([(-50,-50,-.004),(50,-50,-.004),(50,50,-.004),(-50,50,-.004)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new(stem+'_Preview_Water',floor_data); scene.collection.objects.link(floor)
    water=bpy.data.materials.new(stem+'_Preview_Water'); water.diffuse_color=(.045,.13,.18,1); water.use_nodes=True
    wb=water.node_tree.nodes['Principled BSDF']; wb.inputs['Base Color'].default_value=(.045,.13,.18,1); wb.inputs['Roughness'].default_value=.33; wb.inputs['Metallic'].default_value=.15
    floor_data.materials.append(water); floor['preview_only']=True
    checkpoint(race,'export')
    export_game(out,race)
    raw=(out/(stem+'.glb')).read_bytes(); assert struct.unpack_from('<III',raw)==(0x46546C67,2,len(raw))
    jl=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+jl])
    assert len(doc['materials'])==1 and len(doc['images'])==2
    assert not doc.get('cameras') and not doc.get('animations') and not doc.get('skins')
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    points=[v.co for obj in parts for v in obj.data.vertices]
    minimum=[min(v[i] for v in points) for i in range(3)]; maximum=[max(v[i] for v in points) for i in range(3)]
    triangles=sum(doc['accessors'][primitive['indices']]['count']//3 for m in doc['meshes'] for primitive in m['primitives'])
    report=dict(race=race,name=p['label'],stem=stem,scene=scene.name,glb=(out/(stem+'.glb')).relative_to(ROOT).as_posix(),
        editable_parts=len(parts),triangles=triangles,game_meshes=len(doc['meshes']),materials=1,embedded_textures=2,
        texture_size=[512,512],filter='nearest',closed_source_meshes=True,bounds_blender=dict(min=minimum,max=maximum),
        waterline=0,forward_godot='-Z',recommended_map_scale=.52,unit_representation='1 unit = 1 boat',
        source_preservation='Existing scenes and assets retained; only new IDs created.',
        glb_sha256=hashlib.sha256(raw).hexdigest())
    checkpoint(race,'render')
    views={'three_quarter':((4.4,6.4,4.2),4.15,Vector((0,0,1.14))),
           'game_top':((3.2,5.0,6.8),3.95,Vector((0,0,.91))),
           'side':((6,.4,2.8),3.95,Vector((0,0,1.16))),
           'top':((0,0,8),3.70,Vector((0,0,0)))}
    for label,(position,scale,aim) in views.items():
        checkpoint(race,'render_'+label)
        camera.location=position; camera.data.ortho_scale=scale
        camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
    # A dry studio view shows the submerged hull and pivot placement.
    floor.hide_render=True; camera.location=(4.4,6.4,4.2); camera.data.ortho_scale=4.15
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/'previews'/'dry_hull.png'); bpy.ops.render.render(write_still=True)
    floor.hide_render=False
    scene['asset']=stem; scene['civilization']=race; scene['waterline']=0.; scene['map_scale']=.52
    checkpoint(race,'save_source')
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},fake_user=True,compress=True)
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    boats.append(dict(scene=scene,root=root,parts=parts[:],material=mat,report=report,out=out))

# Open a clean four-boat lineup in the existing Blender window.
checkpoint('all','review_scene')
review=bpy.data.scenes.new(PREFIX+'_Review'); bpy.context.window.scene=review
for i,boat in enumerate(boats):
    collection=bpy.data.collections.new(PREFIX+'_'+boat['report']['race']+'_Review'); review.collection.children.link(collection)
    r=boat['root'].copy(); collection.objects.link(r); r.location=((i-1.5)*2.28,0,0)
    for part in boat['parts']:
        obj=part.copy(); collection.objects.link(obj); obj.parent=r
    text=bpy.data.curves.new(PREFIX+'_Label_'+str(i),'FONT'); text.body=boat['report']['name'].upper(); text.align_x='CENTER'; text.size=.20; text.extrude=.001
    label=bpy.data.objects.new(text.name,text); collection.objects.link(label); label.location=((i-1.5)*2.28,2.1,.035)
    # Text lies flat on the review's surface, facing the high camera.
    label.data.materials.append(boat['material'])
camera,target=studio(review,PREFIX+'_Review',12)
camera.location=(5.2,10,8.2); target=Vector((0,0,1.0))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=11.1
review.render.resolution_x=1600; review.render.resolution_y=850
review.render.filepath=str(REVIEW/'four_boats.png'); bpy.ops.render.render(write_still=True)
# A .blend library snapshot excludes the hundreds of unrelated scenes.
bpy.data.libraries.write(str(REVIEW/'embark_boats_v1_review.blend'),{review,*[b['scene'] for b in boats]},fake_user=True,compress=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active; space.shading.type='MATERIAL'
            space.region_3d.view_distance=10.8; space.region_3d.view_location=(0,0,1.)
            space.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
manifest=dict(version=1,purpose='One small boat per embarked unit, one design per faction.',
    waterline_origin=True,forward_godot='-Z',recommended_map_scale=.52,
    assets=[b['report'] for b in boats],source_scene_count_before=len(prior['scene_names']),
    original_scenes_retained=all(n in bpy.data.scenes for n in prior['scene_names']))
(REVIEW/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.app.driver_namespace['embark_boats_v1']=boats
result=dict(status='PASS',boats=[dict(race=b['report']['race'],triangles=b['report']['triangles'],editable_parts=b['report']['editable_parts']) for b in boats],
    review_scene=review.name,original_scenes_retained=manifest['original_scenes_retained'])
