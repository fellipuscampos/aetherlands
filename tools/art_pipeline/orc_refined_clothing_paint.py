"""Readable sewn leather and skeletal armor over the unchanged 18 cuboids."""
import numpy as np

SKIN=np.array((91,111,63)); BONE=np.array((205,191,153)); EDGE=np.array((55,35,23))
PALETTE={'leather':(105,65,37),'strap':(67,43,27),'iron':(88,92,83),
         'hardware':(139,137,117),'bone':(205,191,153),'horn':(161,143,104),
         'cloth':(92,48,35),'darkcloth':(45,47,36),'olive':(68,72,45)}

def surface(kind,shape,tier=0,seed=0):
    h,w=shape;yy,xx=np.mgrid[:h,:w];u=(xx+.5)/w;v=(yy+.5)/h
    base=np.array(PALETTE[kind]);rng=np.random.default_rng(seed)
    grain=rng.choice([-4,-2,0,0,2,4],(h,w))
    tile=np.broadcast_to(base,(h,w,3)).astype(np.int16).copy()+grain[...,None]
    edge=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy])
    if kind in ('leather','strap'):
        tile+=((np.sin(u*13+v*9)*2).astype(int))[...,None]
        tile[edge<1]=base-[30,20,12];tile[edge==1]=base+[17,12,7]
        seam=(edge==3)&((xx+yy)%4==1);tile[seam]=(160,118,72)
        tile[(u>.34)&(u<.38)&(v>.2)&(v<.6)]=base+[9,7,4]
    elif kind in ('bone','horn'):
        # Warm cortical grain and longitudinal growth ridges, never white tiles.
        tile+=np.rint((np.cos(u*19)*5+v*12-7))[...,None].astype(int)
        tile[u<.12]=base-[36,31,21];tile[(u>.44)&(u<.57)]=base+[17,14,9]
        tile[v<.08]=base-[29,25,18]
    elif kind in ('iron','hardware'):
        tile[edge<1]=base-[25,24,20];tile[edge==1]=base+[33,32,25]
        tile[(u>.47)&(u<.57)]=base+[14,14,10]
    else:
        tile[(xx+yy*3)%7==0]=base-[6,5,4]
        tile[edge<1]=base-[20,17,12];tile[(edge==2)&((xx+yy)%4==1)]=base+[30,25,15]
    return np.clip(tile,0,255).astype(np.uint8)

def grain(position,base):
    q=np.floor(position*260).astype(np.int64)
    fine=((q[...,0]*73856093)^(q[...,1]*19349663)^(q[...,2]*83492791))%9-4
    return np.array(base,dtype=np.int16)+fine[...,None]

def heavy(row):return row['family'] in ('guardian','cavalry') and row['tier']>=2

