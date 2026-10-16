"""Original lair art. Execute only inside Blender, through localhost:9876 MCP.

No game source, existing asset, active scene or running process is replaced.
The delivery folder has .gdignore until the game owner integrates the assets.
"""
import bpy
import bmesh
import numpy as np
import math
import json
import random
from pathlib import Path
from mathutils import Vector, Euler

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
OUT = ROOT / 'assets/generated/monster_lairs_v2'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').touch()
TAU = math.tau

ROWS = [
 ('goblin','Básico','Acampamento de saqueadores','Tenda remendada, paliçada irregular, saque e fogueira apagada.'),
 ('skeleton','Básico','Cripta violada','Sepultura aberta e ossário sob um arco funerário partido.'),
 ('worg','Básico','Toca das raízes','Abrigo baixo entre raízes de árvore caída, ossos de presas e terra pisada.'),
 ('giant_spider','Básico','Ninho de seda','Troncos mortos sustentam teias poligonais, casulos e bolsas de ovos.'),
 ('troll','Intermediário','Abrigo sob a laje','Caverna de blocos pesados, musgo, clava e restos de uma refeição.'),
 ('wyvern','Intermediário','Poleiro da escarpa','Escarpa escalonada com galhos chamuscados, ovos e ossos na plataforma.'),
 ('minotaur','Intermediário','Labirinto arruinado','Paredes baixas em meandro, porta com chifres e troféu de crânio bovino.'),
 ('basilisk','Intermediário','Ninho da petrificação','Ninho de gravetos e palha em rocha árida, ovos manchados e presas petrificadas.'),
 ('colossal_worm','Avançado','Poço de escavação','Funil profundo entre placas de areia rompida, túneis escuros e cascas segmentadas.'),
 ('arboreal_ancient','Avançado','Berço de pedra viva','Pedras de espiral ancestral, raízes e musgo em torno de um núcleo verde.'),
 ('mana_devourer','Avançado','Jazida arcana exaurida','Leito cúbico fraturado, cristais drenados e fendas violetas na rocha.'),
 ('corrupted_hero','Avançado','Vigília abandonada','Posto militar em ruínas, assento vazio, estandarte gasto e escudo-torre esquecido.'),
]

# Hand-drawn material vocabulary. Shared atlas, nearest filtering, no shader dependency.
PALETTE = [
 ('earth',(77,58,40)), ('dirt',(109,80,48)), ('sand',(184,139,76)),
 ('sand_light',(214,178,112)), ('stone',(109,119,125)), ('stone_light',(157,166,165)),
 ('slate',(60,73,83)), ('black',(23,27,30)), ('wood',(98,61,34)),
 ('wood_light',(143,97,49)), ('endgrain',(160,112,62)), ('moss',(70,104,42)),
 ('grass',(108,131,55)), ('cloth',(116,84,43)), ('cloth_patch',(152,119,64)),
 ('red',(116,40,36)), ('iron',(78,87,92)), ('bone',(219,206,163)),
 ('silk',(196,208,191)), ('egg',(217,199,139)), ('charcoal',(45,40,38)),
 ('ember',(193,86,26)), ('green',(76,181,101)), ('violet',(160,93,214)),
 ('crystal',(120,113,144)), ('deadwood',(89,85,78)), ('bluecloth',(59,75,100)),
 ('rust',(127,79,49)), ('pale_stone',(178,181,161)), ('straw',(165,127,58)),
 ('root',(91,73,43)), ('rune',(134,220,147)),
 ('chitin_amber',(170,108,39)), ('chitin_dark',(43,36,40)),
 ('wyvern_egg',(179,172,148)), ('spider_egg',(174,190,145)),
]
P = {name:i for i,(name,col) in enumerate(PALETTE)}

def atlas():
    name='Lairs_V2_PixelAtlas'
    existing=bpy.data.materials.get(name)
    if existing: return existing
    size=1024; cell=128
    pix=np.ones((size,size,4),dtype=np.float32)
    em=np.ones((size,size,4),dtype=np.float32); em[:,:,:3]=0
    for i,(key,col) in enumerate(PALETTE):
        rng=np.random.default_rng(6014+i)
        tile=np.zeros((cell,cell,3),dtype=np.float32); tile[:]=col
        # Restrained 2px blocks, sparse long marks, and deliberately authored grain.
        tile += rng.integers(-4,5,(64,64)).repeat(2,0).repeat(2,1)[:,:,None]
        for j in range(42):
            x,y=rng.integers(3,112,2); w=int(rng.integers(2,10)); h=int(rng.integers(1,4))
            tile[y:y+h,x:x+w] += rng.choice([-12,9])
        if key in ('wood','wood_light','deadwood','root'):
            for y in range(5,128,12):
                tile[y:y+2,:]-=14
                for x in range((y*7)%19,120,28): tile[y+3:y+4,x:x+19]+=14
        if key=='endgrain':
            yy,xx=np.mgrid[:128,:128]
            rings=np.maximum(abs(xx-64),abs(yy-64))
            tile[(rings%5)==0]-=35
        if key in ('cloth','cloth_patch','red','bluecloth'):
            tile[::8,:,:]-=5; tile[:,::8,:]-=5
            for x in range(5,128,8): tile[5:7,x:x+3]+=27
        if key in ('stone','stone_light','slate','pale_stone'):
            for j in range(6):
                x,y=rng.integers(4,94,2)
                tile[y:y+2,x:x+17]-=21; tile[y:y+11,x+15:x+17]-=21
        if key in ('egg','wyvern_egg','spider_egg'):
            # Dense enough to remain legible on a 10-20px shell face at map scale.
            for yy in range(3,128,8):
                for xx in range(3,128,9):
                    x=xx+int(rng.integers(-2,3)); y=yy+int(rng.integers(-2,3))
                    tile[y:y+2,x:x+2]=np.array(col)*(.56 if key!='spider_egg' else .76)
        if key=='straw':
            for y in range(2,120,5): tile[y:y+1,(y*3)%31:115]+=24
        if key=='silk':
            yy,xx=np.mgrid[:128,:128]
            tile[((xx+yy)%9)<2]+=15; tile[((xx-yy)%13)==0]-=11
        if key=='iron':
            # Sparse corrosion rather than a uniformly new steel surface.
            for j in range(26):
                x,y=rng.integers(2,118,2); tile[y:y+3,x:x+5]=(113,79,53)
        x=(i%8)*cell; y=(i//8)*cell
        pix[y:y+cell,x:x+cell,:3]=np.clip(tile/255,0,1)
        if key in ('green','violet','rune','ember'):
            em[y:y+cell,x:x+cell,:3]=np.clip(np.array(col)/255,0,1)
    imgs=[]
    for suffix,data in [('albedo',pix),('emission',em)]:
        img=bpy.data.images.new(name+'_'+suffix,size,size,alpha=False)
        img.pixels.foreach_set(data.ravel()); img.filepath_raw=str(OUT/('lairs_v2_'+suffix+'.png'))
        img.file_format='PNG'; img.save(); img.pack(); imgs.append(img)
    mat=bpy.data.materials.new(name); mat.use_nodes=True; mat.use_backface_culling=True
    bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.86
    bs.inputs['Specular IOR Level'].default_value=.18
    for idx,target in [(0,'Base Color'),(1,'Emission Color')]:
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=imgs[idx]; tex.interpolation='Closest'
        mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[target])
    bs.inputs['Emission Strength'].default_value=.28
    return mat

