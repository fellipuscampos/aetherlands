"""War bulls in the running Blender; retain the approved riders and clips."""
import bpy,sys,importlib,numpy as np
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import WORK
from build_elf_troops import FACES
from build_orc_tribal_equipment import frame
from build_orc_squire import rectangle
from build_orc_refined_clothing import pack,uvboxes,gutter
from orc_refined_clothing_paint import surface
import build_orc_horns_hoods as shared
importlib.reload(shared)

FROZEN=WORK/'war_bulls/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')
REVISION='war_bull_v2'
DESCRIPTION='Reference-inspired compact war bull: heavy shaggy forequarters, deep dark-brown coat, sloping long skull, short upright keratin horns and ochre saddle hide. Original riders, weapons, saddle, stirrups, rig and animation curves preserved.'

def box(g,name,center,size,kind,bone):return g.box(name,np.zeros(3),np.eye(3),center,size,kind,bone)

def torso(g):
    ring=[(-.25,1.36),(.25,1.36),(.35,1.12),(.29,.88),(.235,.59),(-.235,.59),(-.29,.88),(-.35,1.12)]
    verts=[(x,y,z) for y in (-.67,.64) for x,z in ring];n=8
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return g.mesh('BullBody',verts,faces,'leather','horse_body')

def horn(g,sign):
    # Compact, predominantly upright four-sided horns, as in the reference.
    centers=[([sign*.20,-.81,1.64],.075),([sign*.275,-.77,1.765],.063),
             ([sign*.30,-.77,1.885],.045),([sign*.305,-.79,1.99],.023)]
    verts=[]
    tips=[np.array(c) for c,_ in centers]+[np.array([sign*.295,-.81,2.065])]
    for index,(center,radius) in enumerate(centers):
        tangent=tips[index+1]-tips[max(0,index-1)];tangent/=np.linalg.norm(tangent)
        a=np.cross(tangent,[0,1,0]);a/=np.linalg.norm(a);b=np.cross(tangent,a)
        verts.extend((np.array(center)+radius*(np.cos(angle)*a+np.sin(angle)*b)).tolist() for angle in (0,np.pi/2,np.pi,np.pi*1.5))
    verts.append(tips[-1].tolist())
    faces=[(3,2,1,0)]+[(i+r,(i+1)%4+r,(i+1)%4+r+4,i+r+4) for r in (0,4,8) for i in range(4)]
    faces.extend((i+12,(i+1)%4+12,16) for i in range(4))
    return g.mesh('BullHorn_'+str(sign),verts,faces,'bone','horse_head')

def ear(g,sign):
    # Bovine ears point sideways below the horns, rather than upright pig ears.
    verts=[]
    for z in (-.025,.025):
        verts.extend(([sign*.24,-.745,1.56+z],[sign*.39,-.715,1.50+z],
                      [sign*.40,-.61,1.52+z],[sign*.24,-.61,1.57+z]))
    faces=[(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
    return g.mesh('BullEar_'+str(sign),verts,faces,'leather','horse_head')

def head(g):
    # Wide upper cranium, tapered lower face, sloping forward like the reference.
    verts=[[-.175,-1.35,1.04],[.175,-1.35,1.04],[-.22,-.84,1.04],[.22,-.84,1.04],
           [-.24,-1.17,1.66],[.24,-1.17,1.66],[-.27,-.64,1.66],[.27,-.64,1.66]]
    return g.mesh('BullHead',verts,FACES,'leather','horse_head')

def neck(g):
    verts=[[-.235,-.90,.64],[.235,-.90,.64],[-.25,-.30,.74],[.25,-.30,.74],
           [-.28,-.85,1.60],[.28,-.85,1.60],[-.24,-.30,1.36],[.24,-.30,1.36]]
    return g.mesh('BullWithers',verts,FACES,'leather','horse_neck')

def spatial_fraction(obj,poly,w,h):
    uv=np.array([tuple(obj.data.uv_layers.active.data[i].uv) for i in poly.loop_indices])
    points=np.array([tuple(obj.data.vertices[i].co) for i in poly.vertices])
    lo=np.rint(uv.min(0)*[w,h]).astype(int);hi=np.rint(uv.max(0)*[w,h]).astype(int)
    yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]];unit=np.stack(((xx+.5)/w,(yy+.5)/h),axis=-1)
    local=(unit-uv[0])@np.linalg.inv(np.stack((uv[1]-uv[0],uv[-1]-uv[0]),axis=1)).T
    position=points[0]+local[...,0,None]*(points[1]-points[0])+local[...,1,None]*(points[-1]-points[0])
    all_points=np.array([tuple(v.co) for v in obj.data.vertices])
    return (position-all_points.min(0))/np.ptp(all_points,axis=0)

