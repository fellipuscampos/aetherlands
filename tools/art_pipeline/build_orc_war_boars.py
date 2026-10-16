"""Replace only mounted animals, reusing all existing quadruped animation bones."""
import bpy,sys,importlib,numpy as np
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import WORK
from build_elf_troops import FACES
from build_orc_tribal_equipment import frame
from build_orc_squire import rectangle
from build_orc_refined_clothing import pack,uvboxes,gutter
import build_orc_horns_hoods as shared
importlib.reload(shared)

FROZEN=WORK/'war_boars/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')
REVISION='war_boar_v1'
DESCRIPTION='Orc war boar: low skull, broad barrel, short bristled neck, curved tusks and cloven hooves. Original rider, saddle, stirrups, hand contacts, skeleton and animation curves preserved.'

def box(g,name,center,size,kind,bone):return g.box(name,np.zeros(3),np.eye(3),center,size,kind,bone)

def barrel(g):
    # An octagonal cross section rounds the flank in blocky facets. The original
    # saddle contact stays exactly at z=1.36; the broad belly hides long thighs.
    ring=[(-.24,1.36),(.24,1.36),(.34,1.17),(.34,.80),(.24,.58),(-.24,.58),(-.34,.80),(-.34,1.17)]
    verts=[(x,y,z) for y in (-.65,.64) for x,z in ring];n=8
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return g.mesh('BoarBody',verts,faces,'leather','horse_body')

def tusk(g,sign):
    vertices=[]
    for center,radius in (([sign*.19,-1.075,1.00],.046),([sign*.255,-1.19,1.095],.035),([sign*.285,-1.215,1.24],.021)):
        vertices.extend((np.array(center)+[np.cos(a)*radius,0,np.sin(a)*radius]).tolist() for a in (0,np.pi/2,np.pi,np.pi*1.5))
    vertices.append([sign*.305,-1.235,1.37])
    faces=[(3,2,1,0)]+[(i+r,(i+1)%4+r,(i+1)%4+r+4,i+r+4) for r in (0,4) for i in range(4)]
    faces.extend((i+8,(i+1)%4+8,12) for i in range(4))
    return g.mesh('BoarTusk_'+str(sign),vertices,faces,'bone','horse_head')

def crest(g,name,start,end,height):
    # Low sawtooth bristles, with a deliberate gap beneath the existing saddle.
    outline=[(start,1.355),(end,1.355),(end,1.355+height*.40)]
    step=(end-start)/5
    for y in np.linspace(end-step/2,start+step/2,5):outline.extend(((y,1.355+height),(y-step*.40,1.355+height*.47)))
    outline.append((start,1.355+height*.4))
    axes=np.array([[0,1,0],[1,0,0],[0,0,1]])
    return g.plate(name,np.zeros(3),axes,outline,.075,0,'darkcloth','horse_body')

def material(obj,poly,shape,tier,frac=None):
    name=obj['part'];h,w=shape;yy,xx=np.mgrid[:h,:w];u=(xx+.5)/w;v=(yy+.5)/h
    fur=np.array(((80,64,46),(73,58,40),(57,56,45),(42,46,39))[tier])
    rng=np.random.default_rng(sum(map(ord,name))+poly.index*137)
    tile=np.broadcast_to(fur,(h,w,3)).astype(np.int16).copy()+rng.integers(-4,5,(h,w,1))
    # Fine vertical guard hair, without a noisy camouflage or cloth appearance.
    tile[((xx*3+yy)%13==0)&(yy%4!=0)]-=np.array([9,8,6])
    if 'Tusk' in name or 'Bone' in name:
        from orc_closed_bone_armor_paint import detail
        tile=detail(shape,poly.index).astype(np.int16)
        if 'Tusk' in name and poly.index<5:tile-=np.array([22,19,13])
    elif 'Bristle' in name:tile-=np.array([25,21,14])
    elif name.startswith('BoarHoof'):
        tile[:]=(42,35,27);tile[(u>.45)&(u<.55)]=(19,21,17)
        tile[(v>.82)&((u<.43)|(u>.57))]=(72,60,42)
    elif name=='BoarSnout':
        tile=np.broadcast_to(fur+[26,17,12],(h,w,3)).astype(np.int16).copy()+rng.integers(-3,4,(h,w,1))
        if poly.index==2:
            nose=(((u>.19)&(u<.35))|((u>.65)&(u<.81)))&(v>.38)&(v<.66)
            tile[nose]=(27,25,20);tile[(v>.13)&(v<.20)&(u>.12)&(u<.88)]=fur-[16,12,8]
    elif name=='BoarHead':
        if poly.index in (4,5):
            y,z=frac[...,1],frac[...,2]
            eye=(y>.16)&(y<.31)&(z>.61)&(z<.71)
            tile[(y>.10)&(y<.36)&(z>.56)&(z<.79)]=fur-[24,21,14]
            tile[eye]=(176,145,61);tile[eye&(y<.22)]=(24,27,19)
            brow=(y>.10)&(y<.36)&(z>.74)&(z<.84+.12*y)
            tile[brow]=fur-[34,28,20]
        if poly.index==2:
            tile[v>.75]=fur-[13,10,7];tile[(v>.16)&(v<.21)]=fur-[20,17,11]
    elif name.startswith('BoarEar') and poly.index==2:
        inner=(u>.18)&(u<.82)&(v>.12)&(v<.87);tile[inner]=fur+[36,15,8]
    elif name.startswith('BoarBit'):
        from orc_refined_clothing_paint import surface
        tile=surface('iron',shape,tier,poly.index).astype(np.int16)
    elif name.startswith('BoarBridle'):
        from orc_refined_clothing_paint import surface
        tile=surface('strap',shape,tier,poly.index).astype(np.int16)
    return np.clip(tile,0,255).astype(np.uint8)

