"""Localised UV/texture repair after manual edits, in the live Blender via MCP.
Finds parts whose object transform is not identity or whose world-space texel
density drifted from 64 px/m (e.g. a block scaled in Object Mode), applies the
transform into the mesh, re-projects ONLY those parts at 64 px/m into free atlas
space and paints ONLY their islands with the same painter. Every other atlas
pixel stays byte-identical. Requires BACKUP (path) global; the atlas becomes a
fresh image datablock (stale packed-image guard).
"""
import bpy
import bmesh
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
NAME='Skeleton_Warrior_V1'; OUT=ROOT/'assets/generated/skeletons/skeleton_warrior_v1'
DENSITY=64; PAD=2
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
bpy.data.libraries.write(BACKUP,{scene},path_remap='RELATIVE',fake_user=True,compress=True)
parts=[o for o in scene.objects if o.type=='MESH' and not o.name.endswith('StudioGround')]
atlas=bpy.data.images[NAME+'_PixelAtlas']; SIZE=atlas.size[0]
def world_density(o):
    me=o.data; uv=me.uv_layers['Metric_Pixel_UV'].data; d=[]
    for p in me.polygons:
        L=list(p.loop_indices)
        for i,li in enumerate(L):
            lj=L[(i+1)%len(L)]
            a=o.matrix_world@me.vertices[me.loops[li].vertex_index].co; b=o.matrix_world@me.vertices[me.loops[lj].vertex_index].co
            if (a-b).length>1e-7: d.append((uv[li].uv-uv[lj].uv).length*SIZE/(a-b).length)
    return d
targets=[o for o in parts if o.matrix_basis!=Matrix.Identity(4) or max(abs(x-DENSITY) for x in world_density(o))>.03]
for o in targets:
    o.data.transform(o.matrix_basis); o.matrix_basis=Matrix.Identity(4)

# Occupancy of every untouched island (UV bbox + padding), in atlas pixels.
occupied=[[False]*SIZE for _ in range(SIZE)]
for o in parts:
    if o in targets: continue
    uv=o.data.uv_layers['Metric_Pixel_UV'].data
    for p in o.data.polygons:
        us=[uv[li].uv for li in p.loop_indices]
        x0=max(0,math.floor(min(u.x for u in us)*SIZE)-PAD); x1=min(SIZE,math.ceil(max(u.x for u in us)*SIZE)+PAD)
        y0=max(0,math.floor(min(u.y for u in us)*SIZE)-PAD); y1=min(SIZE,math.ceil(max(u.y for u in us)*SIZE)+PAD)
        for y in range(y0,y1):
            row=occupied[y]
            for x in range(x0,x1): row[x]=True
islands=[]
for obj in targets:
    me=obj.data; bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    for p in me.polygons:
        normal=p.normal.normalized(); desired=Vector(obj['paint_up'])
        up=desired-normal*desired.dot(normal)
        if up.length<.001: up=Vector((0,1,0))-normal*normal.y
        if up.length<.001: up=Vector((1,0,0))-normal*normal.x
        up.normalize(); right=up.cross(normal).normalized()
        co=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        minimum=Vector((min(c.x for c in co),min(c.y for c in co))); co=[c-minimum for c in co]
        islands.append({'obj':obj,'polygon':p.index,'coords':co,'normal':normal,'right':right,
                        'w':max(1,math.ceil(max(c.x for c in co)*DENSITY)),'h':max(1,math.ceil(max(c.y for c in co)*DENSITY))})
for island in sorted(islands,key=lambda i:(-i['h'],-i['w'])):
    W,H=island['w']+2*PAD,island['h']+2*PAD; placed=False
    for y in range(0,SIZE-H+1):
        for x in range(0,SIZE-W+1):
            if any(occupied[yy][x:x+W].count(True) for yy in range(y,y+H)): continue
            island['x']=x+PAD; island['y']=y+PAD
            for yy in range(y,y+H): occupied[yy][x:x+W]=[True]*W
            placed=True; break
        if placed: break
    assert placed, 'No free atlas space at 64 px/m; never shrink islands to fit.'

# Same painter as skeleton_warrior_paint_save.py (definitions only).
source=(ROOT/'tools/art_pipeline/skeleton_warrior_paint_save.py').read_text(encoding='utf-8')
exec(source[source.index('# Aged ivory bone ramp'):source.index('pixels=[0.0]')])
pixels=list(atlas.pixels[:])
for index,item in enumerate(islands):
    t=paint(item,9000+index); w,h=item['w'],item['h']; ox,oy=item['x'],item['y']
    for y in range(-PAD,h+PAD):
        for x in range(-PAD,w+PAD):
            color=t[h-1-max(0,min(h-1,y))][max(0,min(w-1,x))]
            k=((oy+y)*SIZE+ox+x)*4; pixels[k:k+4]=[c/255 for c in color]+[1]
mat=bpy.data.materials[NAME+'_PixelArt']
bpy.data.images.remove(atlas)
image=bpy.data.images.new(NAME+'_PixelAtlas',width=SIZE,height=SIZE,alpha=True)
image.colorspace_settings.name='sRGB'; image.pixels.foreach_set(pixels)
image.filepath_raw=str(OUT/'skeleton_warrior_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE': node.image=image
for item in islands:
    me=item['obj'].data; uv=me.uv_layers['Metric_Pixel_UV'].data
    for li,co in zip(me.polygons[item['polygon']].loop_indices,item['coords']):
        uv[li].uv=((item['x']+co.x*DENSITY)/SIZE,(item['y']+co.y*DENSITY)/SIZE)
worst=max(abs(x-DENSITY) for o in parts for x in world_density(o))
assert worst<.03, worst
coords=[v.co for o in parts for v in o.data.vertices]
result={'backup':BACKUP,'patched':[o.name.removeprefix(NAME+'_') for o in targets],'islands':len(islands),
        'max_density_error_px_per_m':worst,'height_m':max(c.z for c in coords)-min(c.z for c in coords)}
