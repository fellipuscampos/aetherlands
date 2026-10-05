"""Pixel-paint the metric UV islands of the Ancient Golem: albedo + emission atlases
(Mana Devourer convention: Emission Strength 1.6, both images packed and saved).
Same logic as the approved bestiary: top-lit gradient and dark 1 px borders on every face,
one motif per material at real pixel size (64 px/m): warm grey stone cut into big plates
with cracks, moss caps and vines with leaves and small flowers climbing the sides, a
glowing rune ring on the outer forearms; dark root/wood joints with fibres; moss and leaf
foliage; glowing eyes, chest core and crystals (the only emissive pixels besides runes).
Images are always FRESH datablocks (stale packed-image guard).
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
STONE=[(150,142,124),(138,130,114),(160,152,134)]; CRACK=(88,80,70); STONE_HI=(190,182,160); SEAM=(98,90,78)
VINE=(46,86,34); VINE_LEAF=(84,140,52); FLOWER=[(236,206,72),(214,70,70)]
MOSS=[(78,116,44),(90,132,52),(66,100,38)]; MOSS_HI=(124,164,70); MOSS_DARK=(46,76,30)
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
    elif reg=='stone':
        noise(STONE)
        # Big cut plates: seams every ~0.4 m with staggered rows (rock golem chunks).
        rows=max(1,h//26); cols=max(1,w//26)
        for y in range(h):
            for x in range(w):
                r=y*rows//h; c=(x+(r%2)*13)*cols//max(1,w)
                if y and (y*rows)//h!=((y-1)*rows)//h: t[y][x]=SEAM
                elif x and ((x+(r%2)*13)*cols)//max(1,w)!=((x-1+(r%2)*13)*cols)//max(1,w): t[y][x]=SEAM
        for _ in range(max(1,w*h//320)):                                        # cracks
            x,y=rng.randrange(w),rng.randrange(h)
            for _ in range(rng.randrange(3,9)):
                put(x,y,CRACK); x+=rng.choice((-1,0,1)); y+=rng.choice((0,1))
        for _ in range(max(0,w*h//300)): put(rng.randrange(w),rng.randrange(h),STONE_HI)
        if top:
            for y in range(h):                                                  # moss caps
                for x in range(w):
                    if min(x,y,w-1-x,h-1-y)>rng.choice((1,2,3,5)): t[y][x]=rng.choice(MOSS)
        elif side:
            for x in range(w):
                L=rng.choice((0,1,1,2,3))
                for y in range(h):
                    if frac(x,y)>.92-L*.05: t[y][x]=rng.choice(MOSS)
            for _ in range(1 if w*h>900 and rng.random()<.6 else 0):           # a vine climbing the face
                x=rng.randrange(2,max(3,w-2)); y=h-1
                while y>=0:
                    put(x,y,VINE)
                    if rng.random()<.22: put(x+rng.choice((-1,1)),y,VINE_LEAF)
                    if rng.random()<.05: put(x+rng.choice((-1,1)),y,rng.choice(FLOWER))
                    y-=1; x=max(0,min(w-1,x+rng.choice((-1,0,0,0,1))))
        light()
        if part=='Head' and n.y<-.9:
            for y in range(h):                                                  # dark sockets under the brow
                for x in range(w):
                    p=world(x,y)
                    if abs(abs(p.x)-.13)<.10 and abs(p.z-2.27)<.07: t[y][x]=SOCKET
        if part=='Chest' and n.y<-.9:
            for y in range(h):                                                  # dark cavity around the core
                for x in range(w):
                    p=world(x,y)
                    if abs(p.x)<.30 and abs(p.z-1.56)<.26: t[y][x]=SOCKET if rng.random()<.8 else GRAIN
        if part.startswith('Forearm') and side and abs(n.x)>.9 and n.x*item['center'].x>0:
            # Glowing rune ring on the outer forearm.
            cx,cy,r0=w/2,h*.45,min(w,h)*.22
            for y in range(h):
                for x in range(w):
                    d=((x-cx)**2+(y-cy)**2)**.5
                    if r0-1.2<d<r0+.6 and not (x>cx+r0*.5 and y<cy): put(x,y,FISSURE,FISSURE)
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
        noise(ROOT)
        for x in range(w):
            if rng.random()<.35:
                for y in range(h):
                    if rng.random()<.8: put(x,y,GRAIN)
        for y in range(h):
            for x in range(w):
                pass
        light()
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
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'ancient_golem_v1_{suffix}.png'); im.file_format='PNG'
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
    assert not obj.modifiers and obj.animation_data is None
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
 'notes':'Ancient golem built like the approved bestiary (mirrored blocks, pixel art detail). Static model for review.'}
st['report']=report; st['root']=root; st['material']=mat; st['images']=images
(OUT/'ancient_golem_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','width_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
