# Strong dark bark / warm heartwood separation makes the emissive core the focal point.
palette={'bark':(81,61,38),'bark_dark':(43,35,25),'wood':(125,95,56),'wood_light':(165,132,79),
         'moss':(65,97,42),'moss_dark':(43,68,36),'vine':(72,95,41),'core':(113,224,85)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(120700+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-7,8,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255)
    if kind in ('wood','wood_light','bark','bark_dark','vine'):
        # Low-frequency stepped strips suggest bark clefts; no regular plank checkerboard.
        for cx in range(3,w,10):
            for cy in range(0,h,17):
                drift=int(rng.integers(-1,2)); length=int(rng.integers(7,16))
                x=max(0,cx+drift); rgb[cy:cy+length,x:x+2]=np.maximum(0,base-22)
                if x+2<w: rgb[cy:cy+length,x+2:x+3]=np.minimum(255,base+13)
        if min(w,h)>8:
            for _ in range(max(1,w*h//240)):
                cx=int(rng.integers(1,w-2)); cy=int(rng.integers(1,h-2))
                rgb[cy:cy+4,cx:cx+3]=np.maximum(0,base-12)
        if 'Crown' in o.name or 'Trunk_Wall' in o.name or 'Great_Root_Shoulder' in o.name:
            rgb[:2]=np.maximum(0,rgb[:2]-14)
    elif kind.startswith('moss'):
        clusters=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+clusters[:,:,None],0,255)
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[65,154,48]
        # A single, softly varied luminous cube; avoid a target of concentric square frames.
        rgb[(xx>w*.30)&(xx<w*.72)&(yy>h*.30)&(yy<h*.75)]=[169,248,122]
        for _ in range(4):
            cx=int(rng.integers(2,max(3,w-3))); cy=int(rng.integers(2,max(3,h-3)))
            rgb[cy:cy+2,cx:cx+2]=[199,255,157]
    light=1.06 if n.z>.8 else .76 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    emission=tile[:,:,:3]*.90 if kind=='core' else np.zeros((h,w,3),dtype=np.float32)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
