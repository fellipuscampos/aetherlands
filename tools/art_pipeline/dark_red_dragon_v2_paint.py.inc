# Burgundy almost-black hide with small broken, angular scale clusters.
palette={'body':(58,12,20),'scale':(76,18,27),'belly':(158,135,98),
    'ivory':(219,205,171),'horn':(32,19,25),'eye':(255,50,5),
    'dark':(12,7,11),'mouth':(34,6,12),'membrane':(68,15,23)}
pixels=np.ones((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,:3]=0
emission=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['surface']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(784117+index); yy,xx=np.indices((h,w))
    rgb=np.broadcast_to(base,(h,w,3)).copy(); energy=np.zeros((h,w,3))
    if kind in ('body','scale','horn'):
        # Irregular overlapping chips. Dark channels are interrupted and have
        # diagonal pixel steps, avoiding the masonry pattern of the first version.
        sh=5
        for ry in range(-1,math.ceil(h/sh)+1):
            y0=ry*sh; x0=int(rng.integers(-7,0))
            while x0<w:
                sw=int(rng.integers(4,10)); shade=int(rng.choice([-24,-12,-3,10,25]))
                x1=max(0,x0); x2=min(w,x0+sw); y1=max(0,y0); y2=min(h,y0+sh)
                if x2>x1 and y2>y1:
                    rgb[y1:y2,x1:x2]=np.clip(base+[shade,shade*.55,shade*.6],0,255)
                    if 0<=y0<h and rng.random()<.76:
                        rgb[y0:y0+1,max(0,x0+1):min(w,x0+sw-2)]=base*.54
                    if 0<=y0+1<h and rng.random()<.60:
                        rgb[y0+1:y0+2,max(0,x0+1):min(w,x0+sw-3)]=np.clip(base+[27,8,11],0,255)
                    if 0<=y0+3<h and 0<=x0+sw-1<w:
                        rgb[y0+3:min(h,y0+5),x0+sw-1:x0+sw]=base*.61
                    if rng.random()<.28 and 0<=y0+2<h:
                        rgb[y0+2:y0+3,max(0,x0+2):min(w,x0+4)]=base*.72
                x0+=sw
        if kind=='horn': rgb*=.83
    elif kind=='membrane':
        broad=rng.integers(-7,8,(math.ceil(h/7),math.ceil(w/7))).repeat(7,0).repeat(7,1)[:h,:w]
        rgb=np.clip(base+broad[:,:,None]*[1,.5,.6],0,255)
        # Wide stepped shadows in the leather, sparse highlights.
        ribs=((xx*2+yy)%47<3)&(yy%31<19)
        rgb[ribs]=base*.69
        for patch in range(max(1,w*h//270)):
            px=int(rng.integers(0,w)); py=int(rng.integers(0,h))
            rgb[py:min(h,py+3),px:min(w,px+8)]=base+[9,3,3]
    elif kind=='belly':
        rgb[(yy%8<1)]=base*.78
        rgb[(yy%8==2)&(xx%13<9)]=base+[12,10,8]
    elif kind=='eye':
        rgb[:]=base
        energy=np.power(rgb/255,2.2)*1.8
    # Save palette bytes unchanged, then reload the PNG as an sRGB file image.
    # Generated images and file images have different pixel-buffer semantics.
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=rgb/255
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    emission[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(energy,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    face=it['obj'].data.polygons[it['face']]
    for li,c in zip(face.loop_indices,it['coords']):
        it['obj'].data.uv_layers.active.data[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
