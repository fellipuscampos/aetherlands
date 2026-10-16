"""Closed cortical bone plates, with skin visible only through narrow seams."""
import numpy as np
from orc_refined_clothing_paint import grain,SKIN

BONE=np.array((215,202,165)); SHADE=np.array((153,139,108)); RIDGE=np.array((235,224,188))

def color(position,u,v):
    tile=grain(position,BONE)
    # Broad facet lighting and subtle longitudinal cortical fibers.
    light=10*np.cos((u-.42)*5)-7*np.abs(v-.55)
    tile+=np.rint(light)[...,None].astype(int)
    fiber=(np.floor(position[...,0]*160)+np.floor(position[...,2]*95)).astype(int)%19==0
    tile[fiber]-=[7,6,4]
    # Sparse stepped hairline fissures, enough to identify actual old bone.
    crack=(abs(u-(.18+.018*np.floor(v*8)))<.009)&(v>.18)&(v<.48)
    tile[crack]=SHADE+[10,8,4]
    return tile

def plates(obj,poly,frac,position,row,original):
    name=obj['part'];x,y,z=(frac[...,i] for i in range(3));vertical=poly.index>=2
    u=x if poly.index in (0,1,2,3) else y;v=z if vertical else y
    tile=color(position,u,v);green=grain(position,SKIN)
    # A warm bevel makes the coverage read as carved armor rather than paint.
    edge=np.minimum.reduce((u,1-u,v,1-v))
    tile[edge<.026]=SHADE;tile[(edge>=.026)&(edge<.06)]=BONE+[13,11,6]
    seam=np.zeros(u.shape,bool)
    if name=='Head':
        if poly.index==2:
            # Fully enclosed boar skull: thick brows, cheekbones, nasal bridge,
            # closed toothed jaw. The only dark openings expose green skin.
            orbit=((x>.12)&(x<.40)|(x>.60)&(x<.88))&(z>.51)&(z<.69)
            orbital_rim=((x>.08)&(x<.44)|(x>.56)&(x<.92))&(z>.47)&(z<.75)
            tile[orbital_rim]=SHADE+[19,18,12];tile[orbit]=green[orbit]
            inner=(abs(x-.5)<.09)&(z>.30)&(z<.82);tile[inner]=RIDGE
            side=(abs(x-.5)>.34)&(z>.21)&(z<.48);tile[side]=BONE-[17,15,10]
            nostril=(((x>.39)&(x<.45))|((x>.55)&(x<.61)))&(z>.34)&(z<.41)
            tile[nostril]=green[nostril]
            mouth=(abs(x-.5)<.34)&(z>.15)&(z<.26)
            tile[mouth]=green[mouth]
            teeth=mouth&((np.floor(x*26).astype(int)%3)!=0)&(((z>.20)&(z<.26))|((z>.15)&(z<.18)))
            tile[teeth]=RIDGE
            jaw=(abs(x-.5)<.34)&(z>.07)&(z<.16);tile[jaw]=BONE+[9,8,5]
            # Eye pixels are an explicit protected, symmetric feature.
            amber=(original[...,0]>145)&(original[...,1]>120)&(original[...,2]<110)
            tile[amber&orbital_rim]=original[amber&orbital_rim]
            pupil=(original[...,0]<45)&(original[...,1]<50)&orbital_rim
            tile[pupil]=original[pupil]
            # A few tiny growth cracks, avoiding eyes and the central keel.
            crack=(abs(x-(.24+.12*z))<.009)&(z>.80)&(z<.94)
            tile[crack]=SHADE
        elif poly.index in (3,4,5):
            seam=(abs(z-.24)<.014)&(u>.10)&(u<.90)
            tile[(abs(u-.5)<.038)&(z>.3)]=RIDGE
        else:
            tile[abs(x-.5)<.045]=RIDGE
    elif name in ('Chest','Belly'):
        if vertical:
            # Three broad, interlocking bony lamellae instead of thin ribs.
            a=abs(u-.5);curve=z+.23*a
            levels=(.29,.60,.88) if name=='Chest' else (.36,.73)
            for level in levels:
                gap=abs(curve-level)
                seam|=(gap<.013)&(a>.065)&(a<.46)
                tile[(gap>=.013)&(gap<.042)]=SHADE+[12,10,5]
                tile[(curve-level>.042)&(curve-level<.075)]=RIDGE
            tile[a<.055]=BONE+[8,7,4]
            tile[a<.019]=RIDGE
            # A small nape/neck opening, never a bare chest.
            if name=='Chest':seam|=(z>.945)&(a<.13)
        else:seam=(abs(u-.5)<.02)&(v>.18)&(v<.80)
    elif name=='Pelvis':
        # The approved sewn panels and belt are real geometry on top of this.
        for level in (.27,.55):
            curve=z+.24*abs(u-.5);gap=abs(curve-level)
            seam|=(gap<.012)&(abs(u-.5)>.10)
            tile[(gap>.012)&(gap<.043)]=SHADE
            tile[(curve-level>.043)&(curve-level<.075)]=RIDGE
    elif name.startswith(('Shoulder','UpperArm','Forearm','Thigh','Shin')):
        if vertical:
            seam|=((z<.035)|(z>.965))&(u>.10)&(u<.90)
            seam|=(abs(u-.5)<.013)&(z>.12)&(z<.86)&(poly.index in (3,4))
            ridge=abs(u-.5)
            tile[ridge<.04]=RIDGE
            tile[(ridge>.36)&(ridge<.405)]=SHADE+[9,8,4]
            # Broad elbow/knee cuff with an overlapping pointed end.
            if name.startswith(('Forearm','Shin','Thigh')):
                curve=z+.28*abs(u-.5);gap=abs(curve-.77)
                seam|=(gap<.013)&(abs(u-.5)>.07)
                tile[(gap>.013)&(gap<.048)]=SHADE+[9,8,4]
                tile[(curve-.77>.048)&(curve-.77<.08)]=RIDGE
        else:
            tile[abs(u-.5)<.045]=RIDGE
    elif name.startswith('Hand'):
        # Knuckle scales cover the hand without touching the grip geometry.
        if vertical:
            seam=(z<.025)&(u>.15)&(u<.85)
            tile[(np.floor(u*4).astype(int)%2==0)&(z>.42)&(z<.57)]=SHADE+[16,14,8]
        else:
            seam=(abs(u-.25)<.012)|(abs(u-.50)<.012)|(abs(u-.75)<.012)
    elif name.startswith('Foot'):
        if vertical:
            tile[z<.13]=(57,44,29) # retained leather sole below the sabaton
            curve=z+.12*y
            seam=(abs(curve-.43)<.014)&(u>.06)&(u<.94)
            tile[(curve>.455)&(curve<.48)]=RIDGE
        else:
            for level in (.28,.57,.83):
                seam|=abs(y-level)<.012
                tile[(y>level+.012)&(y<level+.045)]=RIDGE
    tile[seam]=green[seam]
    return np.clip(tile,0,255).astype(np.uint8)

def detail(shape,seed=0):
    h,w=shape;yy,xx=np.mgrid[:h,:w];u=(xx+.5)/w;v=(yy+.5)/h
    edge=np.minimum.reduce((xx,yy,w-1-xx,h-1-yy))
    rng=np.random.default_rng(seed)
    tile=np.broadcast_to(BONE,(h,w,3)).astype(np.int16).copy()+rng.integers(-3,4,(h,w,1))
    tile[edge<1]=SHADE;tile[edge==1]=BONE+[13,12,8]
    tile[(u>.45)&(u<.56)]=RIDGE
    tile[(v>.72)&(v<.80)&(abs(u-.5)>.12)]=SHADE+[12,10,5]
    tile[(v>.80)&(v<.86)&(abs(u-.5)>.12)]=RIDGE
    return np.clip(tile,0,255).astype(np.uint8)
