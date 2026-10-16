# Current forest bark/foliage colors, clustered pixel paint at 64 pixels per meter.
palette={'bark':(106,76,47),'bark_dark':(75,54,36),'cut_wood':(174,137,84),
 'sapwood':(139,111,64),'mask':(147,119,73),'hollow':(29,35,24),
 'leaf':(69,112,53),'leaf_light':(92,132,61),'leaf_dark':(48,100,69),
 'moss':(80,109,55),'fresh_leaf':(138,176,76),'amber':(247,201,100)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(20261011+index)
    yy,xx=np.indices((h,w))
    clusters=rng.integers(-8,9,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255)
    if kind in ('bark','bark_dark','mask','sapwood'):
        # Angular long grain, short breaks, no noisy marble pattern.
        grain=((xx//2*19+yy//15*7)%23)<3
        rgb[grain]=np.maximum(0,base-18)
        highlight=(xx%11==2)&(yy%29<18)
        rgb[highlight]=np.minimum(255,base+10)
        if w>14 and h>15:
            cx=w//2+int(rng.integers(-3,4)); cy=h//2
            ring=np.maximum(abs(xx-cx),abs((yy-cy)//2))
            rgb[(ring==3)|(ring==5)]=np.maximum(0,base-15)
    elif kind=='cut_wood':
        ring=np.maximum(abs(xx-w//2),abs(yy-h//2))//3%5
        rgb[ring==0]=base-24; rgb[ring==1]=base+8
    elif kind.startswith('leaf') or kind in ('moss','fresh_leaf'):
        leafnoise=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+leafnoise[:,:,None],0,255)
        if h>6: rgb[:2]=np.maximum(0,rgb[:2]-13)
    elif kind=='hollow': rgb=np.broadcast_to(base,(h,w,3)).copy()
    elif kind=='amber': rgb=np.broadcast_to(base,(h,w,3)).copy(); rgb[h//2:,w//2:]=[255,225,151]
    face_light=1.06 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .89
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*face_light/255,0,1)
    emission=np.zeros((h,w,3),dtype=np.float32)
    if kind=='amber': emission=tile[:,:,:3]*.65
    # The sprout is living plant matter, not a mana cube or necromantic core.
    if kind=='fresh_leaf': emission=tile[:,:,:3]*.06
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
