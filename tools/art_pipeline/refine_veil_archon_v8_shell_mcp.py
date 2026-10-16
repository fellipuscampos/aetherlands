"""Fit larger reference-like runic plates, preserving editable parts and rigid pivots."""
import bpy,bmesh,math
import numpy as np
from pathlib import Path
from mathutils import Vector,Euler
st=bpy.app.driver_namespace['veil_archon_blocky_v8'];scene=st['scene'];rig=st['rig'];parts=st['parts']
assert not scene.get('shell_fit_finished'),'This one-time shell fit has already run.'
bpy.context.window.scene=scene
core=next(o for o in parts if o['rig_bone']=='core');C=rig.data.bones['core'].head_local.copy()
factor=(core.data.vertices[0].co-C).length/(.96*math.sqrt(3)/2)
new_centers={}
for o in parts:
    if o['kind']!='plate':continue
    seed=int(o['rune_seed']);R=Euler(o['local_rotation'],'XYZ').to_matrix()
    old_c=rig.data.bones[o['rig_bone']].head_local.copy();delta=Vector((0,0,0))
    if seed<4:
        width,height=.60,.63;delta=Vector(((-1 if seed in (0,2) else 1)*.035,0,(1 if seed<2 else -1)*.035))
    elif seed<14:
        upper=(seed-4)%2==0;width,height=(1.12,.56) if upper else (1.04,.56)
        delta=Vector((0,0,.045 if upper else -.055))
    elif seed<26:width,height=.82,.80
    else:width,height=.80,.76
    c=old_c+R@(delta*factor);new_centers[o['rig_bone']]=c
    w=width/2;h=height/2;q=min(width,height)*.14;corner=seed>=26
    if corner:
        profile=[(-w,-h),(w,-h),(w,-h+q),(w-q,-h+q),(w-q,-h+2*q),
          (w-2*q,-h+2*q),(w-2*q,h-q),(q/2,h-q),(q/2,h),(-q/2,h),
          (-q/2,h-q),(-w+2*q,h-q),(-w+2*q,-h+2*q),(-w+q,-h+2*q),(-w+q,-h+q),(-w,-h+q)]
    else:
        profile=[(-w,-h),(w-q,-h),(w-q,-h+q),(w,-h+q),
          (w,h),(-w+q,h),(-w+q,h-q),(-w,h-q)]
    depth=.12 if corner else .14
    vs=[c+R@(Vector((x,y,z))*factor) for y in (-depth/2,depth/2) for x,z in profile]
    assert len(vs)==len(o.data.vertices)
    for v,co in zip(o.data.vertices,vs):v.co=co
    o.data.update()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,c in new_centers.items():
    b=rig.data.edit_bones[n];delta=c-b.head;b.head+=delta;b.tail+=delta
bpy.ops.object.mode_set(mode='OBJECT');scene.frame_set(1)
for o in parts:
    for uv in list(o.data.uv_layers):o.data.uv_layers.remove(uv)
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo');OUT=Path(st['out']);STEM=st['stem'];NAME=st['name']
source=(ROOT/'tools/art_pipeline/build_veil_archon_blocky_v8_mcp.py').read_text(encoding='utf-8')
exec(source[source.index('DENSITY=64; PAD=2; islands=[]'):source.index('images=[]')],globals())
images=[]
for suffix,data in [('albedo',pixels),('emission',energy)]:
    im=bpy.data.images.new(NAME+'_Fitted_'+suffix,width=SIZE,height=SIZE,alpha=True)
    im.colorspace_settings.name='sRGB';im.pixels.foreach_set(data.reshape(-1))
    im.filepath_raw=str(OUT/(STEM+'_'+suffix+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
for node in st['material'].node_tree.nodes:
    if node.type=='TEX_IMAGE':node.image=images[0] if node.image==st['images'][0] else images[1]
st.update(images=images,atlas=SIZE,islands=islands)
scene['shell_fit_finished']=True
scene.render.filepath=str(OUT/'previews/three_quarter.png');bpy.ops.render.render(write_still=True)
result={'larger_runic_plates':34,'pixel_maps_refreshed':True,'atlas':SIZE,'shell_fit_finished':True}
