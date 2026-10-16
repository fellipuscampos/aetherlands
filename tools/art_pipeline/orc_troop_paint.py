"""Extend the approved leather/bone paint into practical class progressions."""
import numpy as np
from orc_troop_assets import PROFILES
from orc_clothing_paint import leather


def body(canvas,obj,poly,lo,hi,frac,row):
    part=obj['part']; tier=row['tier']; family=row['family']
    if part=='Head' or part.startswith(('ElfEar','Brow','Tusk','Shield')): return
    x0,y0=lo; x1,y1=hi; tile=canvas[y0:y1,x0:x1,:3].astype(np.int16)
    armor,style=PROFILES[family][tier]
    fx,fy,fz=(frac[...,i] for i in range(3)); yy,xx=np.mgrid[:y1-y0,:x1-x0]
    qx=np.floor(fx*20).astype(int); qz=np.floor(fz*24).astype(int)
    front=poly.index in (2,3); metal=np.array(armor)
    dark=np.maximum(metal-22,0); light=np.minimum(metal+18,255)
    # Change hide shades while keeping the approved placement and seams.
    if family in ('ranger','rogue'):
        brown=(tile[...,0]>tile[...,1]+7)&(tile[...,1]>tile[...,2]+7)&(tile[...,0]<145)
        delta=np.array(armor)-np.array([90,62,40])
        tile[brown]=np.maximum(tile[brown]+delta,0)
    elif family=='warrior':
        brown=(tile[...,0]>tile[...,1]+7)&(tile[...,0]<120)
        tile[brown]+=np.array([7,-1,-2])
    mask=np.zeros(fz.shape,dtype=bool)
    if part=='Chest' and family in ('guardian','cavalry') and tier>0:
        mask=(fz<.82)&(fx>.47) if tier==1 else (fz<.86)
        if poly.index in (4,5): mask=fz<.86
    elif part=='Chest' and family=='warrior' and tier>=2:
        mask=(fx>.67)&(fz<.87)
    elif part.startswith('Shoulder') and tier>0:
        if family in ('guardian','warrior','cavalry'): mask=fz>.20
        elif tier>=2: mask=(fz>.24)&(fx>.10)&(fx<.90)
    elif part.startswith('Forearm') and tier>=1:
        mask=(fz>.27)&(fz<.70)
    elif part.startswith('Shin') and tier>=2:
        mask=(fz>.26)&(fz<.62)
    elif part=='Pelvis' and tier==3:
        mask=(fz>.60)&(fz<.94)
    if mask.any():
        if style in ('hide','reinforced'):
            base=np.array(armor)+[7,5,3]
            tile[mask]=base
            seams=mask&((qx%7==0)|(qz%7==0)); tile[seams]=np.maximum(base-16,0)
            rivets=mask&(qx%7==3)&(qz%7==3); tile[rivets]=(120,115,94)
        elif style=='lamellar':
            tile[mask]=metal
            joints=mask&((qz%5==0)|((qx+(qz//5%2)*2)%5==0))
            tile[joints]=dark
            tile[mask&(qz%5==2)&(qx%5==2)]=light
        else:
            tile[mask]=metal
            edge=mask&((fx<.09)|(fx>.91)|(abs(fz-.27)<.032)|(abs(fz-.70)<.032))
            tile[edge]=dark
            ridge=mask&(abs(fx-.50)<.028); tile[ridge]=light
            if part=='Chest':
                join=mask&(abs(fz-(.64-.19*abs(fx-.5)))<.026)
                tile[join]=dark
            if tier==3:
                trim=mask&((fx<.07)|(fx>.93)|(abs(fz-.30)<.027))
                tile[trim]=(133,106,65)
            else:
                tile[mask&(qx%11==2)&(qz%11==2)]=(126,123,105)
    # Upper arms and most bellies remain bare; strength belongs to the body.
    canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)


def equipment(part,region,normal,shape,row):
    h,w=shape; yy,xx=np.mgrid[:h,:w]
    u=(xx+.5)/w; v=(yy+.5)/h
    seed=4000+sum(map(ord,part))+row['tier']*101
    rng=np.random.default_rng(seed)
    armor,style=PROFILES[row['family']][row['tier']]
    if region.startswith('horse_'):
        if any(key in region for key in ('mane','tail','hoof')): base=(33,31,26)
        elif region=='horse_ear': base=(73,52,33)
        else: base=((80,54,35),(65,49,35),(49,45,35),(45,43,36))[row['tier']]
        kind='horse_coat'
    elif 'shield' in region or part.startswith('Shield'):
        base=(85,63,39); kind='shield'
    elif any(key in region for key in ('string','rein')):
        base=(105,91,61) if 'string' in region else (48,35,24); kind='leather'
    elif any(key in region for key in ('haft','wood','shaft')) or part.startswith('BowLimb'):
        base=(80,57,34); kind='wood'
    elif any(key in region for key in ('pelt','fur')):
        base=(81,79,61); kind='fur'
    elif any(key in region for key in ('tabard','cape','cloak','mantle','blanket','pennant','team')):
        base={'guardian':(73,55,37),'warrior':(94,49,33),'ranger':(62,66,44),'cavalry':(85,56,35),'rogue':(38,43,35)}[row['family']]
        kind='cloth'
    elif any(key in region for key in ('leather','quiver','scabbard','grip','saddle','fletch')):
        base=(67,48,30); kind='leather'
    elif region=='horn':
        base=(173,160,123); kind='bone'
    else:
        base=(128,131,118) if any(key in region for key in ('blade','edge','head','ricasso','knife','dagger')) else (85,89,79)
        if row['tier']==3 and region in ('gold','sword_guard','sword_cross','brass'): base=(137,111,68)
        kind='metal'
    tile=np.clip(np.array(base)+rng.choice([-2,0,0,0,2],shape)[...,None],0,255).astype(np.int16)
    if kind in ('leather','cloth'):
        edge=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy])
        tile[edge<1]=np.array(base)-18
        stitch=(edge==2)&((xx+yy)%4==0); tile[stitch]=np.array(base)+26
        if kind=='cloth': tile[(xx+yy)%6==0]=np.array(base)-5
    elif kind in ('wood','shield'):
        plank=np.floor(u*5).astype(int)
        tile[(plank%2)==0]=np.array(base)-7
        tile[(np.floor(u*40).astype(int)+np.floor(v*4).astype(int))%13==0]=np.array(base)-15
        if kind=='shield':
            tile[(v<.07)|(v>.93)]=(58,61,53)
            tile[((v<.08)|(v>.92))&((abs(u-.13)<.03)|(abs(u-.87)<.03))]=(118,115,93)
            if row['tier']>=2: tile[(u<.06)|(u>.94)]=np.array(armor)
    elif kind=='metal':
        tile[(u<.07)|(u>.93)]=np.array(base)+24
        tile[(u>.46)&(u<.55)]=np.array(base)+11
        tile[(v<.045)|(v>.955)]=np.array(base)-24
    elif kind=='fur':
        tile[(xx+yy*3)%9==0]=np.array(base)-13
    if region=='horse_head':
        if abs(normal.x)>.5:
            eye=(u>.46)&(u<.66)&(v>.60)&(v<.76)
            tile[eye]=(32,30,24)
            tile[eye&(u<.50)]=(164,155,130)
        elif normal.y<-.45:
            tile[v<.31]=np.array(base)-[18,12,6]
            nostril=(v>.30)&(v<.40)&((u>.15)&(u<.28)|(u>.72)&(u<.85))
            tile[nostril]=(30,27,21)
    return np.clip(tile,0,255).astype(np.uint8),kind
