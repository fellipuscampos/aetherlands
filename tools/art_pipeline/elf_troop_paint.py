"""Sober elven material painting; integer mirrored faces on the existing head."""
import numpy as np

VERSION = 'elf_material_refinement_v2'
GOLD = (195,164,91)
SILVER = (169,184,176)
BRONZE = (145,117,73)
SLATE = (75,94,97)
IVORY = (204,202,173)
PALE = (237,221,209)
FULL_HELMETS = {'greathelm','great_helm'}
PROFILES = {
    'guardian': [('leather',(103,85,56),(149,157,117)),
                 ('lamellar',BRONZE,(124,149,126)),
                 ('plate',SILVER,(81,110,99)),
                 ('plate',GOLD,IVORY)],
    'warrior': [('quilt',(112,132,87),(112,132,87)),
                ('brigandine',(113,78,53),(140,146,111)),
                ('plate',SLATE,(92,118,105)),
                ('plate',GOLD,IVORY)],
    'ranger': [('leather',(118,91,53),(125,143,97)),
               ('leather',(101,80,49),(91,117,83)),
               ('lamellar',(119,137,116),(85,109,89)),
               ('lamellar',GOLD,IVORY)],
    'cavalry': [('leather',(94,107,71),(179,177,139)),
                ('mail',BRONZE,(90,125,108)),
                ('plate',SILVER,(111,145,122)),
                ('plate',GOLD,IVORY)],
    'rogue': [('leather',(88,81,62),(99,111,91)),
              ('leather',(65,78,67),(84,100,85)),
              ('leather',(53,60,58),(68,80,73)),
              ('plate',(169,139,77),(48,67,59))],
}


def positions(obj,poly,uv,lo,hi,width,height):
    x0,y0=lo; x1,y1=hi
    yy,xx=np.mgrid[y0:y1,x0:x1]
    coords=np.array([list(obj.data.vertices[obj.data.loops[i].vertex_index].co) for i in poly.loop_indices])
    unit=np.stack([(xx+.5)/width,(yy+.5)/height],axis=-1)
    basis=np.stack([uv[1]-uv[0],uv[-1]-uv[0]],axis=1)
    local=(unit-uv[0])@np.linalg.inv(basis).T
    return coords[0]+local[...,0,None]*(coords[1]-coords[0])+local[...,1,None]*(coords[-1]-coords[0])


def noise_color(base,shape,seed,spread=2):
    rng=np.random.default_rng(seed)
    return np.clip(np.array(base)+rng.choice([-spread,0,0,0,spread],shape)[...,None],0,255).astype(np.int16)


