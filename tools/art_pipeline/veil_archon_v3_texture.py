# The current game's cube-skull motifs are repainted as cold spectral bone, alongside black stone.
import random
skeleton_source=(ROOT/'tools/art_pipeline/skeleton_warrior_paint_save.py').read_text(encoding='utf-8')
exec(skeleton_source[skeleton_source.index('# Aged ivory bone ramp'):skeleton_source.index('pixels=[0.0]')],globals())
GLOW=(109,215,251); GLOW_HI=(205,245,255)
palette={'obsidian':(17,23,32),'obsidian_mid':(29,38,51),'blue_facet':(46,81,126),
 'bone_blue':(137,177,202),'energy_dim':(64,154,215),'core':(73,160,248),
 'skull_blue':(140,180,201),'jaw_blue':(140,180,201)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,3]=1; energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; o=it['obj']; kind=o['kind']; n=it['normal']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(148800+index); yy,xx=np.indices((h,w))
    clusters=rng.integers(-4,5,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255); emission=np.zeros((h,w,3),dtype=np.float32)
    if kind.startswith('obsidian'):
        # Large plane divisions and sparse square cuts keep the dark silhouettes readable.
        if h>8:
            rgb[yy<2]=np.maximum(0,base-7); rgb[yy>=h-2]=base+8
        for _ in range(max(1,w*h//170)):
            x=int(rng.integers(0,w)); y=int(rng.integers(0,h))
            rgb[y:y+2,x:x+3]=np.clip(base+int(rng.choice([-9,7,13])),0,255)
    elif kind=='blue_facet':
        rgb[xx<2]=base*.76; rgb[xx>=w-2]=base*1.17
        emission=rgb/255*.13
    elif kind in ('skull_blue','jaw_blue'):
        item=dict(it); item['obj']={'region':'skull' if kind=='skull_blue' else 'jaw','part':o.name}
        painted=np.asarray(paint(item,index),dtype=np.float32)[::-1]
        brightness=np.clip((painted[:,:,0]*.3+painted[:,:,1]*.59+painted[:,:,2]*.11-34)/202,0,1)
        rgb=np.array((18,31,45))+brightness[:,:,None]*np.array((143,166,174))
        for glow in (GLOW,GLOW_HI):
            mask=np.all(painted==np.array(glow),axis=2)
            rgb[mask]=glow; emission[mask]=np.array(glow)/255*.65
    elif kind=='bone_blue':
        rgb[yy<1]=base*.82; rgb[yy>=h-1]=base*1.08
        emission=rgb/255*.11
    elif kind=='energy_dim':
        rgb[(xx+yy//5)%5==0]=[86,184,238]
        emission=rgb/255*.26
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[36,93,187]
        rgb[(xx>w*.3)&(xx<w*.73)&(yy>h*.27)&(yy<h*.72)]=[143,210,252]
        for _ in range(3):
            x=int(rng.integers(2,max(3,w-3))); y=int(rng.integers(2,max(3,h-3)))
            rgb[y:y+2,x:x+2]=[205,240,255]
    light=1.08 if n.z>.8 else .75 if n.z<-.8 else 1 if n.y<0 else .85
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    if kind=='core': emission=tile[:,:,:3]*.92
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
