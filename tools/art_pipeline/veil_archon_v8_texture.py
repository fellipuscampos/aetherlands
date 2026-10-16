# Hand-designed pixel glyphs and mineral inlays; no skull, face, fingers, or humanoid cues.
glyphs=[
 ["001010100","001010100","001010100","001010100","001010100","001010100","011010110","001111100","000010000"],
 ["000010000","000111000","001101100","011000110","110000011","011000110","001101100","000111000","000010000"],
 ["001111000","011001100","110000110","110000000","110000000","110000110","011001100","001111000","000010000"],
 ["110000000","011000000","001100000","000111100","001100000","011000000","110000000","000000110","000001100"],
 ["000010000","001010100","001111100","000010000","111111111","000010000","001111100","001010100","000010000"],
 ["011111110","010000010","010000010","000000010","000111110","000100000","000100000","000100010","000111110"],
 ["001001000","011011000","110110000","100100010","000000110","000001100","000011000","000110000","001100000"],
 ["001111000","011001100","110000110","000000110","000011100","000110000","001100000","001111110","000000000"],
 ["010000010","010010010","010010010","011111110","000010000","000010000","000010000","001111100","000010000"]]
palette={'plate':(25,20,42),'lattice':(174,170,232),'core':(186,191,238),'orbit':(106,84,188)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
def polygon_mask(it,w,h):
    yy,xx=np.indices((h,w));xx=xx+.5;yy=yy+.5;inside=np.zeros((h,w),dtype=bool)
    pts=[(c.x*DENSITY,c.y*DENSITY) for c in it['coords']]
    for (x0,y0),(x1,y1) in zip(pts,pts[1:]+pts[:1]):
        if abs(y1-y0)<1e-8:continue
        inside^=((y0>yy)!=(y1>yy))&(xx<(x1-x0)*(yy-y0)/(y1-y0)+x0)
    return inside
def paint_rune(rgb,emission,seed,cx,cy,scale):
    glyph=glyphs[seed%len(glyphs)];gh=len(glyph);gw=len(glyph[0]);ox=int(cx-gw*scale/2);oy=int(cy-gh*scale/2)
    for j,row in enumerate(glyph):
        for i,v in enumerate(row):
            if v!='1':continue
            x=ox+i*scale;y=oy+(gh-1-j)*scale
            if x<0 or y<0 or x+scale>rgb.shape[1] or y+scale>rgb.shape[0]:continue
            rgb[y:y+scale,x:x+scale]=[197,189,225]
            emission[y:y+scale,x:x+scale]=[.22,.205,.29]
            if scale>1:rgb[y+scale-1:y+scale,x:x+scale]=[231,221,247]
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(811070+index);yy,xx=np.indices((h,w))
    clusters=rng.integers(-3,4,(math.ceil(h/3),math.ceil(w/3))).repeat(3,0).repeat(3,1)[:h,:w]
    rgb=np.clip(base+clusters[:,:,None],0,255);emission=np.zeros((h,w,3),dtype=np.float32)
    if kind=='plate':
        mask=polygon_mask(it,w,h);eroded=mask.copy()
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1),(2,0),(-2,0),(0,2),(0,-2)]:
            shifted=np.roll(mask,(dy,dx),(0,1))
            if dy>0:shifted[:dy]=False
            if dy<0:shifted[dy:]=False
            if dx>0:shifted[:,:dx]=False
            if dx<0:shifted[:,dx:]=False
            eroded&=shifted
        rim=mask&~eroded
        if n.y<-.80:
            rgb[rim]=[39,30,57]
            # A quiet thin etching, kept away from the main runes.
            if h>20 and w>22:
                rgb[(yy==4)&(xx>5)&(xx<w-5)]=[44,34,65]
                rgb[(yy==h-5)&(xx>5)&(xx<w-5)]=[44,34,65]
            seed=int(o['rune_seed']);count=int(o['rune_count'])
            if count==1:
                scale=max(1,min(3,(min(w,h)-10)//9))
                paint_rune(rgb,emission,seed,w*.5,h*.50,scale)
            else:
                scale=max(1,min(2,(h-9)//9))
                paint_rune(rgb,emission,seed,w*.30,h*.5,scale)
                paint_rune(rgb,emission,seed+3,w*.72,h*.5,scale)
            # Sparse beveled-paint accents at two clipped corners, still physically sharp.
            rgb[rim&(yy>=h-3)]=[74,60,96]
        else:
            rgb[rim]=[39,31,58]
    elif kind=='lattice':
        rgb[(xx==w//2)|(yy==h//2)]=[222,215,251]
        emission=rgb/255*.66
    elif kind=='core':
        rgb=np.broadcast_to(base,(h,w,3)).copy()
        rgb[(xx<2)|(xx>=w-2)|(yy<2)|(yy>=h-2)]=[121,106,197]
        rgb[(xx>w*.22)&(xx<w*.78)&(yy>h*.22)&(yy<h*.78)]=[233,231,254]
        emission=rgb/255*.78
    else:
        rgb[(xx==w//2)|(yy==h//2)]=[177,157,235];emission=rgb/255*.38
    light=1.06 if n.z>.8 else .77 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):
        uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