def head_face(canvas,obj,poly,uv,lo,hi,row,hair_color):
    pos=positions(obj,poly,uv,lo,hi,canvas.shape[1],canvas.shape[0]//2)
    verts=np.array([list(v.co) for v in obj.data.vertices])
    frac=(pos-verts.min(axis=0))/(verts.max(axis=0)-verts.min(axis=0))
    reg=obj['region']; normal=poly.normal
    kind,armor,cloth=PROFILES[row['family']][row['tier']]
    full=reg in FULL_HELMETS
    hood=reg in ('face_hood','rogue_hood')
    open_helm=reg in ('face_helm','face_coif')
    x0,y0=lo; x1,y1=hi
    tile=noise_color(PALE,frac.shape[:2],531+row['tier']*37+poly.index)
    audit=None
    if full:
        tile=noise_color(armor,frac.shape[:2],722+poly.index)
        fx,fz=frac[...,0],frac[...,2]
        if normal.y<-.6:
            # Metal faceplate, two equal vision slots and practical breathing holes.
            nx=len(np.unique(np.round(fx,5))); nz=len(np.unique(np.round(fz,5)))
            front=noise_color(armor,(nz,nx),822)
            front[:,0]=np.array(armor)-35; front[:,-1]=np.array(armor)-35
            front[0]=np.array(armor)-28; front[-1]=np.array(armor)+20
            ex=max(2,round(nx*.16)); ew=max(3,round(nx*.26)); ey=round(nz*.61)
            for dx in range(ew):
                front[ey,ex+dx]=(30,36,32); front[ey,nx-1-ex-dx]=(30,36,32)
            mid=nx//2
            front[1:-1,mid]=np.array(armor)+22
            for x in (ex,ex+2):
                front[max(2,round(nz*.25)),x]=(57,56,44)
                front[max(2,round(nz*.25)),nx-1-x]=(57,56,44)
            tile=map_front(front,frac)
            audit=dict(mode='closed_helmet',left_eye_pixels=0,right_eye_pixels=0,
                       left_visor_pixels=ew,right_visor_pixels=ew,width=nx,height=nz)
        else:
            edge=(frac[...,2]<.04)|(frac[...,2]>.96)
            tile[edge]=np.array(armor)-22
    elif normal.y<-.6:
        nx=len(np.unique(np.round(frac[...,0],5))); nz=len(np.unique(np.round(frac[...,2],5)))
        front=np.empty((nz,nx,3),dtype=np.int16)
        # Mirror even the subtle surface noise, then draw each feature in integer pixels.
        half=noise_color(PALE,(nz,(nx+1)//2),411+row['tier'])
        front[:,:half.shape[1]]=half
        front[:,nx//2:]=half[:,:(nx+1)//2][:,::-1]
        border=max(1,round(nx*.1)); top=max(2,round(nz*.16))
        if hood:
            front[:,:border]=cloth; front[:,-border:]=cloth; front[-top:]=cloth
        elif open_helm:
            metal=GOLD if row['tier']==3 else (SILVER if reg=='face_helm' else BRONZE)
            front[:,:border]=metal; front[:,-border:]=metal; front[-top:]=metal
        hairline=nz-top-2 if hood or open_helm else nz-2
        front[hairline:hairline+2,border:nx-border]=hair_color
        if not hood and not open_helm:
            front[-2:]=hair_color
            front[round(nz*.4):,:1]=hair_color; front[round(nz*.4):,-1:]=hair_color
        ex=max(border+1,round(nx*.22)); ew=max(2,round(nx*.17)); ey=round(nz*.51)
        ew=min(ew,(nx-2*ex-2)//2)
        brow=np.clip(np.array(hair_color)-65,0,255)
        for dx in range(ew):
            for x in (ex+dx,nx-1-ex-dx):
                front[ey,x]=(38,67,59)
                front[min(nz-1,ey+2),x]=brow
        front[ey,ex]=(243,242,227); front[ey,nx-1-ex]=(243,242,227)
        # A centered nose and a short mouth; both use exact mirrored columns.
        center_cols=[nx//2] if nx%2 else [nx//2-1,nx//2]
        for x in center_cols:
            front[max(0,ey-3):ey-1,x]=(214,194,182)
        mouth_start=round(nx*.36)
        front[max(1,round(nz*.24)),mouth_start:nx-mouth_start]=(165,120,115)
        tile=map_front(front,frac)
        audit=dict(mode='hood' if hood else 'open_helmet' if open_helm else 'face',
                   left_eye_pixels=ew,right_eye_pixels=ew,pupil_pixels_per_eye=ew-1,
                   eyes_mirrored=True,width=nx,height=nz)
        assert np.array_equal(front[ey,:nx//2],front[ey,-(nx//2):][::-1])
    elif hood:
        tile=noise_color(cloth,frac.shape[:2],31+poly.index)
    elif open_helm:
        tile=noise_color(SILVER if reg=='face_helm' else BRONZE,frac.shape[:2],52+poly.index)
        if abs(normal.x)>.6:
            mask=(frac[...,1]<.35)&(frac[...,2]<.78)
            tile[mask]=PALE
    elif normal.z>.6 or normal.y>.6:
        tile=noise_color(hair_color,frac.shape[:2],63+poly.index)
    elif abs(normal.x)>.6:
        mask=(frac[...,2]>.68)|(frac[...,1]>.65)
        hair=noise_color(hair_color,frac.shape[:2],13+poly.index)
        tile[mask]=hair[mask]
    canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)
    if audit:
        audit['uv_bounds']=[int(x0),int(y0),int(x1),int(y1)]
        if audit['mode']!='closed_helmet':
            vx=np.unique(np.round(frac[...,0],5)); vz=np.unique(np.round(frac[...,2],5))
            ix=np.searchsorted(vx,np.round(frac[...,0],5)); iz=np.searchsorted(vz,np.round(frac[...,2],5))
            samples=[]
            for side in (0,1):
                coords=[]
                for dx in range(ew):
                    column=ex+dx if side==0 else nx-1-ex-dx
                    y,x=np.argwhere((ix==column)&(iz==ey))[0]
                    coords.append([int(x+x0),int(y+y0)])
                samples.append(coords)
            audit['eye_atlas_pixels']=samples
    return audit


def map_front(front,frac):
    # UV rotations cannot affect the mirror or feature dimensions.
    values_x=np.unique(np.round(frac[...,0],5)); values_z=np.unique(np.round(frac[...,2],5))
    ix=np.searchsorted(values_x,np.round(frac[...,0],5))
    iz=np.searchsorted(values_z,np.round(frac[...,2],5))
    return front[iz,ix]


def material_kind(obj,row):
    part=obj['part']; reg=obj['region']; kind,armor,cloth=PROFILES[row['family']][row['tier']]
    if part=='Head': return None,None
    if reg.startswith('horse_'): return None,None
    if reg in ('hair',): return 'hair',None
    if part.startswith('Shield') and reg not in ('brass','gold'):
        return 'shield',armor if row['tier']>1 else (125,104,66)
    if part=='Chest': return kind,armor
    if part=='Belly': return ('mail',armor) if row['tier']>0 and row['family'] in ('guardian','cavalry') else ('cloth',cloth)
    if part.startswith('Shoulder'):
        if row['tier']==3: return 'plate',armor
        if row['tier']>=2: return 'plate',SLATE if row['family']=='rogue' else armor
        if row['family']=='ranger' and row['tier']==1: return 'fur',(131,129,101)
        return 'leather',(91,78,48) if row['tier']==0 else BRONZE
    if part.startswith('Forearm') or part.startswith('Shin'):
        if row['tier']==3: return 'plate',armor
        if row['tier']==2: return 'plate',SLATE if row['family']=='rogue' else armor
        return 'leather',(87,71,47)
    if part.startswith('UpperArm'): return ('mail',armor) if row['family'] in ('guardian','cavalry') and row['tier']>=1 else ('cloth',cloth)
    if part.startswith('Thigh'): return 'cloth',(79,85,68) if row['family']!='rogue' else (49,59,53)
    if part=='Pelvis': return 'belt',cloth
    if part.startswith('Foot'): return 'boot',(63,55,40)
    if part.startswith('Hand'): return 'glove',(85,68,45)
    if reg in ('helm','steel','iron','greathelm','great_helm','skullcap','shoulder_plate','plate','gauntlet','gorget','pauldron_lame'):
        return 'plate',armor if row['tier']==3 else SILVER if row['tier']!=1 else BRONZE
    if reg in ('gold','brass','circlet','sword_guard','sword_cross','sword_pommel','band'):
        return 'plate',GOLD if row['tier']==3 else BRONZE
    if reg in ('cape','cloak','royal_cloak','tabard','royal_tabard','saddle_blanket','pennant','team'):
        return 'cloth_border',cloth if row['tier']<3 else IVORY if row['family']!='rogue' else cloth
    if reg in ('cap','quiver','dark_leather','saddle','scabbard','leather_belly'):
        return 'leather',(99,80,49)
    if reg in ('fur_boot','fur_pauldron','pelt'): return 'fur',(181,180,154) if row['tier']==3 else (128,124,98)
    return None,None


def surface(canvas,obj,poly,uv,lo,hi,row,hair_color):
    kind,base=material_kind(obj,row)
    if kind is None: return None
    if kind=='hair': base=hair_color
    x0,y0=lo; x1,y1=hi
    pos=positions(obj,poly,uv,lo,hi,canvas.shape[1],canvas.shape[0]//2)
    verts=np.array([list(v.co) for v in obj.data.vertices]); origin=verts[0]
    axes=[verts[j]-origin for j in (1,2,4)]
    uvfrac=np.stack([(pos-origin)@axis/max(axis@axis,1e-9) for axis in axes],axis=-1)
    fx,fy,fz=uvfrac[...,0],uvfrac[...,1],uvfrac[...,2]
    n=np.array(poly.normal); front=abs(n@(axes[1]/np.linalg.norm(axes[1])))>.65
    # Consistent material motifs across adjacent faces, measured along each cuboid.
    qx=np.floor(np.clip(fx,0,.9999)*16).astype(int)
    qz=np.floor(np.clip(fz,0,.9999)*20).astype(int)
    yy,xx=np.mgrid[0:y1-y0,0:x1-x0]
    edge=np.minimum.reduce([xx,yy,x1-x0-1-xx,y1-y0-1-yy])
    tile=noise_color(base,xx.shape,940+poly.index+sum(ord(c) for c in obj['part']),2)
    dark=np.clip(np.array(base)-30,0,255); light=np.clip(np.array(base)+23,0,255)
    if kind in ('plate','lamellar','brigandine','mail'):
        if kind=='plate':
            tile[edge==0]=dark; tile[edge==1]=light
            if front:
                ridge=(abs(fx-.5)<.035)
                tile[ridge]=light
                if obj['part']=='Chest':
                    join=abs(fz-(.76-.22*abs(fx-.5)))<.022
                    tile[join]=dark
                if obj['part'].startswith('Forearm'):
                    tile[(abs(fz-.2)<.025)|(abs(fz-.8)<.025)]=dark
        elif kind=='lamellar':
            seams=(qz%4==0)|((qx+(qz//4%2)*2)%4==0)
            tile[seams]=dark; tile[(qz%4==1)&(qx%4==2)]=light
        elif kind=='brigandine':
            seams=(qx%5==0)&front; tile[seams]=dark
            rivets=(qx%5==2)&(qz%5==2)&front; tile[rivets]=BRONZE
        else:
            tile[(qx+(qz//2)%2)%2==0]=np.array(base)-18
            tile[(qz%2==0)&(qx%2==1)]=np.array(base)+12
    elif kind in ('cloth','quilt','cloth_border'):
        tile[((qx+qz)%4==0)]=np.array(base)-6
        if kind=='quilt': tile[((qx+qz)%6==0)|((qx-qz)%6==0)]=np.array(base)-16
        if kind=='cloth_border':
            tile[edge==0]=np.array(base)-35
            tile[edge==1]=np.array((76,105,83)) if row['tier']==3 else np.array(IVORY)-24
        elif front:
            tile[(fx<.055)|(fx>.945)]=np.array(base)-15
    elif kind in ('leather','boot','glove','belt'):
        tile[edge==0]=dark
        if kind=='leather' and front:
            tile[(fx<.09)|(fx>.91)]=dark
            tile[((qx==1)|(qx==14))&(qz%3==1)]=np.array(base)+19
            if obj['part']=='Chest':
                tile[(abs(fx-.5)<.045)]=dark
                tile[(abs(fx-.5)<.11)&(qz%3==0)]=np.array(base)+18
        if kind in ('belt','boot','glove'):
            band=fz>.62 if kind=='belt' else (abs(fz-.72)<.07 if kind=='boot' else fz<.18)
            tile[band]=(63,51,35)
            if kind=='belt' and front: tile[band&(abs(fx-.5)<.09)]=BRONZE
        elif obj['part'].startswith(('Forearm','Shin')):
            tile[(abs(fz-.22)<.055)|(abs(fz-.78)<.055)]=dark
    elif kind=='shield':
        tile[((qx%5)==0)&front]=dark
        tile[edge<2]=np.array(GOLD if row['tier']==3 else SILVER)-5
        rivets=((qx%6==2)&((fz<.1)|(fz>.9)))&front
        tile[rivets]=np.array(base)+24
    elif kind=='fur':
        tile[(qz+qx*2)%5==0]=np.array(base)-13
    canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)
    return kind
