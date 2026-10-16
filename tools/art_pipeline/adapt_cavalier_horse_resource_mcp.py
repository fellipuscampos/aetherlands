"""Copy the approved cavalry horse into a static map resource via Blender MCP."""
import bpy
import bmesh
import hashlib
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1.blend'
OUT=ROOT/'assets/generated/resources/horses/horse_resource_v1'
STEM='horse_resource_v1'; SCALE=.35
assert not (OUT/(STEM+'.glb')).exists(), 'Preserve existing adapted asset.'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
previous_scenes=[s.name for s in bpy.data.scenes]
reference=bpy.app.driver_namespace.get('resource_horse_reference')
if reference is None:
    with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded):
        loaded.scenes=[available.scenes[0]]
    reference=loaded.scenes[0]
    bpy.app.driver_namespace['resource_horse_reference']=reference
source_parts=sorted([o for o in reference.objects if o.type=='MESH'
    and o.get('part','').startswith('Horse') and not o.get('part','').startswith('HorseBit')],
    key=lambda o:o['part'])
assert len(source_parts)==19
assert all(o.matrix_basis==Matrix.Identity(4) for o in source_parts)
source_material=source_parts[0].data.materials[0]
base_node=next(n for n in source_material.node_tree.nodes if n.type=='TEX_IMAGE' and n.label=='Base Color')
source_image=base_node.image
source_pixels=np.empty(len(source_image.pixels),dtype=np.float32); source_image.pixels.foreach_get(source_pixels)
source_pixels=source_pixels.reshape(source_image.size[1],source_image.size[0],4)

coords=[v.co for o in source_parts for v in o.data.vertices]
lo=Vector(tuple(min(v[j] for v in coords) for j in range(3)))
hi=Vector(tuple(max(v[j] for v in coords) for j in range(3)))
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
scene=bpy.data.scenes.new('Horse_Map_Resource_V1'); bpy.context.window.scene=scene
root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
root['resource_id']='horses'; root['source_asset']='cavalier_v1'; root['source_scale']=SCALE
parts=[]; islands=[]; strap_pixels_removed=0
for source in source_parts:
    obj=source.copy(); obj.data=source.data.copy(); obj.name=STEM+'_'+source['part']
    scene.collection.objects.link(obj); obj.parent=root; obj.matrix_parent_inverse=Matrix.Identity(4)
    obj.matrix_basis=Matrix.Identity(4); obj.modifiers.clear(); obj.vertex_groups.clear(); obj.animation_data_clear()
    obj['source_part']=source['part']; obj['resource_id']='horses'
    for original,vertex in zip(source.data.vertices,obj.data.vertices):
        vertex.co=(original.co-center)*SCALE
        assert (vertex.co/SCALE+center-original.co).length<1e-6
    # Crop the actual painted source islands; no new face, coat or anatomy.
    for face in source.data.polygons:
        uv=np.array([list(source.data.uv_layers.active.data[i].uv) for i in face.loop_indices])
        uv*=np.array(source_image.size)
        lower=np.rint(uv.min(axis=0)).astype(int); upper=np.rint(uv.max(axis=0)).astype(int)
        w,h=upper-lower+1
        tile=source_pixels[lower[1]:upper[1]+1,lower[0]:upper[0]+1].copy()
        assert tile.shape[:2]==(h,w)
        if source['part']=='HorseHead':
            # Remove only the original painted leather bridle. Eyes, blaze,
            # muzzle and every other source pixel remain intact.
            leather=np.all(np.rint(tile[:,:,:3]*255).astype(int)==(70,44,28),axis=2)
            clean=np.argwhere(~leather)
            for y,x in np.argwhere(leather):
                nearest=clean[np.argmin(np.sum((clean-(y,x))**2,axis=1))]
                tile[y,x]=tile[tuple(nearest)]
                strap_pixels_removed+=1
        islands.append(dict(obj=obj,face=face.index,uv=uv,lower=lower,w=int(w),h=int(h),tile=tile))
    parts.append(obj)
assert strap_pixels_removed>0

