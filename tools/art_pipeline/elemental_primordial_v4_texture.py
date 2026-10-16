# Charcoal and warm dark stone frame cyan mineral columns, following the user's reference.
palette={'stone':(54,53,50),'dark':(31,33,33),'ridge':(76,74,67),'face':(33,40,40),
 'crystal':(40,110,121),'seam':(74,190,200),'eye':(122,236,232),'core':(101,208,216)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(461826+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        rgb[yy>=h-1]=base+12;rgb[yy<1]=base-8
        for _ in range(max(1,w*h//230)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+5]=base+int(rng.choice([-13,11]))
        if w>18 and h>20:
            x=int(w*.38)
            for y in range(3,h-3):
                q=max(2,min(w-3,x+((y//7)%3)-1));rgb[y,q:q+1]=base-18
        if kind=='face' and 'Recessed_Dark_Face' in o.name:
            # Pixel-cut teeth along the lower face, without separate rounded mouth geometry.
            rgb[(yy<h*.16)&(xx>w*.14)&(xx<w*.86)]=[14,22,22]
            for x in range(max(1,w//6),w-max(1,w//6),max(2,w//6)):
                rgb[max(0,int(h*.08)):max(1,int(h*.13)),x:x+1]=[111,125,117]
    elif kind=='crystal':
        # Depth comes from large interrupted mineral bands, not repetitive noisy pixels.
        rgb[xx<2]=[105,191,195];rgb[xx>=w-2]=[117,218,221]
        rgb[yy>=h-2]=[73,163,172]
        if w>7 and h>12:
            vein=(xx>w*.46)&(xx<w*.60)&(yy<h*.57)
            rgb[vein]=[73,163,174]
            for j in range(4):
                x=int(w*(.19+j*.16));y=int(h*(.11+j*.06));height=int(h*(.20+j*.08))
                rgb[y:min(h,y+height),x:min(w,x+max(1,w//8))]=[54+j*8,133+j*11,143+j*11]
            rgb[(yy<h*.18)&(xx>w*.24)&(xx<w*.77)]=[114,212,213]
        emission=rgb/255*.07
    elif kind in ('seam','eye'):
        rgb[:]=base;rgb[yy>=h-1]=np.minimum(255,base+23);emission=rgb/255*(.28 if kind=='seam' else .70)
    elif kind=='core':
        rgb[:]=[116,222,225];rgb[(xx<2)|(yy<2)]=[61,159,177]
        rgb[(xx>=w-2)|(yy>=h-2)]=[194,247,242]
        rgb[(xx>w*.22)&(xx<w*.68)&(yy>h*.35)&(yy<h*.71)]=[185,242,238]
        emission=rgb/255*.70
    light=1.04 if n.z>.8 else .80 if n.z<-.8 else 1 if n.y<0 else .90
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
