"""Pixel-paint the metric UV islands of the static Hunter V1 (Caçador): albedo + emission (black).
Archer palette and machinery, plus: a darker green hood painted on the head with a FUR rim around the
face, a seasoned face with dark hair and a short beard, dark studded leather with a ragged fur collar,
leather belly with straps, leather pauldrons with fur on top, fur-cuffed boots, a dark recurve bow
with horn caps, barred brown/white fletchings and a sheathed hunting knife. Images are always FRESH.
"""
import bpy
import bmesh
import json
import random
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['hunter']; NAME=st['name']; scene=st['scene']; parts=st['parts']
SIZE=st['size']; PAD=st['pad']; D=st['density']; islands=st['islands']; OUT=Path(st['out'])
GAMB=[(190,172,132),(198,180,140),(182,164,124)]; GAMB_SEAM=(150,132,96); GAMB_HI=(210,194,156)
LEATHER=[(112,72,44),(122,80,50),(102,66,40)]; LEATHER_DARK=(70,44,28); LEATHER_HI=(146,100,64)
HARD=[(92,58,36),(100,64,40),(86,54,34)]
WOOL=[(86,80,72),(94,88,80),(80,74,66)]; WOOL_DARK=(62,58,52)
SKIN=[(212,162,124),(204,154,118),(218,170,130)]; SKIN_SHADE=(178,130,96); HAIR=[(62,44,30),(74,52,34)]   # seasoned hunter, dark hair and short beard
DLEATHER=[(76,52,36),(84,58,40),(70,48,32)]; FUR=[(150,118,82),(164,130,92),(136,104,72),(120,92,62)]; HORN=[(224,214,190),(206,196,170)]
GREEN=[(50,72,44),(56,80,48),(46,66,40)]; GREEN_DARK=(32,46,28); YEW=[(112,76,46),(122,84,52),(102,68,40)]; YEW_DARK=(72,48,28)   # darker forest hood, dark recurve
EYE_W=(240,236,228); PUPIL=(40,48,70); BROW=(80,52,30); MOUTH=(150,88,72)
IRON=[(118,120,126),(128,130,136),(110,112,118)]; IRON_HI=(176,178,184); IRON_DARK=(70,72,78)
BRASS=[(196,160,84),(206,170,92),(186,150,76)]; BRASS_DARK=(138,108,52)
WOOD=[(150,108,66),(160,116,72),(140,100,60)]; WOOD_DARK=(104,72,42)
TEAM=[(54,82,140),(60,90,150),(50,76,130)]; TEAM_DARK=(36,56,100)
RIVET_C=(196,196,190)
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
        noise([shade(c,18) for c in LEATHER])                              # plain gloves (no dark lines; user)
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
    elif reg=='gambeson_chest':
        quilt()
        if front or back:
            # Diagonal leather baldric (shoulder to hip) with a brass buckle on the front.
            each(lambda x,y,c: (LEATHER_DARK if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.05 else rng.choice(LEATHER)) if abs((fl(x,y) if front else 1-fl(x,y))-fz(x,y))<.11 else None)
            if front: each(lambda x,y,c: rng.choice(BRASS) if abs(fl(x,y)-.5)<.06 and abs(fz(x,y)-.5)<.07 else None)
        elif not (top or bottom): each(lambda x,y,c: shade(c,-14) if fz(x,y)<.12 else None)
    elif reg=='pelvis_sash':
        quilt()
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else LEATHER_DARK) if fz(x,y)>.62 else None)
            each(lambda x,y,c: rng.choice(TEAM) if .30<fz(x,y)<.62 else None)                   # blue team sash
            each(lambda x,y,c: TEAM_DARK if abs(fz(x,y)-.46)<.03 else None)
    elif reg=='cap':
        noise([shade(c,-6) for c in LEATHER])
        if top: each(lambda x,y,c: LEATHER_DARK if abs(fl(x,y)-.5)<.04 else None)           # stitched crown seam
        elif not bottom:
            each(lambda x,y,c: LEATHER_DARK if fz(x,y)<.12 else (LEATHER_HI if fz(x,y)>.90 else None))
            each(lambda x,y,c: GAMB_SEAM if fz(x,y)<.12 and x%3==0 else None)                     # stitched brim
    elif reg=='axe_haft':
        noise(WOOD); each(lambda x,y,c: WOOD_DARK if x%3==0 and rng.random()<.5 else None)
        each(lambda x,y,c: (LEATHER_DARK if int(fh(x,y)*24)%2 else rng.choice(LEATHER)) if fh(x,y)<.38 else None)   # grip wrap
    elif reg=='axe_head':
        noise(IRON); each(lambda x,y,c: IRON_DARK if edge(x,y)==0 else None)
    elif reg=='axe_edge':
        noise([IRON_HI,(196,198,204),(164,166,172)])
    elif reg=='hood':
        noise(GREEN)
        if not (top or bottom):
            each(lambda x,y,c: GREEN_DARK if x%6==0 and rng.random()<.7 else None)                         # cloth folds
            each(lambda x,y,c: GREEN_DARK if edge(x,y)==0 else None)                                     # hemmed edge
        else: each(lambda x,y,c: GREEN_DARK if (x+y)%7==0 else None)
    elif reg=='hunter_chest':
        noise(DLEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.92 else (LEATHER_DARK if fz(x,y)<.06 else None))
            if front:
                each(lambda x,y,c: (GAMB[0] if abs(fl(x,y)-.5)<.06 else (LEATHER_DARK if abs(fl(x,y)-.5)<.08 else None)))   # laced opening
                each(lambda x,y,c: GAMB_SEAM if abs(fl(x,y)-.5)<.06 and y%3==0 else None)
            if front or back:   # quiver strap: from the left shoulder down to the right hip (front), mirrored on the back
                each(lambda x,y,c: (LEATHER_DARK if abs((1-fl(x,y) if front else fl(x,y))-fz(x,y))<.04 else HARD[0]) if abs((1-fl(x,y) if front else fl(x,y))-fz(x,y))<.09 else None)
        else: outline(LEATHER_DARK)
        if front or back: each(lambda x,y,c: RIVET_C if x%4==1 and y%4==1 and .10<fz(x,y)<.78 and abs(fl(x,y)-.5)>.10 else None)   # studs
        if top: noise(FUR)
        elif not bottom: each(lambda x,y,c: rng.choice(FUR) if fz(x,y)>.84 or (fz(x,y)>.78 and rng.random()<.5) else None)   # ragged fur collar
    elif reg=='leather_belly':
        noise(DLEATHER)
        if not (top or bottom): each(lambda x,y,c: LEATHER_DARK if abs(fz(x,y)-.35)<.06 or abs(fz(x,y)-.75)<.06 else None)   # straps
    elif reg=='fur_pauldron':
        noise(DLEATHER)
        if top: noise(FUR); each(lambda x,y,c: shade(c,-18) if (x+2*y)%5==0 else None)               # fur strands
        elif not bottom:
            each(lambda x,y,c: rng.choice(FUR) if fz(x,y)>.66 or (fz(x,y)>.52 and rng.random()<.45) else None)   # ragged fur edge
            each(lambda x,y,c: LEATHER_DARK if edge(x,y)==0 and fz(x,y)<.5 else None)
    elif reg=='fur_boot':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: rng.choice(FUR) if fz(x,y)>.82 or (fz(x,y)>.74 and rng.random()<.5) else None)   # fur cuff
            each(lambda x,y,c: LEATHER_DARK if abs(fz(x,y)-.40)<.04 else None)
        elif top: noise(FUR)
        else: outline(LEATHER_DARK)
    elif reg=='horn':
        noise(HORN); each(lambda x,y,c: (150,140,120) if edge(x,y)==0 else None)
    elif reg=='knife':
        noise([shade(c,-20) for c in LEATHER])
        if not (top or bottom):
            each(lambda x,y,c: (rng.choice(LEATHER) if fz(x,y)<.92 else rng.choice(IRON)) if fz(x,y)>.66 else None)   # grip + pommel
            each(lambda x,y,c: rng.choice(IRON) if abs(fz(x,y)-.66)<.04 or fz(x,y)<.06 else None)                    # guard, chape
    elif reg=='bow_wood':
        noise(YEW); each(lambda x,y,c: YEW_DARK if (x%4==0 and rng.random()<.6) else None)
        if not (top or bottom) and abs(n.dot(Vector((0,1,0))))>.6: each(lambda x,y,c: shade(c,-14) if edge(x,y)==0 else None)
    elif reg=='bow_grip':
        each(lambda x,y,c: LEATHER_DARK if y%2 else rng.choice(LEATHER))                               # leather wrap
    elif reg=='bow_string':
        noise([(222,214,190),(210,202,178)])
    elif reg=='quiver':
        noise(LEATHER)
        if not (top or bottom):
            each(lambda x,y,c: LEATHER_DARK if abs(fz(x,y)-.80)<.04 or abs(fz(x,y)-.25)<.04 else None)   # bands
            each(lambda x,y,c: LEATHER_HI if fz(x,y)>.94 else None)
        else: outline(LEATHER_DARK)
    elif reg=='fletching':
        noise([(236,232,222),(226,222,212)])
        each(lambda x,y,c: (96,66,40) if (y//2)%2==0 else None)                                          # barred brown/white feathers
        if bottom: noise(WOOD)
    elif reg=='arrow_shaft':
        noise(WOOD)
    elif reg=='arrow_head':
        noise(IRON); outline(IRON_DARK)
    elif reg in ('face','face_hood'):
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
            # Short beard on the jaw and chin + moustache; closed mouth line inside it.
            each(lambda x,y,c: rng.choice(HAIR) if fz(x,y)<.28 or ((x<3 or x>w-4) and fz(x,y)<.45) else None)
            for xx in range(m0-1,w-m0+1): t[my-1][xx]=HAIR[0]
            for xx in range(m0+1,w-m0-1): t[my][xx]=(92,52,40)
            mirror(0,w//2+1,0,rng.choice(HAIR)); mirror(0,w//2+1,1,HAIR[0])   # fringe under the hat
            mirror(0,1,2,HAIR[1]); mirror(0,1,3,HAIR[1])                        # sideburns
        elif side or back:
            each(lambda x,y,c: rng.choice(HAIR) if (back and fz(x,y)>.25) or (side and fz(x,y)>.70) else None)
            if side:
                each(lambda x,y,c: rng.choice(HAIR) if fz(x,y)>.35 and ((n.x>0 and fl(x,y)>.78) or (n.x<0 and fl(x,y)<.22)) else None)
                each(lambda x,y,c: SKIN_SHADE if abs(fz(x,y)-.50)<.07 and abs(fl(x,y)-.5)<.09 else None)   # ear
        elif top: noise(HAIR)
        else: noise([SKIN_SHADE])
        if reg=='face_hood':
            # Hood PAINTED on the head (user removed the hood blocks): green over the top, back and sides,
            # framing the face on the front with a darker rim; a hair fringe peeks under the rim.
            if front:
                each(lambda x,y,c: rng.choice(GREEN) if fz(x,y)>.80 or ((x<2 or x>w-3) and fz(x,y)>.12) else None)
                each(lambda x,y,c: rng.choice(FUR) if (abs(fz(x,y)-.79)<.07 and 1<x<w-2) or ((2<=x<=3 or w-4<=x<=w-3) and fz(x,y)>.10) else None)   # thick FUR rim around the face
                each(lambda x,y,c: rng.choice(HAIR) if .68<fz(x,y)<.72 and 3<x<w-4 and (x%3)!=1 else None)
            elif top or back or side:
                noise(GREEN); each(lambda x,y,c: GREEN_DARK if x%6==0 and rng.random()<.7 else None)   # cloth folds
                if back: each(lambda x,y,c: GREEN_DARK if abs(fl(x,y)-.5)<.03 else None)              # back seam
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
    im.pixels.foreach_set(data); im.filepath_raw=str(OUT/f'hunter_v1_{suffix}.png'); im.file_format='PNG'
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
report={'name':NAME,'kind':'v2_unit_hunter (Caçador)','pipeline':'Blender MCP localhost:9876 (tools/art_pipeline/hunter_*.py)',
 'height_m':max(v.z for v in coordinates)-min(v.z for v in coordinates),
 'front_y_m':min(v.y for v in coordinates),'back_y_m':max(v.y for v in coordinates),
 'x_m':[min(v.x for v in coordinates),max(v.x for v in coordinates)],'triangles':triangles,'editable_parts':len(parts),
 'nonmanifold_edges':nonmanifold,'shade':'Flat','materials':1,
 'texture':{'size':[SIZE,SIZE],'filter':'NEAREST','images':['albedo','emission'],'emission_strength':1.6,'unique_uv_islands':len(islands),
            'density_px_per_meter':D,'measured_min':min(density),'measured_max':max(density),'padding':PAD},
 'rig':False,'animations':[],'front':'-Y in Blender / +Z in glTF','origin':'between the feet, on the ground',
 'rig_bone_map':{o['part']:o['rig_bone'] for o in parts},
 'notes':'Static Hunter V1 (Caçador), Archer copy, 1.80 m, one block per body part. Bow, horn caps follow hand_l; string halves string_u/string_d; nocked arrow on its own bone; quiver follows chest; knife follows hips; hood painted on the head.'}
st['report']=report; st['root']=root; st['material']=mat
(OUT/'hunter_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(OUT/'hunter_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={k:report[k] for k in ('height_m','front_y_m','back_y_m','x_m','triangles','editable_parts','nonmanifold_edges')}|{'density':[min(density),max(density)],'atlas':SIZE}
