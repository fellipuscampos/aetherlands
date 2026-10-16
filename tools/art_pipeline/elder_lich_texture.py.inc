palette={'cloth':(65,48,91),'cloth_dark':(42,35,61),'cape':(51,39,73),'shadow':(19,26,31),
         'bone':(180,179,154),'skull_face':(190,189,164),'brass':(151,126,79),'brass_dark':(105,91,67),
         'spirit_dim':(79,134,112),'glow':(89,220,149),'wood':(65,50,54),
         'book_cover':(68,42,69),'paper':(193,185,146)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind])/255
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=base
    emission=np.zeros((h,w,3),dtype=np.float32)
    shade=1.07 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .86
    tile[:,:,:3]*=shade
    rng=np.random.default_rng(18000+index)
    if kind not in ('glow','spirit_dim','shadow'):
        for _ in range(max(1,w*h//130)):
            xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h))
            pw=int(rng.integers(2,5)); ph=int(rng.integers(1,4))
            tile[yy:yy+ph,xx:xx+pw,:3]=base*shade*float(rng.choice([.88,.94,1.06,1.12]))
    if kind in ('cloth','cloth_dark','cape') and min(w,h)>6:
        # Broad worn vertical folds and restrained hems; no modern checkerboard panels.
        for xx in range(5,w-3,12): tile[:,xx:xx+2,:3]*=.86
        tile[:2,:,:3]*=.78
        if 'Front_Vestment' in o.name or 'Ancient_Cape' in o.name:
            tile[2:4,2:w-2,:3]=np.array((107,91,76))/255
            for xx in range(4,w-3,13):
                tile[5:9,xx:xx+2,:3]=np.array((121,107,80))/255
                tile[6:8,xx-1:xx+3,:3]=np.array((121,107,80))/255
    elif kind in ('brass','brass_dark'):
        if h>2: tile[-1:,:,:3]=base*1.13
        if w>2: tile[:,0,:3]=base*.74
    elif kind=='wood':
        for xx in range(2,w,4): tile[:,xx:xx+1,:3]*=.80
    elif kind=='paper' and n.z>.7 and min(w,h)>8:
        for yy,length in [(3,w-5),(6,w-7),(9,w-6),(12,w-8)]:
            if yy<h-2: tile[yy:yy+1,3:max(4,length),:3]=np.array((85,67,63))/255
        tile[:,0:1,:3]*=.75
    elif kind=='skull_face' and n.y<-.8:
        # Minecraft-like square sockets and painted teeth; no anatomical protruding nose.
        def rect(x0,y0,x1,y1,rgb,emit=False):
            x0,x1=round(x0*w),round(x1*w); y0,y1=round(y0*h),round(y1*h)
            tile[y0:y1,x0:x1,:3]=np.array(rgb)/255
            if emit: emission[y0:y1,x0:x1,:]=np.array(rgb)/255
        rect(.12,.46,.40,.73,(29,36,34)); rect(.60,.46,.88,.73,(29,36,34))
        rect(.22,.54,.34,.63,(114,238,164),True); rect(.66,.54,.78,.63,(114,238,164),True)
        rect(.12,.74,.42,.79,(132,137,117)); rect(.58,.74,.88,.79,(132,137,117))
        rect(.34,.24,.66,.32,(60,63,52))
        for xx in (.39,.49,.59): rect(xx,.28,xx+.05,.35,(197,196,172))
        rect(.46,.38,.54,.42,(138,145,126))
    if kind=='glow': emission=tile[:,:,:3]*.75
    if kind=='spirit_dim':
        emission=tile[:,:,:3]*.24
        if h>7: tile[:h//3,:,:3]*=.76
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

