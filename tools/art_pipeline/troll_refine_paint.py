"""Paint uniquely packed, physically proportioned UV islands in Blender."""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector

state=bpy.app.driver_namespace['troll_refinement']
scene=state['scene']; parts=state['parts']; islands=state['islands']; NAME=state['name']
OUT=Path(state['out']); SOURCE=Path(state['source']); SIZE=512; DENSITY=64; PAD=2
BASE=(57,79,83); MID=(69,94,95); HI=(84,108,105); SHA=(43,62,68); DARK=(28,42,48)
pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BASE[0]/255,BASE[1]/255,BASE[2]/255,1]

def rectangle(t,x,y,w,h,c):
    for yy in range(max(0,round(y)),min(len(t),round(y+h))):
        for xx in range(max(0,round(x)),min(len(t[0]),round(x+w))): t[yy][xx]=c
def polygon(t,points,c):
    points=[(round(x),round(y)) for x,y in points]
    for y in range(max(0,min(p[1] for p in points)),min(len(t),max(p[1] for p in points)+1)):
        for x in range(max(0,min(p[0] for p in points)),min(len(t[0]),max(p[0] for p in points)+1)):
            inside=False; j=len(points)-1
            for i in range(len(points)):
                ax,ay=points[i]; bx,by=points[j]
                if ((ay>y+.5)!=(by>y+.5)) and x+.5<(bx-ax)*(y+.5-ay)/(by-ay)+ax: inside=not inside
                j=i
            if inside: t[y][x]=c