def body(obj,poly,frac,position,row,original):
    name=obj['part'];x,y,z=(frac[...,i] for i in range(3));vertical=poly.index>=2
    front=poly.index==2;back=poly.index==3;u=x if poly.index in (0,1,2,3) else y
    skin=grain(position,SKIN);tile=skin.copy();tier=row['tier'];full=heavy(row)
    leather=np.array((105,65,37))
    if row['family']=='rogue':leather=np.array((72,51,33))
    elif row['family']=='ranger':leather=np.array((95,72,42))
    hide=grain(position,leather);strap=grain(position,(65,42,27))
    stitches=(np.floor(position[...,2]*140).astype(int)%5==1)
    if name in ('Chest','Belly'):
        if front or back:
            if name=='Chest':
                tile[(z>.30)&(z<.78)&(abs(x-.5)>.12)&(abs(x-.5)<.43)]=SKIN+[4,5,3]
                tile[(z<.18)&(abs(x-.5)<.40)]=SKIN-[6,7,4]
            else:tile[(abs(x-.5)<.025)&(z>.3)]=SKIN-[7,8,4]
        if full:
            # A sternum plus three curved rib pairs: green skin between bones.
            mask=np.zeros(x.shape,bool)
            if front or back:
                mask|=(abs(x-.5)<.043)&(z>.05)&(z<.89)
                levels=(.25,.49,.74) if name=='Chest' else (.36,.74)
                for level in levels:
                    line=level-.28*abs(x-.5)
                    mask|=(abs(z-line)<.063)&(abs(x-.5)>.02)&(abs(x-.5)<.43)
                if name=='Chest':mask|=(z>.87)&(abs(x-.5)>.20)&(abs(x-.5)<.41)
            elif vertical:
                for level in (.16,.40,.65):mask|=abs(z-level)<.06
            bone=grain(position,BONE)
            bone+=np.rint(10*np.cos(x*22))[...,None].astype(int)
            tile[mask]=bone[mask]
            ridge=mask&(abs(x-.5)<.018);tile[ridge]=BONE+[19,16,9]
        return np.clip(tile,0,255).astype(np.uint8)
    if name.startswith('Shoulder'):
        # Shoulder silhouette is built as actual strapped leather pauldrons.
        return np.clip(tile,0,255).astype(np.uint8)
    if name.startswith('UpperArm'):
        if full:
            bone_mask=(abs(u-.5)<.115)&(z>.12)&(z<.86)&vertical
            bone_mask|=(z>.82)&(z<.94)&vertical
            tile[bone_mask]=grain(position,BONE)[bone_mask]
        cuff=(z>.79)&(z<.94);tile[cuff]=strap[cuff]
        tile[cuff&((z<.82)|(z>.91))]=(43,30,21)
        tile[cuff&(z>.84)&(z<.87)&(np.floor(u*30).astype(int)%4==1)]=(148,108,67)
    elif name.startswith('Hand'):
        # The approved green hands stay bare, preserving every finger/grip.
        tile=original.astype(np.int16).copy()
    elif name=='Pelvis':
        tile=hide.copy();belt=z>.60;tile[belt]=strap[belt]
        tile[(abs(z-.60)<.03)|(z>.95)]=EDGE
        seam=(abs(x-.23)<.016)|(abs(x-.77)<.016) if front or back else abs(y-.5)<.02
        tile[seam&~belt]=EDGE
        stitch=(abs(x-.27)<.015)|(abs(x-.73)<.015)
        tile[stitch&stitches&~belt]=(160,118,72)
        if front or back:tile[belt&(abs(x-.13)<.022)&(z>.75)&(z<.84)]=(137,134,114)
    elif name.startswith('Thigh'):
        # Short hide shorts above exposed thigh. No painted dangling rags.
        mask=z>.82;tile[mask]=hide[mask];tile[mask&(z<.87)]=EDGE
        if full:
            mask=vertical&(abs(u-.5)<(.115+.16*z))&(z>.16)&(z<.73)
            tile[mask]=grain(position,BONE)[mask]
            tile[mask&(abs(u-.5)<.035)]=BONE+[17,14,8]
        band=(z>.15)&(z<.23);tile[band]=strap[band]
    elif name.startswith('Forearm') or name.startswith('Shin'):
        bracer=name.startswith('Forearm');cover=np.ones(z.shape,bool) if bracer else z<.80
        tile[cover]=hide[cover]
        tile[cover&((z<.07)|(z>.93 if bracer else z>.75))]=EDGE
        perimeter=np.minimum(u,1-u)
        tile[cover&(perimeter<.035)]=EDGE
        seams=cover&((abs(u-.085)<.015)|(abs(u-.915)<.015))&stitches&(z>.09)&(z<.72)
        tile[seams]=(160,118,72)
        bands=(abs(z-.22)<.049)|(abs(z-.68)<.049)
        tile[bands]=strap[bands];tile[bands&(abs(z-.22)>.035)&(abs(z-.68)>.035)]=EDGE
        if front or back:
            studs=bands&((abs(x-.18)<.025)|(abs(x-.82)<.025));tile[studs]=(145,141,116)
        if full:
            # Long bone flanked by skin, broad joint heads and narrow shaft.
            bone=vertical&(z>.08)&(z<.90)&(abs(u-.5)<(.09+.20*((z<.25)|(z>.74))))
            skin_gap=vertical&(u>.20)&(u<.80)&~bands
            tile[skin_gap]=skin[skin_gap];tile[bone]=grain(position,BONE)[bone]
            tile[bone&(abs(u-.5)<.027)]=BONE+[19,16,10]
    elif name.startswith('Foot'):
        tile=hide.copy();tile[z<.21]=(38,30,23);tile[(z>.21)&(z<.26)]=(131,88,48)
        seam=abs(y-.23)<.018;tile[seam&(z>.26)]=EDGE
        tile[(y>.26)&(y<.30)&(z>.26)&(np.floor(x*28).astype(int)%4==1)]=(161,117,70)
        if full and poly.index==1:
            bone=(abs(x-.5)<.34)&(y<.75);toe=(np.floor(x*22).astype(int)%4<2)
            tile[bone&toe]=BONE
    return np.clip(tile,0,255).astype(np.uint8)

def skull(poly,frac,position,original):
    x,y,z=(frac[...,i] for i in range(3));tile=grain(position,SKIN)
    if poly.index==2:
        spread=.30+.17*(z>.37)
        mask=(abs(x-.5)<spread)&(z>.11)
        eyes=(z>.48)&(z<.72)&(((x>.12)&(x<.43))|((x>.57)&(x<.88)))
        nose=(abs(x-.5)<(.035+.04*(.49-z)))&(z>.31)&(z<.49)
        teeth=(z>.13)&(z<.29)&(np.floor(x*28).astype(int)%4==0)
        mask&=~(eyes|nose|teeth)
        tile[mask]=grain(position,BONE)[mask]
        rim=mask&((z>.9)|(abs(x-.5)>.40));tile[rim]=BONE-[26,23,15]
        # Keep the symmetric amber eyes from the original single head texture.
        amber=(original[...,0]>145)&(original[...,1]>120)&(original[...,2]<110)
        tile[amber&eyes]=original[amber&eyes]
        pupil=eyes&(original[...,0]<45)&(original[...,1]<50);tile[pupil]=original[pupil]
    elif poly.index==1:
        mask=(x>.10)&(x<.90)&(y>.10)&(y<.90);tile[mask]=grain(position,BONE)[mask]
        tile[mask&(abs(x-.5)<.035)]=BONE+[18,14,8]
    elif poly.index in (3,4,5):
        u=x if poly.index==3 else y
        mask=((z>.67)&(u>.12)&(u<.90))|((z>.22)&(z<.37)&(u>.12)&(u<.84))
        tile[mask]=grain(position,BONE)[mask]
    return np.clip(tile,0,255).astype(np.uint8)
