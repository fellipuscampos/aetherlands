"""Remove construction-grid edges, then repaint continuous faces into fresh packed images."""
import bpy,bmesh,math
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler
st=bpy.app.driver_namespace['veil_archon_blocky_v7'];scene=st['scene'];parts=st['parts']
assert not scene.get('continuous_surfaces_finished'),'This one-time surface repair has already run.'
bpy.context.window.scene=scene
before=sum(len(o.data.polygons) for o in parts)
for o in parts:
    bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()
    bmesh.ops.dissolve_limit(bm,angle_limit=.001,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=False,delimit=set())
    loose=[v for v in bm.verts if not v.link_edges]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    for p in o.data.polygons:p.use_smooth=False
    for uv in list(o.data.uv_layers):o.data.uv_layers.remove(uv)
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo');OUT=Path(st['out']);STEM=st['stem'];NAME=st['name']
source=(ROOT/'tools/art_pipeline/build_veil_archon_blocky_v7_mcp.py').read_text(encoding='utf-8')
exec(source[source.index('DENSITY=64; PAD=2; islands=[]'):source.index('images=[]')],globals())
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_Continuous_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB';im.pixels.foreach_set(data.reshape(-1))
    im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
for node in st['material'].node_tree.nodes:
    if node.type=='TEX_IMAGE':
        node.image=images[0] if node.image==st['images'][0] else images[1]
st.update(images=images,atlas=SIZE,islands=islands)
scene['continuous_surfaces_finished']=True
scene.render.filepath=str(OUT/'previews/three_quarter.png');bpy.ops.render.render(write_still=True)
for o in parts:o.data.calc_loop_triangles()
result={'faces_before':before,'faces_after':sum(len(o.data.polygons) for o in parts),
 'triangles':sum(len(o.data.loop_triangles) for o in parts),'atlas':SIZE,'fresh_pixel_maps':True}