def paint(island,index):
    w,h=island['w'],island['h']; reg=island['region']; normal=island['normal']; part=island['part']
    c=BASE
    if reg=='hide': c=(75,52,36)
    if reg=='wood': c=(84,57,34)
    if reg=='endgrain': c=(148,112,65)
    if reg=='belt': c=(47,36,28)
    if reg=='bone': c=(196,185,148)
    if reg in ('brow','iron'): c=(37,53,59)
    if reg=='mouth': c=(23,31,34)
    t=[[c for _ in range(w)] for _ in range(h)]
    rng=random.Random(840+index)
    # One actual texel is always the same physical size. All these motifs are
    # drawn directly at the dimensions of this face, never bitmap-resized.
    def rect(x,y,ww,hh,color): rectangle(t,x*w/100,y*h/100,ww*w/100,hh*h/100,color)
    def poly(points,color): polygon(t,[(x*w/100,y*h/100) for x,y in points],color)
    def sym(points,color):
        poly(points,color); poly([(100-x,y) for x,y in points],color)
    if reg in ('skin','shoulder','upper_arm','forearm','thigh','shin','hand','foot','face','nose','jaw','chest','abdomen','ear','back'):
        for _ in range(max(1,w*h//50)):
            x=rng.randrange(w); y=rng.randrange(h)
            rectangle(t,x,y,rng.choice([1,2,3]),rng.choice([1,2]),rng.choice([(61,84,87),(53,75,80),(65,88,89)]))
    front=normal.y<-.55
    rear=normal.y>.55
    if reg=='chest' and front:
        sym([(3,12),(16,8),(37,14),(46,24),(46,69),(39,77),(12,72),(3,60)],MID)
        sym([(7,16),(18,13),(37,20),(42,28),(42,35),(27,27),(11,27)],HI)
        sym([(5,69),(18,76),(39,79),(47,71),(47,78),(37,85),(16,81),(5,76)],SHA)
        rect(48,24,4,59,SHA)
        poly([(72,27),(75,27),(75,39),(79,39),(79,51),(82,51),(82,60),(78,60),(74,48),(74,41),(72,39)],(122,132,117))
    elif reg=='chest' and rear:
        sym([(4,8),(20,5),(44,23),(44,59),(31,73),(12,58),(4,35)],MID)
        sym([(10,12),(20,10),(40,23),(40,31),(21,18),(10,25)],HI)
        sym([(11,58),(31,68),(44,57),(44,67),(31,79),(15,68)],SHA)
        rect(48,9,4,81,SHA)
    elif reg=='abdomen' and front:
        for y in (5,36,67):
            sym([(27,y),(43,y),(47,y+5),(47,y+22),(38,y+25),(28,y+21)],MID)
            sym([(28,y+22),(41,y+24),(47,y+19),(47,y+25),(38,y+29),(28,y+26)],SHA)
        rect(49,3,2,91,SHA)
    elif reg in ('upper_arm','forearm','thigh','shin','shoulder') and front:
        if reg=='shoulder':
            poly([(10,12),(82,12),(90,25),(86,85),(15,86),(10,70)],MID)
            rect(14,16,63,5,HI); rect(14,21,5,30,HI)
        elif reg=='forearm':
            poly([(15,11),(39,6),(72,10),(81,27),(73,66),(60,93),(33,93),(21,63)],MID)
            poly([(26,18),(35,14),(40,23),(37,55),(31,78),(27,66)],HI)
            poly([(61,26),(68,26),(65,54),(56,78),(51,78),(55,49)],HI)
        else:
            poly([(17,9),(67,8),(80,24),(74,82),(60,94),(29,86),(17,62)],MID)
            rect(22,14,8,44,HI)
    elif reg=='face' and front:
        sym([(6,10),(21,7),(42,18),(45,24),(31,19),(9,20)],MID)
        sym([(5,37),(16,37),(42,42),(42,59),(7,59),(4,54)],DARK)
        sym([(11,46),(37,48),(39,55),(11,54)],(169,157,48))
        sym([(12,47),(27,48),(27,52),(12,51)],(224,205,79))
        rect(27,48,5,8,DARK); rect(68,48,5,8,DARK)
        sym([(6,64),(31,65),(38,72),(33,84),(10,80),(6,76)],MID)
    elif reg=='ear' and front:
        poly([(10,22),(23,13),(85,25),(35,75),(13,76)],(114,92,71))
        poly([(20,27),(67,28),(33,61),(23,66)],(139,109,77))
    elif reg=='hand':
        # Solid hands: no knuckle tiles, finger lines or grid-like markings.
        if front: rect(10,10,80,5,(67,90,92))
    elif reg=='hide':
        poly([(0,0),(19,0),(26,48),(18,100),(0,100)],(52,38,29))
        poly([(27,0),(59,0),(68,30),(57,73),(35,96),(29,96)],(94,67,43))
        poly([(76,0),(100,0),(100,100),(71,100),(74,66),(84,37)],(58,42,31))
        if part in ('HideFront','HideBack') and (front or rear):
            poly([(56,55),(84,59),(76,88),(52,81)],(111,81,52))
            # Single-pixel stitches have the same physical thickness everywhere.
            for y in range(round(h*.58),round(h*.83),4): rectangle(t,round(w*.53),y,3,1,(157,134,87))
    elif reg=='wood':
        for x in range(0,w,6):
            rectangle(t,x,0,2,h,(48,36,26))
            rectangle(t,x+2,0,2,h,(109,77,42))
            if h>6: rectangle(t,x+3,rng.randrange(max(1,h//3)),1,max(2,h//3),(132,96,52))
        for _ in range(max(1,w*h//140)):
            rectangle(t,rng.randrange(w),rng.randrange(h),2,3,(62,44,29))
    elif reg=='endgrain':
        for n in range(2,min(w,h)//2,4):
            rectangle(t,n,n,w-2*n,1,(101,78,45)); rectangle(t,n,h-n-1,w-2*n,1,(101,78,45))
            rectangle(t,n,n,1,h-2*n,(101,78,45)); rectangle(t,w-n-1,n,1,h-2*n,(101,78,45))
    elif reg=='bone':
        rectangle(t,0,0,max(1,w//5),h,(172,165,137))
        rectangle(t,max(1,w-2),0,2,h,(223,214,178))
    elif reg=='belt':
        rectangle(t,0,0,w,1,(83,60,39))
        if part=='Belt':
            for x in range(3,w,7): rectangle(t,x,1,2,1,(147,125,84))
    elif reg in ('brow','iron'):
        rectangle(t,0,0,w,1,(58,77,79)); rectangle(t,0,max(0,h-1),w,1,(25,38,44))
    return t

for index,island in enumerate(islands):
    t=paint(island,index); w,h=island['w'],island['h']; ox,oy=island['x'],island['y']
    # Edge dilation protects the island when mip levels are generated by engine.
    for py in range(-PAD,h+PAD):
        for px in range(-PAD,w+PAD):
            c=t[h-1-max(0,min(h-1,py))][max(0,min(w-1,px))]
            i=((oy+py)*SIZE+ox+px)*4
            pixels[i:i+4]=[n/255 for n in c]+[1.0]
atlas=bpy.data.images.new(NAME+'_MetricPixelAtlas512',width=SIZE,height=SIZE,alpha=True)
atlas.colorspace_settings.name='sRGB'; atlas.pixels.foreach_set(pixels)
atlas.filepath_raw=str(OUT/'troll_blocky_v3_atlas.png'); atlas.file_format='PNG'; atlas.save(); atlas.pack()
mat=bpy.data.materials.new(NAME+'_PixelArt_MAT'); mat.use_nodes=True
shader=mat.node_tree.nodes.get('Principled BSDF'); shader.inputs['Roughness'].default_value=.95
shader.inputs['Specular IOR Level'].default_value=.1
tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=atlas; tex.interpolation='Closest'; tex.extension='EXTEND'
mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
for obj in parts.objects:
    obj.data.materials.clear(); obj.data.materials.append(mat)
    obj.data.uv_layers.new(name='Metric_Pixel_UV')
for island in islands:
    me=island['obj'].data; uv=me.uv_layers.active.data; p=me.polygons[island['polygon']]
    for li,co in zip(p.loop_indices,island['coords']):
        uv[li].uv=((island['x']+co.x*DENSITY)/SIZE,(island['y']+co.y*DENSITY)/SIZE)

# Verify metric equality for EVERY edge on EVERY face, not just atlas area.
densities=[]
for obj in parts.objects:
    me=obj.data; uv=me.uv_layers.active.data
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            world=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if world>1e-7: densities.append((uv[li].uv-uv[lj].uv).length*SIZE/world)
assert max(abs(d-DENSITY) for d in densities)<.03
report={'name':NAME,'revision':'specific fit corrections + metric UV + three gameplay clips',
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','materials':1,'islands':len(islands),
            'target_px_per_meter':DENSITY,'measured_min':min(densities),'measured_max':max(densities),
            'max_relative_error':max(abs(d-DENSITY)/DENSITY for d in densities),'padding_pixels':PAD,
            'method':'orthonormal projection at exact scale; non-overlapping unique islands; face-sized painting'},
 'geometry_corrections':scene['refinement_notes'],'height_m':2.5,'status':'geometry and UV verified; animation pending'}
state['report']=report; state['material']=mat
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'troll_blocky_v3_refinement_work.blend'))
result={'uv_validation':report['texture'],'geometry_parts':len(parts.objects)}
