"""Pixel-paint metric UV islands and save an editable, static Goblin source."""
import bpy
import bmesh
import json
import math
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['goblin_raider']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']
OUT=Path(st['out']); SOURCE=Path(st['source'])
BASE=(85,114,60); MID=(101,132,68); HI=(124,151,82); SHA=(58,82,42); DARK=(35,52,30)
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
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; n=item['normal']; front=n.y<-.5
    colors={'rag':(91,62,38),'belt':(52,37,25),'wrap':(150,125,79),
      'boot':(58,46,30),'pouch':(128,91,49),'pouch_flap':(153,111,60),
      'gold':(211,163,42),'blade':(106,118,111),'iron':(55,60,52),
      'brow':(46,66,34),'bone':(219,211,168),'mouth':(31,36,25)}
    color=colors.get(reg,BASE); t=[[color for _ in range(w)] for _ in range(h)]
    rng=random.Random(610+index)
    def rp(x,y,ww,hh,c): rect(t,x*w/100,y*h/100,ww*w/100,hh*h/100,c)
    def pp(points,c): polygon(t,[(x*w/100,y*h/100) for x,y in points],c)
    def sym(points,c): pp(points,c); pp([(100-x,y) for x,y in points],c)
    if reg in ('skin','chest','abdomen','limb','face','nose','jaw','ear','hand'):
        for _ in range(max(1,w*h//45)):
            rect(t,rng.randrange(w),rng.randrange(h),rng.choice([1,2]),1,
                 rng.choice([(81,108,56),(93,121,63),(76,105,52)]))
    if reg=='face' and front:
        sym([(5,14),(21,12),(43,24),(43,31),(23,23),(8,24)],MID)
        sym([(4,37),(18,37),(43,42),(43,60),(8,60)],DARK)
        sym([(9,46),(36,47),(38,55),(10,55)],(203,184,51))
        sym([(10,47),(23,47),(23,51),(10,51)],(245,220,90))
        rp(28,47,5,9,DARK); rp(67,47,5,9,DARK)
        sym([(6,65),(30,66),(38,75),(32,86),(11,84),(6,78)],MID)
        sym([(9,84),(27,87),(32,85),(31,91),(13,90)],SHA)
    elif reg=='ear' and front:
        pp([(9,29),(16,14),(89,17),(47,61),(23,88),(11,80)],(128,112,60))
        pp([(24,33),(65,23),(38,58),(24,70)],(156,133,70))
    elif reg=='nose':
        if abs(n.x)>.6:
            pp([(3,6),(29,8),(78,67),(91,95),(67,83),(15,26)],MID)
        elif n.z>.2: rp(12,7,23,80,HI)
    elif reg=='chest' and front:
        sym([(7,15),(20,9),(43,20),(46,63),(35,76),(13,71),(6,51)],MID)
        sym([(10,60),(23,72),(42,70),(46,64),(46,76),(34,80),(13,76)],SHA)
        rp(48,20,4,50,SHA)
    elif reg=='abdomen' and front:
        rp(24,12,19,60,MID); rp(57,12,19,60,MID); rp(48,8,4,70,SHA)
    elif reg=='limb' and front:
        pp([(18,8),(68,8),(78,23),(73,81),(50,93),(25,83),(18,50)],MID)
        rp(23,14,12,46,HI)
    elif reg=='hand':
        if front: rect(t,1,1,max(1,w-2),1,MID)
    elif reg in ('rag','pouch','pouch_flap','boot'):
        dark=tuple(max(0,c-18) for c in color); light=tuple(min(255,c+13) for c in color)
        pp([(0,0),(18,0),(24,50),(14,100),(0,100)],dark)
        pp([(25,0),(69,0),(77,31),(60,89),(31,96)],light)
        if reg=='rag':
            pp([(57,54),(88,58),(82,89),(52,85)],(119,87,49))
            for y in range(round(h*.59),round(h*.85),3): rect(t,round(w*.54),y,2,1,(165,138,80))
        if reg in ('pouch','pouch_flap') and front:
            for x in range(2,max(2,w-1),3): rect(t,x,h-2,1,1,(194,158,96))
    elif reg in ('belt','wrap'):
        rect(t,0,0,w,1,tuple(min(255,c+20) for c in color))
        if reg=='wrap' and h>3: rect(t,0,h//2,w,1,(116,96,60))
    elif reg=='blade':
        rect(t,0,0,1,h,(174,184,163)); rect(t,max(0,w-2),0,2,h,(75,87,80))
        if w>4 and h>6: rect(t,w//2,h//3,1,2,(132,90,50))
    elif reg=='gold':
        rect(t,0,0,w,1,(251,222,104)); rect(t,0,1,1,max(1,h-1),(251,222,104))
        rect(t,max(0,w-1),1,1,h,(137,98,20))
    elif reg=='bone': rect(t,0,0,1,h,(167,166,129))
    elif reg=='brow': rect(t,0,0,w,1,(60,82,44))
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BASE[0]/255,BASE[1]/255,BASE[2]/255,1]
for index,item in enumerate(islands):
    t=paint(item,index); w,h=item['w'],item['h']; ox,oy=item['x'],item['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            color=t[h-1-max(0,min(h-1,y))][max(0,min(w-1,x))]
            k=((oy+y)*SIZE+ox+x)*4; pixels[k:k+4]=[c/255 for c in color]+[1]
image=bpy.data.images.new(NAME+'_PixelAtlas',width=SIZE,height=SIZE,alpha=True)
image.colorspace_settings.name='sRGB'; image.pixels.foreach_set(pixels)
image.filepath_raw=str(OUT/'goblin_raider_v3_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.93
bsdf.inputs['Specular IOR Level'].default_value=.12
node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image; node.interpolation='Closest'; node.extension='EXTEND'
mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(mat)
    obj.data.uv_layers.new(name='Metric_Pixel_UV')
for item in islands:
    me=item['obj'].data; uv=me.uv_layers.active.data
    for li,co in zip(me.polygons[item['polygon']].loop_indices,item['coords']):
        uv[li].uv=((item['x']+co.x*DENSITY)/SIZE,(item['y']+co.y*DENSITY)/SIZE)

# A single root at the feet, all named components retained for direct adjustment.
root=bpy.data.objects.new(NAME+'_ROOT',None); scene.collection.objects.link(root)
root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.09
for obj in parts: obj.parent=root
density=[]; triangles=0; nonmanifold=0
for obj in parts:
    me=obj.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles)
    bm=bmesh.new(); bm.from_mesh(me); nonmanifold+=sum(not e.is_manifold for e in bm.edges); bm.free()
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons)
    assert not obj.modifiers and obj.animation_data is None
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-7: density.append((me.uv_layers.active.data[li].uv-me.uv_layers.active.data[lj].uv).length*SIZE/length)
assert nonmanifold==0
assert max(abs(d-DENSITY) for d in density)<.03
coordinates=[v.co for o in parts for v in o.data.vertices]
height=max(v.z for v in coordinates)-min(v.z for v in coordinates)
assert abs(height-1.3)<.001
report={'name':NAME,'pipeline':'Blender MCP localhost:9876','height_m':height,'triangles':triangles,
 'editable_parts':len(parts),'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'notes':'Static editable model; no animations requested. Same metric texel density as approved Troll.',
 'visual_review':'pending renders'}
st['report']=report
(OUT/'goblin_raider_v3_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True); bpy.context.view_layer.objects.active=root
bpy.data.libraries.write(str(SOURCE/'goblin_raider_v3.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
