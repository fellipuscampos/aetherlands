# Closely related mineral tones, pixel-cut faults and pale cyan energy. No four-color robot limbs.
palette={'stone':(49,67,77),'dark':(29,40,49),'ridge':(73,94,103),'crystal':(154,195,199),
 'seam':(66,158,176),'eye':(167,243,241),'mouth':(12,20,27),'core':(92,200,216)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(350831+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-5,6,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge'):
        rgb[yy>=h-1]=base+14;rgb[yy<1]=base-8
        for _ in range(max(1,w*h//220)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h));rgb[y:y+2,x:x+4]=base+int(rng.choice([-12,12]))
        # Sparse, irregular faults; no concentric panel borders or uniform horizontal brick bands.
        if w>16 and h>16 and index%3==0:
            x=int(w*.42)
            for y in range(3,h-4):
                q=max(2,min(w-3,x+((y//6)%3)-1))
                rgb[y,q:q+1]=base-20
                if y>h*.3 and y<h*.7:
                    rgb[y,q+1:q+2]=[72,140,152];emission[y,q+1:q+2]=[.02,.065,.075]
    elif kind=='crystal':
        rgb[xx<2]=base-28;rgb[xx>=w-2]=np.minimum(255,base+23);emission=rgb/255*.018
    elif kind in ('seam','eye'):
        rgb[:]=base;rgb[yy>=h-1]=np.minimum(255,base+35);emission=rgb/255*(.30 if kind=='seam' else .65)
    elif kind=='core':
        rgb[:]=[111,218,224]
        # A single bright solid energy cube, with sparse pixel highlights on its face.
        rgb[(xx<2)|(yy<2)]=[65,156,176]
        rgb[(xx>=w-2)|(yy>=h-2)]=[194,246,241]
        rgb[(xx>w*.18)&(xx<w*.65)&(yy>h*.37)&(yy<h*.68)]=[174,239,235]
        rgb[(xx>w*.25)&(xx<w*.39)&(yy>h*.68)&(yy<h*.81)]=[206,251,245]
        emission=rgb/255*.66
    light=1.04 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
