"""Pixel-paint metric UV islands of the static Skeleton Warrior.
Every motif is drawn at the island's real pixel size (64 px/m), never a square
swatch resized to fit. The atlas is always a FRESH image datablock (re-using an
already-packed image keeps stale packed bytes; see ASSET_FACTORY_GUIDE section 6).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['skeleton_warrior']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
# Aged ivory bone ramp, rusty iron, faded navy cloth.
BONE=(206,196,166); MID=(220,212,186); HI=(236,230,210); SHA=(170,158,128); DARK=(112,100,80); GAP=(46,40,38)
RUST=(94,66,52); IRON=(92,94,98); ORANGE=(132,76,44)
GLOW=(110,226,214); GLOW_HI=(222,255,248)
BONES=('ribs','spine','pelvis','bone','skull','jaw','hand','foot')
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
    colors={'rust':RUST,'rust_dark':(74,54,44),'leather':(66,48,34),'cloth':(62,72,94),
            'grip':(70,50,34),'blade':(118,116,110)}
    color=colors.get(reg,BONE); t=[[color for _ in range(w)] for _ in range(h)]
    rng=random.Random(2210+index)
    def rp(x,y,ww,hh,c): rect(t,x*w/100,y*h/100,ww*w/100,hh*h/100,c)
    def pp(points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def sym(points,c): pp(points,c); pp([(100-x,y) for x,y in points],c)
    if reg in BONES:
        # Aged bone: sparse stains and hairline cracks, one physical pixel wide.
        for _ in range(max(1,w*h//45)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),1,rng.choice([(196,186,156),(212,203,175),(190,178,146)]))
        for _ in range(max(0,w*h//160)):
            x=rng.randrange(w); y=rng.randrange(h); rect(t,x,y,1,rng.choice([2,3]),SHA)
    if reg in ('rust','rust_dark'):
        # Corroded iron: grey metal showing through orange/brown rust blotches.
        for _ in range(max(1,w*h//7)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),rng.choice([1,2]),
                 rng.choice([IRON,IRON,shade(IRON,-14),ORANGE,shade(color,-14),shade(color,10),shade(color,-6)]))
        rect(t,0,0,w,1,shade(color,30)); rect(t,0,max(0,h-1),w,1,shade(color,-26))
        if w>6 and h>3:
            for x in range(2,w-1,5): rect(t,x,h//2,1,1,(170,150,120))
        if part.startswith('Helmet') and (front or lateral) and w>8:
            # Dents and a punched-through hole.
            rect(t,w//3,1,2,max(1,h//2),shade(color,-34)); rect(t,(2*w)//3,max(0,h//3),2,2,GAP)
    elif reg=='ribs':
        if front or lateral or rear:
            # Rib bands separated by dark gaps; lower ribs angle down towards the sternum.
            for k,y in enumerate(range(2,h-2,5)):
                rect(t,0,y+3,w,2,GAP)
                rect(t,0,y,w,1,HI)
            if front:
                rp(44,0,12,100,MID); rp(47,0,6,100,HI)          # sternum
                sym([(0,72),(40,90),(40,100),(0,100)],GAP)       # costal arch opening
            if rear:
                rp(44,0,12,100,SHA); rp(47,0,6,100,BONE)
                for y in range(1,h,4): rect(t,round(w*.44),y,round(w*.12),1,DARK)
        if top: rp(30,20,40,60,SHA)
        if bottom: rp(10,15,80,70,GAP)
    elif reg=='spine':
        for y in range(1,h,4): rect(t,0,y,w,1,DARK)
        rect(t,0,0,1,h,HI); rect(t,max(0,w-1),0,1,h,SHA)
    elif reg=='pelvis':
        if front:
            sym([(8,30),(30,30),(34,72),(12,78)],GAP)            # obturator holes
            rp(46,10,8,80,MID)
        elif rear: rp(44,0,12,100,SHA)
        rect(t,0,0,w,1,HI)
    elif reg=='skull':
        if front:
            # Big dark sockets with cold glowing pinpoints, nasal cavity, upper teeth.
            sym([(6,30),(42,30),(42,62),(30,68),(8,62)],GAP)
            sym([(20,42),(30,42),(30,52),(20,52)],GLOW); sym([(22,44),(27,44),(27,49),(22,49)],GLOW_HI)
            pp([(44,66),(56,66),(50,80)],GAP)
            rp(10,84,80,16,MID)
            for x in range(round(w*.14),round(w*.86),3): rect(t,x,round(h*.86),1,max(1,round(h*.14)),DARK)
            sym([(4,10),(40,10),(42,20),(6,24)],HI)
        elif lateral:
            pp([(0,40),(14,40),(14,64),(0,64)],SHA); rp(55,45,12,14,GAP)   # temple + ear hole
        elif top or rear: rp(30,20,40,6,SHA)
    elif reg=='jaw':
        if front:
            for x in range(round(w*.12),round(w*.88),3): rect(t,x,0,1,max(1,round(h*.5)),DARK)
            rect(t,0,0,w,1,HI)
        elif lateral: rp(0,0,100,30,SHA)
    elif reg=='bone':
        # Long bones: light shaft highlight, darker knobbly ends (joints).
        rect(t,0,0,w,max(1,h//10),HI); rect(t,0,h-max(1,h//10),w,max(1,h//10),SHA)
        if front: rect(t,max(0,w//3),max(1,h//10),1,max(1,h-2*max(1,h//10)),HI)
        if rear: rect(t,max(0,w//2),0,1,h,SHA)
    elif reg=='hand':
        if front or rear or lateral:
            for x in range(2,max(3,w-1),3): rect(t,x,0,1,max(1,(2*h)//3),GAP)
            rect(t,0,h-2,w,2,HI)
    elif reg=='foot':
        if front:
            for x in range(2,max(3,w-1),3): rect(t,x,0,1,h,GAP)
        if top:
            for x in range(2,max(3,w-1),3): rect(t,x,0,1,max(1,h//2),GAP)
    elif reg=='cloth':
        dark=(44,52,70); light=(84,96,120)
        for _ in range(max(1,w*h//9)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),rng.choice([1,2]),rng.choice([dark,light,(70,82,104)]))
        pp([(0,0),(14,0),(20,55),(12,100),(0,100)],dark)
        pp([(32,0),(58,0),(64,40),(54,86),(38,92)],light)
        rp(0,90,100,10,(38,44,58))
        for _ in range(max(1,w*h//120)):
            x=rng.randrange(max(1,w-3)); y=rng.randrange(max(1,h-3)); rect(t,x,y,2,2,GAP)   # moth holes
        if part=='TabardFront' and front:
            # Faded old kingdom crest: a pale tower block.
            pp([(38,18),(62,18),(62,46),(56,46),(56,40),(44,40),(44,46),(38,46)],(150,146,126))
            rp(40,12,4,6,(150,146,126)); rp(48,12,4,6,(150,146,126)); rp(56,12,4,6,(150,146,126))
    elif reg=='leather':
        rect(t,0,0,w,1,shade(color,22)); rect(t,0,max(0,h-1),w,1,shade(color,-18))
        for _ in range(max(1,w*h//20)): rect(t,rng.randrange(w),rng.randrange(h),1,1,shade(color,-14))
    elif reg=='grip':
        for y in range(0,h,3): rect(t,0,y,w,1,(46,34,24))
    elif reg=='blade':
        for _ in range(max(1,w*h//5)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),rng.choice([1,2]),
                 rng.choice([shade(color,10),shade(color,-12),ORANGE,(132,80,48),RUST]))
        broad='edge_dir' in obj and abs(n.dot(Vector(obj['paint_up']).cross(Vector(obj['edge_dir']))))>.9
        if broad and w>4:
            rect(t,max(0,w//2),0,1,h,(90,88,84))                 # fuller line
            rect(t,0,0,1,h,(168,166,156)); rect(t,max(0,w-1),0,1,h,(168,166,156))  # dull worn edges
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BONE[0]/255,BONE[1]/255,BONE[2]/255,1]
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
image.filepath_raw=str(OUT/'skeleton_warrior_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.93
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
    root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.12
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/skeleton_warrior_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static editable model; no animations requested. Same metric texel density as Troll, Goblin and Minotaur.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'skeleton_warrior_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
