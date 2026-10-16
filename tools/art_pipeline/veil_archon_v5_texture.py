# The supplied reference's dark mineral armor and red-magenta energy, painted in coarse pixels.
palette={'dark':(22,28,32),'ridge':(47,61,65),'energy':(195,35,91),'core':(219,48,111)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(570020+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind in ('dark','ridge'):
        rgb[yy>=h-1]=base+12;rgb[xx<1]=base+7
        if h>8:
            for k in range(max(1,w*h//180)):
                x=int(rng.integers(0,w));y=int(rng.integers(0,h))
                rgb[y:y+2,x:x+4]=base+int(rng.choice([-5,8]))
    elif kind=='energy':
        rgb[xx<1]=[238,76,136];rgb[yy>=h-1]=[252,134,176]
        emission=rgb/255*.45
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.23)&(xx<w*.73)&(yy>h*.22)&(yy<h*.75)]=[249,145,187]
        rgb[(xx<1)|(yy<1)]=[167,22,72];emission=rgb/255*.65
    light=1.08 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .87
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
