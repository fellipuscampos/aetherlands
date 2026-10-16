"""Inspect restored original human heads, painted white hair/hoods via MCP."""
import bpy,json,numpy as np,ast,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/human_school_mages_review'
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']
review=bpy.app.driver_namespace['human_school_mage_review_v1']; scene=review['scene']; camera=scene.camera
bpy.context.window.scene=scene
preferences=bpy.context.preferences.addons['cycles'].preferences
previous_compute=preferences.compute_device_type; previous_device=scene.cycles.device
preferences.compute_device_type='OPTIX'; preferences.get_devices()
for device in preferences.devices:
    if device.type=='OPTIX': device.use=True; scene.cycles.device='GPU'
contacts=[]
base=bpy.app.driver_namespace['human_school_mage_base']
original=next(o for o in base.objects if o.get('part')=='Head')
source_image=next(n.image for n in original.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
source_pixels=np.rint(np.array(source_image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
source=(ROOT/'tools/art_pipeline/restore_human_mage_heads_mcp.py').read_text(encoding='utf-8')
paint_namespace=dict(np=np,HOODS={'infernal':(102,48,40),'necromancy':(86,59,105),'elementalism':(93,129,130)})
for node in ast.parse(source).body:
    if isinstance(node,ast.FunctionDef) and node.name=='paint_head': exec(compile(ast.get_source_segment(source,node),'<restored_head_paint>','exec'),paint_namespace)
for a in assets:
    assert not any(o['part'].startswith('Grimoire_') for o in a['parts'])
    assert a['body']['Hand_l']['pose']=='relaxed_empty_hand'
    head=a['body']['Head']; image=next(n.image for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and 'albedo' in n.image.name)
    pixels=np.rint(np.array(image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    uv=head.data.uv_layers.active.data
    for face in head.data.polygons:
        points=np.array([list(uv[i].uv) for i in face.loop_indices])*512
        lo=np.floor(points.min(axis=0)).astype(int)
        w,h=np.ceil(points.max(axis=0)-lo-.5-.00002).astype(int)+1
        tile=pixels[lo[1]:lo[1]+h,lo[0]:lo[0]+w]
        srcuv=np.array([list(original.data.uv_layers.active.data[i].uv) for i in original.data.polygons[face.index].loop_indices])*512
        origin=np.floor(srcuv.min(axis=0)).astype(int)
        sampled=source_pixels[origin[1]:origin[1]+h,origin[0]:origin[0]+w]
        expected,_,_=paint_namespace['paint_head'](sampled,face.index,a['report']['school'])
        assert np.array_equal(tile,expected),(a['report']['school'],face.index,'Original head pixel layout changed')
    edges=[(head.data.vertices[e.vertices[0]].co-head.data.vertices[e.vertices[1]].co).length for e in head.data.edges]
    assert max(abs(length-.262702703) for length in edges)<1e-6
    assert not any(o['part'].startswith(('Grey_temple_','Grey_hair_back','Block_beard_','Hood_','Short_hood_')) for o in a['parts'])
    row=a['report']['style_validation']; row.update(actual_head_texture_verified=True,actual_head_size_verified=True)
    contacts.append(row)
old=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y)
fonts={o:o.hide_render for o in scene.objects if o.type=='FONT'}
try:
    if not globals().get('MAGE_INSPECT_SIDE_ONLY',False):
        camera.location=(3.5,-17,5); camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(WORK/'human_mages_three_quarter.png'); bpy.ops.render.render(write_still=True)
    for i,col in enumerate(review['collections']): col.hide_render=i!=4
    for o in fonts: o.hide_render=True
    target=review['roots'][4].location+Vector((0,0,1.0)); camera.location=target+Vector((5,-1.3,1.2)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=2.55; scene.render.resolution_x=scene.render.resolution_y=900
    scene.render.filepath=str(WORK/'arcanist_side_inspection.png'); bpy.ops.render.render(write_still=True)
finally:
    camera.location,camera.rotation_euler,camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y=old
    for col in review['collections']: col.hide_render=False
    for o,hidden in fonts.items(): o.hide_render=hidden
    preferences.compute_device_type=previous_compute; scene.cycles.device=previous_device
(WORK/'style_revision_validation.json').write_text(json.dumps(contacts,indent=2),encoding='utf-8')
result=dict(status='PASS',models=6,style_validation=contacts)
