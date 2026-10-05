"""Pixel-paint the metric UV islands of the static Corrupted Hero V1 (approved composition:
one block per body part): albedo + emission atlases (Golem convention; the emission atlas
is kept for a later corruption accent but is black for now). The armour detail lives HERE,
not in geometry: helm slits/grille/crest/ear rivets on the single head cube, breastplate
plate + ridge + rivets on the chest, pauldron lames on the shoulder cubes, vambrace lames
and cuff on the forearms, greave ridge on the shins, mail on the thin upper arms/thighs,
leather belt + plate fauld on the waist, slate-blue cloth, leather gloves, studded club.
Painterly, desaturated palette. Stripes follow each part's own axes (cuboid vertex order).
Images are always FRESH datablocks (stale packed-image guard).
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['corrupted_hero']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
PLATE=[(152,152,149),(158,157,154),(147,147,144)]; PLATE_HI=(172,171,167); PLATE_DARK=(98,98,100); PLATE_BLOT=(136,136,134); PLATE_STREAK=(112,112,112)
CLOTH=[(62,76,96),(70,84,104),(56,69,87)]; CLOTH_DARK=(40,49,63); CLOTH_HI=(86,100,120)
LEATHER=[(98,62,40),(110,70,46),(87,55,36)]; LEATHER_DARK=(60,38,26)
GOLD=[(196,170,108),(208,182,118),(184,158,98)]; GOLD_DARK=(140,116,66)
SLIT=(18,18,22); TRIM=(196,196,192); RIVET_C=(206,206,202)
MAIL=[(64,66,72),(72,74,80),(58,60,66)]; MAIL_DARK=(34,35,40)
WOOD=[(92,62,40),(102,70,46),(84,56,36)]; WOOD_DARK=(62,40,26); IRON=(72,74,80); IRON_HI=(150,152,158)
IRON_HEAD=[(70,72,78),(78,80,86),(64,66,72)]; RUST=[(116,76,52),(104,66,44)]; GRIME=(112,108,100)
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def axes(obj):
    v=obj.data.vertices; return (v[1].co-v[0].co).normalized(),(v[2].co-v[0].co).normalized(),(v[4].co-v[0].co).normalized()
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; n=item['normal']
    rng=random.Random(5120+index)
    right=item['right']; up=n.cross(right)
    lat,dep,hgt=axes(obj)
    def frac_dir(Dv):
        gx,gy=right.dot(Dv),up.dot(Dv)
        vals=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(vals),max(vals)
        return lambda x,y: .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    fz=frac_dir(Vector((0,0,1))); fh=frac_dir(hgt); fl=frac_dir(lat)
    top=n.z>.6; bottom=n.z<-.6; front=n.y<-.6; back=n.y>.6
    t=[[PLATE[0]]*w for _ in range(h)]; e=[[(0,0,0)]*w for _ in range(h)]
    def noise(pal,weights=(5,3,2)):
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(pal,weights)[0]
    def each(fn):
        for y in range(h):
            for x in range(w):
                c=fn(x,y,t[y][x])
                if c is not None: t[y][x]=c
    def blotches(color,count,rmax=3):
        for _ in range(count):
            cx,cy=rng.randrange(w),rng.randrange(h); r=rng.randint(1,rmax)
            for y in range(max(0,cy-r),min(h,cy+r+1)):
                for x in range(max(0,cx-r),min(w,cx+r+1)):
                    if (x-cx)**2+(y-cy)**2<=r*r+rng.randint(-1,1): t[y][x]=color
    def streaks(color,count):
        for _ in range(count):
            x,y=rng.randrange(w),rng.randrange(h)
            for _ in range(rng.randint(2,5)):
                if 0<=x<w and 0<=y<h: t[y][x]=color
                y+=1; x+=rng.choice((-1,0,0,1))
    def area_count(k): return max(1,int(w*h/k))
    def edge(x,y): return min(x,y,w-1-x,h-1-y)
    def plate():
        noise(PLATE); blotches(PLATE_BLOT,area_count(90),4); blotches(PLATE_HI,area_count(400),2); streaks(PLATE_STREAK,area_count(260))
        # Old and worn: grime patches, a few rust spots and dents.
        blotches(GRIME,area_count(160),3); blotches(rng.choice(RUST),area_count(520),1); blotches(PLATE_DARK,area_count(700),1)
        each(lambda x,y,c: PLATE_DARK if edge(x,y)==0 else (TRIM if edge(x,y)==1 and w>5 and h>5 else None))
        if not (top or bottom): each(lambda x,y,c: shade(c,-12) if fz(x,y)<.18 and edge(x,y)>1 else None)
    def bands(step,offset=0):
        if top or bottom: return
        each(lambda x,y,c: PLATE_DARK if (y+offset)%step==step-1 and 1<x<w-2 else (TRIM if (y+offset)%step==0 and 1<x<w-2 and 1<y<h-2 else None))
    def rivets(spacing):
        if w<7 or h<7: return
        for x in range(3,w-3,spacing):
            for y in (2,h-3): t[y][x]=RIVET_C
    def slits():
        # Just two wide horizontal openings (eye band + lower band), placed by real height.
        each(lambda x,y,c: SLIT if (.56<fz(x,y)<.68 and .10<fl(x,y)<.90) or (.36<fz(x,y)<.44 and .20<fl(x,y)<.80) else None)
        each(lambda x,y,c: PLATE_DARK if (abs(fz(x,y)-.70)<.02 and .10<fl(x,y)<.90) else None)
    if reg in ('chest','shoulder','forearm','shin','foot','knee','shield_ridge'):
        plate()
        if reg=='chest':
            if front or back:
                each(lambda x,y,c: shade(c,8) if .14<fl(x,y)<.86 and .12<fz(x,y)<.90 else None)
                each(lambda x,y,c: PLATE_DARK if (abs(fl(x,y)-.14)<.02 or abs(fl(x,y)-.86)<.02) and .12<fz(x,y)<.90 else None)
                if front: each(lambda x,y,c: TRIM if abs(fl(x,y)-.5)<.02 and .2<fz(x,y)<.85 else None)
                rivets(6)
            else: bands(9)
        elif reg=='shoulder':
            bands(7,2); rivets(5)
        elif reg=='forearm':
            bands(8,3); each(lambda x,y,c: TRIM if fz(x,y)<.10 and not (top or bottom) else None)
        elif reg=='shin':
            if front: each(lambda x,y,c: TRIM if abs(fl(x,y)-.5)<.03 else None)
            bands(11,4)
        elif reg=='foot':
            if not (top or bottom): each(lambda x,y,c: PLATE_DARK if y%5==4 and 1<x<w-2 else None)
    elif reg=='helm':
        plate()
        if front: slits(); rivets(7)
        elif top: each(lambda x,y,c: TRIM if abs(fl(x,y)-.5)<.05 else (PLATE_DARK if abs(fl(x,y)-.5)<.08 else None))
        elif not bottom:
            cx,cy=w//2,int(h*.55)
            for y in range(h):
                for x in range(w):
                    if abs((x-cx)**2+(y-cy)**2-9)<3: t[y][x]=PLATE_DARK
            each(lambda x,y,c: shade(c,-14) if fz(x,y)<.15 else None)
    elif reg=='mail':
        for y in range(h):
            for x in range(w): t[y][x]=MAIL_DARK if (x+(y//2)%2)%2==0 and y%2==0 else rng.choice(MAIL)
        if not (top or bottom): each(lambda x,y,c: shade(c,-10) if fz(x,y)<.2 else None)
    elif reg=='waist':
        plate()
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.94 else LEATHER_DARK) if fz(x,y)>.55 else (PLATE_DARK if y%6==5 else None))
        elif top: noise(LEATHER)
    elif reg=='cloth':
        noise(CLOTH); blotches(CLOTH_DARK,area_count(70),2)
        folds=set(); x0=rng.randrange(2,6)
        while x0<w: folds.add(x0); x0+=rng.randrange(7,12)
        each(lambda x,y,c: CLOTH_DARK if (x in folds and rng.random()<.7) else (CLOTH_HI if x-1 in folds and rng.random()<.6 else None))
        if not (top or bottom):
            # Frayed, torn hem and a stitched patch: a ragged old tabard.
            each(lambda x,y,c: (CLOTH_DARK if rng.random()<.55 else shade(c,-30)) if fz(x,y)<.10+.06*((x*7)%3)/2 else None)
            if w>=10 and h>=14 and rng.random()<.6:
                px,py=rng.randrange(1,w-7),rng.randrange(int(h*.3),h-8)
                for yy in range(py,py+6):
                    for xx in range(px,px+6): t[yy][xx]=(84,90,92) if (xx==px or yy==py or xx==px+5 or yy==py+5) and (xx+yy)%2 else (76,82,86)
    elif reg=='glove':
        noise(LEATHER); blotches(LEATHER_DARK,area_count(60),2)
        if not (top or bottom): each(lambda x,y,c: LEATHER_DARK if fz(x,y)>.85 else (shade(c,-18) if x%5==0 and fz(x,y)<.45 else None))
    elif reg=='gold':
        noise(GOLD)
        if front: each(lambda x,y,c: GOLD_DARK if edge(x,y)==0 else None)
    elif reg=='grip':
        noise(LEATHER); each(lambda x,y,c: LEATHER_DARK if int(fh(x,y)*10)%2 else None)
    elif reg=='haft':
        noise(WOOD); each(lambda x,y,c: WOOD_DARK if (x%3==0 and rng.random()<.5) else None)
    elif reg=='iron_head':
        # Square iron block: dark iron, bevelled light rim, rivets, rust and grime.
        noise(IRON_HEAD); blotches(rng.choice(RUST),area_count(120),2); blotches(GRIME,area_count(160),2)
        each(lambda x,y,c: IRON_HI if edge(x,y)==1 else ((40,41,46) if edge(x,y)==0 else None))
        for (rx,ry) in ((3,3),(w-4,3),(3,h-4),(w-4,h-4)):
            if 0<=rx<w and 0<=ry<h: t[ry][rx]=IRON_HI
    elif reg=='handle':
        noise(LEATHER); each(lambda x,y,c: LEATHER_DARK if int(fh(x,y)*12)%2 else None)
    elif reg=='club_head':
        noise(WOOD); each(lambda x,y,c: WOOD_DARK if x%4==0 and rng.random()<.6 else None)
        each(lambda x,y,c: IRON if abs(fh(x,y)-.22)<.06 or abs(fh(x,y)-.78)<.06 else None)
        if abs(n.dot(hgt))<.6:
            # Iron studs in a staggered (quincunx) pattern between the bands: reads as a war club.
            for fy,xs in ((.38,(.25,.75)),(.50,(.5,)),(.62,(.25,.75))):
                for fx in xs:
                    each(lambda x,y,c: IRON_HI if abs(fh(x,y)-fy)<.035 and abs(fl(x,y)-fx)<.08 else (IRON if abs(fh(x,y)-fy)<.05 and abs(fl(x,y)-fx)<.11 else None))
        else:
            each(lambda x,y,c: IRON if edge(x,y)<2 else None)
    elif reg=='shield':
        plate(); blotches(PLATE_DARK,area_count(140),2)
        if abs(n.dot(dep))>.6:
            each(lambda x,y,c: (rng.choice(CLOTH) if abs(fl(x,y)-.5)<.16 else (CLOTH_DARK if abs(fl(x,y)-.5)<.19 else None)) if edge(x,y)>2 else None)
    else:
        raise RuntimeError('unpainted region '+reg)
    return t,e

pixels=([c/255 for c in PLATE[0]]+[1])*(SIZE*SIZE); energy=[0,0,0,1]*(SIZE*SIZE)
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
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'corrupted_hero_v1_{suffix}.png'); im.file_format='PNG'
    im.save(); im.pack(); images.append(im)
mat=bpy.data.materials.get(NAME+'_PixelArt')
if mat is None:
    mat=bpy.data.materials.new(NAME+'_PixelArt'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.88
    bsdf.inputs['Metallic'].default_value=0; bsdf.inputs['Specular IOR Level'].default_value=.25
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
report={'name':NAME,'kind':'corrupted_hero (replaces mycotic_hive)','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/corrupted_hero_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'front_y_m':min(v.y for v in coordinates),'back_y_m':max(v.y for v in coordinates),
 'x_m':[min(v.x for v in coordinates),max(v.x for v in coordinates)],'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,'unique_uv_islands':len(islands),
            'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF','origin':'between the feet, on the ground',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static, approved composition: one block per body part (head, chest, belly, waist, thigh, shin, foot, shoulder, upper arm, forearm, hand). Club follows hand_r, tower shield follows forearm_l, tabard strips follow hips.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'corrupted_hero_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'corrupted_hero_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={k:report[k] for k in ('height_m','front_y_m','back_y_m','x_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
