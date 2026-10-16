# Restrained pixel-painted Hytale materials on large flat blocks. No gridded brick bands.
palette={'stone':(64,61,58),'dark':(30,31,30),'ridge':(79,73,65),'face':(38,43,39),
 'crystal':(39,92,102),'core':(101,211,217)}
pixels=np.zeros((SIZE,SIZE,4),dtype=np.float32);pixels[:,:,3]=1;energy=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h'];o=it['obj'];kind=o['kind'];n=it['normal'];base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(663513+index);yy,xx=np.indices((h,w));emission=np.zeros((h,w,3),dtype=np.float32)
    variation=rng.integers(-3,4,(math.ceil(h/5),math.ceil(w/5))).repeat(5,0).repeat(5,1)[:h,:w]
    rgb=np.clip(base+variation[:,:,None],0,255)
    if kind in ('stone','dark','ridge','face'):
        # Broad, hand-placed pixel mineral patches, not dense speckle or continuous panel edging.
        for _ in range(max(1,w*h//430)):
            x=int(rng.integers(0,w));y=int(rng.integers(0,h))
            rgb[y:y+max(1,h//11),x:x+max(1,w//9)]=base+int(rng.choice([-7,7]))
        if w>17 and h>21 and index%3==0:
            for y in range(4,h-3):
                q=max(1,min(w-2,int(w*.68)+((y//7)%3)-1));rgb[y,q:q+1]=base-12
        if kind=='face' and 'Small_Six_Eyed_Head' in o.name and n.y<-.90:
            for row,(height,width) in enumerate([(.72,.29),(.50,.30),(.30,.22)]):
                for side in (-1,1):
                    x=int(w*(.5+side*width));y=int(h*height)
                    # Six small, slanted pixel eyes integrated into the face, like the image.
                    for dy in range(2):
                        q=x+side*dy
                        rgb[max(0,y+dy):min(h,y+dy+1),max(0,q-1):min(w,q+2)]=[106,204,211]
                        emission[max(0,y+dy):min(h,y+dy+1),max(0,q-1):min(w,q+2)]=[.17,.48,.52]
            mask=(yy<h*.17)&(yy>h*.06)&(xx>w*.27)&(xx<w*.73);rgb[mask]=[16,21,19]
            for x in range(int(w*.29),int(w*.71),3):rgb[int(h*.14):int(h*.19),x:x+1]=[104,112,96]
    elif kind=='crystal':
        # The reference has a dark mineral interior and bright irregular light at the roots.
        if w>6 and h>10:
            for j in range(6):
                x=int(w*(.07+j*.15));y=int(h*(.015+j*.02));vh=int(h*(.20+(j%3)*.17))
                rgb[y:min(h,y+vh),x:min(w,x+max(1,w//8))]=[48+j*8,124+j*13,137+j*11]
            trace=(xx==max(1,int(w*.86)))&(yy<h*.73);rgb[trace]=[111,197,202]
            rgb[(yy<h*.085)&(xx>w*.13)&(xx<w*.76)]=[126,211,214]
            emission[(yy<h*.31)&(xx>w*.14)&(xx<w*.72)]=[.016,.047,.054]
    elif kind=='core':
        rgb[:]=[110,213,219];rgb[(xx>w*.22)&(xx<w*.69)&(yy>h*.32)&(yy<h*.70)]=[166,237,237]
        emission=rgb/255*.57
    light=1.04 if n.z>.8 else .80 if n.z<-.8 else 1 if n.y<0 else .90
    tile=np.ones((h,w,4),dtype=np.float32);tile[:,:,:3]=np.clip(rgb*light/255,0,1)
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    energy[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(emission,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    uv=o.data.uv_layers.active.data
    for li,c in zip(o.data.polygons[it['polygon']].loop_indices,it['coords']):uv[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)
