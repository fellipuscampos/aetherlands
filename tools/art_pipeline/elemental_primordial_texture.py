# Quiet voxel cloud strata, deep ice and molten fissures; the nucleus carries all four focal colors.
palette={'cloud':(51,76,86),'mist':(141,163,164),'ember':(47,44,41),
 'flame':(216,119,32),'ice':(53,126,148),'ice_light':(111,182,197),
 'stone':(81,81,68),'mineral':(125,143,111),'wind':(103,142,150),'core':(115,204,211)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(144920+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    clusters=rng.integers(-5,6,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('cloud','mist','wind'):
        # Pixel bands follow the air flow, without painting every underlying voxel-cell boundary.
        if h>9:
            stripe=(yy//max(3,h//4))%3
            rgb[stripe==1]=np.clip(rgb[stripe==1]+7,0,255)
            rgb[yy>=h-1]=base+17;rgb[yy<1]=base-13
        if kind=='wind':
            rgb[(xx+yy//4)%13==0]=base+18;emission=rgb/255*.025
    elif kind=='ember':
        rgb[yy>=h-1]=base+15
        if n.y<-.65 and w>8 and h>8:
            x=max(2,w//2)
            for y in range(2,h-2):
                q=x+((y//5)%3)-1
                rgb[y,q:q+1]=[238,139,36];emission[y,q:q+1]=[.40,.16,.018]
                if y%7==0 and q+2<w:rgb[y,q:q+3]=[220,105,22];emission[y,q:q+3]=[.33,.10,.009]
    elif kind=='flame':
        rgb[xx>w*.38]=[238,154,45];rgb[(xx>w*.48)&(xx<w*.65)]=[255,210,96]
        rgb[yy>=h-2]=[249,173,57];emission=rgb/255*.48
    elif kind in ('ice','ice_light'):
        rgb[xx<2]=base*.73;rgb[xx>=w-2]=np.minimum(255,base+39)
        if h>8 and w>8:
            for y in range(2,h-2):
                q=min(w-2,max(1,w//3+y//6));rgb[y,q:q+1]=np.minimum(255,base+42)
        emission=rgb/255*.055
    elif kind in ('stone','mineral'):
        rgb[yy>=h-2]=base+16
        for _ in range(max(1,w*h//145)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-18,15]))
    else:
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[49,137,164]
        rgb[(xx>w*.24)&(xx<w*.76)&(yy>h*.24)&(yy<h*.76)]=[211,240,238]
        for x,y,color in [(w*.20,h*.20,(229,139,48)),(w*.78,h*.20,(115,154,107)),
          (w*.20,h*.78,(78,170,218)),(w*.78,h*.78,(228,236,225))]:
            x=int(x);y=int(y);rgb[max(0,y-1):min(h,y+2),max(0,x-1):min(w,x+2)]=color
        emission=rgb/255*.70
    light=1.08 if n.z>.8 else .74 if n.z<-.8 else 1 if n.y<0 else .87
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
