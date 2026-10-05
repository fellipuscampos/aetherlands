"""Pixel-paint metric UV islands of the static Minotaur and save its sources.
Every motif is drawn directly at the island's real pixel size (64 px/m),
never a square swatch resized to fit.
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['minotaur_blocky']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
# Reddish-brown bull fur, five shade ramp like the Troll's teal ramp.
BASE=(116,62,44); MID=(136,77,53); HI=(160,96,64); SHA=(90,47,35); DARK=(62,32,26)
SPECK=[(108,57,41),(125,69,49),(100,52,38)]
FUR=('chest','abdomen','hump','shoulder','upper_arm','forearm','thigh','shin','skin','head','hand','tail','ear')
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
    front=n.y<-.5; rear=n.y>.5; top=n.z>.6; bottom=n.z<-.6
    colors={'cloth':(128,34,44),'belt':(66,44,30),'wrap':(84,57,37),'iron':(102,106,110),'iron_dark':(70,73,78),
      'hoof':(56,51,53),'horn':(214,203,174),'blade':(118,124,130),'wood':(92,62,38),
      'fur_dark':(70,37,29),'brow':(74,39,30),'muzzle':(128,82,62),'jaw':(118,74,56)}
    color=colors.get(reg,BASE); t=[[color for _ in range(w)] for _ in range(h)]
    rng=random.Random(1310+index)
    def rp(x,y,ww,hh,c): rect(t,x*w/100,y*h/100,ww*w/100,hh*h/100,c)
    def pp(points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def sym(points,c): pp(points,c); pp([(100-x,y) for x,y in points],c)
    if reg in FUR or reg in ('fur_dark','muzzle','jaw','brow'):
        # Speckles plus short vertical fur strokes, one physical pixel wide.
        base=color
        for _ in range(max(1,w*h//40)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),1,
                 shade(base,rng.choice([-8,6,-14])) if reg not in FUR else rng.choice(SPECK))
        for _ in range(max(1,w*h//90)):
            rect(t,rng.randrange(w),rng.randrange(h),1,2,shade(base,-22))
    if reg=='chest' and front:
        sym([(3,10),(17,6),(40,13),(46,22),(46,66),(38,76),(11,71),(3,58)],MID)
        sym([(7,14),(19,11),(38,18),(42,27),(42,33),(26,25),(10,25)],HI)
        sym([(5,67),(18,75),(39,79),(47,70),(47,78),(37,86),(15,81),(5,75)],SHA)
        rp(48,22,4,62,SHA)
        # Darker chest-hair diamond between the pectorals.
        pp([(50,20),(60,34),(56,58),(50,72),(44,58),(40,34)],SHA)
        for k in range(6): rect(t,round(w*(.45+.02*(k%3))),round(h*(.30+.07*k)),1,2,DARK)
    elif reg in ('chest','hump') and (rear or top):
        # Dark bull mane across the hump and upper back, fading downwards.
        pp([(0,0),(100,0),(100,38),(84,52),(64,44),(50,58),(34,45),(16,54),(0,40)],SHA)
        for _ in range(max(1,w*h//25)):
            x=rng.randrange(w); y=rng.randrange(max(1,int(h*.5))); rect(t,x,y,1,rng.choice([2,3]),DARK)
        if reg=='chest': rp(48,8,4,84,SHA)
    elif reg=='hump' and front:
        rp(0,0,100,100,SHA)
        for _ in range(max(1,w*h//20)): rect(t,rng.randrange(w),rng.randrange(h),1,2,DARK)
    elif reg=='abdomen' and front:
        for y in (6,38,70):
            sym([(27,y),(43,y),(47,y+5),(47,y+20),(38,y+23),(28,y+19)],MID)
            sym([(28,y+20),(41,y+22),(47,y+18),(47,y+24),(38,y+28),(28,y+25)],SHA)
        rp(49,3,2,94,SHA)
    elif reg in ('upper_arm','forearm','thigh','shin','shoulder') and (front or (reg=='shoulder' and top)):
        if reg=='shoulder':
            pp([(10,12),(82,12),(90,25),(86,85),(15,86),(10,70)],MID)
            rp(14,16,63,6,HI); rp(14,22,6,30,HI)
        elif reg=='forearm':
            pp([(15,11),(39,6),(72,10),(81,27),(73,66),(60,93),(33,93),(21,63)],MID)
            pp([(26,18),(35,14),(40,23),(37,55),(31,78),(27,66)],HI)
            pp([(61,26),(68,26),(65,54),(56,78),(51,78),(55,49)],HI)
        else:
            pp([(17,9),(67,8),(80,24),(74,82),(60,94),(29,86),(17,62)],MID)
            rp(22,14,8,44,HI)
    elif reg in ('upper_arm','forearm','thigh','shin') and rear:
        rp(0,0,100,28,SHA)
    elif reg=='head' and front:
        # Curly forehead tuft, heavy dark brow shadow, glowing red eyes.
        for _ in range(max(1,w*h//18)):
            x=rng.randrange(w); y=rng.randrange(max(1,int(h*.22))); rect(t,x,y,2,2,rng.choice([SHA,DARK,MID]))
        sym([(4,22),(18,22),(44,28),(44,46),(6,46),(3,38)],DARK)
        sym([(9,30),(36,33),(38,42),(10,41)],(196,36,30))
        sym([(10,31),(22,32),(22,37),(10,36)],(255,96,58))
        rp(29,32,4,10,DARK); rp(67,32,4,10,DARK)
        sym([(4,48),(22,48),(30,58),(8,60)],MID)
    elif reg=='head' and abs(n.x)>.6:
        # Red glint near the front edge so the eyes still read in 3/4 views.
        pp([(0,0),(100,0),(100,20),(0,26)],SHA)
    elif reg=='head' and top:
        for _ in range(max(1,w*h//14)): rect(t,rng.randrange(w),rng.randrange(h),2,2,rng.choice([SHA,DARK]))
    elif reg=='muzzle':
        if front:
            rp(0,0,100,18,shade(color,14))
            sym([(14,30),(32,30),(34,52),(16,52)],(46,25,22))
            sym([(16,32),(26,32),(26,40),(16,40)],(28,15,14))
            sym([(10,24),(36,24),(38,30),(12,30)],(150,104,82))
            rp(0,86,100,14,(48,27,23))
        elif top: rp(18,0,64,100,shade(color,12))
        elif abs(n.x)>.6: rp(0,82,100,18,(48,27,23))
    elif reg=='jaw':
        if front or abs(n.x)>.6: rp(0,0,100,24,(52,30,25))
    elif reg=='ear' and (front or rear):
        pp([(10,25),(88,30),(80,75),(14,72)],(150,96,84))
        pp([(20,35),(70,38),(64,62),(22,60)],(170,114,98))
    elif reg=='hand':
        if front: rect(t,1,1,max(1,w-2),1,MID)
    elif reg=='horn':
        seg=obj.get('horn_segment',0)
        ramp=[(184,170,138),(206,195,165),(224,215,189),(236,230,208)]
        base=ramp[seg]; t=[[base for _ in range(w)] for _ in range(h)]
        rect(t,0,0,1,h,shade(base,-26)); rect(t,max(0,w-1),0,1,h,shade(base,14))
        for y in range(2,h,5): rect(t,1,y,max(1,w-2),1,shade(base,-18))
        if seg==3: rect(t,0,h-max(2,h//3),w,max(2,h//3),(92,84,76))
        if seg==0: rect(t,0,0,w,max(1,h//4),(150,136,108))
    elif reg=='hoof':
        rect(t,0,0,w,1,(84,78,80))
        if front:
            rect(t,w//2,0,1,h,(26,24,26)); rect(t,1,1,1,max(1,h-2),(88,82,84))
            rect(t,w//2+2,1,1,max(1,h-2),(80,74,76))
    elif reg=='cloth':
        dark=(96,24,34); light=(154,54,62)
        for _ in range(max(1,w*h//10)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),rng.choice([1,2]),rng.choice([dark,light,(140,44,52)]))
        pp([(0,0),(14,0),(20,55),(12,100),(0,100)],dark)
        pp([(30,0),(58,0),(66,40),(54,86),(36,94)],light)
        rp(0,88,100,12,(84,20,30))
        if part=='LoinFront' and front:
            # Faded hand-painted bull-horn mark on the front flap.
            pp([(30,26),(40,40),(60,40),(70,26),(66,44),(50,52),(34,44)],(196,160,120))
    elif reg=='belt':
        rect(t,0,0,w,1,shade(color,22)); rect(t,0,max(0,h-1),w,1,shade(color,-18))
        if h>4:
            for x in range(3,w,6): rect(t,x,h//2,2,1,(150,124,82))
    elif reg=='wrap':
        rect(t,0,0,w,1,shade(color,24)); rect(t,0,max(0,h-1),w,1,shade(color,-20))
    elif reg in ('iron','iron_dark'):
        rect(t,0,0,w,1,shade(color,42)); rect(t,0,max(0,h-1),w,1,shade(color,-34))
        if w>6 and h>3:
            for x in range(2,w-1,6): rect(t,x,h//2,1,1,shade(color,60))
        for _ in range(max(0,w*h//60)): rect(t,rng.randrange(w),rng.randrange(h),1,1,(118,80,56))
    elif reg=='blade':
        for _ in range(max(1,w*h//30)): rect(t,rng.randrange(w),rng.randrange(h),1,1,shade(color,rng.choice([-10,8])))
        broad='edge_dir' in obj and abs(n.dot(Vector(obj['paint_up']).cross(Vector(obj['edge_dir']))))>.9
        if broad and w>8:
            # Bright honed edge on the outer side of each bit, darker towards the socket.
            outward=item['right'].dot(Vector(obj['edge_dir']))>0
            ex=w-5 if outward else 0; ix=0 if outward else w-4
            rect(t,ex,0,5,h,(176,182,186)); rect(t,ex+(4 if outward else 0),0,1,h,(204,209,212))
            rect(t,ix,0,4,h,(108,112,118))
            for k in range(3): rect(t,ex+(1 if outward else 2),rng.randrange(h),2,1,(120,124,128))
    elif reg=='wood':
        for x in range(0,w,4):
            rect(t,x,0,1,h,(66,44,28))
            if h>6: rect(t,x+2,rng.randrange(max(1,h//2)),1,max(2,h//3),(118,82,48))
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BASE[0]/255,BASE[1]/255,BASE[2]/255,1]
for index,item in enumerate(islands):
    t=paint(item,index); w,h=item['w'],item['h']; ox,oy=item['x'],item['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            color=t[h-1-max(0,min(h-1,y))][max(0,min(w-1,x))]
            k=((oy+y)*SIZE+ox+x)*4; pixels[k:k+4]=[c/255 for c in color]+[1]
# Always a fresh datablock: editing pixels of an already-packed image and calling
# pack() keeps the OLD packed bytes, so saved .blend/GLB files got a stale atlas.
stale=bpy.data.images.get(NAME+'_PixelAtlas')
if stale: bpy.data.images.remove(stale)
image=bpy.data.images.new(NAME+'_PixelAtlas',width=SIZE,height=SIZE,alpha=True)
image.colorspace_settings.name='sRGB'; image.pixels.foreach_set(pixels)
image.filepath_raw=str(OUT/'minotaur_blocky_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.93
    bsdf.inputs['Specular IOR Level'].default_value=.12
    node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image; node.interpolation='Closest'; node.extension='EXTEND'
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

# One root at the feet; every named component stays separate and editable.
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
height=max(v.z for v in coordinates)-min(v.z for v in coordinates)
head_top=max(v.co.z for o in parts if o['part']=='Head' for v in o.data.vertices)
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/minotaur_blocky_*.py)',
 'height_m':height,'head_top_m':head_top,'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'notes':'Static editable model; no animations requested. Same metric texel density as approved Troll and Goblin V3.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'minotaur_blocky_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