def saddle_hide(g,sign):
    verts=[]
    for offset in (0,.014):
        verts.extend(([sign*(.268+offset),-.28,1.335],[sign*(.268+offset),.31,1.335],
                      [sign*(.357+offset),.31,1.08],[sign*(.357+offset),-.28,1.08]))
    faces=[(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
    return g.mesh('BullSaddleHide_'+str(sign),verts,faces,'leather','horse_body')

def material(obj,poly,shape,tier,frac=None):
    name=obj['part'];h,w=shape;yy,xx=np.mgrid[:h,:w];u=(xx+.5)/w;v=(yy+.5)/h
    coat=np.array(((74,32,16),(65,33,19),(49,31,20),(35,28,20))[tier])
    # Broad, restrained pixel clusters and darker shaggy forequarters.
    rng=np.random.default_rng(sum(map(ord,name))+poly.index*137)
    clusters=rng.integers(-6,7,((h+3)//4,(w+3)//4,1)).repeat(4,0).repeat(4,1)[:h,:w]
    tile=np.broadcast_to(coat,(h,w,3)).astype(np.int16).copy()+clusters+rng.integers(-1,2,(h,w,1))
    if name=='BullBody':
        shade={0:3,1:0,2:6,3:-6,4:-12,5:-12,6:-6,7:6,8:2,9:2}[poly.index]
        tile+=shade
        if poly.index in (3,7):tile+=np.rint(6*np.sin(v*np.pi))[...,None].astype(int)
    elif 'Horn' in name:
        segment=0 if poly.index<5 else 1 if poly.index<9 else 2 if poly.index<13 else 3
        base=np.array(((95,83,60),(134,118,83),(170,154,115),(115,104,77))[segment])
        tile=np.broadcast_to(base,(h,w,3)).astype(np.int16).copy()+rng.integers(-3,4,(h,w,1))
        if segment<2:tile[yy%6==0]-=[14,12,9]
    elif 'Bone' in name:
        from orc_closed_bone_armor_paint import detail
        tile=detail(shape,poly.index).astype(np.int16)
    elif 'Hoof' in name:
        tile[:]=(68,58,43);tile+=np.rint(v*12)[...,None].astype(int)
        tile[(v>.83)]=(97,82,58)
    elif name=='BullMuzzle':
        tile[:]=(39,27,22);tile+=rng.integers(-2,3,(h,w,1))
        if poly.index==2:
            x,z=frac[...,0],frac[...,2]
            nostril=(((x>.15)&(x<.27))|((x>.73)&(x<.85)))&(z>.47)&(z<.60)
            tile[nostril]=(19,18,15)
            tile[(z>.11)&(z<.16)&(x>.13)&(x<.87)]=(25,20,17)
    elif name=='BullHead':
        x,y,z=(frac[...,i] for i in range(3))
        tile-=np.array([19,10,4])
        if poly.index==2:tile[(abs(x-.5)<.12)&(z>.60)]+=np.array([8,4,1])
        elif poly.index in (4,5):
            eye=(y>.28)&(y<.43)&(z>.59)&(z<.71)
            tile[(y>.23)&(y<.47)&(z>.54)&(z<.75)]=(18,15,12)
            tile[eye]=(202,192,164);tile[eye&(y<.35)]=(17,17,13)
    elif name in ('BullWithers','BullForelock','BullBeard'):
        tile-=np.array([22,11,5])
        tile[((xx//2+yy//5)%5==0)&(yy%5<3)]-=np.array([7,4,2])
    elif name.startswith('BullSaddleHide'):
        tile=np.broadcast_to((155,108,47),(h,w,3)).astype(np.int16).copy()+clusters
        tile[(u<.08)|(u>.92)|(v<.09)|(v>.92)]=(114,76,33)
        tile[((u<.11)|(u>.89)|(v<.12)|(v>.88))&((xx+yy)%4==0)]=(185,143,72)
    elif name.startswith('BullEar'):
        if poly.index==1:
            tile[:]=coat-[11,6,0];tile[(u>.12)&(u<.89)&(v>.15)&(v<.86)]=coat+[37,15,7]
    elif name=='BullTailTuft':tile-=np.array([31,23,14])
    elif name.startswith('BullBit'):tile=surface('iron',shape,tier,poly.index).astype(np.int16)
    elif name.startswith('BullBridle'):tile=surface('strap',shape,tier,poly.index).astype(np.int16)
    return np.clip(tile,0,255).astype(np.uint8)

def modify(g,canvas):
    tier=g.row['tier'];h,w=canvas.shape[:2]
    factor=max(v.co.z for v in g.by['BoarBody'].data.vertices)/1.36
    g.remove([n for n in g.by if n.startswith('Boar')])
    torso(g)
    neck(g);head(g)
    box(g,'BullMuzzle',[0,-1.375,1.11],[.31,.14,.28],'leather','horse_head')
    box(g,'BullForelock',[0,-1.03,1.676],[.45,.32,.048],'leather','horse_head')
    box(g,'BullBeard',[0,-.93,.875],[.33,.19,.38],'leather','horse_head')
    for sign in (-1,1):
        horn(g,sign);ear(g,sign)
        box(g,'BullBit_'+str(sign),[sign*.182,-1.30,1.145],[.022,.060,.060],'iron','horse_head')
        saddle_hide(g,sign)
    box(g,'BullTailBase',[0,.69,1.17],[.055,.12,.28],'leather','horse_tail')
    box(g,'BullTailShaft',[0,.75,.84],[.045,.055,.45],'leather','horse_tail')
    box(g,'BullTailTuft',[0,.75,.55],[.105,.105,.17],'leather','horse_tail')
    donors={}
    for leg in ('fl','fr','bl','br'):
        sign=1 if leg.endswith('l') else -1;y=-.42 if leg.startswith('f') else .42;x=sign*.22
        for prefix,center,size,bone in (
            ('BullThigh',[x,y,.65],[.235,.26,.38],'horse_thigh_'+leg),
            ('BullCannon',[x,y,.26],[.19,.215,.40],'horse_cannon_'+leg)):
            obj=box(g,prefix+'_'+leg,center,size,'leather',bone)
            if leg!='fl':donors[obj['part']]=prefix+'_fl'
        for toe in (-1,1):
            obj=box(g,'BullHoof_'+leg+'_'+str(toe),[x+toe*.052,y-.005,.05],[.087,.195,.10],'leather','horse_cannon_'+leg)
            if leg!='fl':donors[obj['part']]='BullHoof_fl_'+str(toe)
    reshaped=[]
    for side,sign in (('l',1),('r',-1)):
        obj=g.by['Rein_'+side+'1'];old=np.array([tuple(v.co) for v in obj.data.vertices])
        # Current rein layout already places its preserved upper end in 4..7.
        end=old[4:].mean(axis=0);start=np.array([sign*.182,-1.30,1.145])*factor
        direction=end-start;length=np.linalg.norm(direction);direction/=length
        a=np.cross(direction,[1,0,0]);a/=np.linalg.norm(a);b=np.cross(direction,a)
        vertices=np.array([a*sx*.006+b*sy*.006+direction*sz*length/2+(start+end)/2
                           for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)])
        for vertex,point in zip(obj.data.vertices,vertices):vertex.co=point
        obj.data.update();reshaped.append(obj['part'])
    if tier>=2:
        outline=[(-.145,0),(.145,0),(.12,-.15),(.055,-.20),(-.055,-.20),(-.12,-.15)]
        angle=-np.arctan(.18/.62);axes=np.array([[1,0,0],[0,np.cos(angle),-np.sin(angle)],[0,np.sin(angle),np.cos(angle)]])
        g.plate('BullBoneForehead',np.array([0,-1.19,1.61]),axes,outline,.025,0,'bone','horse_head')
        for sign in (-1,1):
            box(g,'BullBoneFlank_'+str(sign),[sign*.345,.45,1.13],[.026,.20,.21],'bone','horse_body')
            box(g,'BullBoneShoulder_'+str(sign),[sign*.30,-.69,1.235],[.026,.20,.25],'bone','horse_neck')
    for obj in g.new:
        for vertex in obj.data.vertices:vertex.co*=factor
        obj.data.update()
    unique=[o for o in g.new if o['part'] not in donors]
    pack(canvas,unique,[o for o in g.parts if o not in g.new],False)
    for obj in g.new:
        if obj['part'] in donors:
            donor=g.by[donors[obj['part']]]
            for p,dp in zip(obj.data.polygons,donor.data.polygons):
                for i,j in zip(p.loop_indices,dp.loop_indices):obj.data.uv_layers.active.data[i].uv=donor.data.uv_layers.active.data[j].uv
        else:
            for poly,box_ in zip(obj.data.polygons,uvboxes(obj)):
                x0,y0,x1,y1=np.rint(np.array(box_)*[w,h,w,h]).astype(int)
                frac=spatial_fraction(obj,poly,w,h) if obj['part']=='BullHead' else rectangle(obj,poly,w,h)[2] if obj['part']=='BullMuzzle' else None
                canvas[y0:y1,x0:x1,:3]=material(obj,poly,(y1-y0,x1-x0),tier,frac);gutter(canvas,x0,y0,x1,y1)
        obj.data.uv_layers.active.name=g.parts[0].data.uv_layers[0].name
    # Shared mount builder uses this generic geometry-record hook.
    g.war_boar_new={o['part']:dict(vertices=[list(v.co) for v in o.data.vertices],bone=o['rig_bone'],uv_boxes=uvboxes(o)) for o in g.new}
    return [],reshaped

def update_report(report,changes):
    report['mount_revision']=REVISION;report['mount_species']='war_bull';report['mount_refinement']=changes
    changes.update(original_saddle_and_stirrups_preserved=True,original_rider_and_weapons_preserved=True,
        unchanged_animation_curves=True,legacy_quadruped_bone_names_preserved=True)

def build(row):return shared.build(row,refinement=sys.modules[__name__])
