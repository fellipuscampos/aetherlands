"""Pixel-paint the metric UV islands of the Mycotic Hive V3: albedo + emission atlases
(Mana Devourer convention: Emission Strength 1.6, both images packed and saved).
Motifs are drawn at real pixel size (64 px/m); world-space cells keep blotches continuous
across faces. Materials: glowing orange orb with hot cores, darker swirl veins and pink
tints; dark wine-brown bark (claws, trunk, horn) with long fibres, light ridges and violet
glints; roots of the same bark with glowing violet sap streaks. Images are always FRESH
datablocks (stale packed-image guard).
"""
import bpy
import bmesh
import json
import math
import random
from pathlib import Path

st=bpy.app.driver_namespace['mycotic_hive']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
BLACK=(0,0,0)
ORB=[(255,146,36),(255,160,52),(248,134,30)]; ORB_HOT=(255,214,120); ORB_WHITE=(255,240,186)
SWIRL=(214,84,22); SWIRL_DARK=(168,56,18); PINK=(255,112,140)
BARK=[(58,32,30),(68,38,34),(50,28,28)]; FIBRE=(38,20,20); RIDGE=(98,58,48); GLINT=(126,86,178)
VIOLET=(160,104,255); VIOLET_DIM=(86,52,150)

def mix(a,b,f): return tuple(round(x+(y-x)*f) for x,y in zip(a,b))
def hash3(ix,iy,iz,seed):
    h=(ix*73856093)^(iy*19349663)^(iz*83492791)^(seed*2654435761)
    h=(h^(h>>13))*1274126177; return ((h^(h>>16))&0xffffffff)/4294967296
def cell(p,s,seed): return hash3(math.floor(p.x/s),math.floor(p.y/s),math.floor(p.z/s),seed)

def paint(item,index):
    w,h=item['w'],item['h']; reg=item['obj']['region']; n=item['normal']
    bottom=n.z<-.6
    rng=random.Random(31030+index)
    right=item['right']; up=item['up']; mn=item['minimum']; off=item['offset']
    def world(x,y): return right*(mn.x+(x+.5)/D)+up*(mn.y+(h-1-y+.5)/D)+n*off
    t=[[None]*w for _ in range(h)]; e=[[BLACK]*w for _ in range(h)]
    def put(x,y,c,glow=None):
        if 0<=x<w and 0<=y<h:
            t[y][x]=c
            if glow: e[y][x]=glow
    def walk(x,y,length,c,glow=None,drift=(-1,0,0,1)):
        for _ in range(length):
            put(x,y,c,glow); y+=1; x+=rng.choice(drift)
            if not 0<=y<h: break
    if reg=='orb':
        for y in range(h):
            for x in range(w):
                p=world(x,y); r=cell(p,.12,3); c=rng.choices(ORB,(5,3,2))[0]
                if r<.14: c=ORB_HOT if rng.random()<.8 else ORB_WHITE                  # hot glowing cores
                elif r>.90: c=PINK if rng.random()<.6 else c                           # pink tints
                t[y][x]=c
        for _ in range(max(1,w*h//260)):                                               # darker swirls under the skin
            x=rng.randrange(w); walk(x,rng.randrange(max(1,h//2)),rng.randrange(h//3,h+1),SWIRL if rng.random()<.7 else SWIRL_DARK)
        for y in range(h):
            for x in range(w): e[y][x]=mix(t[y][x],BLACK,.30)                          # the whole orb glows
    elif reg in ('bark','root'):
        cols=[rng.choices(BARK,(5,3,2))[0] for _ in range(w)]
        for x in range(w):
            if rng.random()<.22: cols[x]=FIBRE
            elif rng.random()<.10: cols[x]=RIDGE
        for y in range(h):
            for x in range(w): t[y][x]=cols[x] if rng.random()<.85 else rng.choice(BARK)
        for _ in range(max(0,w*h//500)): put(rng.randrange(w),rng.randrange(h),GLINT)
        if reg=='root' and not bottom:
            for _ in range(max(1,w*h//420)):                                           # glowing violet sap streaks
                walk(rng.randrange(w),rng.randrange(max(1,h//2)),rng.randrange(3,max(4,h//2)),VIOLET,VIOLET_DIM,(0,0,0,1,-1))
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
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'mycotic_hive_v3_{suffix}.png'); im.file_format='PNG'
    im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.get(NAME+'_Organism_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_Organism_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.72
    bsdf.inputs['Metallic'].default_value=0; bsdf.inputs['Specular IOR Level'].default_value=.28
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/mycotic_hive_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),
 'width_m':max(v.x for v in coordinates)-min(v.x for v in coordinates),'min_z':min(v.z for v in coordinates),
 'triangles':triangles,'editable_parts':len(parts),'parts_per_region':regions,
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,
            'unique_uv_islands':len(islands),'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'notes':'Stationary orb-organism from cubes/rectangles and tapered blocks. Same metric texel density as the approved models; albedo + emission like the Mana Devourer.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'mycotic_hive_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','width_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
