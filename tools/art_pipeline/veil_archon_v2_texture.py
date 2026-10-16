# Restrained cloth folds and weathered silver; the cube is the only strong light source.
palette={'cloth':(36,57,98),'cloth_dark':(23,36,62),'cloth_mid':(43,65,104),
 'silver':(137,156,174),'silver_light':(182,200,215),'silver_dim':(98,124,150),
 'portal':(64,86,121),'portal_edge':(124,155,190),'core':(88,157,239)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(128100+index); yy,xx=np.indices((h,w))
    clusters=rng.integers(-6,7,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind.startswith('cloth'):
        rgb[:2]*=.76
        if h>10 and w>7:
            for x in range(4,w-2,11):
                rgb[:,x:x+1]*=.78; rgb[:,x+1:x+2]*=1.10
    elif kind.startswith('silver') or kind=='portal_edge':
        rgb[yy<1]=base*.76; rgb[yy>=h-1]=np.minimum(255,base*1.10)
        for _ in range(max(1,w*h//170)):
            x=int(rng.integers(0,w)); y=int(rng.integers(0,h))
            rgb[y:y+1,x:x+2]=np.maximum(0,base-15)
    elif kind=='portal' and n.y<-.8:
        mask=((xx//3+2*(yy//4))%13==1)&(xx>2)&(xx<w-2)&(yy>2)&(yy<h-2)
        rgb[mask]=[101,153,212]; emission[mask]=np.array((101,153,212))/255*.12
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[47,102,191]
        rgb[(xx>w*.30)&(xx<w*.75)&(yy>h*.25)&(yy<h*.73)]=[157,207,249]
        for _ in range(3):
            x=int(rng.integers(2,max(3,w-3))); y=int(rng.integers(2,max(3,h-3)))
            rgb[y:y+2,x:x+2]=[209,235,253]
    light=1.05 if n.z>.8 else .76 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.78
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
