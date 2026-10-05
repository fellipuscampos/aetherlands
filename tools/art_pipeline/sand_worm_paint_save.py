"""Pixel-paint metric UV islands of the static Sand Worm V1 (Scolopendra-like colours).
Every motif is drawn at the island's real pixel size (64 px/m). Readable materials:
black-blue head + collar, rust-red body rings (dark rear band on each tergite, cream
belly), amber legs/antennae with black claw tips, dark venom fangs. Stripes follow each
part's own body axis (read from the cuboid's vertices), not the UV orientation. The atlas
is always a FRESH image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['sand_worm']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; DENSITY=st['density']; islands=st['islands']; OUT=Path(st['out'])
HEAD=[(30,28,33),(38,36,43),(24,22,27)]; HEAD_HI=(78,74,90); HEAD_DARK=(12,11,14)
BODY=[(142,46,30),(156,54,34),(130,40,28)]; BODY_HI=(198,98,56); BODY_DARK=(92,26,20); SEAM=(58,18,14)
BELLY=[(214,168,104),(204,156,94),(224,180,116)]; BELLY_LINE=(170,122,72)
LEG=[(232,170,46),(220,156,38),(240,184,62)]; LEG_DARK=(150,92,24); CLAW=(32,22,18)
FANG=(92,30,26); FANG_TIP=(22,16,18); FANG_HI=(150,70,52)
MOUTH=(124,26,32); MOUTH_DARK=(80,14,20); TOOTH=(238,230,212)
EYE=(255,198,40); EYE_HI=(255,240,150); EYE_RIM=(70,40,10); PUPIL=(10,8,6)
def rect(t,x,y,w,h,c):
    for yy in range(max(0,round(y)),min(len(t),round(y+h))):
        for xx in range(max(0,round(x)),min(len(t[0]),round(x+w))): t[yy][xx]=c
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def axes(obj):
    # fbox/beam vertex order: index = z*4 + y*2 + x  ->  v1-v0 = lateral, v2-v0 = along, v4-v0 = up (fbox)
    v=obj.data.vertices; lat=(v[1].co-v[0].co).normalized(); along=(v[2].co-v[0].co).normalized()
    up=(v[4].co-v[0].co).normalized()
    return lat,along,up
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; n=item['normal']
    rng=random.Random(4410+index)
    right=item['right']; up=n.cross(right)
    lat,along,dorsal=axes(obj)
    if reg in ('leg','leg_tip','fang','fang_tip','antenna','antenna_tip','cercus'): along=dorsal  # beams: v4-v0 runs along the beam
    def frac_dir(D):
        gx,gy=right.dot(D),up.dot(D)
        vals=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(vals),max(vals)
        return lambda x,y: .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    fa=frac_dir(along); fu=frac_dir(dorsal); fl=frac_dir(lat)
    on_top=n.dot(dorsal)>.6; on_bottom=n.dot(dorsal)<-.6; on_end=abs(n.dot(along))>.6
    def fill(c): return [[c for _ in range(w)] for _ in range(h)]
    def noise(t,palette,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(palette,weights)[0]
    def each(t,fn):
        for y in range(h):
            for x in range(w):
                c=fn(x,y,t[y][x])
                if c is not None: t[y][x]=c
    t=fill(BODY[0])
    if reg in ('segment','collar'):
        pal=HEAD if reg=='collar' else BODY
        noise(t,pal)
        if on_bottom:
            noise(t,BELLY); each(t,lambda x,y,c: BELLY_LINE if fa(x,y)<.12 or fa(x,y)>.9 else None)
        elif on_end: t=fill(SEAM if reg=='segment' else HEAD_DARK)
        else:
            each(t,lambda x,y,c: rng.choices(BELLY,(5,3,2))[0] if fu(x,y)<.28 else (shade(c,-26) if fu(x,y)>.78 else None))
            each(t,lambda x,y,c: SEAM if fa(x,y)<.06 else None)
    elif reg in ('tergite','collar_plate'):
        pal=HEAD if reg=='collar_plate' else BODY; hi=HEAD_HI if reg=='collar_plate' else BODY_HI
        dark=HEAD_DARK if reg=='collar_plate' else BODY_DARK
        noise(t,pal)
        if on_top:
            # Rear dark band, bright leading edge, thin dark median line and pale side rims.
            each(t,lambda x,y,c: dark if fa(x,y)<.22 else (hi if fa(x,y)>.9 else None))
            each(t,lambda x,y,c: shade(c,-22) if abs(fl(x,y)-.5)<.05 else None)
            each(t,lambda x,y,c: shade(c,14) if (fl(x,y)<.06 or fl(x,y)>.94) and fa(x,y)>=.22 else None)
        elif on_bottom: t=fill(dark)
        else: each(t,lambda x,y,c: dark if fu(x,y)<.35 else (hi if fu(x,y)>.85 else None))
    elif reg in ('leg','cercus','leg_tip','antenna','antenna_tip'):
        noise(t,LEG)
        if reg=='leg': each(t,lambda x,y,c: LEG_DARK if fa(x,y)<.18 else None)
        if reg in ('leg_tip','cercus'): each(t,lambda x,y,c: CLAW if fa(x,y)>.72 else (LEG_DARK if fa(x,y)>.62 else None))
        if reg=='antenna': each(t,lambda x,y,c: LEG_DARK if int(fa(x,y)*8)%2==1 and fa(x,y)>.2 else None)
        if reg=='antenna_tip': each(t,lambda x,y,c: CLAW if fa(x,y)>.6 else (LEG_DARK if int(fa(x,y)*6)%2==1 else None))
    elif reg in ('skull','claw_base','brow'):
        noise(t,HEAD)
        if on_top and reg=='skull':
            each(t,lambda x,y,c: HEAD_HI if fa(x,y)>.93 else (shade(c,-10) if abs(fl(x,y)-.5)<.03 else None))
        elif reg=='skull' and not on_bottom and not on_end:
            each(t,lambda x,y,c: HEAD_DARK if fu(x,y)<.3 else (HEAD_HI if fu(x,y)>.94 else None))
        if reg=='brow': each(t,lambda x,y,c: HEAD_HI if on_top and fa(x,y)>.75 else HEAD_DARK)
        if on_bottom: t=fill(HEAD_DARK)
    elif reg=='head_plate':
        noise(t,[shade(c,10) for c in HEAD])
        if on_top:
            each(t,lambda x,y,c: HEAD_HI if fl(x,y)<.05 or fl(x,y)>.95 or fa(x,y)>.94 else (HEAD_DARK if fa(x,y)<.08 else None))
            each(t,lambda x,y,c: HEAD_DARK if abs(fl(x,y)-.5)<.04 and fa(x,y)<.7 else None)
    elif reg=='clypeus':
        noise(t,[FANG,shade(FANG,8),shade(FANG,-8)])
        each(t,lambda x,y,c: HEAD_DARK if fu(x,y)<.2 else None)
    elif reg=='mouth':
        noise(t,[MOUTH,MOUTH_DARK],(3,2))
    elif reg=='tooth':
        t=fill(TOOTH); rect(t,0,0,1,h,shade(TOOTH,-26))
    elif reg=='fang':
        noise(t,[FANG,shade(FANG,10),shade(FANG,-10)])
        each(t,lambda x,y,c: FANG_HI if fu(x,y)>.85 else None)
    elif reg=='fang_tip':
        t=fill(FANG_TIP); each(t,lambda x,y,c: FANG if fa(x,y)<.25 else (shade(FANG_TIP,30) if fu(x,y)>.8 else None))
    elif reg=='eye':
        t=fill(EYE_RIM)
        if on_top:
            rect(t,1,1,max(1,w-2),max(1,h-2),EYE); rect(t,1,1,max(1,(w-2)//3),max(1,(h-2)//3),EYE_HI)
            each(t,lambda x,y,c: PUPIL if abs(fl(x,y)-.5)<.12 and .2<fa(x,y)<.8 else None)
    return t

pixels=[0.0]*(SIZE*SIZE*4)
for i in range(0,len(pixels),4): pixels[i:i+4]=[BODY[0][0]/255,BODY[0][1]/255,BODY[0][2]/255,1]
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
image.filepath_raw=str(OUT/'sand_worm_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.88
    bsdf.inputs['Specular IOR Level'].default_value=.14
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
report={'name':NAME,'kind':'colossal_worm','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/sand_worm_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'front_y_m':min(v.y for v in coordinates),'back_y_m':max(v.y for v in coordinates),
 'width_m':max(v.x for v in coordinates)-min(v.x for v in coordinates),'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','unique_uv_islands':len(islands),
            'density_px_per_meter':DENSITY,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF','origin':'logical tile centre, under the rearing front',
 'body_path':{'points':st['path'],'length_m':st['path_length'],'segment_spacing_m':st['spacing'],'segments':st['segments']},
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static, fully above ground. Planned clips: Burrow (dive into the ground at the origin) and Emerge (reverse), no Walk. Each segment and leg is a separate part on its own future bone so the chain can slide along a path.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'sand_worm_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
# Isolated editable source (only this scene and what it uses), like the other bestiary models.
bpy.data.libraries.write(str(OUT/'sand_worm_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={k:report[k] for k in ('height_m','front_y_m','back_y_m','width_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
