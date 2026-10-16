# Current Arcanist palette: midnight blue cloth, silver and azure mana. Metric pixel paint.
palette={'blue':(49,72,115),'blue_dark':(29,43,71),'veil':(49,72,115),'veil_dark':(38,54,87),
 'silver':(156,170,181),'silver_light':(206,220,229),'silver_dim':(113,133,154),
 'portal':(137,154,177),'core':(108,179,248)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(61200+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-6,7,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('veil','veil_dark'):
        for cx in range(5,w-3,13):
            for cy in range(h):
                bend=1 if cy//15%3==1 else 0
                rgb[cy,cx+bend:cx+bend+2]*=.77
                rgb[cy,cx+bend+2:cx+bend+3]*=1.14
        rgb[:2]*=.72
    elif kind.startswith('silver') or kind=='portal':
        rgb[yy<2]=base*.77; rgb[yy>=h-2]=np.minimum(255,base*1.12)
        if kind=='portal' and n.y<-.8:
            # One continuous pixel inscription per fragment, with a quiet blue emission.
            mask=((xx//3+yy//3)%9==0)&(xx>2)&(xx<w-2)&(yy>2)&(yy<h-2)
            rgb[mask]=[88,137,200]; emission[mask]=np.array((88,137,200))/255*.25
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[58,113,207]
        rgb[(xx>w*.28)&(xx<w*.76)&(yy>h*.25)&(yy<h*.76)]=[185,221,255]
        for _ in range(4):
            cx=int(rng.integers(2,max(3,w-3))); cy=int(rng.integers(2,max(3,h-3)))
            rgb[cy:cy+2,cx:cx+2]=[224,243,255]
    if 'Shoulder_Inset' in o.name and n.y<-.8 and w>6 and h>4:
        # An open square spiral recalls the school's portals, rather than a healing cross.
        rgb[h-2,1:w-1]=[118,165,219]
        rgb[1:h-1,w-2]=[118,165,219]
        rgb[1,3:w-1]=[118,165,219]
        rgb[1:max(2,h-3),3]=[118,165,219]
        if h>6: rgb[h-4,3:max(4,w-4)]=[118,165,219]
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .86
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.90
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