def modify(g,canvas):
    tier=g.row['tier'];h,w=canvas.shape[:2]
    factor=max(v.co.z for v in g.by['HorseBody'].data.vertices)/1.36
    # Keep all four saddle pieces and both rider-weighted stirrups verbatim.
    g.remove([n for n in g.by if n.startswith('Horse')])
    barrel(g);box(g,'BoarWithers',[0,-.48,1.22],[.55,.38,.36],'leather','horse_neck')
    box(g,'BoarHead',[0,-.86,1.16],[.42,.46,.36],'leather','horse_head')
    box(g,'BoarSnout',[0,-1.195,1.10],[.34,.30,.22],'leather','horse_head')
    for sign in (-1,1):
        box(g,'BoarEar_'+str(sign),[sign*.145,-.695,1.395],[.10,.09,.15],'leather','horse_head')
        tusk(g,sign)
        box(g,'BoarBit_'+str(sign),[sign*.221,-1.03,1.17],[.022,.070,.070],'iron','horse_head')
        box(g,'BoarBridle_'+str(sign),[sign*.215,-.855,1.23],[.014,.32,.030],'strap','horse_head')
    crest(g,'BoarBristleFront',-.61,-.31,.13);crest(g,'BoarBristleRear',.31,.60,.09)
    box(g,'BoarTailBase',[0,.69,1.16],[.07,.15,.07],'leather','horse_tail')
    box(g,'BoarTailCurl',[0,.76,1.22],[.07,.07,.14],'leather','horse_tail')
    box(g,'BoarTailTip',[0,.72,1.28],[.07,.10,.045],'leather','horse_tail')
    shared={}
    for leg in ('fl','fr','bl','br'):
        sign=1 if leg.endswith('l') else -1;y=-.42 if leg.startswith('f') else .42;x=sign*.225
        for prefix,center,size,bone in (
            ('BoarThigh',[x,y,.65],[.23,.25,.38],'horse_thigh_'+leg),
            ('BoarCannon',[x,y,.26],[.20,.215,.40],'horse_cannon_'+leg),
            ('BoarHoof',[x,y-.015,.035],[.225,.255,.07],'horse_cannon_'+leg)):
            obj=box(g,prefix+'_'+leg,center,size,'leather',bone)
            if leg!='fl':shared[obj['part']]=prefix+'_fl'
    # Relocate only the animal end of each rein. The old upper endpoint and
    # the next two segments keep the exact old hand contact and seam motion.
    reshaped=[]
    for side,sign in (('l',1),('r',-1)):
        obj=g.by['Rein_'+side+'1'];origin,axes,size=frame(obj);major=int(np.argmax(size))
        endpoints=np.stack((origin-axes[:,major]*size[major]/2,origin+axes[:,major]*size[major]/2))
        end=endpoints[np.argmax(endpoints[:,2])];start=np.array([sign*.221,-1.03,1.17])*factor
        direction=end-start;length=np.linalg.norm(direction);direction/=length
        a=np.cross(direction,[1,0,0]);a/=np.linalg.norm(a);b=np.cross(direction,a)
        vertices=np.array([(a*sx*.006+b*sy*.006+direction*sz*length/2+(start+end)/2)
                           for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)])
        for vertex,point in zip(obj.data.vertices,vertices):vertex.co=point
        obj.data.update();reshaped.append(obj['part'])
    if tier>=2:
        box(g,'BoarBoneForehead',[0,-.855,1.353],[.265,.265,.026],'bone','horse_head')
        for sign in (-1,1):
            # Chamfered slabs behind the rider's knee, on the beast's flanks.
            box(g,'BoarBoneFlank_'+str(sign),[sign*.349,.39,1.095],[.036,.32,.25],'bone','horse_body')
            box(g,'BoarBoneShoulder_'+str(sign),[sign*.29,-.52,1.215],[.025,.24,.25],'bone','horse_neck')
    unique=[o for o in g.new if o['part'] not in shared]
    for obj in g.new:
        for vertex in obj.data.vertices:vertex.co*=factor
        obj.data.update()
    pack(canvas,unique,[o for o in g.parts if o not in g.new],False)
    for obj in g.new:
        if obj['part'] in shared:
            donor=g.by[shared[obj['part']]]
            for p,dp in zip(obj.data.polygons,donor.data.polygons):
                for i,j in zip(p.loop_indices,dp.loop_indices):obj.data.uv_layers.active.data[i].uv=donor.data.uv_layers.active.data[j].uv
        else:
            for poly,box_ in zip(obj.data.polygons,uvboxes(obj)):
                x0,y0,x1,y1=np.rint(np.array(box_)*[w,h,w,h]).astype(int)
                frac=rectangle(obj,poly,w,h)[2] if obj['part']=='BoarHead' else None
                canvas[y0:y1,x0:x1,:3]=material(obj,poly,(y1-y0,x1-x0),tier,frac);gutter(canvas,x0,y0,x1,y1)
        obj.data.uv_layers.active.name=g.parts[0].data.uv_layers[0].name
    g.war_boar_new={o['part']:dict(vertices=[list(v.co) for v in o.data.vertices],bone=o['rig_bone'],uv_boxes=uvboxes(o)) for o in g.new}
    g.scene['war_boar_new_parts']=str(len(g.new))
    return [],reshaped

def update_report(report,changes):
    report['mount_revision']=REVISION;report['mount_species']='war_boar'
    report['mount_refinement']=changes
    changes.update(original_saddle_and_stirrups_preserved=True,original_rider_and_weapons_preserved=True,
        unchanged_animation_curves=True,legacy_quadruped_bone_names_preserved=True)

def build(row):return shared.build(row,refinement=sys.modules[__name__])
