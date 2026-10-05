"""Pixel-paint metric UV islands of the Giant Spider.
Every motif is drawn at the island's real pixel size (64 px/m). Readable materials:
hard black-violet chitin with plate seams and glossy highlights (carapace), dark
abdomen, banded bristly legs with dark tips, glowing violet
eyes and glossy black fangs. The atlas is always a FRESH image
datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['spider']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
CHITIN=[(34,28,40),(42,34,48),(28,22,34)]; SEAM=(16,12,20); GLOSS=(124,108,146); SHEEN=(74,62,90)
DARK=[(28,22,32),(34,28,38)]
LEG=[(36,30,42),(42,34,48),(30,24,36)]; BAND=(70,58,78); BRISTLE=(56,46,62); TIP=(12,10,14)
EYE=(196,96,255); EYE_HI=(244,214,255); EYE_DARK=(70,26,100)
FANG=(20,16,22); FANG_HI=(96,86,104)
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
    rng=random.Random(14010+index)
    right=item['right']; up=n.cross(right)
    gx,gy=right.z,up.z
    zs=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(zs),max(zs)
    def frac(x,y): return .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    def fill(c): return [[c for _ in range(w)] for _ in range(h)]
    def pp(t,points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def noise(t,palette,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(palette,weights[:len(palette)])[0]
    def gloss(t):
        # Hard-shell read: a bright glossy streak near the top edge, darker lower rim.
        for y in range(h):
            for x in range(w):
                f=frac(x,y)
                if .78<f<.86: t[y][x]=GLOSS if rng.random()<.6 else SHEEN
                elif f<.14: t[y][x]=SEAM
    def plates(t,step):
        # Chitin plate seams across the shell.
        along_rows=abs(up.y)>abs(right.y)
        for y in range(h):
            for x in range(w):
                a=y if along_rows else x
                if a%step==step-1: t[y][x]=SEAM
                elif a%step==0: t[y][x]=shade(t[y][x],14)
    t=fill(CHITIN[0])
    if reg in ('carapace','carapace_dark'):
        noise(t,CHITIN if reg=='carapace' else DARK)
        if reg=='carapace':
            if top:
                plates(t,7)
                pp(t,[(44,0),(56,0),(53,100),(47,100)],SEAM)                      # mid-dorsal groove
                pp(t,[(30,20),(42,30),(42,36),(30,30)],SHEEN); pp(t,[(70,20),(58,30),(58,36),(70,30)],SHEEN)
            elif lateral or front or rear: gloss(t)
    elif reg=='abdomen':
        noise(t,CHITIN)
        if top or rear:
            plates(t,8)
            for _ in range(max(1,w*h//60)): rect(t,rng.randrange(w),rng.randrange(h),1,2,BRISTLE)
        elif lateral:
            gloss(t)
        elif bottom: noise(t,DARK)
    elif reg in ('leg','leg_tip','chelicera'):
        noise(t,LEG)
        for _ in range(max(1,w*h//34)): rect(t,rng.randrange(w),rng.randrange(h),1,2,BRISTLE)      # sparse bristles
        # Pale joint band near the root end of every segment (texture top = segment root).
        rect(t,0,0,w,max(1,h//10),BAND)
        if reg=='leg_tip':
            for y in range(h):
                if y>h*.78: rect(t,0,y,w,1,TIP)                                   # dark claw end
        if reg=='chelicera': rect(t,0,h-max(1,h//6),w,max(1,h//6),TIP)
        if top or lateral:
            for y in range(h):
                for x in range(w):
                    if frac(x,y)>.85 and rng.random()<.5: t[y][x]=SHEEN
    elif reg=='fang':
        t=fill(FANG); rect(t,0,0,1,h,FANG_HI)
    elif reg=='eye':
        t=fill(EYE_DARK)
        if front or top:
            rect(t,0,0,w,h,EYE); rect(t,1,1,max(1,w//3),max(1,h//3),EYE_HI)
            rect(t,0,h-1,w,1,EYE_DARK)
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[CHITIN[0][0]/255,CHITIN[0][1]/255,CHITIN[0][2]/255,1]
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
image.filepath_raw=str(OUT/'giant_spider_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.80
    bsdf.inputs['Specular IOR Level'].default_value=.20
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
report={'name':NAME,'pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/spider_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'length_m':max(v.y for v in coordinates)-min(v.y for v in coordinates),
 'width_m':max(v.x for v in coordinates)-min(v.x for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Giant spider; 8 two-segment legs. Same metric texel density as the approved models.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'giant_spider_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={k:report[k] for k in ('height_m','length_m','width_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
