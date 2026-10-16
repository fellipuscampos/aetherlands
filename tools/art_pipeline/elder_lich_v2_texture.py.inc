# Bone motifs are reused from the current Skeleton Warrior's metric pixel painter.
import random
skeleton_source=(ROOT/'tools/art_pipeline/skeleton_warrior_paint_save.py').read_text(encoding='utf-8')
exec(skeleton_source[skeleton_source.index('# Aged ivory bone ramp'):skeleton_source.index('pixels=[0.0]')],globals())
# Preserve the necromancy identity while adapting the existing pupil motif to green.
GLOW=(114,238,164); GLOW_HI=(222,255,233)
palette={'cloth':(55,45,69),'cloth_dark':(40,33,51),'cape':(48,38,63),'shadow':(19,26,31),
         'bone':BONE,'skull_face':BONE,'brass':(151,126,79),'brass_dark':(105,91,67),
         'spirit_dim':(79,134,112),'glow':(89,220,149),'wood':(65,50,54),
         'book_cover':(68,42,69),'paper':(193,185,146)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind])/255
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=base
    emission=np.zeros((h,w,3),dtype=np.float32)
    face_light=1.07 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .86
    tile[:,:,:3]*=face_light
    rng=np.random.default_rng(18000+index)
    if kind not in ('glow','spirit_dim','shadow','bone','skull_face','cloth','cloth_dark','cape'):
        for _ in range(max(1,w*h//130)):
            xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h))
            pw=int(rng.integers(2,5)); ph=int(rng.integers(1,4))
            tile[yy:yy+ph,xx:xx+pw,:3]=base*face_light*float(rng.choice([.88,.94,1.06,1.12]))
    if kind in ('bone','skull_face'):
        # The skull, separate jaw and cubic hands now use the actual current skeleton motifs.
        region='skull' if kind=='skull_face' else 'jaw' if o.name.endswith('Skull_Jaw') else 'hand' if 'Square_Hand' in o.name else 'bone'
        item=dict(it); item['obj']={'region':region,'part':o.name}
        painted=np.asarray(paint(item,index),dtype=np.float32)[::-1]/255
        tile[:,:,:3]=painted
        if region=='skull' and n.y<-.5:
            for rgb in (GLOW,GLOW_HI):
                mask=np.all(np.isclose(painted,np.array(rgb)/255),axis=2)
                emission[mask]=painted[mask]*.8
    elif kind in ('cloth','cloth_dark','cape'):
        # Solid clusters at physical pixel resolution; purple tones match the human necromancer.
        for _ in range(max(1,w*h//12)):
            xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h))
            pw=int(rng.integers(1,3)); ph=int(rng.integers(1,3))
            offset=int(rng.choice([-9,-6,-4,4,6,9]))
            tile[yy:yy+ph,xx:xx+pw,:3]=np.clip(base+offset/255,0,1)*face_light
        if min(w,h)>6:
            # A few stepped folds retain readability from the strategy camera.
            for xx in range(4,w-3,13):
                for yy in range(h):
                    bend=1 if (yy//14)%3==1 else 0
                    tile[yy,xx+bend:xx+bend+2,:3]*=.78
                    tile[yy,xx+bend+2:xx+bend+4,:3]*=1.10
            tile[:2,:,:3]*=.73
            if 'Front_Vestment' in o.name or 'Ancient_Cape' in o.name or 'Side_Vestment' in o.name:
                tile[:max(2,h//10),:,:3]*=.86
                for _ in range(max(1,w*h//380)):
                    xx=int(rng.integers(2,max(3,w-2))); yy=int(rng.integers(1,max(2,h//3)))
                    tile[yy:yy+2,xx:xx+1,:3]=np.array((28,24,36))/255
            if 'Front_Vestment' in o.name or 'Ancient_Cape' in o.name:
                tile[2:4,2:w-2,:3]=np.array((100,85,69))/255
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
    if kind=='glow': emission=tile[:,:,:3]*.75
    if kind=='spirit_dim':
        emission=tile[:,:,:3]*.24
        if h>7: tile[:h//3,:,:3]*=.76
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

