# Weathered pale wood, deeply separated bark ridges, restrained moss and luminous green core.
palette={'wood':(133,121,94),'wood_light':(174,159,120),'bark':(76,69,48),
         'moss':(75,108,51),'moss_dark':(49,78,46),'vine':(84,105,47),
         'seed':(155,120,58),'core':(136,238,88)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(91000+index); yy,xx=np.indices((h,w))
    noise=rng.integers(-7,8,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+noise[:,:,None],0,255)
    if kind in ('wood','wood_light','bark','vine'):
        # Grain follows each actual root segment; no identical concentric square motif on every face.
        grain=((xx//2*13+yy//19*5)%19)<2
        rgb[grain]=np.maximum(0,base-23)
        light=(xx%9==3)&(yy%23<17); rgb[light]=np.minimum(255,base+13)
        if min(w,h)>9:
            for _ in range(max(1,w*h//220)):
                cx=int(rng.integers(2,w-2)); cy=int(rng.integers(1,h-1)); length=int(rng.integers(3,9))
                rgb[cy:cy+length,cx:cx+1]=np.maximum(0,base-35)
    elif kind.startswith('moss'):
        clusters=rng.integers(-12,13,(math.ceil(h/4),math.ceil(w/4))).repeat(4,0).repeat(4,1)[:h,:w]
        rgb=np.clip(base+clusters[:,:,None],0,255)
    elif kind=='core':
        # Broad bright center and a calm dark perimeter; one solid cube with a single texture.
        d=np.maximum(abs((xx+.5)/w-.5),abs((yy+.5)/h-.5))
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[d>.36]=[75,173,56]; rgb[d<.19]=[194,255,148]; rgb[d<.09]=[232,255,202]
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .87
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    emission=tile[:,:,:3]*.85 if kind=='core' else np.zeros((h,w,3),dtype=np.float32)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
