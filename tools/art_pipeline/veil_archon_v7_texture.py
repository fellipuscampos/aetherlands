# Mineral layers, painted creases and sparse arcane red fissures, matching the accepted bosses' pixel scale.
palette={'shell':(24,39,44),'ridge':(49,71,76),'edge':(80,105,109),
 'energy':(134,22,57),'crown':(176,31,73),'core':(192,34,88)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal']
    base=np.array(palette[kind],dtype=float);rng=np.random.default_rng(670020+index)
    yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('shell','ridge','edge'):
        # Broad lighter mineral planes, two-pixel cracks, and edge wear give each volume weight.
        rgb[yy>=h-2]=base+8;rgb[xx<1]=base+12
        for _ in range(max(1,w*h//150)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h))
            rgb[y:y+2,x:x+int(rng.integers(2,6))]=base+int(rng.choice([-7,10,14]))
        if kind=='shell' and n.y<-.8 and w>8 and h>10 and ('Chest' in o.name or 'Upper_Arm' in o.name):
            # One short branching fissure per broad inner plate, integrated into the pixel map.
            x=max(2,w//2); y0=max(2,h//4)
            for y in range(y0,min(h-2,y0+max(3,h//3))):
                q=x+(y-y0)//5
                if q>=w-2:break
                rgb[y,q:q+1]=[169,35,75];emission[y,q:q+1]=[.20,.025,.05]
    elif kind in ('energy','crown'):
        # Dark red edges and one pale interior stripe keep the energy from looking like pink plastic.
        rgb[(xx<1)|(yy<1)]=base*.6
        stripe=(xx==max(1,w//2)) if w<h else (yy==max(1,h//2))
        rgb[stripe]=[241,93,141]
        rgb[yy>=h-1]=[222,58,116]
        emission=rgb/255*(.32 if kind=='energy' else .5)
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx>w*.26)&(xx<w*.74)&(yy>h*.26)&(yy<h*.74)]=[248,127,171]
        rgb[(xx<1)|(yy<1)]=[126,18,51];emission=rgb/255*.62
    light=1.07 if n.z>.8 else .73 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
