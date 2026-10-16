"""Hand-authored pixel surface rules matching the sharp cuboid human art language.

No random scratches on skin/hands. Armour borders, fasteners, woven padding,
leather closures and beard locks have distinct, physically meaningful patterns.
Tiles are bottom-up because Blender image pixels and metric UVs are bottom-up.
"""
import hashlib
import numpy as np

PALETTE = {
    'skin': (204,151,109), 'beard': (73,46,29), 'hair': (63,40,27),
    'cloth': (87,80,69), 'clan': (45,76,82), 'leather': (108,70,42),
    'wood': (142,99,58), 'steel': (119,124,128), 'edge': (183,186,188),
    'iron': (65,70,75), 'copper': (185,119,59), 'gold': (208,169,83),
    'shadow': (53,59,59), 'linen': (184,168,129), 'ivory': (195,180,136),
    'fur': (110,78,49), 'mane': (61,43,29), 'feather': (179,165,129),
    'coal': (31,32,32), 'glass': (65,114,120), 'ember': (222,96,32),
    'olive': (92,101,78), 'mail': (108,112,114),
}


def paint_tile(obj, face, w, h, row):
    part=obj.get('part',obj.name); region=obj['surface']; style=obj.get('paint_style','')
    n=face.normal; front=n.y<-.6; top=n.z>.6; bottom=n.z<-.6
    yy,xx=np.mgrid[:h,:w]
    beard_colors={'guardian':(64,55,47),'warrior':(73,46,29),'ranger':(103,67,40),
                  'rogue':(58,54,52),'cavalry':(91,66,42)}
    beard_color=beard_colors.get(row.get('family'),PALETTE['beard'])
    hair_color=tuple(max(0,c-7) for c in beard_color)
    accents={'guardian':(45,76,82),'warrior':(98,54,40),'ranger':(71,83,51),
             'cavalry':(61,77,85),'rogue':(50,56,60)}
    accent=np.array(accents.get(row.get('family'),PALETTE['clan']))
    base=np.array(beard_color if region=='beard' else hair_color if region=='hair' else accent if region=='clan' else PALETTE[region],dtype=np.int16)
    seed=int(hashlib.sha256((part+str(face.index)).encode()).hexdigest()[:8],16)
    rng=np.random.default_rng(seed)
    # Coherent pixel patches read as material, rather than salt-and-pepper noise.
    patches=rng.choice([-7,-3,0,4,7],size=((h+1)//2,(w+1)//2),p=[.08,.18,.49,.18,.07])
    noise=np.repeat(np.repeat(patches,2,axis=0),2,axis=1)[:h,:w]
    tile=np.clip(base[None,None,:]+noise[:,:,None],0,255).astype(np.int16)
    edge=np.minimum.reduce([xx,yy,w-1-xx,h-1-yy])
    copper=np.array(PALETTE['copper']); iron=np.array(PALETTE['iron'])
    light=np.minimum(base+30,255); dark=np.maximum(base-31,0)
    tier=row.get('tier',0); trim=np.array(PALETTE['edge'])

    def setwhere(mask,color): tile[mask]=color
    def rect(x0,y0,x1,y1,c):
        tile[max(0,int(y0)):min(h,int(y1)),max(0,int(x0)):min(w,int(x1))]=c
    def border(c,thick=1): setwhere(edge<thick,c)
    def rivets(c,spacing=5):
        if min(w,h)<6: return
        for y in range(2,h-2,spacing):
            tile[y,2]=c; tile[y,w-3]=c
    def quilt():
        setwhere(((xx+yy)%6==0)|((xx-yy)%6==0),base-22)
        setwhere((xx+yy)%6==1,base+8)
    def band(y,c,width=1): rect(0,y,w,y+width,c)

    if region=='skin':
        tile[:]=base # skin stays quiet and uniform
        if part=='body_head':
            if front:
                # Heavy horizontal brows; small sober eyes like the human faces.
                brow=np.array(PALETTE['beard'])
                for cx in (.29,.71):
                    ex=int((w-1)*cx); ey=int(h*.54)
                    rect(ex-2,ey,ex+2,ey+2,(232,219,195))
                    rect(ex,ey,ex+1,ey+2,(43,48,48))
                nx=w//2
                rect(nx-1,h*.38,nx+1,h*.52,(190,132,89))
                rect(nx-1,h*.37,nx+2,h*.40,(169,109,73))
                rect(w*.14,0,w*.86,h*.28,beard_color)
            else:
                # Sideburns/back hair belong to the head texture, not fake ears/neck.
                if n.y>.6: tile[:]=hair_color
                rect(0,h*.61,w,h,hair_color)
                if abs(n.x)>.6: rect(w*.74,h*.25,w,h*.61,beard_color)
    elif region in ('beard','hair','mane'):
        # Vertical stepped locks; irregular length, never three smooth sausage braids.
        setwhere((xx%4==0)&(yy<h*.86),base-12)
        setwhere((xx%4==1)&(yy<h*.73),base+13)
        if part.startswith('beard') and front:
            for i in range(2,w-2,5):
                rect(i,h*.10,i+2,h*.21,base-10)
            band(h-1,base+8)
    elif region=='linen':
        if not part.startswith('ram_'):
            quilt()
        else:
            setwhere(((xx//3+yy//3)%4==0),base-8)
    elif region=='mail':
        setwhere(((xx%3==0)&(yy%3<2))|((xx%3==2)&(yy%3==1)),base-36)
        setwhere((xx%3==1)&(yy%3==2),base+14)
        if not (top or bottom): band(0,iron)
    elif region=='ivory' and part.startswith('ram_horn'):
        if not (top or bottom): setwhere(yy%4==0,base-18)
        border(base-14)
    elif region=='wood':
        setwhere(xx%7==0,base-29); setwhere(xx%7==1,base+10)
        if not (top or bottom):
            # Occasional elongated grain, restrained enough to read as timber.
            setwhere(((xx+2)%11==0)&((yy+3)%9<4),base-13)
    elif region=='leather':
        border(base-27)
        if style in ('jerkin','trail_coat','scout_jerkin'):
            if front:
                rect(w*.45,0,w*.55,h,base-32)
                for y in range(2,h-2,4): rect(w*.46,y,w*.54,y+1,PALETTE['linen'])
            rivets((171,142,102),5)
            if min(w,h)>6: setwhere(edge==1,base+20)
        elif 'bracer' in part or part.startswith('body_forearm'):
            if not (top or bottom):
                for fy in (.22,.70):
                    y=int(h*fy); band(y,base-30,2)
                    if front: rect(w*.40,y,w*.63,y+2,copper)
        elif part.startswith('body_shin'):
            if not (top or bottom):
                band(h-2,base+27,2)
                for fy in (.30,.61): band(int(h*fy),base-30)
        elif part.startswith('body_foot'):
            if not top: band(0,(54,37,25),max(1,int(h*.20)))
            if tier>=2 and row.get('family') in ('guardian','warrior','cavalry'):
                if front:
                    rect(1,h*.22,w-1,h*.86,PALETTE['steel'])
                    rect(1,h*.79,w-1,h*.86,PALETTE['edge'])
                elif top: rect(0,0,w,h*.48,PALETTE['steel'])
        elif 'grip' not in part and not part.startswith('body_hand'):
            rivets(base+25,6)
        if part.startswith('body_hand'): tile[:]=base+7
    elif region in ('steel','iron','edge','copper','gold'):
        border(dark)
        if min(w,h)>=5: setwhere(edge==1,light)
        if style in ('cuirass','scout_cuirass','pauldron','greave','sabaton','plate','plate_bracer','lamellar','helm','helm_cheek'):
            border(iron)
            if min(w,h)>=5: setwhere(edge==1,trim)
            if style in ('cuirass','scout_cuirass'):
                if front:
                    rect(w*.48,2,w*.52,h-2,np.minimum(base+31,255))
                    rivets((181,179,165),5)
                if style=='scout_cuirass' and front:
                    strap=np.abs(yy/max(h-1,1)-(1-xx/max(w-1,1)))<.075
                    setwhere(strap,PALETTE['leather'])
            elif style=='pauldron' and not (top or bottom):
                for y in range(3,h-2,4): band(y,iron); band(y+1,base+19)
            elif style=='greave' and front:
                rect(w*.44,2,w*.58,h-2,base+32)
                band(h-2,PALETTE['leather'],2)
            elif style=='plate_bracer' and not (top or bottom):
                for fy in (.22,.73):
                    y=int(h*fy); band(y,PALETTE['leather'],2)
                    if front: rect(w*.41,y,w*.61,y+2,copper)
            elif style=='helm' and not top:
                band(1,iron); band(h-2,trim)
                if front:
                    for x in range(3,w-2,6): rect(x,1,x+1,2,PALETTE['edge'])
            elif style=='helm_cheek' and not top:
                band(0,trim)
            elif style=='lamellar' and not top:
                setwhere((edge>2)&((yy%4==0)|((xx+(yy//4)%2*2)%5==0)),iron)
                setwhere((edge>2)&(yy%4==2)&(xx%5==2),copper)
        if obj.get('bore_faces_start') is not None and face.index>=obj['bore_faces_start']:
            tile[:]=PALETTE['coal']
    elif region in ('clan','shadow','olive','cloth'):
        # Cloth has hems and folds, not random vertical marks across all limbs.
        if style in ('mantle','tabard'):
            border(np.maximum(base-20,0))
            if tier==3 and min(w,h)>4: setwhere(edge==1,trim)
            if not (top or bottom): setwhere((xx==w//3)|(xx==w*2//3),base-11)
        elif part.startswith('body_thigh'):
            if not (top or bottom): rect(w-2,0,w-1,h,base-10)

    if style in ('forge_tunic','mail_baldric') and front:
        # Construction follows the human tunic/baldric, with the dwarf clan palette.
        if style=='forge_tunic': quilt()
        strap=np.abs(yy/max(h-1,1)-(1-xx/max(w-1,1)))<.085
        setwhere(strap,PALETTE['leather'])
        setwhere(strap & (abs(yy-h*.40)<1),copper)
    if style in ('trail_jerkin','mine_jerkin'):
        border(base-23)
        if front:
            rect(w*.47,0,w*.53,h,PALETTE['leather'])
            rivets((147,126,96),6)
            strap=np.abs(yy/max(h-1,1)-(1-xx/max(w-1,1)))<.065
            setwhere(strap,PALETTE['leather'])
    if style=='surcoat':
        border(base-23)
        if not (top or bottom):
            rect(0,0,2,h,PALETTE['mail']); rect(w-2,0,w,h,PALETTE['mail'])
            band(0,base-24)
    if style=='leather_shoulder':
        border(base-29)
        if not (top or bottom):
            for y in range(3,h-2,5): band(y,base-26); band(y+1,base+18)
        for x in (2,w-3): rect(x,h-3,x+1,h-2,(175,156,122))
    if style=='belted_skirt' and not (top or bottom):
        # One continuous belt painted around the pelvis; the buckle is the sole mesh.
        rect(0,h*.56,w,h*.88,PALETTE['leather'])
        rect(0,h*.56,w,h*.63,(67,43,29))
        rect(0,h*.84,w,h*.88,(137,98,61))
        if row.get('family')=='warrior': rect(0,h*.30,w,h*.51,accent)
        else: band(0,np.maximum(base-23,0))
    if style in ('cap','cowl'):
        border(base-21)
        if not (top or bottom): band(1,PALETTE['leather'])
    if style=='hammer_head':
        border(np.array(PALETTE['coal']))
        if abs(n.x)>.6:
            tile[:]=np.array(PALETTE['steel'])+noise[:,:,None]
            border(np.array(PALETTE['iron']))
            if min(w,h)>5: setwhere(edge==1,PALETTE['edge'])
        elif front or n.y>.6:
            # Forged socket cheeks with working fasteners; no clan glyphs.
            for fx in (.27,.73):
                rect(w*fx,2,w*fx+1,h-2,PALETTE['steel'])
                for fy in (.23,.76):
                    x=int(w*fx); y=int(h*fy)
                    rect(x-1,y-1,x+2,y+2,PALETTE['coal'])
                    rect(x,y,x+1,y+1,PALETTE['edge'])
    if style in ('axe_blade','seax_blade'):
        # Bright ground cutting edge, dull body of the steel forging.
        border(PALETTE['iron'])
        if min(w,h)>4: setwhere(edge==1,PALETTE['edge'])
        if style=='axe_blade' and abs(n.y)>.6:
            rect(w-3,1,w-1,h-1,PALETTE['edge'])
    if style=='crossbow_stock' and top:
        rect(w*.40,0,w*.60,h,PALETTE['iron'])
    if style in ('bolt_case','toolbox') and not (top or bottom):
        if style=='bolt_case': band(int(h*.26),copper,2)
        else:
            for fx in (.18,.82): rect(w*fx,1,w*fx+1,h-1,PALETTE['iron'])
            band(h-2,PALETTE['iron'])
    if style=='goggles' and front:
        for x0,x1 in ((.07,.42),(.58,.93)):
            rect(w*x0,1,w*x1,h-1,PALETTE['glass'])
            rect(w*x0,1,w*x0+1,h-1,(135,163,153))
    if style=='mount_plate':
        border(PALETTE['iron'])
        if min(w,h)>4: setwhere(edge==1,PALETTE['edge'])
        rivets(PALETTE['edge'],7)
    if style=='riveted_panel':
        border(PALETTE['iron'],2)
        rivets(PALETTE['edge'],7)
        if front: rect(w*.48,2,w*.52,h-2,PALETTE['steel'])
    if style=='clan_shield':
        if front:
            if tier<=1:
                timber=np.array(PALETTE['wood'])-(14 if tier==1 else 0)
                tile[:]=timber+noise[:,:,None]
                setwhere(xx%9==0,timber-40)
                setwhere(xx%9==1,timber+12)
                for fy in (.24,.76):
                    y=int(h*fy)
                    rect(1,y-1,w-1,y+2,PALETTE['iron'])
                    rect(1,y+1,w-1,y+2,PALETTE['steel'])
                    for x in range(5,w-4,9): rect(x,y,x+1,y+1,PALETTE['edge'])
            else:
                steel=np.array(PALETTE['iron'] if tier==3 else PALETTE['steel'])
                tile[:]=steel+noise[:,:,None]
                # Two riveted plate seams, quiet enough to read as real armour.
                for fx in (.25,.75):
                    x=int(w*fx)
                    rect(x,2,x+1,h-2,steel-23)
                    rect(x+1,2,x+2,h-2,steel+22)
                    for y in range(5,h-4,8):
                        rect(x-1,y-1,x+2,y+2,PALETTE['iron'])
                        rect(x,y,x+1,y+1,PALETTE['edge'])
            # Follow the actual stepped contour instead of framing its bounding box.
            points=np.array([(obj.data.vertices[i].co.x,obj.data.vertices[i].co.z) for i in face.vertices])
            points=(points-points.min(axis=0))*64
            distance=np.full((h,w),1e9)
            for a,b in zip(points,np.roll(points,-1,axis=0)):
                d=b-a; length2=np.dot(d,d)
                t=np.clip(((xx-a[0])*d[0]+(yy-a[1])*d[1])/length2,0,1)
                distance=np.minimum(distance,np.sqrt((xx-a[0]-t*d[0])**2+(yy-a[1]-t*d[1])**2))
            setwhere(distance<2.6,PALETTE['steel'])
            setwhere((distance>=.8)&(distance<1.5),PALETTE['edge'])
            setwhere(distance<.8,PALETTE['iron'])
            for y in range(5,h-4,6):
                for x in (3,w-4): rect(x,y,x+1,y+1,PALETTE['edge'])
        elif n.y>.6:
            # The rear is timber/leather, never an ornamental front decal.
            tile[:]=np.array(PALETTE['wood'])+noise[:,:,None]
            setwhere(xx%7==0,np.array(PALETTE['wood'])-23)
        else:
            tile[:]=PALETTE['steel']

    if style=='ram_wool':
        setwhere(((xx//2+yy//3)%5==0),base-10)
    return np.clip(tile,0,255).astype(np.float32)/255
