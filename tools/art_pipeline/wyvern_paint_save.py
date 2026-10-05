"""Pixel-paint metric UV islands of the static Wyvern (V2, reference-driven red).
Every motif is drawn at the island's real pixel size (64 px/m). Three readable
materials: reptile scales (body, head, limbs, tail) with ochre ventral scutes,
thin membrane (wings), and bone (claws, horns, spines, tail blade). The atlas is
always a FRESH image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['wyvern']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
# V2 palette (reference-driven red wyvern): vivid red scales in 3-tone pixel noise,
# darker dorsal, cream-tan belly plates, brighter mottled membrane, dark-red finger
# bones, pale bone horns/spines/claws, white teeth, blood-red mouth, yellow slit eyes.
RED=[(150,30,30),(166,38,34),(136,26,28)]; RED_HI=(196,62,50); RED_SHA=(112,22,24); RED_DARK=(74,14,18)
BELLY=[(214,166,124),(204,154,114),(222,176,134)]; BELLY_LINE=(184,130,96)
MEM=[(178,38,36),(162,30,30),(196,52,44)]; MEM_DARK=(118,20,24)
FINGER=(96,18,22); BONE=(228,216,192); BONE_SHA=(196,182,154); BONE_DARK=(150,134,110)
MOUTH=(158,28,36); MOUTH_DARK=(112,14,22); TOOTH=(242,238,228)
EYE=(250,214,40); EYE_RIM=(255,140,20); PUPIL=(12,8,6)
SCALY=('chest','hips','neck','skull','snout','jaw','limb','hand','tail','brow')
def rect(t,x,y,w,h,c):
    for yy in range(max(0,round(y)),min(len(t),round(y+h))):
        for xx in range(max(0,round(x)),min(len(t[0]),round(x+w))): t[yy][xx]=c
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; part=obj['part']; n=item['normal']
    front=n.y<-.5; rear=n.y>.5; top=n.z>.6; bottom=n.z<-.6; lateral=abs(n.x)>.6
    rng=random.Random(9910+index)
    right=item['right']; up=n.cross(right)
    fall=Vector((0,1,0)) if (top or bottom) else Vector((0,0,-1))
    dx,dy=right.dot(fall),-up.dot(fall); vertical=abs(dy)>=abs(dx)
    flip=(dy if vertical else dx)<0
    gx,gy=right.z,up.z
    zs=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(zs),max(zs)
    def frac(x,y): return .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    def fill(c): return [[c for _ in range(w)] for _ in range(h)]
    def cell(x,y):
        a,b=(y,x) if vertical else (x,y)
        if flip: a=(h if vertical else w)-1-a
        return a,b
    def noise(t,palette,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(palette,weights)[0]
    def plates(t,step=6):
        # Cream belly plates across the body: each plate its own soft value, a light
        # top edge and a soft seam (reads as leathery scutes, not planks).
        noise(t,BELLY); jit={}
        for y in range(h):
            for x in range(w):
                a,b=cell(x,y); row=a//step
                if row not in jit: jit[row]=rng.choice([-8,-4,0,4])
                if a%step==step-1: t[y][x]=BELLY_LINE
                elif a%step==0: t[y][x]=shade(t[y][x],10+jit[row])
                else: t[y][x]=shade(t[y][x],jit[row])
    t=fill(RED[0])
    tone={'limb':-14,'hand':-20}.get(reg,0)
    if reg=='tail': tone=-4*int(part.split('_')[1])
    pal=[shade(c,tone) for c in RED]
    if reg in SCALY:
        noise(t,pal)
        if lateral or front or rear:
            for y in range(h):
                for x in range(w):
                    f=frac(x,y)+rng.uniform(-.05,.05)
                    if f>.82: t[y][x]=shade(t[y][x],-30)               # darker dorsal band
                    elif f<.22 and reg in ('chest','hips','neck','tail'): t[y][x]=rng.choices(BELLY,(5,3,2))[0]
        if top and reg in ('chest','hips','neck','tail','skull','snout'):
            noise(t,[RED_SHA,RED_DARK,pal[2]],(5,2,3))
        if bottom and reg in ('chest','hips','neck','tail','jaw'): plates(t)
        if reg=='neck' and front: plates(t)
        if reg=='snout':
            if front:
                rect(t,0,int(h*.75),w,h,RED_DARK)
                for cx in (int(w*.22),int(w*.66)): rect(t,cx,int(h*.18),max(2,w//7),max(2,h//6),RED_DARK)
            if bottom: noise(t,[MOUTH,MOUTH_DARK],(3,2))
        if reg=='jaw':
            if top: noise(t,[MOUTH,MOUTH_DARK],(3,2))
            if lateral:
                for y in range(h):
                    for x in range(w):
                        if frac(x,y)<.45: t[y][x]=rng.choices(BELLY,(5,3,2))[0]
        if reg=='skull' and lateral:
            for y in range(h):
                for x in range(w):
                    if frac(x,y)>.62: t[y][x]=shade(t[y][x],-26)
        if reg=='brow': noise(t,[RED_DARK,RED_SHA],(3,2))
        if reg=='hand': rect(t,0,0,w,1,RED_HI)
    elif reg=='membrane':
        if lateral or abs(n.x)>.25:
            noise(t,MEM)
            for y in range(h):
                for x in range(w):
                    if frac(x,y)<.08 and rng.random()<.8: t[y][x]=MEM_DARK   # dark trailing edge
        else: t=fill(MEM_DARK)
    elif reg=='wing_bone':
        noise(t,[FINGER,shade(FINGER,10),shade(FINGER,-10)])
    elif reg=='eye':
        t=fill(RED_DARK)
        if lateral or (front and abs(n.x)>.3):
            rect(t,0,0,w,h,EYE_RIM); rect(t,1,1,max(1,w-2),max(1,h-2),EYE); rect(t,w//2,0,1,h,PUPIL)
    elif reg=='tooth':
        t=fill(TOOTH); rect(t,0,0,1,h,shade(TOOTH,-24))
    elif reg in ('bone','bone_spike','claw'):
        noise(t,[BONE,BONE_SHA,BONE],(5,2,2))
        for y in range(h):
            for x in range(w):
                f=frac(x,y)
                if (reg=='claw' and f<.25) or (reg!='claw' and f>.80): t[y][x]=BONE_DARK
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[RED[0][0]/255,RED[0][1]/255,RED[0][2]/255,1]
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
image.filepath_raw=str(OUT/'wyvern_blocky_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.90
    bsdf.inputs['Specular IOR Level'].default_value=.12
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/wyvern_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),
 'wingspan_m':max(v.x for v in coordinates)-min(v.x for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static editable wyvern; wings are the forelimbs. Membranes follow hand_* rigidly (a future flap rig would need per-finger weights).'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'wyvern_blocky_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','wingspan_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
