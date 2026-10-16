"""Replace the unfinished V4 wing panels with the traced reference silhouette."""
import bpy, bmesh, math
import numpy as np
from pathlib import Path
from mathutils import Vector, Euler, Matrix

st=bpy.app.driver_namespace['seraph_blocky_v4']
NAME,STEM,OUT=st['name'],st['stem'],Path(st['out'])
scene,parts,rig=st['scene'],st['parts'],st['rig']
bpy.context.window.scene=scene
builder=(OUT.parents[3]/'tools/art_pipeline/build_seraph_blocky_v4_mcp.py').read_text(encoding='utf-8')
outline_code=builder[builder.index('def reference_outline():'):builder.index('# Retain the exact approved core')]
exec(outline_code)
old=bpy.app.driver_namespace['seraph_blocky_v3']
factor=old['rig'].data.bones['core'].head_local.y/-.92
zoffset=old['rig'].data.bones['body'].head_local.z-1.75*factor
settings={'main':((.46,.15,1.97),1.0,13,18),
          'lower':((.45,.03,1.54),.80,-45,-22),
          'crown':((.25,.43,2.02),.54,68,52)}
for o in parts:
    if o['kind']!='wing_feather': continue
    band=o['wing_band']; sign=1 if o['rig_bone'].endswith('_R') else -1
    root_position,scale,angle,yaw=settings[band]
    pivot=Vector((sign*root_position[0],root_position[1],root_position[2]))
    R=Matrix.Rotation(sign*math.radians(yaw),3,'Z')@Matrix.Rotation(-sign*math.radians(angle),3,'Y')
    profile=[(sign*x*scale,z*scale) for x,z in reference_outline()]
    depth=.11 if band!='crown' else .085; n=len(profile)
    coords=[pivot+R@Vector((x,y,z)) for y in (-depth/2,depth/2) for x,z in profile]
    coords=[Vector((c.x*factor,c.y*factor,c.z*factor+zoffset)) for c in coords]
    anchor=rig.data.bones[o['rig_bone']].head_local
    stretch=1.0
    if band=='lower': stretch=(.22-anchor.z)/(min(c.z for c in coords)-anchor.z)
    elif band=='crown': stretch=(3.22-anchor.z)/(max(c.z for c in coords)-anchor.z)
    for c in coords: c.z=anchor.z+(c.z-anchor.z)*stretch
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    faces.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    previous=o.data
    me=bpy.data.meshes.new(o.name+'_Traced'); me.from_pydata(coords,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    o.data=me; o['local_rotation']=list(R.to_euler('XYZ'))
    o.vertex_groups.clear(); o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(me.vertices))),1,'REPLACE')
    if previous.users==0: bpy.data.meshes.remove(previous)

# Regenerate the atlas with the same materials and the new feather outlines.
for o in parts:
    for uv in list(o.data.uv_layers): o.data.uv_layers.remove(uv)
palette_code=builder[builder.index('DENSITY=64;'):builder.index('images=[]')]
exec(palette_code)
for im,data in zip(st['images'],(pixels,energy)):
    if im.size[0]!=SIZE: im.scale(SIZE,SIZE)
    im.pixels.foreach_set(data.reshape(-1)); im.save(); im.pack()
for o in parts:
    if len(o.data.materials)==0: o.data.materials.append(st['material'])
    o.data.calc_loop_triangles()
st['atlas']=SIZE; st['islands']=islands
scene.frame_set(1)
scene.render.filepath=str(OUT/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
result={'reference_contour_traced':True,'wing_panels':6,'parts':len(parts),
        'triangles':sum(len(o.data.loop_triangles) for o in parts)}
