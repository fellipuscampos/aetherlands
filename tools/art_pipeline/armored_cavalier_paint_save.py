"""Pixel-paint the metric UV islands of the static ArmoredCavalier V1 (Cavaleiro Blindado): albedo + emission (black).
Shock Cavalier palette and machinery, retuned for the elite heavy knight (NO gold): PLAIN steel plate on the rider
(dark edges only — no stripes, no separate chest plates), a closed great helm painted on the head (eye slit only), a blue heater shield with a steel rim and a white bend, and a dapple-GREY warhorse with the blue caparison
(no horse plates: the user removed them). Images are always FRESH datablocks.
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['armored_cavalier']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
GAMB=[(190,172,132),(198,180,140),(182,164,124)]; GAMB_SEAM=(150,132,96); GAMB_HI=(210,194,156)
LEATHER=[(112,72,44),(122,80,50),(102,66,40)]; LEATHER_DARK=(70,44,28); LEATHER_HI=(146,100,64)
HARD=[(92,58,36),(100,64,40),(86,54,34)]
WOOL=[(86,80,72),(94,88,80),(80,74,66)]; WOOL_DARK=(62,58,52)
SKIN=[(220,168,128),(212,160,122),(226,176,136)]; SKIN_SHADE=(186,136,100); HAIR=[(96,64,38),(108,72,42)]
COAT=[(104,102,100),(114,112,110),(96,94,92)]; COAT_DARK=(146,144,140); COAT_LIGHT=(150,148,144); MANE=[(46,44,44),(54,52,52),(40,38,38)]   # DAPPLE-grey warhorse: darker than the steel barding (light 'COAT_DARK' specks = dapples)
STEEL=[(168,172,180),(178,182,190),(160,164,172)]; STEEL_HI=(214,218,226); STEEL_DARK=(104,108,118)
MAIL=[(96,98,106),(106,108,116),(88,90,98)]; MAIL_DARK=(52,54,60)
HOOF=[(58,56,54),(66,64,60)]; BLAZE=[(232,226,214),(222,216,204)]; MUZ=[(70,56,50),(78,62,54),(64,50,44)]
EYE_W=(240,236,228); PUPIL=(40,48,70); BROW=(80,52,30); MOUTH=(150,88,72)
IRON=[(118,120,126),(128,130,136),(110,112,118)]; IRON_HI=(176,178,184); IRON_DARK=(70,72,78)
BRASS=[(196,160,84),(206,170,92),(186,150,76)]; BRASS_DARK=(138,108,52)
WOOD=[(150,108,66),(160,116,72),(140,100,60)]; WOOD_DARK=(104,72,42)
TEAM=[(54,82,140),(60,90,150),(50,76,130)]; TEAM_DARK=(36,56,100)
RIVET_C=(196,196,190)
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def axes(obj):
    v=obj.data.vertices; return (v[1].co-v[0].co).normalized(),(v[2].co-v[0].co).normalized(),(v[4].co-v[0].co).normalized()
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; n=item['normal']
    rng=random.Random(8820+index)
    right=item['right']; up=n.cross(right)
    lat,dep,hgt=axes(obj)
    def frac_dir(Dv):
        gx,gy=right.dot(Dv),up.dot(Dv)
        vals=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(vals),max(vals)
        return lambda x,y: .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    fz=frac_dir(Vector((0,0,1))); fl=frac_dir(lat); fh=frac_dir(hgt)
    top=n.z>.6; bottom=n.z<-.6; front=n.y<-.6; back=n.y>.6; side=abs(n.x)>.6
    t=[[GAMB[0]]*w for _ in range(h)]; e=[[(0,0,0)]*w for _ in range(h)]
    def noise(pal,weights=(5,3,2)):
        wts=list(weights)[:len(pal)] if len(pal)<=len(weights) else None   # any palette size
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(pal,wts)[0]
    def each(fn):
        for y in range(h):
            for x in range(w):
                c=fn(x,y,t[y][x])
                if c is not None: t[y][x]=c
    def edge(x,y): return min(x,y,w-1-x,h-1-y)
    def outline(c): each(lambda x,y,_: c if edge(x,y)==0 else None)
    def quilt():
        # Diamond stitching of a padded gambeson.
        noise(GAMB)
        each(lambda x,y,c: GAMB_SEAM if (x+y)%6==0 or (x-y)%6==0 else (GAMB_HI if (x+y)%6==1 else None))
    def straps(color,dark,every,width=2):
        if top or bottom: return
        each(lambda x,y,c: (dark if (y%every)==0 else color) if (y%every)<width else None)
    if reg=='gambeson':
        quilt()
        if not (top or bottom): each(lambda x,y,c: shade(c,-14) if fz(x,y)<.12 else None)
    elif reg=='jerkin':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.92 else (LEATHER_DARK if fz(x,y)<.06 else None))
            if front:
                # Laced front opening over the gambeson, rivets along the edges.
                each(lambda x,y,c: (GAMB[0] if abs(fl(x,y)-.5)<.07 else (LEATHER_DARK if abs(fl(x,y)-.5)<.09 else None)))
                each(lambda x,y,c: GAMB_SEAM if abs(fl(x,y)-.5)<.07 and y%3==0 else None)
            for y in range(2,h-2,4):
                for x in (2,w-3):
                    if 0<=x<w: t[y][x]=RIVET_C
        else: outline(LEATHER_DARK)
    elif reg=='shoulder':
        noise(HARD)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_DARK if y%5==4 else (LEATHER_HI if y%5==0 else None))
        else: each(lambda x,y,c: LEATHER_DARK if edge(x,y)==0 else (LEATHER_HI if edge(x,y)==1 else None))
        if w>5 and h>5: t[1][1]=RIVET_C; t[1][w-2]=RIVET_C
    elif reg=='bracer':
        noise(LEATHER); outline(LEATHER_DARK)
        if not (top or bottom):
            # Two straps around the bracer; a small brass BUCKLE centred on each strap on the arm's OUTER face only.
            # (User: on one arm the buckle smeared into two full yellow bands. The old test used `fl`, which is constant
            # on faces square to the block's width axis, so the whole strap turned brass. Now the buckle is centred along
            # the face's own across-axis and only drawn on the outer face, identical on both arms.)
            sgn=1 if obj['part'].endswith('_l') else -1
            across=n.cross(hgt); fa=frac_dir(across) if across.length>1e-6 else (lambda x,y: .5)
            outer=n.x*sgn>.45
            for fy in (.28,.70):
                each(lambda x,y,c: LEATHER_DARK if abs(fh(x,y)-fy)<.07 else None)
                if outer: each(lambda x,y,c: rng.choice(BRASS) if abs(fh(x,y)-fy)<.07 and abs(fa(x,y)-.5)<.16 else None)
    elif reg=='glove':
        noise([shade(c,18) for c in LEATHER]); each(lambda x,y,c: LEATHER_DARK if x%4==0 and not (top or bottom) and fz(x,y)<.5 else None)
    elif reg=='trousers':
        noise(WOOL); each(lambda x,y,c: WOOL_DARK if x%5==0 and rng.random()<.6 else None)
    elif reg=='boot_shaft':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.90 else None)          # folded cuff
            for fy in (.35,.62):
                each(lambda x,y,c: LEATHER_DARK if abs(fz(x,y)-fy)<.04 else None)
        else: outline(LEATHER_DARK)
    elif reg=='boot':
        noise([shade(c,-12) for c in LEATHER])
        if not (top or bottom): each(lambda x,y,c: (40,28,20) if fz(x,y)<.22 else None)   # sole
    elif reg=='pelvis':
        quilt()
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else LEATHER_DARK) if fz(x,y)>.62 else None)
            each(lambda x,y,c: GAMB_SEAM if fz(x,y)<.62 and x%5==0 else None)   # skirt panels
    elif reg=='brass':
        noise(BRASS); outline(BRASS_DARK)
    elif reg=='iron':
        noise(IRON)
        if not (top or bottom): each(lambda x,y,c: IRON_HI if fz(x,y)>.8 else (IRON_DARK if fz(x,y)<.2 else None))
        else: each(lambda x,y,c: IRON_DARK if edge(x,y)==0 else None)
    elif reg=='gambeson_chest':
        quilt()
        if front or back:
            # Diagonal leather baldric (shoulder to hip) with a brass buckle on the front.
            each(lambda x,y,c: (LEATHER_DARK if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.05 else rng.choice(LEATHER)) if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.11 else None)
            if front: each(lambda x,y,c: rng.choice(BRASS) if abs(fl(x,y)-.5)<.06 and abs(fz(x,y)-.5)<.07 else None)
        elif not (top or bottom): each(lambda x,y,c: shade(c,-14) if fz(x,y)<.12 else None)
    elif reg=='pelvis_sash':
        quilt()
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else LEATHER_DARK) if fz(x,y)>.62 else None)
            each(lambda x,y,c: rng.choice(TEAM) if .30<fz(x,y)<.62 else None)                   # blue team sash
            each(lambda x,y,c: TEAM_DARK if abs(fz(x,y)-.46)<.03 else None)
    elif reg=='cap':
        noise([shade(c,-6) for c in LEATHER])
        if top: each(lambda x,y,c: LEATHER_DARK if abs(fl(x,y)-.5)<.04 else None)           # stitched crown seam
        elif not bottom:
            each(lambda x,y,c: LEATHER_DARK if fz(x,y)<.12 else (LEATHER_HI if fz(x,y)>.90 else None))
            each(lambda x,y,c: GAMB_SEAM if fz(x,y)<.12 and x%3==0 else None)                     # stitched brim
    elif reg=='axe_haft':
        noise(WOOD); each(lambda x,y,c: WOOD_DARK if x%3==0 and rng.random()<.5 else None)
        each(lambda x,y,c: (LEATHER_DARK if int(fh(x,y)*24)%2 else rng.choice(LEATHER)) if fh(x,y)<.38 else None)   # grip wrap
    elif reg=='axe_head':
        noise(IRON); each(lambda x,y,c: IRON_DARK if edge(x,y)==0 else None)
    elif reg=='axe_edge':
        noise([IRON_HI,(196,198,204),(164,166,172)])
    elif reg in ('horse_body','horse_neck','horse_head','horse_leg','horse_cannon_front','horse_cannon_back','horse_ear'):
        noise(COAT); each(lambda x,y,c: COAT_DARK if rng.random()<.07 else None)                          # coat texture: subtle specks (diagonal lines read as knitting)
        if reg=='horse_body':
            if bottom: noise([COAT_LIGHT,shade(COAT_LIGHT,-8)])                                           # lighter belly
            elif side: each(lambda x,y,c: shade(c,-10) if fz(x,y)<.18 else None)
        if reg=='horse_head':
            # ONE rectangular head with the face PAINTED (user: no separate muzzle block). fd: 0 = nose end, 1 = poll;
            # fh: up the head's own height.
            fd=frac_dir(dep)
            if front:
                noise(MUZ); each(lambda x,y,c: (26,20,18) if abs(fh(x,y)-.52)<.13 and abs(abs(fl(x,y)-.5)-.24)<.09 else None)   # nostrils
            elif top:
                each(lambda x,y,c: rng.choice(MUZ) if fd(x,y)<.22 else (rng.choice(BLAZE) if abs(fl(x,y)-.5)<.17 and fd(x,y)<.92 else None))   # nose, blaze
                each(lambda x,y,c: LEATHER_DARK if abs(fd(x,y)-.36)<.03 or abs(fd(x,y)-.86)<.03 else None)                  # noseband, browband
            elif side:
                each(lambda x,y,c: rng.choice(MUZ) if fd(x,y)<.24 else None)                                              # dark nose
                each(lambda x,y,c: (40,30,28) if fd(x,y)<.30 and abs(fh(x,y)-.22)<.05 else None)                         # mouth line
                each(lambda x,y,c: (22,18,16) if abs(fd(x,y)-.70)<.045 and abs(fh(x,y)-.62)<.12 else None)               # eye
                each(lambda x,y,c: (236,232,224) if abs(fd(x,y)-.68)<.02 and abs(fh(x,y)-.70)<.05 else None)            # glint
                each(lambda x,y,c: LEATHER_DARK if abs(fd(x,y)-.36)<.03 or abs(fd(x,y)-.54)<.022 or abs(fd(x,y)-.86)<.03 else None)   # noseband, cheek strap, browband
            elif bottom:
                each(lambda x,y,c: rng.choice(MUZ) if fd(x,y)<.30 else None)
        if reg=='horse_cannon_front' and not (top or bottom):
            each(lambda x,y,c: rng.choice(BLAZE) if fz(x,y)<.30 else None)                              # white socks
        if reg=='horse_ear' and front: each(lambda x,y,c: COAT_DARK if edge(x,y)>0 else None)
    elif reg=='horse_muzzle':
        # Muzzle. fd: 0 = nose tip, 1 = where it meets the skull. Dark nose, blaze running down the top, noseband.
        fd=frac_dir(dep); noise(COAT)
        if front:
            noise(MUZ); each(lambda x,y,c: (26,20,18) if abs(fz(x,y)-.50)<.13 and abs(abs(fl(x,y)-.5)-.24)<.09 else None)   # nostrils
        elif top:
            each(lambda x,y,c: rng.choice(MUZ) if fd(x,y)<.32 else (rng.choice(BLAZE) if abs(fl(x,y)-.5)<.17 else None))
            each(lambda x,y,c: LEATHER_DARK if abs(fd(x,y)-.62)<.05 else None)                                   # noseband
        elif side:
            each(lambda x,y,c: rng.choice(MUZ) if fd(x,y)<.40 else None)
            each(lambda x,y,c: LEATHER_DARK if abs(fd(x,y)-.62)<.05 else None)
            each(lambda x,y,c: (40,30,28) if fd(x,y)<.45 and abs(fh(x,y)-.22)<.05 else None)                    # mouth line
        else: noise(MUZ)
    elif reg=='horse_mane':
        noise(MANE); each(lambda x,y,c: shade(c,-14) if x%2==0 and rng.random()<.6 else None)                  # strands
    elif reg=='horse_tail':
        noise(MANE); each(lambda x,y,c: shade(c,-14) if x%2==0 else None)
    elif reg=='horse_hoof':
        noise(HOOF)
    elif reg=='saddle_blanket':
        noise(TEAM)
        each(lambda x,y,c: (226,222,210) if edge(x,y)<=1 and not top else None)                          # white trim
    elif reg=='saddle':
        noise(LEATHER); outline(LEATHER_DARK)
        if top: each(lambda x,y,c: LEATHER_HI if abs(fl(x,y)-.5)<.30 and edge(x,y)>1 else None)
    elif reg=='rein':
        noise([LEATHER_DARK])
    elif reg=='lance_haft':
        noise(WOOD); each(lambda x,y,c: WOOD_DARK if x%3==0 and rng.random()<.5 else None)
        each(lambda x,y,c: (LEATHER_DARK if int(fh(x,y)*30)%2 else rng.choice(LEATHER)) if .24<fh(x,y)<.34 else None)   # grip
    elif reg=='pennant':
        each(lambda x,y,c: rng.choice(TEAM) if fz(x,y)>.5 else (226,222,210))                             # blue over white
    elif reg in ('breastplate','plate','vambrace','sabaton','pauldron','steel_plate'):
        # PLAIN steel (user rules: no stripes, no separate chest plates): only a dark edge, slightly darker flanks.
        noise(STEEL)
        each(lambda x,y,c: STEEL_DARK if edge(x,y)==0 else None)
        if reg=='breastplate' and (front or back): each(lambda x,y,c: shade(c,-10) if abs(fl(x,y)-.5)>.34 and edge(x,y)>0 else None)
        if reg=='pauldron' and top: each(lambda x,y,c: STEEL_HI if edge(x,y)==1 else None)
        if reg=='sabaton' and not (top or bottom): each(lambda x,y,c: (40,36,34) if fz(x,y)<.18 else None)   # sole
        if reg=='steel_plate' and front:
            for x in range(2,w-2,4):
                for y in (2,h-3):
                    if 0<=y<h: t[y][x]=STEEL_HI
    elif reg=='great_helm':
        noise(STEEL); each(lambda x,y,c: STEEL_DARK if edge(x,y)==0 else None)
        if front:
            each(lambda x,y,c: (20,20,24) if abs(fz(x,y)-.60)<.045 and .12<fl(x,y)<.88 else None)            # eye slit
    elif reg=='shield_heater':
        noise([(110,80,52),(118,86,56)])                                                                   # wooden edges
        if abs(n.x)>.6:
            noise(TEAM); fa=frac_dir(Vector((0,1,0)))
            if n.x>0: each(lambda x,y,c: (226,222,210) if abs(fa(x,y)-(1-fz(x,y)))<.10 else None)          # white bend (outer face)
            each(lambda x,y,c: rng.choice(STEEL) if edge(x,y)<2 else None)                                   # steel rim
    elif reg in ('mail','mail_chest'):
        for y in range(h):
            for x in range(w): t[y][x]=MAIL_DARK if (x+(y//2)%2)%2==0 and y%2==0 else rng.choice(MAIL)
        if reg=='mail_chest' and (front or back):   # leather lance-rest strap across the mail
            each(lambda x,y,c: (LEATHER_DARK if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.04 else rng.choice(LEATHER)) if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.09 else None)
    elif reg in ('face','face_helm','face_coif'):
        noise(SKIN)
        if front:
            # Symmetric, steady face (user: the first one looked crooked/goofy). Mirrored columns around the
            # centre: straight brows, dark narrow eyes right under them, a nose shade, a straight mouth.
            def mirror(x0,width,y,c):
                for dx in range(width):
                    for xx in (x0+dx,w-1-x0-dx):
                        if 0<=xx<w and 0<=y<h: t[y][xx]=c
            eye_y=int(round(h*.48)); ex=int(round(w*.22)); ew=max(2,int(round(w*.18)))
            mirror(ex-1,ew+1,eye_y-2,BROW)                      # brows, a bit wider than the eyes
            mirror(ex,ew,eye_y,PUPIL)                          # eyes: dark, narrow
            mirror(ex,1,eye_y,EYE_W)                           # small white on the OUTER corner
            c0=w//2-1 if w%2==0 else w//2
            for y in range(eye_y+1,eye_y+4):
                for xx in range(c0,w-c0): t[y][xx]=SKIN_SHADE   # nose shade, centred
            m0=int(round(w*.36)); my=int(round(h*.74))
            for xx in range(m0,w-m0): t[my][xx]=MOUTH            # one continuous, centred mouth line
            mirror(0,w//2+1,0,rng.choice(HAIR)); mirror(0,w//2+1,1,HAIR[0])   # fringe under the hat
            if reg in ('face_helm','face_coif'):   # nasal helmet PAINTED on the head: iron over the brow with a nose guard
                each(lambda x,y,c: rng.choice(IRON) if fz(x,y)>.70 or (abs(fl(x,y)-.5)<.06 and fz(x,y)>.42) else None)
                each(lambda x,y,c: IRON_DARK if abs(fz(x,y)-.70)<.03 else None)
            mirror(0,1,2,HAIR[1]); mirror(0,1,3,HAIR[1])                        # sideburns
        elif side or back:
            each(lambda x,y,c: rng.choice(HAIR) if (back and fz(x,y)>.25) or (side and fz(x,y)>.70) else None)
            if side:
                each(lambda x,y,c: rng.choice(HAIR) if fz(x,y)>.35 and ((n.x>0 and fl(x,y)>.78) or (n.x<0 and fl(x,y)<.22)) else None)
                each(lambda x,y,c: SKIN_SHADE if abs(fz(x,y)-.50)<.07 and abs(fl(x,y)-.5)<.09 else None)   # ear
        elif top: noise(HAIR)
        else: noise([SKIN_SHADE])
        if reg=='face_coif':   # mail coif framing the face and covering the neck (painted)
            mailpx=lambda x,y: MAIL_DARK if (x+(y//2)%2)%2==0 and y%2==0 else rng.choice(MAIL)
            if front: each(lambda x,y,c: mailpx(x,y) if ((x<3 or x>w-4) and fz(x,y)<.70) or fz(x,y)<.12 else None)
            elif not top and not bottom: each(lambda x,y,c: mailpx(x,y) if fz(x,y)<(.55 if side else .40) else None)
        if reg in ('face_helm','face_coif') and not front and not bottom:
            if top: noise(IRON); each(lambda x,y,c: IRON_HI if abs(fl(x,y)-.5)<.05 else None)
            else: each(lambda x,y,c: rng.choice(IRON) if fz(x,y)>(.55 if side else .40) else None); each(lambda x,y,c: IRON_DARK if abs(fz(x,y)-(.55 if side else .40))<.03 else None)
    elif reg=='shield':
        noise(WOOD)
        if abs(n.dot(dep))>.6:
            # Vertical planks, iron rim, nails; a blue heraldic band down the middle of the front.
            each(lambda x,y,c: WOOD_DARK if x%7==0 else None)
            if obj['part']=='ShieldMid' and n.dot(dep)<0:
                each(lambda x,y,c: rng.choice(TEAM) if abs(fl(x,y)-.5)<.16 else (TEAM_DARK if abs(fl(x,y)-.5)<.19 else None))
            each(lambda x,y,c: rng.choice(IRON) if edge(x,y)<2 else None)
            for y in range(3,h-3,6):
                for x in (3,w-4):
                    if 0<=x<w: t[y][x]=IRON_HI
        else: noise(IRON)
    else:
        raise RuntimeError('unpainted region '+reg)
    return t,e

pixels=([c/255 for c in GAMB[0]]+[1])*(SIZE*SIZE); energy=[0,0,0,1]*(SIZE*SIZE)
for index,it in enumerate(islands):
    t,e=paint(it,index); w,h=it['w'],it['h']; ox,oy=it['x'],it['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            xx=max(0,min(w-1,x)); yy=h-1-max(0,min(h-1,y)); k=((oy+y)*SIZE+ox+x)*4
            pixels[k:k+4]=[v/255 for v in t[yy][xx]]+[1]; energy[k:k+4]=[v/255 for v in e[yy][xx]]+[1]
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    stale=bpy.data.images.get(NAME+'_'+suffix)
    if stale: bpy.data.images.remove(stale)
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True); im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'armored_cavalier_v1_{suffix}.png'); im.file_format='PNG'
    im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.88
    bsdf.inputs['Metallic'].default_value=0; bsdf.inputs['Specular IOR Level'].default_value=.25
    for socket in ('Base Color','Emission Color'):
        node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.interpolation='Closest'; node.extension='EXTEND'; node.label=socket
        mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
    bsdf.inputs['Emission Strength'].default_value=1.6
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE': node.image=images[0] if node.label=='Base Color' else images[1]
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(mat)
    if 'Metric_Pixel_UV' not in obj.data.uv_layers: obj.data.uv_layers.new(name='Metric_Pixel_UV')
for item in islands:
    me=item['obj'].data; uv=me.uv_layers['Metric_Pixel_UV'].data
    for li,co in zip(me.polygons[item['polygon']].loop_indices,item['coords']):
        uv[li].uv=((item['x']+co.x*D)/SIZE,(item['y']+co.y*D)/SIZE)

root=bpy.data.objects.get(NAME+'_ROOT')
if root is None:
    root=bpy.data.objects.new(NAME+'_ROOT',None); scene.collection.objects.link(root)
    root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.2
for obj in parts: obj.parent=root
density=[]; triangles=0; nonmanifold=0
for obj in parts:
    me=obj.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles)
    bm=bmesh.new(); bm.from_mesh(me); nonmanifold+=sum(not e.is_manifold for e in bm.edges); bm.free()
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons), obj.name
    assert not obj.modifiers and obj.animation_data is None
    uv=me.uv_layers['Metric_Pixel_UV'].data
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-7: density.append((uv[li].uv-uv[lj].uv).length*SIZE/length)
assert nonmanifold==0, nonmanifold
assert max(abs(d-D) for d in density)<.03
coordinates=[v.co for o in parts for v in o.data.vertices]
report={'name':NAME,'kind':'v2_unit_armored_cavalier (Cavaleiro Blindado)','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/armored_cavalier_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'front_y_m':min(v.y for v in coordinates),'back_y_m':max(v.y for v in coordinates),
 'x_m':[min(v.x for v in coordinates),max(v.x for v in coordinates)],'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,'unique_uv_islands':len(islands),
            'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF','origin':'between the feet, on the ground',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static ShockArmoredCavalier V1 (Cavaleiro de Choque): ArmoredCavalier copy; rider in mail with a painted helm + coif, heavy lance with a vamplate; black horse with a caparison and a painted chanfron; same rig.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'armored_cavalier_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'armored_cavalier_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={k:report[k] for k in ('height_m','front_y_m','back_y_m','x_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
