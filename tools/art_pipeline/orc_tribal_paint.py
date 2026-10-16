"""Weathered bone, bound wood and practical forged edges; no insignias."""
import numpy as np

PALETTE={'bone':(193,182,150),'bone_dark':(166,154,121),'iron':(66,70,65),
         'edge':(127,130,116),'wood':(87,58,33),'leather':(65,43,27),'cord':(118,101,70)}

def surface(kind,shape,tier=0,seed=1):
    h,w=shape;yy,xx=np.mgrid[:h,:w];u=(xx+.5)/w;v=(yy+.5)/h
    rng=np.random.default_rng(seed)
    base=np.array(PALETTE[kind],dtype=float)
    if kind=='bone' and tier==3:base+=np.array([10,11,10])
    tile=np.broadcast_to(base,(h,w,3)).copy()
    tile+=rng.choice([-2,-1,0,0,0,1,2],(h,w))[...,None]
    if kind.startswith('bone'):
        # Mineral grain and the darker edge of a carved plate, not spots.
        rim=np.minimum(u,1-u);tile+=np.clip((rim-.12)*16,-12,4)[...,None]
        tile+=((np.floor(u*13)+np.floor(v*2))%7==0)[...,None]*-5
        tile[v<.08]-=7;tile[v>.92]+=5
        fracture=(abs(u-(.72-.06*v))<.014)&(v>.61)
        tile[fracture]=base-[35,34,28]
    elif kind=='wood':
        stripe=np.floor(u*13).astype(int)
        tile[(stripe%3)==0]-=10
        grain=(np.floor(u*33)+np.floor(v*5))%17==0;tile[grain]-=10
        tile[(v<.06)|(v>.94)]=base-[15,10,5]
    elif kind=='leather':
        band=np.floor(v*7).astype(int)
        tile[band%2==0]-=[9,6,3]
        tile[np.mod(v*7,1)<.10]=base-[22,14,7]
        tile[(u<.06)|(u>.94)]=base-[14,10,6]
        stitch=(u>.10)&(u<.17)&(np.mod(v*11,1)<.24)
        tile[stitch]=base+[38,31,20]
    elif kind=='cord':
        tile[((xx+yy)//3)%2==0]-=18
    else:
        tile[(u<.075)|(u>.925)]=base+[25,24,19]
        tile[(u>.43)&(u<.51)]=base+[9,9,7]
        tile[(v<.045)|(v>.955)]=base-[17,16,12]
        scratches=(np.mod(u*19+v*2,1)<.035)&(v>.28)&(v<.74)
        tile[scratches]+=7
    return np.clip(tile,0,255).astype(np.uint8)

def mounted_armor(canvas,obj,poly,lo,hi,frac,tier):
    name=obj['part'];x0,y0=lo;x1,y1=hi
    tile=canvas[y0:y1,x0:x1,:3].copy();fx,fy,fz=(frac[...,i] for i in range(3))
    mask=np.zeros(fz.shape,dtype=bool)
    if name=='Chest':
        mask=(fz<.86)&((fx>.64) if tier==0 else np.ones(fz.shape,dtype=bool))
    elif name.startswith('Shoulder'):
        if tier>0 or name.endswith('_l'):mask=fz>.18
    elif name.startswith('Forearm'):mask=(fz>.28)&(fz<.77)
    elif name.startswith('Shin') and tier>0:mask=(fz>.24)&(fz<.67)
    elif name=='Pelvis' and tier>1:mask=(fz>.63)&(fz<.91)&(fx>.25)&(fx<.75)
    if not mask.any():return False
    bone=surface('bone',fz.shape,tier,seed=121+poly.index+sum(map(ord,name)))
    tile[mask]=bone[mask]
    # Several carved plates tied onto hide. All faces get complete edges.
    vertical=(np.mod(fx*(3 if name=='Chest' else 2),1)<.07)
    horizontal=(np.mod(fz*(3 if name=='Chest' else 2),1)<.07)
    joints=mask&(vertical|horizontal)
    tile[joints]=(77,57,35)
    straps=mask&((abs(fz-.32)<.035)|(abs(fz-.68)<.035))
    if name=='Chest':straps=mask&(abs(fz-.25)<.027)
    tile[straps]=(67,44,27)
    if name.startswith('Shoulder'):
        tie=mask&(abs(fx-.20)<.035);tile[tie]=(75,51,30)
    canvas[y0:y1,x0:x1,:3]=tile
    return True
