"""Pixel-paint the metric UV islands of the static Sentinel V1 (Sentinela): albedo + emission
(black). Same palette machinery as the Squire/Guardian; full functional plate (breastplate with
ridge and rivets, gorget, pauldron lames, vambraces, gauntlets with finger plates, greaves,
sabatons), mail at the joints, a closed great helm (eye slit band, breathing holes, centre
ridge), the blue tabard and a heater shield with the silver tower. Plain steel on purpose —
gilding/ornament is reserved for the Guardian Champion. Images are always FRESH datablocks.
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['sentinel']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
GAMB=[(190,172,132),(198,180,140),(182,164,124)]; GAMB_SEAM=(150,132,96); GAMB_HI=(210,194,156)
LEATHER=[(112,72,44),(122,80,50),(102,66,40)]; LEATHER_DARK=(70,44,28); LEATHER_HI=(146,100,64)
HARD=[(92,58,36),(100,64,40),(86,54,34)]
WOOL=[(86,80,72),(94,88,80),(80,74,66)]; WOOL_DARK=(62,58,52)
SKIN=[(222,172,134),(214,164,126),(228,180,142)]; SKIN_SHADE=(190,140,104); HAIR=[(92,60,36),(102,68,40)]
EYE_W=(240,236,228); PUPIL=(40,48,70); BROW=(80,52,30); MOUTH=(150,88,72)
IRON=[(118,120,126),(128,130,136),(110,112,118)]; IRON_HI=(176,178,184); IRON_DARK=(70,72,78)
BRASS=[(196,160,84),(206,170,92),(186,150,76)]; BRASS_DARK=(138,108,52)
WOOD=[(150,108,66),(160,116,72),(140,100,60)]; WOOD_DARK=(104,72,42)
TEAM=[(54,82,140),(60,90,150),(50,76,130)]; TEAM_DARK=(36,56,100)
RIVET_C=(196,196,190)
STEEL=[(160,164,172),(170,174,182),(152,156,164)]; STEEL_HI=(206,210,218); STEEL_DARK=(96,100,110)
MAIL=[(96,98,106),(106,108,116),(88,90,98)]; MAIL_DARK=(52,54,60)
SILVER=(214,218,226); BEARD=(110,74,46)
SLIT=(18,18,22)
def shade(c,d): return tuple(max(0,min(255,v+d)) for v in c)
def axes(obj):
    v=obj.data.vertices; return (v[1].co-v[0].co).normalized(),(v[2].co-v[0].co).normalized(),(v[4].co-v[0].co).normalized()
def paint(item,index):
    w,h=item['w'],item['h']; obj=item['obj']; reg=obj['region']; n=item['normal']
    rng=random.Random(8820+index)
    right=item['right']; up=n.cross(right)
    lat,dep,hgt=axes(obj)
    def frac_dir(Dv):
        gx,gy=right.dot(Dv),up.dot(Dv)
        vals=[gx*x+gy*(h-1-y) for y in (0,h-1) for x in (0,w-1)]; lo,hi=min(vals),max(vals)
        return lambda x,y: .5 if hi-lo<1e-6 else (gx*x+gy*(h-1-y)-lo)/(hi-lo)
    fz=frac_dir(Vector((0,0,1))); fl=frac_dir(lat); fh=frac_dir(hgt)
    top=n.z>.6; bottom=n.z<-.6; front=n.y<-.6; back=n.y>.6; side=abs(n.x)>.6
    t=[[GAMB[0]]*w for _ in range(h)]; e=[[(0,0,0)]*w for _ in range(h)]
    def noise(pal,weights=(5,3,2)):
        wts=list(weights)[:len(pal)] if len(pal)<=len(weights) else None   # any palette size
        for y in range(h):
            for x in range(w): t[y][x]=rng.choices(pal,wts)[0]
    def each(fn):
        for y in range(h):
            for x in range(w):
                c=fn(x,y,t[y][x])
                if c is not None: t[y][x]=c
    def edge(x,y): return min(x,y,w-1-x,h-1-y)
    def outline(c): each(lambda x,y,_: c if edge(x,y)==0 else None)
    def quilt():
        # Diamond stitching of a padded gambeson.
        noise(GAMB)
        each(lambda x,y,c: GAMB_SEAM if (x+y)%6==0 or (x-y)%6==0 else (GAMB_HI if (x+y)%6==1 else None))
    def tower(z0,z1,half):
        # Silver tower (Guardian line): body, a battlement of THREE merlons, a dark door at the base.
        cx=w//2
        each(lambda x,y,c: SILVER if z0<fz(x,y)<z1 and abs(x-cx)<=half else None)
        span=half+1; mw=max(1,(2*span+1)//5)
        for y in range(h):
            if not (z1<=fz(0,y)<z1+.10): continue          # battlement row, right above the body
            for mx in range(cx-span,cx+span+1):
                if ((mx-(cx-span))//mw)%2==0: t[y][mx]=SILVER
        each(lambda x,y,c: TEAM_DARK if z0<fz(x,y)<z0+.12 and abs(x-cx)<=max(0,half//2) else None)
    def straps(color,dark,every,width=2):
        if top or bottom: return
        each(lambda x,y,c: (dark if (y%every)==0 else color) if (y%every)<width else None)
    if reg=='gambeson':
        quilt()
        if not (top or bottom): each(lambda x,y,c: shade(c,-14) if fz(x,y)<.12 else None)
    elif reg=='jerkin':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.92 else (LEATHER_DARK if fz(x,y)<.06 else None))
            if front:
                # Laced front opening over the gambeson, rivets along the edges.
                each(lambda x,y,c: (GAMB[0] if abs(fl(x,y)-.5)<.07 else (LEATHER_DARK if abs(fl(x,y)-.5)<.09 else None)))
                each(lambda x,y,c: GAMB_SEAM if abs(fl(x,y)-.5)<.07 and y%3==0 else None)
            for y in range(2,h-2,4):
                for x in (2,w-3):
                    if 0<=x<w: t[y][x]=RIVET_C
        else: outline(LEATHER_DARK)
    elif reg=='shoulder':
        noise(HARD)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_DARK if y%5==4 else (LEATHER_HI if y%5==0 else None))
        else: each(lambda x,y,c: LEATHER_DARK if edge(x,y)==0 else (LEATHER_HI if edge(x,y)==1 else None))
        if w>5 and h>5: t[1][1]=RIVET_C; t[1][w-2]=RIVET_C
    elif reg=='bracer':
        noise(LEATHER); outline(LEATHER_DARK)
        if not (top or bottom):
            # Two straps with brass buckles around the thick bracer.
            for fy in (.28,.70):
                each(lambda x,y,c: LEATHER_DARK if abs(fh(x,y)-fy)<.07 else None)
                each(lambda x,y,c: rng.choice(BRASS) if abs(fh(x,y)-fy)<.07 and abs(fl(x,y)-.5)<.12 and (front or side) else None)
    elif reg=='glove':
        noise([shade(c,18) for c in LEATHER]); each(lambda x,y,c: LEATHER_DARK if x%4==0 and not (top or bottom) and fz(x,y)<.5 else None)
    elif reg=='trousers':
        noise(WOOL); each(lambda x,y,c: WOOL_DARK if x%5==0 and rng.random()<.6 else None)
    elif reg=='boot_shaft':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.90 else None)          # folded cuff
            for fy in (.35,.62):
                each(lambda x,y,c: LEATHER_DARK if abs(fz(x,y)-fy)<.04 else None)
        else: outline(LEATHER_DARK)
    elif reg=='boot':
        noise([shade(c,-12) for c in LEATHER])
        if not (top or bottom): each(lambda x,y,c: (40,28,20) if fz(x,y)<.22 else None)   # sole
    elif reg=='pelvis':
        quilt()
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else LEATHER_DARK) if fz(x,y)>.62 else None)
            each(lambda x,y,c: GAMB_SEAM if fz(x,y)<.62 and x%5==0 else None)   # skirt panels
    elif reg=='brass':
        noise(BRASS); outline(BRASS_DARK)
    elif reg=='iron':
        noise(IRON)
        if not (top or bottom): each(lambda x,y,c: IRON_HI if fz(x,y)>.8 else (IRON_DARK if fz(x,y)<.2 else None))
        else: each(lambda x,y,c: IRON_DARK if edge(x,y)==0 else None)
    elif reg in ('steel','helm','breastplate','pauldron','vambrace','greave','sabaton','gauntlet','greathelm'):
        noise(STEEL)
        if not (top or bottom):
            each(lambda x,y,c: STEEL_HI if fz(x,y)>.90 else (STEEL_DARK if fz(x,y)<.08 else None))
        each(lambda x,y,c: STEEL_DARK if edge(x,y)==0 else None)
        if reg=='breastplate' and (front or back):
            each(lambda x,y,c: STEEL_HI if abs(fl(x,y)-.5)<.03 and fz(x,y)>.15 else None)        # centre ridge
            each(lambda x,y,c: shade(c,-10) if abs(fl(x,y)-.5)>.30 else None)                   # rounded flanks
            for y in range(2,h-2,4):
                for x in (2,w-3): t[y][x]=RIVET_C
        if reg=='pauldron' and not (top or bottom):
            each(lambda x,y,c: STEEL_DARK if y%4==3 else (STEEL_HI if y%4==0 else None))       # lames
        if reg=='pauldron' and top:
            each(lambda x,y,c: STEEL_HI if edge(x,y)==1 else None)
        if reg=='vambrace' and not (top or bottom):
            for fy in (.33,.66): each(lambda x,y,c: STEEL_DARK if abs(fh(x,y)-fy)<.04 else None)
        if reg=='greave' and front:
            each(lambda x,y,c: STEEL_HI if abs(fl(x,y)-.5)<.05 else None)                      # shin ridge
        if reg=='greave' and not (top or bottom):
            each(lambda x,y,c: rng.choice(LEATHER) if fz(x,y)>.88 else None)                   # leather cuff
        if reg=='sabaton' and not (top or bottom):
            each(lambda x,y,c: (40,28,20) if fz(x,y)<.22 else (STEEL_DARK if y%4==3 else None))
        if reg=='helm' and not (top or bottom):
            each(lambda x,y,c: STEEL_DARK if fz(x,y)<.12 else None)
        if reg=='gauntlet' and not (top or bottom):
            each(lambda x,y,c: STEEL_DARK if y%3==2 else None)                                   # finger plates
        if reg=='greathelm':
            if front:
                # Eye-slit band across the face, breathing holes below on both sides, a centre ridge.
                each(lambda x,y,c: SLIT if .56<fz(x,y)<.64 and .12<fl(x,y)<.88 and abs(fl(x,y)-.5)>.04 else None)
                each(lambda x,y,c: STEEL_HI if abs(fl(x,y)-.5)<.035 and fz(x,y)<.94 else None)
                for y in range(int(h*.62),int(h*.80),2):
                    for x in range(2,w-2,2):
                        if abs(x-(w-1)/2)>w*.16 and abs(x-(w-1)/2)<w*.36: t[y][x]=SLIT
            elif top: each(lambda x,y,c: STEEL_HI if abs(fl(x,y)-.5)<.06 else None)
            elif not bottom:
                each(lambda x,y,c: STEEL_DARK if fz(x,y)<.10 else None)
                cx,cy=w//2,int(h*.45)
                for y in range(h):
                    for x in range(w):
                        if (x-cx)**2+(y-cy)**2<=2: t[y][x]=RIVET_C                             # side rivet
        if reg=='helm' and top:
            each(lambda x,y,c: STEEL_HI if abs(fl(x,y)-.5)<.06 else None)                      # crest ridge
    elif reg in ('mail','mail_skirt'):
        for y in range(h):
            for x in range(w): t[y][x]=MAIL_DARK if (x+(y//2)%2)%2==0 and y%2==0 else rng.choice(MAIL)
        if reg=='mail_skirt' and not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else LEATHER_DARK) if fz(x,y)>.60 else None)   # belt
    elif reg=='tabard':
        noise(TEAM); each(lambda x,y,c: TEAM_DARK if (edge(x,y)==0 or fz(x,y)<.08) else None)
        if front or back:
            tower(.30,.70,max(1,w//6))
    elif reg=='surcoat':
        # Mail hauberk with a blue surcoat over it: surcoat panel on the front/back (silver tower on the
        # front), mail showing on the flanks and at the shoulders.
        for y in range(h):
            for x in range(w): t[y][x]=MAIL_DARK if (x+(y//2)%2)%2==0 and y%2==0 else rng.choice(MAIL)
        if front or back:
            each(lambda x,y,c: (rng.choice(TEAM) if fz(x,y)<.86 else c) if .16<fl(x,y)<.84 else None)
            each(lambda x,y,c: TEAM_DARK if (abs(fl(x,y)-.16)<.03 or abs(fl(x,y)-.84)<.03) and fz(x,y)<.86 else None)
            if front: tower(.18,.62,max(1,w//9))
    elif reg=='round_heraldic':
        # Squire's round shield, reinforced: steel rim, painted blue field, silver tower on the front.
        noise(WOOD)
        if abs(n.dot(dep))>.6:
            each(lambda x,y,c: rng.choice(TEAM) if edge(x,y)>=2 else None)
            if obj['part']=='ShieldMid' and n.dot(dep)<0: tower(.20,.62,max(2,w//8))
            each(lambda x,y,c: rng.choice(STEEL) if edge(x,y)<2 else None)
            for y in range(3,h-3,6):
                for x in (3,w-4):
                    if 0<=x<w: t[y][x]=STEEL_HI
        else: noise(STEEL)
    elif reg=='heater':
        noise(TEAM)
        if abs(n.dot(dep))>.6:
            if obj['part']=='ShieldMid' and n.dot(dep)<0:
                tower(.18,.66,max(2,w//8))
            each(lambda x,y,c: rng.choice(STEEL) if edge(x,y)<2 else None)
            for y in range(3,h-3,5):
                for x in (2,w-3):
                    if 0<=x<w: t[y][x]=STEEL_HI
        else: noise(STEEL)
    elif reg=='face':
        noise(SKIN)
        if front:
            # Symmetric, steady face (user: the first one looked crooked/goofy). Mirrored columns around the
            # centre: straight brows, dark narrow eyes right under them, a nose shade, a straight mouth.
            def mirror(x0,width,y,c):
                for dx in range(width):
                    for xx in (x0+dx,w-1-x0-dx):
                        if 0<=xx<w and 0<=y<h: t[y][xx]=c
            eye_y=int(round(h*.48)); ex=int(round(w*.22)); ew=max(2,int(round(w*.18)))
            mirror(ex-1,ew+1,eye_y-2,BROW)                      # brows, a bit wider than the eyes
            mirror(ex,ew,eye_y,PUPIL)                          # eyes: dark, narrow
            mirror(ex,1,eye_y,EYE_W)                           # small white on the OUTER corner
            c0=w//2-1 if w%2==0 else w//2
            for y in range(eye_y+1,eye_y+4):
                for xx in range(c0,w-c0): t[y][xx]=SKIN_SHADE   # nose shade, centred
            m0=int(round(w*.36)); my=int(round(h*.74))
            for xx in range(m0,w-m0): t[my][xx]=MOUTH            # one continuous, centred mouth line
            # Short beard (same squire, a few years on): jaw line and chin, mirrored, around the mouth.
            for y in range(my+1,h):
                for xx in range(1,w-1):
                    if (y-my)>=1 and (abs(xx-(w-1)/2)<w*.40) and rng.random()<.8: t[y][xx]=BEARD
            for xx in range(m0-1,w-m0+1): t[my-1][xx]=BEARD if abs(xx-(w-1)/2)>1 else t[my-1][xx]   # moustache
            mirror(0,w//2+1,0,rng.choice(HAIR)); mirror(0,w//2+1,1,HAIR[0])   # fringe under the hat
            mirror(0,1,2,HAIR[1]); mirror(0,1,3,HAIR[1])                        # sideburns
        elif side or back:
            each(lambda x,y,c: rng.choice(HAIR) if (back and fz(x,y)>.25) or (side and fz(x,y)>.70) else None)
            if side:
                each(lambda x,y,c: rng.choice(HAIR) if fz(x,y)>.35 and ((n.x>0 and fl(x,y)>.78) or (n.x<0 and fl(x,y)<.22)) else None)
                each(lambda x,y,c: SKIN_SHADE if abs(fz(x,y)-.50)<.07 and abs(fl(x,y)-.5)<.09 else None)   # ear
        elif top: noise(HAIR)
        else: noise([SKIN_SHADE])
    elif reg=='shield':
        noise(WOOD)
        if abs(n.dot(dep))>.6:
            # Vertical planks, iron rim, nails; a blue heraldic band down the middle of the front.
            each(lambda x,y,c: WOOD_DARK if x%7==0 else None)
            if obj['part']=='ShieldMid' and n.dot(dep)<0:
                each(lambda x,y,c: rng.choice(TEAM) if abs(fl(x,y)-.5)<.16 else (TEAM_DARK if abs(fl(x,y)-.5)<.19 else None))
            each(lambda x,y,c: rng.choice(IRON) if edge(x,y)<2 else None)
            for y in range(3,h-3,6):
                for x in (3,w-4):
                    if 0<=x<w: t[y][x]=IRON_HI
        else: noise(IRON)
    else:
        raise RuntimeError('unpainted region '+reg)
    return t,e

pixels=([c/255 for c in GAMB[0]]+[1])*(SIZE*SIZE); energy=[0,0,0,1]*(SIZE*SIZE)
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
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'sentinel_v1_{suffix}.png'); im.file_format='PNG'
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
report={'name':NAME,'kind':'v2_unit_sentinel (Sentinela)','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/sentinel_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'front_y_m':min(v.y for v in coordinates),'back_y_m':max(v.y for v in coordinates),
 'x_m':[min(v.x for v in coordinates),max(v.x for v in coordinates)],'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,'unique_uv_islands':len(islands),
            'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF','origin':'between the feet, on the ground',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static Sentinel V1 (Sentinela), the Guardian evolved: full functional plate, closed great helm, heater shield; 1.80 m, same joints as the Squire. Shield + grip follow hand_l; helm follows head.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'sentinel_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'sentinel_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={k:report[k] for k in ('height_m','front_y_m','back_y_m','x_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
