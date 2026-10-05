"""Pixel-paint metric UV islands of the Forest Elder.
Every motif is drawn at the island's real pixel size (64 px/m). Readable materials:
dark bark with vertical grain, knots and creeping moss; lime-glowing runes; a pale
carved mask with amber eyes; a red-orange-yellow flame-leaf crown; grey branch-wood
claws; layered leaves; a woven red-ochre sash; a vine. The atlas is always a FRESH
image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['forest_elder']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
BARK=[(74,50,36),(82,56,40),(66,44,32)]; BARK_LINE=(48,32,24); BARK_HI=(104,74,52); KNOT=(38,26,20)
MOSS=[(70,100,46),(86,118,54),(56,82,38)]
RUNE=(176,238,92); RUNE_DIM=(104,150,62)
MASK=[(158,118,78),(170,128,86),(146,108,70)]; MASK_LINE=(98,70,46)
EYE=(255,186,40); EYE_HI=(255,238,150); EMBER=(232,96,30)
FLAME=[(124,24,20),(178,40,28),(226,90,30),(250,150,44),(255,206,72)]
WOOD=[(98,74,54),(110,84,60),(88,66,48)]; CLAW=(40,30,24)
LEAF=[(46,94,48),(60,118,58),(38,78,40)]; LEAF_VEIN=(96,150,74); LEAF_DARK=(28,58,30)
SASH=(152,52,34); SASH_OCHRE=(206,134,52); SASH_DARK=(96,30,24)
VINE=[(54,104,46),(40,82,38)]
def rect(t,x,y,w,h,c):
    for yy in range(max(0,round(y)),min(len(t),round(y+h))):
        for xx in range(max(0,round(x)),min(len(t[0]),round(x+w))): t[yy][xx]=c
def polygon(t,pts,c):
    pts=[(round(x),round(y)) for x,y in pts]
    for y in range(max(0,min(p[1] for p in pts)),min(len(t),max(p[1] for p in pts)+1)):
        for x in range(max(0,min(p[0] for p in pts)),min(len(t[0]),max(p[0] for p in pts)+1)):
            inside=False; j=len(pts)-1
            for i in range(len(pts)):
                ax,ay=pts[i]; bx,by=pts[j]
                if ((ay>y+.5)!=(by>y+.5)) and x+.5<(bx-ax)*(y+.5-ay)/(by-ay)+ax: inside=not inside
                j=i
            if inside: t[y][x]=c
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; part=obj['part']; n=item['normal']
    front=n.y<-.5; rear=n.y>.5; top=n.z>.6; bottom=n.z<-.6; lateral=abs(n.x)>.6
    rng=random.Random(12010+index)
    right=item['right']; up=n.cross(right)
    fall=Vector((0,1,0)) if (top or bottom) else Vector((0,0,-1))
    dx,dy=right.dot(fall),-up.dot(fall); vertical=abs(dy)>=abs(dx)
    gx,gy=right.z,up.z
    zs=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(zs),max(zs)
    def frac(x,y): return .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    def fill(c): return [[c for _ in range(w)] for _ in range(h)]
    def rp(t,x,y,ww,hh,c): rect(t,x*w/100,y*h/100,ww*w/100,hh*h/100,c)
    def pp(t,points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def sym(t,points,c): pp(t,points,c); pp(t,[(100-x,y) for x,y in points],c)
    def noise(t,palette,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(palette,weights)[0]
    def grain(t,line,count,length=(4,10)):
        # Wood grain strands along the fall/limb direction.
        L=(dx*dx+dy*dy)**.5 or 1; ux,uy=(dx/L,dy/L) if (dx or dy) else (0,1)
        for _ in range(count):
            x=rng.uniform(0,w); y=rng.uniform(0,h)
            for k in range(rng.randint(*length)):
                xx,yy=int(x+ux*k),int(y+uy*k)
                if 0<=xx<w and 0<=yy<h: t[yy][xx]=line
    def moss(t,threshold,density=.75):
        for y in range(h):
            for x in range(w):
                f=frac(x,y)+rng.uniform(-.08,.08)
                if (top or f>threshold) and rng.random()<density: t[y][x]=rng.choices(MOSS,(5,3,2))[0]
    t=fill(BARK[0])
    if reg in ('bark','bark_moss','bark_runes'):
        noise(t,BARK); grain(t,BARK_LINE,max(1,w*h//14)); grain(t,BARK_HI,max(1,w*h//60),(2,5))
        for _ in range(max(0,w*h//500)):                                       # knots
            cx,cy=rng.randrange(w),rng.randrange(h); rect(t,cx,cy,3,2,KNOT); rect(t,cx+1,cy,1,2,BARK_LINE)
        if lateral or front or rear:
            for y in range(h):
                for x in range(w):
                    f=frac(x,y)
                    if f>.80: t[y][x]=shade(t[y][x],8)
                    elif f<.18: t[y][x]=shade(t[y][x],-10)
        if reg=='bark' and top: moss(t,.0,.55)
        if reg=='bark_moss': moss(t,.62,.8)
        if (reg=='bark_runes' and (lateral or front)) or (part=='Chest' and front):
            # Lime tree-runes (a stem with two branches rising from its middle), softly
            # glowing; one per forearm side, two on the chest.
            for k in range(1 if part!='Chest' else 2):
                cx=int(w*(.32+.36*k)) if part=='Chest' else int(w*.5); top_y=int(h*.28); H=max(6,int(h*.34))
                for yy in range(top_y,top_y+H):
                    rect(t,cx-1,yy,3,1,RUNE_DIM); rect(t,cx,yy,1,1,RUNE)
                mid=top_y+int(H*.55)
                for i in range(1,4):
                    for sgn in (-1,1):
                        rect(t,cx+sgn*i,mid-i*2,1,2,RUNE); rect(t,cx+sgn*i,mid-i*2+2,1,1,RUNE_DIM)
                rect(t,cx,top_y-2,1,1,RUNE)
    elif reg=='mask':
        noise(t,MASK); grain(t,MASK_LINE,max(1,w*h//40),(3,7))
        if front:
            # Carved spirit mask: dark eye slots with glowing amber eyes, cheek grooves,
            # a mouth slit with an ember glow inside, a carved line down the forehead.
            # Angry slanted eye slots (outer corners high), glowing amber eyes inside.
            sym(t,[(6,36),(42,48),(42,58),(10,50)],KNOT)
            sym(t,[(12,41),(38,50),(38,55),(14,48)],EYE); sym(t,[(16,43),(24,46),(24,48),(16,46)],EYE_HI)
            sym(t,[(4,60),(12,60),(20,92),(14,94)],MASK_LINE)
            # Jagged carved maw (teeth-like notches) with a deep ember glow, no smile.
            pp(t,[(24,72),(34,80),(42,72),(50,81),(58,72),(66,80),(76,72),(74,90),(26,90)],KNOT)
            pp(t,[(32,84),(68,84),(66,88),(34,88)],EMBER)
            rp(t,49,6,2,28,MASK_LINE)
    elif reg=='mask_dark':
        noise(t,[KNOT,BARK_LINE,(56,38,28)])
        if front:
            for x in range(2,w-1,5): rect(t,x,max(0,h-2),2,2,MASK_LINE)
    elif reg=='beard':
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices([BARK_LINE,KNOT,MOSS[2],MOSS[0]],(4,2,3,2))[0]
        grain(t,MOSS[1],max(1,w*h//20),(3,8))
    elif reg=='crown':
        # Flame-leaves: dark red at the root through red and orange to yellow tips.
        for y in range(h):
            for x in range(w):
                f=frac(x,y)+rng.uniform(-.07,.07)
                i=0 if f<.15 else 1 if f<.42 else 2 if f<.70 else 3 if f<.88 else 4
                t[y][x]=FLAME[i]
        grain(t,FLAME[1],max(1,w*h//30),(3,8))
    elif reg=='branch':
        noise(t,WOOD); grain(t,BARK_LINE,max(1,w*h//20),(3,7))
        tip_low=part.startswith(('Finger','Thumb','Toe'))
        for y in range(h):
            for x in range(w):
                f=frac(x,y)
                if (tip_low and f<.22) or (not tip_low and f>.85): t[y][x]=CLAW
    elif reg=='leaves':
        # Overlapping leaf shapes falling down, lighter midrib, dark lower edge.
        L,W=6,5; jit={}
        for y in range(h):
            for x in range(w):
                a,b=(y,x) if vertical else (x,y); row=a//L; off=(W//2)*(row%2); col=(b+off)//W; k=(b+off)%W; r=a%L
                if (row,col) not in jit: jit[(row,col)]=rng.choice(LEAF)
                c=jit[(row,col)]
                if r==L-1: c=LEAF_DARK if k in (0,W-1) else shade(c,-14)
                elif k==W//2 and r<L-2: c=LEAF_VEIN
                t[y][x]=c
    elif reg=='sash':
        t=fill(SASH)
        for y in range(h):
            for x in range(w):
                a,b=(y,x) if vertical else (x,y)
                if a%6 in (0,5): t[y][x]=SASH_DARK
                elif (b+a)%6==0 and 1<a%6<4: t[y][x]=SASH_OCHRE           # woven zigzag
                elif rng.random()<.06: t[y][x]=shade(SASH,-12)
    elif reg=='talisman':
        noise(t,MASK)
        if front: rect(t,0,0,w,1,MASK_LINE); rp(t,46,15,8,70,RUNE_DIM); rp(t,48,20,4,60,RUNE); rp(t,30,40,40,6,RUNE)
    elif reg=='vine':
        for y in range(h):
            for x in range(w):
                t[y][x]=VINE[((x+y)//3)%2]                                    # twisted stripes
        for _ in range(max(1,w*h//25)): rect(t,rng.randrange(w),rng.randrange(h),2,1,LEAF[1])
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BARK[0][0]/255,BARK[0][1]/255,BARK[0][2]/255,1]
for index,item in enumerate(islands):
    t=paint(item,index); w,h=item['w'],item['h']; ox,oy=item['x'],item['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            color=t[h-1-max(0,min(h-1,y))][max(0,min(w-1,x))]
            k=((oy+y)*SIZE+ox+x)*4; pixels[k:k+4]=[c/255 for c in color]+[1]
stale=bpy.data.images.get(NAME+'_PixelAtlas')
if stale: bpy.data.images.remove(stale)
image=bpy.data.images.new(NAME+'_PixelAtlas',width=SIZE,height=SIZE,alpha=True)
image.colorspace_settings.name='sRGB'; image.pixels.foreach_set(pixels)
image.filepath_raw=str(OUT/'forest_elder_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.93
    bsdf.inputs['Specular IOR Level'].default_value=.10
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.interpolation='Closest'; node.extension='EXTEND'
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE': node.image=image
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(mat)
    if 'Metric_Pixel_UV' not in obj.data.uv_layers: obj.data.uv_layers.new(name='Metric_Pixel_UV')
for item in islands:
    me=item['obj'].data; uv=me.uv_layers['Metric_Pixel_UV'].data
    for li,co in zip(me.polygons[item['polygon']].loop_indices,item['coords']):
        uv[li].uv=((item['x']+co.x*DENSITY)/SIZE,(item['y']+co.y*DENSITY)/SIZE)

root=bpy.data.objects.get(NAME+'_ROOT')
if root is None:
    root=bpy.data.objects.new(NAME+'_ROOT',None); scene.collection.objects.link(root)
    root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.2
for obj in parts: obj.parent=root
density=[]; triangles=0; nonmanifold=0
for obj in parts:
    me=obj.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles)
    bm=bmesh.new(); bm.from_mesh(me); nonmanifold+=sum(not e.is_manifold for e in bm.edges); bm.free()
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons), obj.name
    assert not obj.modifiers and obj.animation_data is None
    uv=me.uv_layers['Metric_Pixel_UV'].data
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-7: density.append((uv[li].uv-uv[lj].uv).length*SIZE/length)
assert nonmanifold==0, nonmanifold
assert max(abs(d-DENSITY) for d in density)<.03
coordinates=[v.co for o in parts for v in o.data.vertices]
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/forest_elder_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Curupira-inspired forest spirit; feet point backwards. Same metric texel density as the approved models.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'forest_elder_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
