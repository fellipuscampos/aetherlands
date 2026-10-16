"""Complete wrapped leather pieces painted in cuboid/world coordinates.

The approved shield and skin are authored by the existing builder. This module
replaces only the clothing: an uninterrupted baldric, bound bone shoulder,
sewn hide panels, strapped bracers and matching leather boot/foot pieces.
"""
import numpy as np

HIDE=(90,62,40)
BOOT=(64,47,31)
STRAP=(55,40,27)
EDGE=(44,33,23)
THREAD=(128,103,66)
IRON=(104,103,88)
BONE=(177,167,132)
SKIN=(91,111,63)


def leather(position,base):
    """Subtle physical grain; avoid drawing a separate frame around each UV face."""
    q=np.floor(position*350).astype(np.int64)
    hashed=(q[...,0]*73856093)^(q[...,1]*19349663)^(q[...,2]*83492791)
    fine=(hashed%5-2)[...,None]
    q=np.floor(position*24).astype(np.int64)
    coarse=((q[...,0]*13+q[...,1]*23+q[...,2]*37)%5-2)[...,None]
    return np.array(base,dtype=np.int16)+fine+coarse


def finish(obj,poly,frac,tile,position):
    part=obj['part']; fx,fy,fz=(frac[...,i] for i in range(3))
    x,y,z=(position[...,i] for i in range(3))
    front=poly.index==2; back=poly.index==3
    vertical=poly.index in (2,3,4,5)
    qz=np.floor(z*150).astype(int)
    qx=np.floor(fx*28).astype(int)
    qy=np.floor(fy*28).astype(int)
    kind=None
    # Cuboid surface coordinates let cuffs/edges wrap onto the other faces.
    u=fx if poly.index in (0,1,2,3) else fy
    distance_to_corner=np.minimum(u,1-u)
    if part in ('Chest','Belly'):
        tile[:]=leather(position,SKIN)
        if front or back:
            if part=='Chest':
                tile[(fz>.30)&(fz<.78)&(abs(fx-.5)>.12)&(abs(fx-.5)<.43)]=np.array(SKIN)+[4,5,3]
                tile[(fz<.20)&(abs(fx-.5)<.38)]=np.array(SKIN)-[5,6,3]
            else:
                tile[(abs(fx-.5)<.025)&(fz>.32)]=np.array(SKIN)-[7,8,4]
        # One world-space line crosses the differently sized chest and belly.
        center=-.20+1.35*(z-1.011892)
        distance=abs(x-center)
        mask=distance<.040
        if poly.index in (0,1): mask=np.zeros_like(mask)
        raw=leather(position,STRAP); tile[mask]=raw[mask]
        rim=mask&(distance>.032); tile[rim]=EDGE
        stitches=mask&(distance>.025)&(distance<.031)&(qz%4==1)
        tile[stitches]=THREAD
        # The buckle is drawn on the front of the strap, away from body seams.
        if front and part=='Chest':
            buckle=mask&(z>1.304)&(z<1.351)
            frame=buckle&((z<1.312)|(z>1.343)|(distance>.026))
            tile[frame]=IRON
            tongue=buckle&(abs(z-1.328)<.004)&(distance<.028)
            tile[tongue]=IRON
        kind='skin_and_continuous_leather_strap'
    elif part=='Shoulder_r':
        # Remove the isolated stripe from the bare shoulder.
        tile[:]=leather(position,SKIN)
        kind='bare_skin'
    elif part=='UpperArm_r':
        cuff=(fz>.78)&(fz<.95)
        raw=leather(position,STRAP); tile[cuff]=raw[cuff]
        tile[cuff&((fz<.81)|(fz>.92))]=EDGE
        if front:
            stitch=cuff&(fz>.83)&(fz<.87)&(qx%4==1)
            tile[stitch]=THREAD
        kind='skin_with_bound_leather_armband'
    elif part=='Pelvis' or part.startswith('Thigh'):
        # The same hide runs from hips around every side of the upper thigh.
        if part=='Pelvis':
            mask=np.ones(fz.shape,dtype=bool)
        else:
            mask=fz>.64
        raw=leather(position,HIDE); tile[mask]=raw[mask]
        if part=='Pelvis':
            belt=fz>.58; tile[belt]=leather(position,STRAP)[belt]
            tile[(abs(fz-.59)<.026)|(fz>.94)]=EDGE
            if front or back:
                stitch=(fz>.62)&(fz<.68)&(qx%4==1)
                tile[stitch]=THREAD
                rivet=(fz>.76)&(fz<.84)&((abs(fx-.12)<.021)|(abs(fx-.87)<.021))
                tile[rivet]=IRON
            # Double seams on the long sewn hide panels, never stray scratches.
            if front or back:
                seam=(abs(fx-.25)<.025)|(abs(fx-.76)<.025)
                tile[seam&~belt]=EDGE
                stitch=((abs(fx-.29)<.015)|(abs(fx-.72)<.015))&(qz%4==1)&~belt
                tile[stitch]=THREAD
        else:
            hem=mask&(fz<.68); tile[hem]=EDGE
            stitch=mask&(fz>.68)&(fz<.72)&((qx if front or back else qy)%4==1)
            tile[stitch]=THREAD
            seam=mask&(distance_to_corner<.035); tile[seam]=EDGE
        kind='sewn_hide' if part!='Pelvis' else 'belt_and_sewn_hide'
    elif part=='Shoulder_l':
        tile[:]=leather(position,HIDE)
        # Bone extends over the upper shoulder and its four vertical sides.
        if vertical:
            plate=(fz>.35)&(u>.14)&(u<.86)
            border=plate&((fz<.40)|(u<.19)|(u>.81))
        else:
            plate=(fx>.14)&(fx<.86)&(fy>.14)&(fy<.86)&(poly.index==1)
            border=plate&((fx<.19)|(fx>.81)|(fy<.19)|(fy>.81))
        bone=leather(position,BONE); tile[plate]=bone[plate]
        tile[border]=np.array(BONE)-[24,23,18]
        # Full straps wrap over the top, down the front/back, and under it.
        bindings=(abs(fx-.12)<.044)|(abs(fx-.88)<.044)
        tile[bindings]=leather(position,STRAP)[bindings]
        if front or back:
            stitch=bindings&(qz%4==1)&((abs(fx-.12)<.014)|(abs(fx-.88)<.014))
            tile[stitch]=THREAD
            rivet=bindings&(fz>.22)&(fz<.29)
            tile[rivet]=IRON
        # Quiet marks belong to the bone plate, not random colored patches.
        crack=plate&(abs(u-(.62-.15*fz))<.012)&(fz>.62)&(fz<.88)&vertical
        tile[crack]=np.array(BONE)-[28,27,20]
        kind='bound_bone_over_hide'
    elif part.startswith('Forearm'):
        tile[:]=leather(position,BOOT)
        hem=(fz<.07)|(fz>.93); tile[hem]=EDGE
        straps=(abs(fz-.20)<.050)|(abs(fz-.78)<.050)
        tile[straps]=leather(position,STRAP)[straps]
        if vertical:
            seam=distance_to_corner<.035; tile[seam]=EDGE
        if vertical:
            stitches=((u>.065)&(u<.12)|(u>.88)&(u<.935))&(qz%4==1)&(fz>.10)&(fz<.89)
            tile[stitches]=THREAD
        if part.endswith('_l') and front:
            splint=(fx>.28)&(fx<.72)&(fz>.30)&(fz<.66)
            tile[splint]=leather(position,BONE)[splint]
            tile[splint&((fx<.32)|(fx>.68))]=np.array(BONE)-[21,20,16]
        if front:
            rivets=straps&((abs(fx-.15)<.028)|(abs(fx-.85)<.028))
            tile[rivets]=IRON
        kind='stitched_leather_bracer'
    elif part.startswith('Shin'):
        mask=fz<.80
        raw=leather(position,BOOT); tile[mask]=raw[mask]
        cuff=mask&(fz>.73); tile[cuff]=EDGE
        tile[(fz>.68)&(fz<.73)]=np.array(BOOT)+[9,7,4]
        # Two complete straps with modest hardware.
        straps=(abs(fz-.19)<.040)|(abs(fz-.57)<.040)
        tile[straps]=leather(position,STRAP)[straps]
        if vertical:
            seam=mask&(distance_to_corner<.033); tile[seam]=EDGE
            stitches=mask&((u>.052)&(u<.085)|(u>.915)&(u<.948))&(qz%4==1)&(fz>.06)&(fz<.65)
            tile[stitches]=THREAD
        if front:
            rivets=straps&(fx>.70)&(fx<.77); tile[rivets]=IRON
        # The boot continues directly onto the foot at the ankle.
        tile[fz<.06]=np.array(BOOT)-[4,3,2]
        kind='wrapped_leather_boot'
    elif part.startswith('Foot'):
        tile[:]=leather(position,BOOT)
        sole=fz<.20; tile[sole]=(36,31,24)
        tile[(fz>.20)&(fz<.25)]=(95,73,45)
        # A stitched toe seam follows the upper and both side surfaces.
        seam=abs(fy-.22)<.025
        tile[seam&~sole]=EDGE
        stitch=(fy>.25)&(fy<.29)&~sole&(qx%4==1)
        tile[stitch]=THREAD
        kind='matching_leather_boot_foot'
    return kind
