# Restrained directional pixel painting. Blue energy is confined to joints, crown and core.
palette={'armor':(27,37,47),'edge':(48,66,78),'facet':(49,92,133),
 'energy':(66,151,221),'core':(86,163,240)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(450020+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-3,4,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('armor','edge'):
        rgb[yy>=h-1]=base+13
        rgb[xx<1]=base+8
        if h>10 and w>6:
            # A few broad brush marks suggest hard mineral plates, without noisy random pixels.
            for k in range(max(1,w*h//420)):
                x=int(rng.integers(1,max(2,w-2)));y=int(rng.integers(1,max(2,h-2)))
                rgb[y:y+2,x:x+4]=base+int(rng.choice([-5,6]))
    elif kind=='facet':
        rgb[xx<1]=base+24;emission=rgb/255*.07
    elif kind=='energy':
        rgb[yy>=h-1]=[137,205,251];emission=rgb/255*.30
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.23)&(xx<w*.72)&(yy>h*.22)&(yy<h*.75)]=[153,211,250]
        rgb[(xx<1)|(yy<1)]=[52,115,194]
        emission=rgb/255*.60
    light=1.1 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
