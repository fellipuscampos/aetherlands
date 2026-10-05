"""Pixel-paint the metric UV islands of the Ancient Golem V2: albedo + emission atlases
(Mana Devourer convention: Emission Strength 1.6, both images packed and saved).
Same logic as the approved bestiary: top-lit gradient and dark 1 px borders on every face,
one motif per material at real pixel size (64 px/m): pale carved stone plates with an
engraved square-spiral glyph on the big faces, cracks and small moss caps; darker core
stone (torso, pelvis, upper arms) with glowing green fissures; cohesive moss caps on the
top faces; dark sockets around the glowing eyes. The golem is entirely stone.
Emissive pixels: eyes and the root energy veins. Images are always FRESH datablocks.
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['ancient_golem']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
BLACK=(0,0,0)
BARK=[(78,56,40),(68,48,34),(88,64,46)]; GRAIN=(46,32,24); KNOT=(36,24,18); BARK_HI=(116,88,62)
STONE=[(176,178,180),(162,164,168),(188,190,192)]; CRACK=(92,92,98); STONE_HI=(214,216,218); SEAM=(112,112,118)
ROOTS=[(66,46,32),(56,38,26),(78,54,36)]; ROOT_DARK=(34,24,18); ROOT_HI=(104,74,48); VEIN=(120,255,140)
STONE_DARK=[(112,114,118),(100,102,106),(122,124,128)]; STONE_DARK_HI=(148,150,154)
EYES=[sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices) for o in parts if o['part'].startswith('Eye')]
VINE=(46,86,34); VINE_LEAF=(84,140,52); FLOWER=[(236,206,72),(214,70,70)]
MOSS=[(66,96,40),(76,108,46),(58,86,36)]; MOSS_HI=(104,138,62); MOSS_DARK=(42,64,28)
LEAF=[(64,128,48),(56,114,42),(74,140,54)]; LEAF_HI=(104,168,68); LEAF_HOLE=(34,74,28)
SOCKET=(44,28,20)
GLOW=[(120,255,170),(96,236,150)]; GLOW_HOT=(226,255,236); FISSURE=(130,255,170)
TOOTH=[(214,196,150),(200,180,134)]; TOOTH_ROOT=(120,96,66); CLAW=[(40,28,22),(52,36,28)]; CLAW_TIP=(150,130,100)
ROOT=[(100,70,46),(88,60,40),(112,80,52)]; PLATE=[(70,50,36),(82,58,42)]; PLATE_EDGE=(42,30,22)
FUNGUS=(220,180,120); FUNGUS_RIM=(242,214,160); FUNGUS_DARK=(168,124,80)

def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; part=obj['part']; n=item['normal']
    top=n.z>.6; bottom=n.z<-.6; side=not top and not bottom
    rng=random.Random(41040+index)
    right=item['right']; up=item['up']; mn=item['minimum']; off=item['offset']
    gx,gy=right.z,up.z
    zs=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(zs),max(zs)
    def frac(x,y): return .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    def world(x,y): return right*(mn.x+(x+.5)/D)+up*(mn.y+(h-1-y+.5)/D)+n*off
    t=[[None]*w for _ in range(h)]; e=[[BLACK]*w for _ in range(h)]
    def put(x,y,c,glow=None):
        if 0<=x<w and 0<=y<h:
            t[y][x]=c
            if glow: e[y][x]=glow
    def noise(palette,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(palette,weights[:len(palette)])[0]
    def light():
        # Top-lit gradient on side faces, darker on bottoms, 1 px darker border on every face.
        for y in range(h):
            for x in range(w):
                d=0
                if side: d=int((frac(x,y)-.5)*26)
                elif bottom: d=-24
                if min(x,y,w-1-x,h-1-y)==0 and w>3 and h>3: d-=14
                t[y][x]=shade(t[y][x],d)
    if reg=='bark':
        noise(BARK)
        for x in range(w):                                                      # vertical grain
            if rng.random()<.30:
                y=rng.randrange(h); L=rng.randrange(3,max(4,h))
                for k in range(L): put(x,y+k,GRAIN)
            elif rng.random()<.08:
                for y in range(h):
                    if rng.random()<.7: put(x,y,BARK_HI)
        for _ in range(max(0,w*h//700)):                                        # knots
            x,y=rng.randrange(1,max(2,w-3)),rng.randrange(1,max(2,h-3))
            for dx,dy in ((0,0),(1,0),(2,0),(0,1),(2,1),(0,2),(1,2),(2,2)): put(x+dx,y+dy,KNOT)
            put(x+1,y+1,GRAIN)
        body=False
        if body and top:
            for y in range(h):                                                  # moss growing over the back
                for x in range(w):
                    if min(x,y,w-1-x,h-1-y)>rng.choice((2,3,4,6)): t[y][x]=rng.choice(MOSS)
        if body and side:
            for x in range(w):                                                  # moss dripping down the sides
                L=rng.choice((0,0,1,2,2,3,5))
                for y in range(h):
                    if frac(x,y)>.95-L*.03: t[y][x]=rng.choice(MOSS)
        light()
        if body and side:
            # Glowing elemental fissures: jagged cracks climbing the flanks and the chest.
            for _ in range(max(1,w*h//2600)):
                x=rng.randrange(4,max(5,w-4)); y=h-1-rng.randrange(0,max(1,h//4))
                for _ in range(rng.randrange(h//3,max(h//3+1,int(h*.75)))):
                    put(x,y,FISSURE,FISSURE); put(x+1,y,shade(FISSURE,-60))
                    y-=1; x+=rng.choice((-1,-1,0,1,1))
                    if rng.random()<.08:
                        bx,by=x,y
                        for _ in range(rng.randrange(3,8)): put(bx,by,FISSURE,FISSURE); bx+=rng.choice((-1,1)); by-=1
        if part=='Head' and n.y<-.9:
            # Carved dark sockets under the brows and a dark mouth line above the teeth.
            for y in range(h):
                for x in range(w):
                    p=world(x,y)
                    if abs(abs(p.x)-.22)<.14 and 1.27<p.z<1.40: t[y][x]=SOCKET
                    elif abs(p.x)<.04 and 1.30<p.z<1.48: t[y][x]=GRAIN
    elif reg in ('stone','stone_dark'):
        dark=reg=='stone_dark'
        noise(STONE_DARK if dark else STONE)
        if side and not dark and w>=30 and h>=30 and part not in ('Head','Jaw','Brow'):
            # Engraved square-spiral glyph on the big body plates (never on the face).
            cx,cy=w//2,h//2; r=min(w,h)//2-4
            pts=[]; x,y=cx-r,cy-r; L=2*r; dirs=[(1,0),(0,1),(-1,0),(0,-1)]; k=0
            while L>3:
                dx,dy=dirs[k%4]
                for _ in range(L): pts.append((x,y)); x+=dx; y+=dy
                if k%2==1: L-=4
                k+=1
            for px,py in pts: put(px,py,SEAM); put(px+1,py+1,STONE_HI)
        for _ in range(max(1,w*h//320)):                                        # cracks
            x,y=rng.randrange(w),rng.randrange(h)
            for _ in range(rng.randrange(3,9)):
                put(x,y,CRACK); x+=rng.choice((-1,0,1)); y+=rng.choice((0,1))
        for _ in range(max(0,w*h//300)): put(rng.randrange(w),rng.randrange(h),STONE_DARK_HI if dark else STONE_HI)
        cap=top and w>=10 and h>=10
        if cap:
            # Moss grows over PART of the top: an organic boundary (random walk) splits the
            # face, darker rim along it, a few bright tufts; the rest stays bare stone.
            horizontal=rng.random()<.5; n_=w if horizontal else h; m_=h if horizontal else w
            b=rng.uniform(.35,.65)*m_; line=[]
            for _ in range(n_): b=max(2,min(m_-2,b+rng.choice((-1,0,0,1)))); line.append(b)
            flip=rng.random()<.5
            for y in range(h):
                for x in range(w):
                    i,j=(x,y) if horizontal else (y,x)
                    d=(j-line[i]) if not flip else (line[i]-j)
                    if d<0: continue
                    t[y][x]=MOSS_DARK if d<1 else rng.choices(MOSS,(5,3,2))[0]
            for _ in range(max(1,w*h//60)):
                x,y=rng.randrange(w),rng.randrange(h)
                if t[y][x] in MOSS: put(x,y,MOSS_HI)
        elif side:
            for x in range(w):                                                  # short moss drips under the caps
                if rng.random()<.35:
                    L=rng.choice((1,1,2,3))
                    for y in range(h):
                        if frac(x,y)>1-L/max(1,h): t[y][x]=MOSS_DARK if rng.random()<.5 else MOSS[2]
        light()
        if dark and side:
            for _ in range(max(1,w*h//900)):                                    # glowing energy fissures
                x=rng.randrange(w); y=rng.randrange(max(1,h//3))
                for _ in range(rng.randrange(h//3,h+1)):
                    put(x,y,VEIN,VEIN); y+=1; x+=rng.choice((-1,0,0,1))
                    if not 0<=y<h: break
        if part=='Head' and n.y<-.9:
            for eye in EYES:                                                    # dark sockets around the eyes
                for y in range(h):
                    for x in range(w):
                        d=world(x,y)-eye
                        if abs(d.dot(right))<.12 and abs(d.dot(up))<.075: t[y][x]=SOCKET
    elif reg=='moss':
        noise(MOSS)
        for _ in range(max(1,w*h//14)): put(rng.randrange(w),rng.randrange(h),MOSS_HI)
        for _ in range(max(1,w*h//30)): put(rng.randrange(w),rng.randrange(h),MOSS_DARK)
        light()
    elif reg=='leaf':
        noise(LEAF)
        for _ in range(max(1,w*h//10)):                                         # leaf clumps
            x,y=rng.randrange(w),rng.randrange(h)
            for dx,dy in ((0,0),(1,0),(0,1)): put(x+dx,y+dy,LEAF_HI)
        for _ in range(max(1,w*h//22)):                                         # dark gaps between leaves
            x,y=rng.randrange(w),rng.randrange(h); put(x,y,LEAF_HOLE); put(x+1,y,LEAF_HOLE)
        light()
    elif reg=='glow':
        # Concentric glow: solid hot centre, green ring, darker rim (reads as light, not noise).
        ring=max(1,min(w,h)//4)
        for y in range(h):
            for x in range(w):
                d=min(x,y,w-1-x,h-1-y)
                c=GLOW_HOT if d>=ring else (GLOW[0] if d>0 or min(w,h)<4 else GLOW[1])
                t[y][x]=c; e[y][x]=c
    elif reg=='crystal':
        for y in range(h):
            for x in range(w):
                c=GLOW_HOT if x==w//2 or y<2 else rng.choice(GLOW); t[y][x]=c; e[y][x]=c
    elif reg=='root':
        # Tangled living roots: long strands of mixed browns with dark gaps and glowing veins.
        cols=[rng.choice(ROOTS) for _ in range(w)]
        for x in range(w):
            if rng.random()<.25: cols[x]=ROOT_DARK
            elif rng.random()<.18: cols[x]=ROOT_HI
        for y in range(h):
            for x in range(w): t[y][x]=cols[(x+(y//6)*(1 if (x//3)%2 else -1))%w] if rng.random()<.9 else rng.choice(ROOTS)
        light()
        for _ in range(max(1,w*h//700)):                                        # glowing energy veins
            x=rng.randrange(w); y=rng.randrange(max(1,h//3))
            for _ in range(rng.randrange(h//3,h+1)):
                put(x,y,VEIN,VEIN); y+=1; x+=rng.choice((-1,0,0,1))
                if not 0<=y<h: break
    elif reg=='plate':
        # Layered bark plates (like the wolf's mane): horizontal bands with ragged lower edges.
        noise(PLATE)
        band=max(4,h//4)
        for y in range(h):
            for x in range(w):
                if (y+(x*7)%3)%band==band-1: t[y][x]=PLATE_EDGE
                elif (y%band)==0: t[y][x]=shade(t[y][x],18)
        light()
    elif reg in ('tooth','fang'):
        for y in range(h):
            for x in range(w): t[y][x]=TOOTH_ROOT if y<h*.25 else rng.choice(TOOTH)
    elif reg=='claw':
        for y in range(h):
            for x in range(w): t[y][x]=CLAW_TIP if y>h*.8 else rng.choice(CLAW)
    elif reg=='fungus':
        for y in range(h):
            for x in range(w):
                if top: t[y][x]=FUNGUS_RIM if min(x,y,w-1-x,h-1-y)==0 else FUNGUS
                elif bottom: t[y][x]=FUNGUS_DARK if x%2 else FUNGUS
                else: t[y][x]=FUNGUS_RIM if y==0 else FUNGUS
    else:
        raise RuntimeError('unpainted region '+reg)
    return t,e

pixels=([c/255 for c in BARK[0]]+[1])*(SIZE*SIZE); energy=[0,0,0,1]*(SIZE*SIZE)
for index,it in enumerate(islands):
    t,e=paint(it,index); w,h=it['w'],it['h']; ox,oy=it['x'],it['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            xx=max(0,min(w-1,x)); yy=h-1-max(0,min(h-1,y)); k=((oy+y)*SIZE+ox+x)*4
            pixels[k:k+4]=[v/255 for v in t[yy][xx]]+[1]; energy[k:k+4]=[v/255 for v in e[yy][xx]]+[1]
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    stale=bpy.data.images.get(NAME+'_'+suffix)
    if stale: bpy.data.images.remove(stale)
    im=bpy.data.images.new(NAME+'_'+suffix,width=SIZE,height=SIZE,alpha=True); im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'ancient_golem_v2_{suffix}.png'); im.file_format='PNG'
    im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.82
    bsdf.inputs['Metallic'].default_value=0; bsdf.inputs['Specular IOR Level'].default_value=.2
    for socket in ('Base Color','Emission Color'):
        node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.interpolation='Closest'; node.extension='EXTEND'; node.label=socket
        mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs[socket])
    bsdf.inputs['Emission Strength'].default_value=1.6
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE': node.image=images[0] if node.label=='Base Color' else images[1]
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(mat)
    if 'Metric_Pixel_UV' not in obj.data.uv_layers: obj.data.uv_layers.new(name='Metric_Pixel_UV')
for item in islands:
    me=item['obj'].data; uv=me.uv_layers['Metric_Pixel_UV'].data
    for li,co in zip(me.polygons[item['polygon']].loop_indices,item['coords']):
        uv[li].uv=((item['x']+co.x*D)/SIZE,(item['y']+co.y*D)/SIZE)
for m in [m for m in bpy.data.materials if m.name.startswith(NAME+'_Clay_')]: bpy.data.materials.remove(m)

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
    assert all(m.type=='ARMATURE' for m in obj.modifiers) and obj.animation_data is None
    uv=me.uv_layers['Metric_Pixel_UV'].data
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-7: density.append((uv[li].uv-uv[lj].uv).length*SIZE/length)
assert nonmanifold==0, nonmanifold
assert max(abs(d-D) for d in density)<.03
coordinates=[v.co for o in parts for v in o.data.vertices]
regions={}
for o in parts: regions[o['region']]=regions.get(o['region'],0)+1
report={'name':NAME,'display_name':'Ancião da Floresta (golem)','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/ancient_golem_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),
 'width_m':max(v.x for v in coordinates)-min(v.x for v in coordinates),'min_z':min(v.z for v in coordinates),
 'triangles':triangles,'editable_parts':len(parts),'parts_per_region':regions,
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,
            'unique_uv_islands':len(islands),'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Ancient golem V2 after the user voxel-golem reference, nature version (no sword). Static model for review.'}
st['report']=report; st['root']=root; st['material']=mat; st['images']=images
(OUT/'ancient_golem_v2_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','width_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
