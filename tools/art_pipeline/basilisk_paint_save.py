"""Pixel-paint metric UV islands of the static Basilisk V2 (plumage vs scales split).
Every motif is drawn at the island's real pixel size (64 px/m). Patterns are
oriented by each texel's real world direction: feather shingles fall downwards,
scale rows and belly plates run across the body. The atlas is always a FRESH
image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['basilisk']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
# V2 material split, readable at a glance:
#   PLUMAGE (bird): brown-black feathers with copper sheen; iridescent teal plumes.
#   REPTILE (serpent): venom-green scales, yellow ventral scutes, dark bands.
PL=(58,44,36); PL_MID=(78,58,44); PL_HI=(112,80,54); PL_SHA=(38,29,26); PL_DARK=(22,18,17)
COPPER=(158,98,48); COPPER_HI=(200,136,66); TEAL=(44,92,82); TEAL_HI=(70,130,112)
SC=(70,92,46); SC_MID=(86,110,54); SC_HI=(108,132,64); SC_SHA=(50,68,34); SC_DARK=(30,42,22)
BELLY=(176,164,92); BELLY_SHA=(136,124,66)
LEG=(196,150,58); BEAK=(112,104,74); BEAK_DARK=(38,34,28)
COMB=(150,24,36); COMB_SHA=(98,14,24); COMB_HI=(196,52,52)
CLAW=(36,32,30); MOUTH=(96,22,30); TONGUE=(134,36,68); FANG=(236,228,200)
EYE=(226,240,62); EYE_RING=(232,120,30); EYE_HI=(255,255,190); PUPIL=(10,10,8)
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
PLUMAGE=('body','breast','ruff','thigh','hackle','wing_coverts','wing_secondaries','wing_primaries','plume')
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; part=obj['part']; n=item['normal']
    front=n.y<-.5; rear=n.y>.5; top=n.z>.6; bottom=n.z<-.6; lateral=abs(n.x)>.6
    rng=random.Random(7710+index)
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
        return a,b                       # a grows along the fall direction, b across it
    def feathers(t,base,tip=None,L=6,W=4,tip_rate=.3):
        # Real feather shapes: rounded tip (corner pixels show the dark layer below),
        # light shaft, shaded left edge, half-offset rows overlapping down the fall.
        jit={}
        for y in range(h):
            for x in range(w):
                a,b=cell(x,y); row=a//L; off=(W//2)*(row%2); col=(b+off)//W; k=(b+off)%W; r=a%L
                if (row,col) not in jit: jit[(row,col)]=(rng.choice([-6,-3,0,0,3,6]),rng.random()<tip_rate)
                d,acc=jit[(row,col)]; c=shade(base,d)
                if r==L-1: c=PL_DARK if k in (0,W-1) else shade(base,d-16)
                elif k==0: c=shade(base,d-10)
                elif k==W//2 and r<L-2: c=shade(base,d+12)
                if tip and acc and r==L-2 and 0<k<W-1: c=tip
                t[y][x]=c
    def scales(t,base,hi_c,S=4):
        # Scalloped reptile scales: dark U outline, one highlight pixel, half-offset rows.
        jit={}
        for y in range(h):
            for x in range(w):
                a,b=cell(x,y); row=a//S; off=(S//2)*(row%2); col=(b+off)//S; k=(b+off)%S; r=a%S
                if (row,col) not in jit: jit[(row,col)]=rng.choice([-6,-2,0,3])
                c=shade(base,jit[(row,col)])
                if (r==S-1 and 0<k<S-1) or (k==0 and r>=S//2) or (k==S-1 and r>=S//2): c=shade(base,-17)
                elif r==1 and k==1: c=hi_c
                t[y][x]=c
    def scutes(t,step=5):
        for y in range(h):
            for x in range(w):
                a,b=cell(x,y); r=a%step
                t[y][x]=BELLY_SHA if r==step-1 else (shade(BELLY,14) if r==0 else BELLY)
    def volume(t,gain=10,loss=14):
        for y in range(h):
            for x in range(w):
                f=frac(x,y)
                if f>.78: t[y][x]=shade(t[y][x],gain)
                elif f<.25: t[y][x]=shade(t[y][x],-loss)
    t=fill(PL)
    if reg in PLUMAGE:
        base={'wing_coverts':PL_MID,'wing_secondaries':PL,'wing_primaries':PL_SHA,'plume':PL_SHA,'breast':PL_MID,'ruff':PL_MID}.get(reg,PL)
        tip={'plume':TEAL_HI,'wing_primaries':TEAL}.get(reg,COPPER)
        L={'wing_primaries':9,'wing_secondaries':7,'plume':9,'hackle':7}.get(reg,6)
        feathers(t,base,tip,L=L,W=4,tip_rate=.45 if reg in ('hackle','ruff','wing_coverts') else .25)
        if reg in ('hackle','ruff'):
            # Copper-edged hackle tips on the ragged lower band.
            for y in range(h):
                for x in range(w):
                    if frac(x,y)<.20 and rng.random()<.7: t[y][x]=COPPER if rng.random()<.7 else COPPER_HI
        if reg=='plume':
            for y in range(h):
                for x in range(w):
                    if rng.random()<.12: t[y][x]=TEAL
        if lateral or front or rear: volume(t)
    elif reg=='rump':
        # Feathers end in a ragged line on the rump; serpent scales start behind it.
        scales(t,SC,SC_HI)
        if bottom: scutes(t)
        f=fill(PL); feathers(f,PL,COPPER)
        edge=[.42+rng.uniform(-.08,.08) for _ in range(max(w,h)+1)]
        for y in range(h):
            for x in range(w):
                a,b=y,x                     # rows grow away from the body (paint_up points to it)
                if y/max(1,h-1)<edge[x%len(edge)]: t[y][x]=f[y][x]
                elif y/max(1,h-1)<edge[x%len(edge)]+.05: t[y][x]=PL_DARK
        if lateral: volume(t)
    elif reg in ('neck_low','neck_high','tail','head'):
        scales(t,SC,SC_HI)
        if reg=='neck_low' and not front:
            feathers(t,PL,COPPER,L=7)          # hackle zone: feathers, throat stays scaly
        if (reg in ('neck_low','neck_high') and front) or (reg=='tail' and bottom):
            scutes(t)
        if reg=='tail' and not bottom:
            band=int(.16*DENSITY)
            for y in range(h):
                for x in range(w):
                    a,b=cell(x,y)
                    if (a//band)%2==1: t[y][x]=shade(t[y][x],-24)
            if lateral:
                for y in range(h):
                    for x in range(w):
                        if frac(x,y)<.16: t[y][x]=BELLY_SHA
            if top:
                span=w if vertical else h
                for y in range(h):
                    for x in range(w):
                        a,b=cell(x,y)
                        if abs(b-span/2)<max(1,span/7): t[y][x]=SC_DARK
        if reg=='head':
            if top: rect(t,0,0,w,h,SC_SHA); scales(t,SC_SHA,SC)
            if lateral:
                # Dark venom mask streak from the eye back along the skull (viper look).
                for y in range(h):
                    for x in range(w):
                        f=frac(x,y)
                        if .45<f<.70: t[y][x]=shade(t[y][x],-30)
        if lateral and reg!='tail': volume(t,8,10)
    elif reg=='eye':
        t=fill(SC_DARK)
        if lateral or (front and abs(n.x)>.3):
            # Glowing venom eye: orange rim, yellow-green iris, vertical slit, highlight.
            rect(t,0,0,w,h,EYE_RING); rect(t,1,1,max(1,w-2),max(1,h-2),EYE)
            rect(t,w//2,0,1,h,PUPIL); rect(t,1,1,1,1,EYE_HI)
    elif reg=='brow':
        t=fill(SC_DARK); scales(t,SC_SHA,SC_MID,S=3); rect(t,0,0,w,1,SC_MID)
    elif reg in ('tarsus','toe','foot'):
        t=fill(LEG); scales(t,LEG,shade(LEG,12),S=3)
        if reg=='toe':
            if front: t=fill(CLAW)
            else: rect(t,0,h-max(2,h//4),w,max(2,h//4),CLAW)
    elif reg=='claw':
        t=fill(CLAW); rect(t,0,0,1,h,(70,64,60))
    elif reg in ('beak','beak_tip','jaw'):
        t=fill(BEAK)
        for y in range(h):
            for x in range(w):
                if frac(x,y)<.35: t[y][x]=shade(BEAK,-26)
                if rng.random()<.08: t[y][x]=shade(t[y][x],-14)
        if reg=='beak_tip': t=fill(BEAK_DARK)
        if reg=='beak':
            rect(t,0,h-max(1,h//5),w,max(1,h//5),BEAK_DARK)           # dark horn tip half
            if bottom: t=fill(MOUTH)
        if reg=='jaw' and top: t=fill(MOUTH)
        rect(t,0,0,w,1,shade(BEAK,16))
    elif reg=='tongue':
        t=fill(TONGUE); rect(t,0,0,w,1,shade(TONGUE,24))
    elif reg=='comb':
        t=fill(COMB)
        for _ in range(max(1,w*h//10)): rect(t,rng.randrange(w),rng.randrange(h),1,2,rng.choice([COMB_SHA,COMB_HI]))
        for y in range(h):
            for x in range(w):
                if frac(x,y)>.85: t[y][x]=COMB_HI
                elif frac(x,y)<.12: t[y][x]=COMB_SHA
    elif reg=='fang':
        t=fill(FANG); rect(t,0,0,1,h,(196,186,160))
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[PL[0]/255,PL[1]/255,PL[2]/255,1]
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
image.filepath_raw=str(OUT/'basilisk_blocky_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.92
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/basilisk_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static editable rooster+serpent hybrid; no animations requested. Same metric texel density as the approved models.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'basilisk_blocky_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