class Builder:
    def __init__(self,scene,kind):
        self.scene=scene; self.kind=kind; self.parts=[]; self.rng=random.Random(104+sum(map(ord,kind)))
        self.collection=bpy.data.collections.new(kind+'_editable_parts'); scene.collection.children.link(self.collection)
        self.mat=atlas()

    def mesh(self,name,verts,faces,paint):
        original_paints=list(paint) if isinstance(paint,(tuple,list)) else [paint]*len(faces)
        fixed_faces=[]; fixed_paints=[]
        for indices,surface in zip(faces,original_paints):
            points=[Vector(verts[j]) for j in indices]
            normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
            warped=len(indices)>3 and any(abs((v-points[0]).dot(normal))>1e-6 for v in points[3:])
            triangles=[(indices[0],indices[j],indices[j+1]) for j in range(1,len(indices)-1)] if warped else [indices]
            fixed_faces.extend(triangles); fixed_paints.extend([surface]*len(triangles))
        faces=fixed_faces
        me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
        bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
        ob=bpy.data.objects.new(name,me); self.collection.objects.link(ob)
        me.materials.append(self.mat); ob['surface']=paint if isinstance(paint,str) else ','.join(paint)
        ob['piece']=name; self.parts.append(ob)
        paints=fixed_paints
        uv=me.uv_layers.new(name='PixelAtlas')
        # UVs will be assigned after the fit-to-tile scale, keeping 64px/m.
        ob['_paints']=list(paints)
        return ob

    def box(self,name,c,size,mat='stone',rot=(0,0,0),top=None):
        dx,dy,dz=[s/2 for s in size]; e=Euler(rot)
        verts=[tuple(e.to_matrix()@Vector((x,y,z))+Vector(c)) for z in (-dz,dz) for x,y in [(-dx,-dy),(dx,-dy),(dx,dy),(-dx,dy)]]
        paints=[mat,top or mat,mat,mat,mat,mat]
        return self.mesh(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],paints)

    def beam(self,name,a,b,width,mat='wood',depth=None):
        av,bv=Vector(a),Vector(b); d=bv-av
        return self.box(name,(av+bv)/2,(width,depth or width,d.length),mat,d.to_track_quat('Z','Y').to_euler())

    def rock(self,name,c,size,mat='stone',rot=0,top=None):
        # Eight corners with a single clipped edge: a squared rock, never a rounded boulder.
        x,y,z=size; cut=.22
        poly=[(-.5,-.5),(.5-cut,-.5),(.5,-.5+cut),(.5,.5),(-.5,.5)]
        verts=[]
        for zz,factor in [(-z/2,1),(z/2,.84)]:
            for xx,yy in poly:
                vx=xx*x*factor; vy=yy*y*factor
                verts.append((c[0]+vx*math.cos(rot)-vy*math.sin(rot),c[1]+vx*math.sin(rot)+vy*math.cos(rot),c[2]+zz))
        return self.mesh(name,verts,[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],
                         [mat,top or mat]+[mat]*5)

    def taper(self,name,c,width,height,mat='bone',tip=(0,0)):
        x,y,z=c; w=width/2
        return self.mesh(name,[(x-w,y-w,z),(x+w,y-w,z),(x+w,y+w,z),(x-w,y+w,z),(x+tip[0],y+tip[1],z+height)],
                         [(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],mat)

    def base(self,mat='earth',radius=2.05):
        # Low broken ground, without the repeating ten-petal outline of V1.
        self.rock('Terrain_center',(0,.05,.09),(radius*1.55,radius*1.60,.18),mat,top=mat)
        for i,a in enumerate((-.38,.68,1.84,2.70,3.81,4.83)):
            r=radius*self.rng.uniform(.67,.80)
            self.rock('Terrain_edge_%02d'%i,(math.cos(a)*r,math.sin(a)*r,.035),
                (self.rng.uniform(.7,1.1),self.rng.uniform(.55,.85),.07),mat,a+.27,mat)

    def bone(self,c,length=.65,angle=0,mat='bone'):
        x,y,z=c; a=(x-math.cos(angle)*length/2,y-math.sin(angle)*length/2,z)
        b=(x+math.cos(angle)*length/2,y+math.sin(angle)*length/2,z)
        self.beam('Prey_bone',a,b,.09,mat)
        for point in (a,b): self.box('Bone_knuckle',point,(.16,.15,.13),mat,rot=(0,0,angle))

    def skull(self,c,scale=.4,mat='bone',horns=False):
        x,y,z=c; s=scale
        self.box('Skull',(x,y,z+s*.45),(s*.85,s*.7,s*.8),mat)
        self.box('Skull_jaw',(x,y-s*.10,z+.05*s),(s*.65,s*.78,s*.2),mat)
        for xx in (-.23,.23): self.box('Eye_socket',(x+s*xx,y-s*.357,z+s*.5),(s*.21,.012,s*.2),'black')
        self.box('Nose_socket',(x,y-s*.41,z+s*.28),(s*.13,.012,s*.14),'black')
        if horns:
            for sign in (-1,1):
                self.beam('Horn_root',(x+sign*s*.35,y,z+s*.75),(x+sign*s*.85,y,z+s*.94),s*.18,mat)
                self.taper('Horn_tip',(x+sign*s*.85,y,z+s*.94),s*.19,s*.45,mat,tip=(sign*s*.16,0))

    def egg(self,c,scale=.45,mat='egg'):
        x,y,z=c; s=scale
        # Connected chamfered cuboid shell. Broad waist, tapered crown, no pot-like rim.
        outline=[(-.3,-.5),(.3,-.5),(.5,-.3),(.5,.3),(.3,.5),(-.3,.5),(-.5,.3),(-.5,-.3)]
        rings=[(.02,.50),(.19,.87),(.57,.90),(.83,.60),(.94,.24)]
        verts=[(x+u*s*w,y+v*s*w,z+h*s) for h,w in rings for u,v in outline]
        faces=[tuple(reversed(range(8))),tuple(range(32,40))]
        faces += [(k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j) for k in range(4) for j in range(8)]
        return self.mesh('Silk_cocoon' if mat=='silk' else 'Faceted_egg',verts,faces,mat)

    def animal_skull(self,c,scale=.4,horns=False):
        x,y,z=c; s=scale; z-=s*.065
        self.box('Prey_cranium',(x,y,z+s*.43),(s*.78,s*.66,s*.62),'bone')
        self.box('Prey_long_muzzle',(x,y-s*.45,z+s*.23),(s*.46,s*.73,s*.33),'bone')
        for sign in (-1,1):
            self.box('Prey_eye_socket',(x+sign*s*.40,y-s*.13,z+s*.47),(s*.025,s*.19,s*.18),'black')
            self.box('Prey_nostril',(x+sign*s*.12,y-s*.82,z+s*.25),(s*.075,s*.014,s*.11),'black')
            if horns:
                self.beam('Prey_horn',(x+sign*s*.32,y,z+s*.60),(x+sign*s*.78,y+.1*s,z+s*.76),s*.14,'bone')
                self.taper('Prey_horn_tip',(x+sign*s*.78,y+.1*s,z+s*.76),s*.15,s*.42,'bone',(sign*s*.14,0))

    def grass(self,c,mat='grass'):
        x,y,z=c; z=max(z,.183)
        for i in range(3): self.box('Square_grass',(x+(i-1)*.09,y,z+.11+i*.035),(.055,.11,.22+i*.07),mat,rot=(0,(i-1)*.24,0))

    def nest(self,center,radius=1.05,z=.25,mat='wood',layers=3):
        x,y=center
        self.rock('Nest_bedding',(x,y,z-.025),(radius*1.55,radius*1.55,.13),'straw',top='straw')
        for layer in range(layers):
            for i in range(12):
                a=TAU*i/12+(layer%2)*.13
                rr=radius+self.rng.uniform(-.055,.045)
                self.box('Woven_branch',(x+math.cos(a)*rr,y+math.sin(a)*rr,z+layer*.105+self.rng.uniform(-.018,.018)),
                    (self.rng.uniform(.62,.81),.115,.11),mat,rot=(.04*math.sin(i),.06*math.cos(i),a+math.pi/2+self.rng.uniform(-.08,.08)))

def goblin(b):
    b.base();
    # A real triangular, open-front canvas shelter, with thick closed panels.
    b.box('Tent_floor',(0,.45,.18),(2.35,2.15,.14),'wood')
    for sign in (-1,1):
        b.beam('Tent_ridge_support',(sign*0,.45+sign*.95,.22),(0,.45+sign*.95,2.10),.13,'wood_light')
    b.beam('Tent_ridge',(0,-.70,2.10),(0,1.70,2.10),.15,'wood_light')
    for s in (-1,1):
        verts=[(s*.04,-.62,2.08),(s*1.18,-.62,.25),(s*1.18,1.55,.25),(s*.04,1.55,2.08)]
        # Panels are prisms, giving canvas thickness and visible open entrance.
        verts += [(x,y+.035,z-.035) for x,y,z in verts]
        b.mesh('Canvas_roof',verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'cloth')
        b.box('Canvas_patch',(s*.76,.55,.97),(.05,.48,.44),'cloth_patch',rot=(0,-s*.57,0))
        b.beam('Guy_rope',(s*.94,-.61,.58),(s*1.52,-1.04,.14),.032,'straw')
        b.box('Tent_peg',(s*1.52,-1.04,.18),(.10,.10,.38),'wood_light',rot=(0,s*.2,0))
    # Rear cloth triangle, entrance remains a genuine cavity.
    b.mesh('Canvas_back',[(-1.14,1.52,.25),(1.14,1.52,.25),(0,1.52,2.03),(-1.14,1.56,.25),(1.14,1.56,.25),(0,1.56,2.03)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],'cloth')
    for i in range(8):
        x=-1.65+i*.46; y=1.8+math.sin(i)*.1; h=.65+.15*(i%3)
        b.box('Crooked_palisade',(x,y,h/2),(.22,.18,h),'wood',rot=(0,.06*(i%3-1),0))
        b.taper('Stake_point',(x,y,h),.22,.21,'wood_light')
    for y in (.25,.65): b.beam('Palisade_lashing',(-1.78,1.68,y),(1.72,1.68,y),.08,'root')
    b.box('Loot_crate',(1.3,.45,.43),(.65,.65,.62),'wood_light')
    for z in (.22,.65): b.box('Crate_iron_band',(1.3,.45,z),(.67,.68,.06),'iron')
    b.box('Loot_red_cloth',(1.33,.43,.76),(.47,.46,.07),'red')
    for i in range(8):
        a=TAU*i/8; b.rock('Hearth_stone',(-.55+.42*math.cos(a),-1.15+.32*math.sin(a),.16),(.25,.24,.17),'slate',a)
    for i in range(3): b.box('Burned_log',(-.55+(i-1)*.14,-1.15,.18),(.12,.55,.12),'charcoal',rot=(0,0,(i-1)*.45))
    for i in range(3): b.grass((-1.45+i*.2,.9,.1))

def skeleton(b):
    b.base('dirt')
    # Hollow sarcophagus with displaced lid and staircase into darkness.
    b.box('Grave_shadow',(0,-.16,.145),(1.12,1.90,.07),'black')
    for x in (-.73,.73): b.box('Sarcophagus_side',(x,-.08,.40),(.30,2.28,.60),'stone',top='stone_light')
    b.box('Sarcophagus_head',(0,.95,.40),(1.18,.25,.60),'stone',top='stone_light')
    b.box('Sarcophagus_foot',(0,-1.09,.28),(1.18,.23,.34),'stone')
    for i in range(3): b.box('Grave_step',(0,-1.56+i*.16,.08+i*.045),(1.0,.18,.16),'slate')
    b.box('Dislodged_tomb_lid',(-1.25,.10,.54),(.28,1.95,1.0),'pale_stone',rot=(0,-.36,.12))
    for x in (-1.09,1.09):
        for level in range(3): b.box('Funerary_arch_pier',(x,1.2,.30+level*.52),(.47,.5,.49),'stone',top='stone_light')
        b.box('Arch_capital',(x,1.2,1.79),(.65,.63,.18),'pale_stone')
    b.box('Broken_arch_lintel',(-.57,1.2,2.02),(1.62,.56,.35),'stone_light')
    b.box('Broken_arch_fragment',(1.44,-.62,.29),(.60,.56,.44),'stone_light',rot=(0,.19,.4))
    b.skull((-.35,1.16,2.17),.47)
    for i in range(7): b.bone((b.rng.uniform(-.43,.43),b.rng.uniform(-.6,.7),.22),.54,b.rng.random()*TAU)
    b.skull((.14,-.6,.23),.34)
    for x,y,h in [(-1.6,-.95,.65),(1.48,.65,.85),(.8,-1.6,.38)]:
        b.box('Gravestone',(x,y,.1+h/2),(.38,.16,h),'slate',rot=(0,.13,x*.12))
        b.box('Gravestone_mark',(x,y-.085,h*.7),(.19,.015,.055),'stone_light')

def worg(b):
    b.base()
    # Dark recess under a fallen hollow tree, not a miniature human hut.
    b.box('Burrow_dark_back',(0,.66,.57),(1.7,.18,.94),'black')
    for s in (-1,1):
        b.rock('Earthen_bank',(s*1.07,.55,.51),(.92,1.55,.9),'earth',top='moss')
        b.beam('Great_root',(s*1.20,.35,1.0),(s*1.48,-.75,.13),.30,'root')
        b.beam('Root_tip',(s*1.48,-.75,.13),(s*1.83,-1.14,.09),.17,'root')
    b.box('Fallen_trunk',(0,.72,1.12),(3.35,.86,.65),'wood',rot=(0,.04,.10),top='moss')
    b.box('Trunk_cut_end',(1.68,.88,1.10),(.025,.81,.57),'endgrain',rot=(0,0,.10))
    b.beam('Broken_branch',(-.8,.9,1.35),(-1.2,1.32,1.93),.25,'wood')
    b.box('Branch_broken_end',(-1.2,1.32,1.96),(.20,.21,.04),'endgrain')
    b.rock('Den_bedding',(0,.04,.17),(1.48,1.08,.09),'straw')
    for i in range(4): b.bone((.65+i*.13,-1.05+(i%2)*.3,.18),.4+i*.08,i*.9)
    b.skull((-.85,-1.18,.14),.35)
    for x in (-.25,0,.25): b.beam('Territorial_claw_mark',(x,-.25,.22),(x+.10,-.82,.15),.027,'black')
    for i in range(6): b.grass((-1.4+i*.55,1.30,.12))

def giant_spider(b):
    b.base('earth')
    # Snag tripod and thick web spokes; no transparent materials required.
    anchors=[(-1.25,.6,2.35),(1.35,.9,2.05),(.42,-.8,1.78)]
    for i,(x,y,z) in enumerate(anchors):
        b.box('Dead_tree_stump',(x,y,z/2),(.40,.38,z),'deadwood',rot=(0,.10*(-1)**i,.08*(i-1)))
        b.beam('Snag_fork',(x,y,z*.72),(x+(-.45 if i%2==0 else .42),y+.20,z+.26),.14,'deadwood')
        for j in range(3): b.beam('Stump_root',(x,y,.2),(x+math.cos(j*TAU/3)*.55,y+math.sin(j*TAU/3)*.55,.1),.15,'root')
    a=Vector(anchors[0]); c=Vector(anchors[1]); center=(a+c)/2-Vector((0,.12,.50))
    ends=[a,c,a*.72+c*.28,a*.28+c*.72,Vector((-.9,.65,.42)),Vector((.9,.85,.38))]
    for e in ends: b.beam('Silk_radial',center,e,.027,'silk')
    for t in (.27,.50,.73,.94):
        ring=[center+(e-center)*t for e in ends]
        # Ordered outer ring in the web plane.
        ring=[ring[i] for i in [0,2,3,1,5,4]]
        for i in range(len(ring)): b.beam('Silk_cross_thread',ring[i],ring[(i+1)%len(ring)],.019,'silk')
    for i,(x,y,z,s) in enumerate([(-.55,.35,.20,.64),(.55,.25,.20,.51),(.80,1.1,.18,.37)]):
        b.egg((x,y,z),s,'silk')
        for j in range(3): b.box('Cocoon_wrap',(x,y,z+s*(.24+j*.18)),(s*.79,s*.76,.035),'stone_light')
    b.beam('Hanging_silk',(.65,.85,1.92),(.65,.85,1.18),.025,'silk')
    b.egg((.65,.85,.77),.43,'silk')
    for i in range(5): b.egg((-.15+(i%3)*.2,-.68+(i//3)*.23,.12),.21,'egg')
    b.skull((-1,-1,.1),.26)

def troll(b):
    b.base('slate')
    b.box('Cave_recess',(0,.95,.83),(1.9,.15,1.30),'black')
    for s in (-1,1):
        b.rock('Cave_side',(s*1.19,.45,.65),(.98,1.80,1.24),'slate',s*.08,'stone')
        b.rock('Upper_pillar',(s*1.03,.52,1.48),(.76,1.35,.50),'stone',s*.1,'moss')
        b.rock('Rock_scree',(s*1.52,-.74,.24),(.75,.70,.43),'stone',s*.6)
    b.rock('Great_capstone',(0,.63,1.95),(3.13,1.87,.58),'stone',-.04,'moss')
    b.rock('Roof_moss',(0,.72,2.28),(1.52,1.03,.12),'moss',.12)
    b.beam('Discarded_club',(1.65,-.62,.24),(.75,-1.48,.24),.22,'wood_light')
    b.box('Club_head',(.70,-1.54,.26),(.56,.52,.35),'wood',rot=(0,0,-.7),top='endgrain')
    b.skull((-.90,-1.05,.12),.45,horns=True)
    for i in range(3): b.bone((-.45+i*.4,-1.32,.16),.62,i*.6)
    b.rock('Sleeping_bed',(0,.27,.16),(1.44,1.18,.10),'straw')
    for i in range(4): b.grass((-1.48+i*.85,1.15,.12),'moss')

def wyvern(b):
    b.base('slate')
    b.rock('Escarpment_lower',(0,.22,.35),(3.18,2.68,.64),'slate',.08,'stone')
    b.rock('Escarpment_middle',(.12,.43,.92),(2.75,2.3,.55),'slate',-.08,'stone')
    b.rock('High_nesting_ledge',(.13,.32,1.34),(2.80,2.39,.33),'stone',.08,'charcoal')
    for x,y,z,size in [(-1.15,1.05,1.48,(.55,.65,2.45)),(1.10,1.18,1.22,(.65,.6,1.97))]:
        b.rock('Windworn_pinnacle',(x,y,z),size,'slate',x*.2,'stone')
    b.nest((.02,.18),.85,1.61,'charcoal',3)
    b.egg((-.27,.1,1.66),.49); b.egg((.30,.37,1.66),.44)
    for i in range(3): b.bone((-.65+i*.58,-.65,1.56),.5,i*.8)
    b.skull((.95,-.40,1.53),.34)
    for i in range(4): b.box('Scorched_ledge',(-.8+i*.46,-1.03,.72),(.28,.22,.035),'charcoal')

def minotaur(b):
    b.base('dirt')
    for i in range(4):
        for j in range(4): b.box('Broken_paving',(-1.13+i*.75,-1.1+j*.73,.13),(.69,.66,.18),'stone' if (i+j)%3 else 'slate')
    # A visible meander, leaving navigable gaps through the ruined plan.
    # Rear wall meets the side walls at the edge: no overlapping coplanar caps.
    walls=[(-1.52,.15,.52,.35,2.8),(-.02,1.43,.52,2.64,.34),(1.48,.60,.52,.35,1.75),(.25,.1,.48,1.5,.34),(-.34,-.62,.43,.33,1.12)]
    for x,y,z,w,d in walls:
        for level in range(2): b.box('Labyrinth_wall',(x,y,.26+level*.38),(w,d,.35),'stone',top='stone_light')
    for s in (-1,1):
        b.box('Gate_pedestal',(s*.85,-1.13,.28),(.56,.61,.36),'slate')
        b.box('Gate_pillar',(s*.85,-1.13,1.05),(.36,.4,1.2),'stone')
        b.box('Gate_capital',(s*.85,-1.13,1.72),(.56,.6,.17),'stone_light')
    b.box('Horned_lintel',(0,-1.13,1.95),(2.19,.54,.30),'stone_light')
    b.skull((0,-1.45,1.92),.49,horns=True)
    b.box('Faded_red_banner',(.77,-1.37,1.12),(.35,.035,.75),'red')
    b.box('Banner_gold_mark',(.77,-1.392,1.17),(.17,.014,.12),'straw')
    b.rock('Fallen_masonry',(1.18,-.50,.25),(.54,.45,.28),'stone_light',.4)
    b.rock('Fallen_capital',(-1.45,-1.12,.24),(.43,.49,.25),'stone',-.3)

def basilisk(b):
    b.base('sand')
    b.rock('Sun_warmed_bedrock',(0,.37,.20),(3.4,2.7,.28),'sand_light',.14)
    b.nest((.12,.2),1.03,.43,'wood_light',4)
    for x,y,s in [(-.28,.12,.52),(.30,.55,.47),(.49,-.12,.40)]: b.egg((x,y,.46),s)
    # Petrified prey reads as a small mammal statue, contrasting with bones.
    b.box('Petrified_prey_body',(-1.17,-.75,.45),(.62,.34,.37),'pale_stone',rot=(0,.05,.3))
    for x in (-1.38,-1.02):
        for y in (-.86,-.65): b.box('Petrified_prey_leg',(x,y,.27),(.10,.11,.32),'pale_stone')
    b.box('Petrified_prey_head',(-1.49,-.84,.68),(.28,.24,.32),'pale_stone')
    for y in (-.93,-.76): b.taper('Stone_prey_ear',(-1.52,y,.84),.10,.20,'pale_stone')
    b.beam('Stone_tail',(-.90,-.65,.5),(-.71,-.48,.72),.07,'pale_stone')
    for i in range(3): b.rock('Petrification_fragments',(1.25,-.55+i*.35,.20+i*.05),(.33,.3,.3),'pale_stone',i*.4)
    for i in range(4): b.grass((-.5+i*.55,1.45,.11),'straw')
    # Discarded dark feathers, echoing the actual bird-reptile silhouette.
    for i in range(3): b.box('Shed_dark_feather',(.1+i*.30,-1.18,.15),(.11,.50,.04),'charcoal',rot=(0,0,.3+i*.3))

def colossal_worm(b):
    # True recessed funnel, with raised edges to remain readable on uncut game terrain.
    # Dark bottom is ABOVE z=0: it never depends on a terrain boolean or transparency.
    b.box('Tunnel_dark_bottom',(0,0,.025),(1.30,1.30,.05),'black')
    for ring,(r,z,w,h) in enumerate([(1.05,.18,.52,.32),(1.48,.42,.64,.54),(1.96,.17,.63,.30)]):
        for i in range(12):
            a=i*TAU/12; rr=r+b.rng.uniform(-.05,.05)
            b.rock('Ejected_sand_plate',(math.cos(a)*rr,math.sin(a)*rr,z),(w,.67,h),'sand' if ring<2 else 'sand_light',a,top='sand_light')
    # Inner ledges descend towards a black square shaft, instead of a disk painted on sand.
    for s in (-1,1):
        b.box('Inner_tunnel_wall',(s*.74,0,.14),(.18,1.35,.28),'earth')
        b.box('Inner_tunnel_wall',(0,s*.74,.14),(1.35,.18,.28),'earth')
    for i in range(5):
        a=-.7+i*.46; x=math.cos(a)*1.55; y=math.sin(a)*1.55
        b.box('Shed_segment_armor',(x,y,.65),(.42,.28,.11),'charcoal',rot=(0,.15,a))
        b.box('Amber_shell_ridge',(x,y,.72),(.31,.13,.05),'ember',rot=(0,0,a))
    for i in range(3): b.rock('Thrown_stone',(-1.5+i*.8,1.3,.55),(.40,.38,.52),'sand_light',i*.2)
    b.skull((-1.40,-1.4,.28),.30)

def spiral(b,c,size,plane='front'):
    # Raised angular spiral, a geometric counterpart of the existing golem's markings.
    x,y,z=c; s=size
    pts=[(-.44,.44),(.44,.44),(.44,-.44),(-.44,-.44),(-.44,.18),(.18,.18),(.18,-.18),(-.12,-.18)]
    for p,q in zip(pts,pts[1:]):
        if plane=='front': a=(x+p[0]*s,y,z+p[1]*s); d=(x+q[0]*s,y,z+q[1]*s)
        else: a=(x+p[0]*s,y+p[1]*s,z); d=(x+q[0]*s,y+q[1]*s,z)
        b.beam('Ancient_square_spiral',a,d,.035,'slate')

def arboreal_ancient(b):
    b.base('earth')
    for i in range(8):
        a=TAU*i/8
        b.beam('Ancient_root',(math.cos(a)*.50,math.sin(a)*.5,.36),(math.cos(a)*1.67,math.sin(a)*1.67,.12),.23,'root')
        b.beam('Root_fork',(math.cos(a)*1.2,math.sin(a)*1.2,.18),(math.cos(a+.22)*1.88,math.sin(a+.22)*1.88,.07),.12,'root')
    for i,(x,y,z,h) in enumerate([(-1.1,.55,.82,1.50),(.2,1.10,1.0,1.86),(1.12,.44,.63,1.15)]):
        b.rock('Birth_stone',(x,y,z),(.82,.72,h),'stone_light',.07*(i-1),'moss')
        spiral(b,(x,y-.37,z),.59)
        b.box('Moss_drape',(x-.30,y-.39,z+h*.22),(.18,.05,h*.46),'moss')
    b.rock('Central_cradle',(0,-.20,.32),(1.35,1.25,.48),'slate',.1,'stone_light')
    b.box('Green_heart_seam',(0,-.20,.575),(.55,.44,.035),'green')
    for s in (-1,1):
        b.box('Cradle_raised_edge',(s*.49,-.20,.69),(.22,.91,.29),'stone_light',top='moss')
    b.rock('Fallen_spiral_tablet',(-.83,-.85,.20),(.85,.78,.14),'stone_light',0,'stone_light')
    spiral(b,(-.83,-.85,.278),.68,'top')
    for i in range(7): b.grass((-1.3+i*.43,.95,.15),'grass')
    for x,y in [(-1.3,-.65),(.9,-.9)]:
        b.beam('Young_shoot',(x,y,.12),(x,y,.61),.05,'root')
        b.box('Square_leaf',(x+.12,y,.51),(.29,.14,.09),'grass',rot=(0,-.3,0))

def mana_devourer(b):
    b.base('slate')
    # A natural mineral source, not a second copy of the floating monster.
    for i in range(7):
        a=i*TAU/7; x=math.cos(a)*1.13; y=math.sin(a)*1.13
        b.rock('Fractured_arcane_bedrock',(x,y,.30),(.91,.83,.48),'stone',a,top='stone_light')
        b.beam('Violet_fault',(x*.63,y*.63,.34),(x*1.22,y*1.22,.55),.055,'violet')
    b.box('Empty_core_socket',(0,0,.14),(1.14,1.11,.22),'black')
    for s in (-1,1):
        # Raised socket edges clear the bedrock caps; cross-bars meet without coplanar overlap.
        b.box('Socket_mineral_wall',(s*.66,0,.38),(.23,1.26,.50),'crystal')
        b.box('Socket_mineral_wall',(0,s*.66,.38),(1.08,.23,.50),'crystal')
    b.box('Residual_mana',(0,0,.267),(.46,.46,.03),'violet')
    for i,(x,y,h) in enumerate([(-1.15,.92,1.60),(1.15,.9,1.12),(.1,1.4,1.36),(-1.5,-.40,.63)]):
        b.box('Drained_cubic_crystal',(x,y,.2+h/2),(.39,.39,h),'crystal',rot=(0,.12*(-1)**i,i*.2))
        b.box('Faded_crystal_tip',(x+.01,y,.2+h),(.31,.32,.10),'stone_light')
        b.box('Remaining_violet_seam',(x+.20,y-.04,.2+h*.53),(.022,.09,h*.42),'violet')
    for x,y in [(-.8,-1.38),(.92,-1.17)]: b.rock('Drained_fragment',(x,y,.16),(.38,.40,.22),'stone_light',x)

def corrupted_hero(b):
    b.base('dirt')
    # This is the old soldier's abandoned vigil; restrained steel, faded blue, no demon throne.
    for i in range(3):
        for j in range(3): b.box('Watchpost_paving',(-.75+i*.72,-.72+j*.72,.16),(.65,.65,.22),'stone')
    for s in (-1,1):
        for j in range(3 if s<0 else 2):
            b.box('Ruined_watchpost_wall',(s*1.34,.36,.35+j*.43),(.47,1.75-j*.15,.40),'stone',top='stone_light')
    b.box('Broken_rear_wall',(0,1.17,.55),(2.5,.35,.90),'stone')
    b.box('Empty_watch_seat',(0,.47,.56),(1.02,.76,.24),'wood',top='wood_light')
    for x in (-.38,.38): b.box('Seat_leg',(x,.47,.30),(.14,.55,.40),'wood')
    b.box('Seat_back',(0,.85,1.04),(1.0,.12,.85),'wood')
    b.beam('Standard_pole',(-.89,.89,.2),(-.89,.89,2.53),.095,'wood_light')
    b.beam('Banner_crossbar',(-1.0,.89,2.35),(.05,.89,2.35),.07,'iron')
    b.box('Faded_standard',(-.42,.88,1.87),(.83,.045,.90),'bluecloth')
    b.box('Torn_standard_left',(-.68,.88,1.30),(.30,.045,.24),'bluecloth')
    b.box('Torn_standard_right',(-.23,.88,1.36),(.20,.045,.12),'bluecloth')
    b.box('Erased_standard_crest',(-.42,.85,1.90),(.22,.015,.24),'stone_light')
    b.box('Forgotten_tower_shield',(.81,-.48,.72),(.59,.13,1.13),'iron',rot=(.20,0,-.1))
    b.box('Shield_blue_panel',(.81,-.57,.73),(.41,.025,.88),'bluecloth',rot=(.20,0,-.1))
    b.box('Shield_vertical_crest',(.81,-.59,.74),(.058,.018,.66),'stone_light',rot=(.20,0,-.1))
    b.beam('Discarded_mace_handle',(-.96,-.95,.22),(-.1,-1.20,.22),.08,'wood')
    b.box('Discarded_mace_head',(-1.02,-.92,.24),(.33,.31,.28),'iron',rot=(0,0,-.28))
    b.rock('Collapsed_wall_block',(1.37,-1.02,.27),(.49,.47,.37),'stone_light',.28)
    for i in range(4): b.grass((-.85+i*.47,-1.43,.10),'straw')

exec(compile((ROOT/'art_source/monster_lairs_v2/refinements.py').read_text(encoding='utf-8'),
    str(ROOT/'art_source/monster_lairs_v2/refinements.py'),'exec'),globals())
BUILDERS={r[0]:globals()[r[0]] for r in ROWS}

def fit_and_uv(b):
    # Every silhouette fits within radius .78, inside a size=1 pointy hex (inradius .866).
    radius=max(math.hypot(v.co.x,v.co.y) for ob in b.parts for v in ob.data.vertices)
    factor=.78/radius
    ground=min(v.co.z for ob in b.parts for v in ob.data.vertices)
    measured=[]
    for oi,ob in enumerate(b.parts):
        me=ob.data
        for v in me.vertices:
            v.co.z-=ground
            v.co*=factor
        me.update()
        for p,paint in zip(me.polygons,ob['_paints']):
            points=[me.vertices[me.loops[li].vertex_index].co for li in p.loop_indices]
            edges=[points[(i+1)%len(points)]-v for i,v in enumerate(points)]
            u_axis=max(edges,key=lambda v:v.length_squared).normalized()
            v_axis=p.normal.cross(u_axis).normalized()
            coords=[(point.dot(u_axis),point.dot(v_axis)) for point in points]
            minx=min(c[0] for c in coords); miny=min(c[1] for c in coords)
            swatch=P[paint]; offx=(oi*13+p.index*7)%20+3; offy=(oi*7+p.index*11)%20+3
            for li,(u,v) in zip(p.loop_indices,coords):
                uu=(u-minx)*64+offx; vv=(v-miny)*64+offy
                if paint=='endgrain':
                    uu=64+(u-(minx+max(c[0] for c in coords))/2)*64
                    vv=64+(v-(miny+max(c[1] for c in coords))/2)*64
                assert uu<126 and vv<126,(ob.name,uu,vv)
                me.uv_layers.active.data[li].uv=((swatch%8*128+uu)/1024,(swatch//8*128+vv)/1024)
            loop_indices=list(p.loop_indices)
            for i,li in enumerate(loop_indices):
                lj=loop_indices[(i+1)%len(loop_indices)]
                edge=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
                pixels=(me.uv_layers.active.data[li].uv-me.uv_layers.active.data[lj].uv).length*1024
                if edge>1e-7: measured.append(pixels/edge)
        del ob['_paints']
    b.uv_density_range=[min(measured),max(measured)]
    assert min(measured)>63.9 and max(measured)<64.1,b.uv_density_range
    return factor

def studio(scene,kind):
    studio=bpy.data.collections.new(kind+'_STUDIO_not_exported'); scene.collection.children.link(studio)
    world=bpy.data.worlds.new(kind+'_world'); world.use_nodes=True; scene.world=world
    world.node_tree.nodes['Background'].inputs[0].default_value=(.21,.24,.28,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.55
    for name,pos,power,size in [('Key',(-2,-3,5),340,4),('Fill',(3,-1,2.5),130,3),('Rim',(1,3,4),270,3)]:
        ld=bpy.data.lights.new(kind+name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=size
        lo=bpy.data.objects.new(name,ld); studio.objects.link(lo); lo.location=pos
        lo.rotation_euler=(Vector((0,0,.3))-lo.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new(kind+'_camera'); cd.type='ORTHO'
    cam=bpy.data.objects.new('Preview_camera',cd); studio.objects.link(cam); scene.camera=cam
    # A studio floor gives readable contact shadows, and is excluded from export.
    me=bpy.data.meshes.new('Studio_floor'); me.from_pydata([(-200,-200,-.012),(200,-200,-.012),(200,200,-.012),(-200,200,-.012)],[],[(0,1,2,3)]); me.update()
    ob=bpy.data.objects.new('STUDIO_floor',me); studio.objects.link(ob)
    mat=bpy.data.materials.get('Lair_studio_floor') or bpy.data.materials.new('Lair_studio_floor')
    mat.diffuse_color=(.13,.16,.19,1); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.13,.16,.19,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95
    me.materials.append(mat)
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED'; scene.render.threads=4
    scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard'
    return cam

def build(kind,views=('three_quarter','game_top','back'),rebuild=False):
    row=next(r for r in ROWS if r[0]==kind); stem=kind+'_lair_v2'; folder=OUT/stem
    folder.mkdir(exist_ok=True); (folder/'previews').mkdir(exist_ok=True)
    assert rebuild or not (folder/(stem+'.glb')).exists(),'Existing output preserved; choose a new version or explicit rebuild.'
    original=bpy.context.window.scene; original_names=set(s.name for s in bpy.data.scenes)
    scene=bpy.data.scenes.new(stem); bpy.context.window.scene=scene
    try:
        b=Builder(scene,kind); BUILDERS[kind](b); factor=fit_and_uv(b)
        root=bpy.data.objects.new(stem,None); scene.collection.objects.link(root)
        root['monster_kind']=kind; root['tier']=row[1]; root['concept']=row[2]
        root['forward']='-Y Blender / +Z glTF'; root['footprint_radius']=.78
        root['integration']='ART ONLY: no runtime behavior, collider or spawn script'
        for ob in b.parts: ob.parent=root
        # Validate the editable source components, then build a single draw-call runtime mesh.
        verts=[]; faces=[]; uvs=[]; degenerates=0; nonmanifold=0
        for ob in b.parts:
            bm=bmesh.new(); bm.from_mesh(ob.data)
            nonmanifold+=sum(not e.is_manifold for e in bm.edges)
            degenerates+=sum(f.calc_area()<1e-12 for f in bm.faces); bm.free()
            off=len(verts); verts.extend(tuple(v.co) for v in ob.data.vertices)
            for p in ob.data.polygons:
                faces.append(tuple(off+i for i in p.vertices))
                uvs.extend(tuple(ob.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
        assert not nonmanifold and not degenerates,(nonmanifold,degenerates)
        me=bpy.data.meshes.new(stem+'_runtime'); me.from_pydata(verts,[],faces); me.update(); me.materials.append(b.mat)
        uv=me.uv_layers.new(name='PixelAtlas')
        for loop,coord in zip(uv.data,uvs): loop.uv=coord
        runtime=bpy.data.objects.new('Model',me); scene.collection.objects.link(runtime); runtime.parent=root
        for ob in scene.objects: ob.select_set(False)
        runtime.select_set(True); root.select_set(True); bpy.context.view_layer.objects.active=runtime
        bpy.ops.export_scene.gltf(filepath=str(folder/(stem+'.glb')),export_format='GLB',
            use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
            export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
        bpy.data.objects.remove(runtime,do_unlink=True); bpy.data.meshes.remove(me)
        # Semantic anchors are source-only; no invisible geometry is shipped.
        for name,pos in [('AttackTarget',(0,0,.35)),('SpawnCenter',(0,0,0)),('GroundPivot',(0,0,0))]:
            anchor=bpy.data.objects.new(name,None); scene.collection.objects.link(anchor); anchor.parent=root; anchor.location=pos; anchor.empty_display_size=.07
        maxz=max(v[2] for v in verts); minz=min(v[2] for v in verts)
        cam=studio(scene,kind)
        viewspec={'three_quarter':((2.45,-3.7,2.65),(0,0,maxz*.40),max(2.02,maxz*1.72)),
                  'game_top':((1.9,-3.1,5.5),(0,0,maxz*.20),2.05),
                  'back':((-2.6,3.6,2.55),(0,0,maxz*.38),max(2.02,maxz*1.72))}
        for view in views:
            pos,target,scale=viewspec[view]; cam.location=pos; cam.data.ortho_scale=scale
            cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(folder/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True,scene=scene.name)
        pos,target,scale=viewspec['three_quarter']; cam.location=pos; cam.data.ortho_scale=scale
        cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        # Source library contains this scene and dependencies only. Never save over the active file.
        bpy.data.libraries.write(str(folder/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
        # Blender-to-glTF mapping is X,Y,Z -> X,Z,-Y.
        bounds=[[min(v[i] for v in verts) for i in range(3)],[max(v[i] for v in verts) for i in range(3)]]
        triangles=sum(len(f)-2 for f in faces)
        report=dict(kind=kind,tier=row[1],name=row[2],concept=row[3],stem=stem,method='Live Blender MCP localhost:9876',
            editable_parts=len(b.parts),vertices=len(verts),triangles=triangles,materials=1,draw_calls=1,
            atlas=[1024,1024],pixels_per_meter=64,measured_uv_density_range=b.uv_density_range,filter='nearest',footprint_radius=.78,
            height=maxz,ground_min=minz,source_bounds_xyz=bounds,scale_multiplier=1.0,
            forward='-Y Blender / +Z glTF',pivot=[0,0,0],nonmanifold_edges=nonmanifold,degenerate_faces=degenerates,
            animations=[],collision=False,game_source_changed=False,art_scale=factor,
            mesh_components='Closed individual volumes; intentional intersections at structural joints.',
            isolated_by_gdignore=True,previews=list(views))
        (folder/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        (folder/'README.md').write_text('# '+row[2]+'\n\n'+row[3]+'\n\n'
            'Criado no Blender pelo MCP. Fonte editável em `.blend`, malha de runtime em `.glb`.\n'
            'Frente +Z no glTF; origem no chão; escala 1:1. Raio máximo 0,78 m: cabe no hex de raio 1 m.\n'
            'Uma malha, um material; atlas albedo/emissão embutidos, filtro nearest, 64 px/m.\n'
            'As peças de estúdio e os anchors de referência não estão no GLB.\n'
            'Arte estática: spawn, líder, dano e remoção do covil continuam responsabilidade do jogo.\n'
            'A pasta-mãe tem `.gdignore` para impedir importação automática durante trabalhos simultâneos.\n',encoding='utf-8')
        print('LAIR_COMPLETE '+json.dumps(report,ensure_ascii=True))
        return report
    finally:
        bpy.context.window.scene=original
        assert original_names.issubset(set(s.name for s in bpy.data.scenes))

