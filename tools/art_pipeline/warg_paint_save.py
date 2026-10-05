"""Pixel-paint metric UV islands of the static Warg (V2: strand fur, layered plates).
Every motif is drawn at the island's real pixel size (64 px/m). Fur value is
driven by each texel's real world height inside its face (dark saddle on top,
light belly below), so tilted parts (neck, legs, tail) shade consistently.
The atlas is always a FRESH image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['warg']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
# V2 palette: cool wolf greys, pale underside and fur tips, dark nose/claws, yellow eyes.
BASE=(120,123,131); MID=(134,137,145); HI=(152,155,163); SHA=(102,105,113); DARK=(76,78,86)
PALE=(170,172,178); CREAM=(186,188,193); NOSE=(30,30,34); CLAW=(44,44,50)
MOUTH=(96,34,38); GUM=(150,70,74); BONE=(232,226,206); EYE=(250,194,46); EYE_HI=(255,238,150)
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
BODY=('chest','hips','neck','head','leg_upper','leg_lower','tail','tail_tip')
FURPLATE=('mane','ruff','cheek','flap')
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; part=obj['part']; n=item['normal']
    front=n.y<-.5; rear=n.y>.5; top=n.z>.6; bottom=n.z<-.6; lateral=abs(n.x)>.6
    colors={'brow':DARK,'fang':BONE,'paw':PALE,'claws':CLAW,'nose':NOSE,'ear':BASE}
    color=colors.get(reg,BASE); t=[[color for _ in range(w)] for _ in range(h)]
    rng=random.Random(5310+index)
    def rp(x,y,ww,hh,c): rect(t,x*w/100,y*h/100,ww*w/100,hh*h/100,c)
    def pp(points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def sym(points,c): pp(points,c); pp([(100-x,y) for x,y in points],c)
    right=item['right']; up=n.cross(right)
    gx,gy=right.z,up.z
    zs=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(zs),max(zs)
    def frac(x,y): return .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    # Fur falls down on sides/fronts and streams back (+Y) on tops/bottoms.
    fall=Vector((0,1,0)) if (top or bottom) else Vector((0,0,-1))
    dx,dy=right.dot(fall),-up.dot(fall)       # texture direction (rows grow downwards)
    L=(dx*dx+dy*dy)**.5
    if L<1e-6: dx,dy,L=0,1,1
    dx,dy=dx/L,dy/L
    def strands(count,palette,length=(3,7)):
        for _ in range(count):
            x=rng.uniform(0,w); y=rng.uniform(0,h); c=rng.choice(palette)
            for k in range(rng.randint(*length)):
                xx,yy=int(x+dx*k),int(y+dy*k)
                if 0<=xx<w and 0<=yy<h: t[yy][xx]=c
    if reg in BODY and not (top or bottom):
        # Darker back, mid flank, pale belly; dithered borders.
        dark_above={'tail':.55,'tail_tip':.55}.get(reg,.74)
        pale_below={'chest':.30,'hips':.30,'neck':.32,'head':.30,'leg_upper':.40,'leg_lower':.55,'tail':.25,'tail_tip':.25}[reg]
        for y in range(h):
            for x in range(w):
                f=frac(x,y)+rng.uniform(-.06,.06)
                t[y][x]=SHA if f>dark_above else (PALE if f<pale_below else BASE)
    if reg in BODY or reg in FURPLATE or reg in ('muzzle','jaw','ear'):
        # Few, long, low-contrast strands: neighbouring greys only.
        strands(max(1,w*h//34),[SHA],(5,10))
        strands(max(1,w*h//60),[MID],(4,8))
    if reg in ('chest','hips','neck','tail','tail_tip') and top:
        for y in range(h):
            for x in range(w): t[y][x]=SHA if rng.random()<.25 else BASE
        strands(max(1,w*h//24),[DARK],(5,10)); strands(max(1,w*h//48),[MID],(4,8))
    elif reg in BODY and bottom:
        for y in range(h):
            for x in range(w): t[y][x]=PALE if rng.random()<.8 else CREAM
        strands(max(1,w*h//40),[HI],(4,8))
    if reg in FURPLATE:
        # Layered fur plates: grey roots, pale ragged tips at the lowest pixels.
        for y in range(h):
            for x in range(w):
                f=frac(x,y)+rng.uniform(-.08,.08)
                if f<.28: t[y][x]=PALE if rng.random()<.8 else CREAM
                elif f<.40: t[y][x]=HI
                elif f>.82 and reg in ('mane','flap'): t[y][x]=SHA
        strands(max(1,w*h//22),[SHA],(5,11)); strands(max(1,w*h//40),[HI],(4,9))
    if reg=='head':
        if front:
            rp(0,0,100,22,SHA)
            # Hostile yellow eyes in dark sockets under the brows, nose-bridge shadow.
            sym([(8,30),(40,34),(42,52),(12,50)],DARK)
            sym([(14,36),(36,38),(37,48),(15,46)],EYE)
            sym([(26,37),(29,37),(29,48),(26,48)],NOSE)
            sym([(15,37),(19,37),(19,40),(15,40)],EYE_HI)
            sym([(44,40),(50,42),(50,70),(44,66)],SHA)
        elif top:
            for y in range(h):
                for x in range(w): t[y][x]=SHA if rng.random()<.3 else BASE
            strands(max(1,w*h//24),[DARK],(4,8))
    elif reg=='muzzle':
        if top:
            rp(0,0,100,100,MID); rp(40,0,20,100,SHA); strands(max(1,w*h//30),[BASE],(4,8))
        elif front: rp(0,0,100,100,PALE); rp(0,80,100,20,(46,44,48))
        elif lateral:
            rp(0,0,100,40,MID); rp(0,40,100,60,PALE); rp(0,84,100,16,(46,44,48))
            strands(max(1,w*h//30),[MID],(3,6))
        elif bottom:
            for y in range(h):
                for x in range(w): t[y][x]=MOUTH
            rect(t,0,0,1,h,GUM); rect(t,max(0,w-1),0,1,h,GUM)
    elif reg=='nose':
        rect(t,0,0,w,1,(70,70,76))
        if front: sym([(18,40),(38,40),(38,70),(18,70)],(10,10,12))
    elif reg=='jaw':
        if top:
            for y in range(h):
                for x in range(w): t[y][x]=MOUTH
            rp(30,10,40,70,(172,84,90))
        elif front:
            rp(0,0,100,100,PALE); rp(0,0,100,30,(46,44,48))
            for x in range(1,max(2,w-1),3): rect(t,x,0,1,max(1,h//3),BONE)
        elif lateral: rp(0,0,100,100,PALE); rp(0,0,100,22,(46,44,48))
    elif reg=='ear':
        for y in range(h):
            for x in range(w):
                if frac(x,y)>.70: t[y][x]=DARK
        if front: pp([(22,96),(78,96),(54,30),(46,30)],(96,78,82))
    elif reg=='leg_upper' and front: rp(24,6,16,88,MID); rp(28,10,6,50,HI)
    elif reg=='leg_lower' and front: rp(30,0,14,100,MID)
    elif reg=='paw':
        strands(max(1,w*h//30),[HI],(3,6))
        if top or lateral or front: rect(t,0,0,w,1,HI)
    elif reg=='claws':
        if front or top:
            for x in range(2,max(3,w-1),4): rect(t,x,0,2,h,(16,16,18))
        rect(t,0,0,w,1,(84,84,92))
    elif reg=='tail_tip':
        for y in range(h):
            for x in range(w):
                if (h-1-y)/max(1,h-1)<.30: t[y][x]=PALE if rng.random()<.6 else CREAM
    elif reg=='fang': rect(t,0,0,1,h,(196,188,166))
    elif reg=='brow': rect(t,0,max(0,h-1),w,1,SHA)
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BASE[0]/255,BASE[1]/255,BASE[2]/255,1]
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
image.filepath_raw=str(OUT/'warg_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.95
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
    root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.15
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/warg_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static editable quadruped; no animations requested. Same metric texel density as the approved models.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'warg_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