# Pack only the horse's existing pixels, with gutters and nearest filtering.
SIZE=512; PAD=2
atlas=np.ones((SIZE,SIZE,4),dtype=np.float32); atlas[:,:,:3]=(.15,.11,.08)
x=y=PAD; row_height=0
for island in sorted(islands,key=lambda item:-item['h']):
    w,h=island['w'],island['h']
    if x+w+PAD>SIZE: x=PAD; y+=row_height+PAD*2; row_height=0
    assert y+h+PAD<=SIZE, 'Horse atlas exceeded 512 pixels.'
    tile=np.pad(island['tile'],((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    atlas[y-PAD:y+h+PAD,x-PAD:x+w+PAD]=tile
    face=island['obj'].data.polygons[island['face']]
    for index,point in zip(face.loop_indices,island['uv']):
        island['obj'].data.uv_layers.active.data[index].uv=(point-island['lower']+(x,y))/SIZE
    x+=w+PAD*2; row_height=max(row_height,h)
image=bpy.data.images.new(STEM+'_albedo',SIZE,SIZE,alpha=False)
image.pixels.foreach_set(atlas.ravel()); image.filepath_raw=str(OUT/(STEM+'_albedo.png'))
image.file_format='PNG'; image.save(); image.pack()
material=bpy.data.materials.new(STEM+'_Pixel_Material'); material.use_nodes=True; material.use_backface_culling=True
bsdf=material.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value=.88
bsdf.inputs['Specular IOR Level'].default_value=.25
texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image; texture.interpolation='Closest'
material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
triangles=0
for obj in parts:
    obj.data.materials.clear(); obj.data.materials.append(material)
    bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges); assert bm.calc_volume(signed=True)>1e-10
    bm.to_mesh(obj.data); bm.free(); obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    for face in obj.data.polygons: face.use_smooth=False
all_vertices=[v.co for o in parts for v in o.data.vertices]
height=max(v.z for v in all_vertices)
radius=max(math.hypot(v.x,v.y) for v in all_vertices)
assert radius<.46 and min(v.z for v in all_vertices)>-1e-6
assert len([o for o in scene.objects if o.type=='ARMATURE'])==0

# Join export copies; the native source retains nineteen editable body parts.
copies=[]
for obj in parts:
    copy=obj.copy(); copy.data=obj.data.copy(); scene.collection.objects.link(copy); copies.append(copy)
with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
    bpy.ops.object.join()
merged=copies[0]; merged.name='Horse_Resource_Mesh'; merged['source_asset']='cavalier_v1'
for obj in scene.objects: obj.select_set(False)
root.select_set(True); merged.select_set(True); bpy.context.view_layer.objects.active=merged
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,
    use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,
    export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
bpy.data.objects.remove(merged,do_unlink=True)
report=dict(asset=STEM,resource='horses',method='live Blender MCP',source_asset=str(SOURCE.relative_to(ROOT)),
    source_sha256=source_hash,source_geometry_preserved=True,source_painted_pixels_preserved=True,
    source_scale=SCALE,source_parts=[o['part'] for o in parts],removed='rider, saddle, blanket, stirrups, reins, bit and painted bridle',
    bridle_pixels_removed=strap_pixels_removed,triangles=triangles,height=height,footprint_radius=radius,
    materials=1,texture_size=[SIZE,SIZE],texture_filter='nearest',native_editable_parts=len(parts),
    previous_scenes=previous_scenes)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

world=bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.29,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,position,power,scale in [('Key',(2,-3,4),240,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=scale
    light=bpy.data.objects.new(name,ld); scene.collection.objects.link(light); light.location=position
    light.rotation_euler=(Vector((0,0,.3))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
camera=bpy.data.objects.new('Horse_Preview_Camera',cd); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for view,position,scale,aim in [('three_quarter',(1.8,-2.6,1.4),1.25,(0,0,.30)),
                              ('side',(3,0,1.25),1.25,(0,0,.30)),
                              ('game_top',(1.8,-2.9,4.9),2.0,(0,0,.15)),
                              ('top',(0,0,5),1.2,(0,0,0))]:
    camera.location=position; cd.ortho_scale=scale
    camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(1.8,-2.6,1.4); cd.ortho_scale=1.25
camera.rotation_euler=(Vector((0,0,.30))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result=report
