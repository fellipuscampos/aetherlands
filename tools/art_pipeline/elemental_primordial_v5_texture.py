# Broken charcoal mineral faces and opaque cyan crystalline slabs, without framed panel painting.
palette={'stone':(55,52,48),'dark':(30,30,29),'ridge':(69,64,57),'face':(39,43,40),
 'crystal':(34,99,111),'eye':(112,219,223),'core':(127,224,226)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(552431+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        for _ in range(max(1,w*h//240)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-11,10]))
        if w>13 and h>13:
            for y in range(2,h-2):
                q=max(1,min(w-2,int(w*.38)+((y//6)%4)-1));rgb[y,q:q+1]=base-14
        if kind=='face' and n.y<-.8 and w>15 and h>20:
            mouth=(yy>h*.12)&(yy<h*.23)&(xx>w*.27)&(xx<w*.73)
            rgb[mouth]=[16,20,19]
            for x in range(int(w*.29),int(w*.71),max(2,w//8)):
                rgb[int(h*.20):int(h*.24),x:x+1]=[117,126,113]
    elif kind=='crystal':
        # Uneven large veins and a luminous broken root, rather than rectangular neon rims.
        if w>6 and h>10:
            for j in range(5):
                x=int(w*(.08+j*.18));y=int(h*(.035+j*.055));vh=int(h*(.24+(j%3)*.14))
                rgb[y:min(h,y+vh),x:min(w,x+max(1,w//7))]=[52+j*7,136+j*9,147+j*8]
            trace=(xx==max(1,int(w*.78)))&(yy<h*.68)
            rgb[trace]=[120,205,209]
            rgb[(yy<h*.10)&(xx>w*.24)&(xx<w*.65)]=[131,223,223]
        emission=rgb/255*.04
    elif kind=='eye':
        rgb[:]=base;emission=rgb/255*.60
    elif kind=='core':
        rgb[:]=[153,231,232];rgb[(xx<1)|(yy<1)]=[95,193,204]
        rgb[(xx>=w-1)|(yy>=h-1)]=[194,247,242]
        rgb[(xx>w*.27)&(xx<w*.66)&(yy>h*.37)&(yy<h*.68)]=[205,250,241]
        emission=rgb/255*.67
    light=1.05 if n.z>.8 else .79 if n.z<-.8 else 1 if n.y<0 else .89
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
