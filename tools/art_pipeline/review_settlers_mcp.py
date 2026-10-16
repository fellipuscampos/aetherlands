"""Create only the four settlers' side-by-side review in the live Blender."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']
assert not bpy.data.scenes.get('Settlers_V1_Four_Civilizations_Review')
scene=bpy.data.scenes.new('Settlers_V1_Four_Civilizations_Review')
scene['settler_factory_owned']=True; scene['description']='Quatro colonizadores: humano, elfo, anão e orc. Modelos estáticos editáveis para revisão; sem animações.'
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1; scene.frame_set(1)
scene.render.engine='CYCLES'; scene.cycles.samples=16
scene.cycles.use_denoising=True
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
except (RuntimeError,TypeError): pass
scene.render.resolution_x=1800; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
world=bpy.data.worlds.new('Settlers_V1_StudioWorld'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.18,.21,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
scene.world=world
model_roots=[]; collections=[]
for index,asset in enumerate(assets):
    col=bpy.data.collections.new(asset['report']['name']); scene.collection.children.link(col); mapping={}
    for original in [asset['root']]+asset['parts']:
        obj=original.copy(); col.objects.link(obj); mapping[original]=obj
    for original,obj in mapping.items():
        if original.parent in mapping: obj.parent=mapping[original.parent]
    root=mapping[asset['root']]; root.location=((index-1.5)*2,0,0)
    model_roots.append(root); collections.append(col)
    font=bpy.data.curves.new('Settlers_V1_Label_'+asset['report']['race'],'FONT')
    font.body=asset['report']['name'].replace('Colonizador ','').upper()
    font.align_x='CENTER'; font.size=.145; font.extrude=0
    label=bpy.data.objects.new(font.name,font); col.objects.link(label)
    label.location=(root.location.x,-.61,.016); label.rotation_euler=(math.pi/2,0,0)
    mat=bpy.data.materials.new(font.name+'_Mat'); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Base Color'].default_value=(.81,.77,.63,1); bsdf.inputs['Roughness'].default_value=1
    font.materials.append(mat)
studio=bpy.data.collections.new('Settlers_V1_Review_Studio'); scene.collection.children.link(studio)
data=bpy.data.meshes.new('Settlers_V1_StudioFloor')
data.from_pydata([(-30,-30,-.025),(30,-30,-.025),(30,30,-.025),(-30,30,-.025)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(data.name,data); studio.objects.link(floor)
mat=bpy.data.materials.new('Settlers_V1_StudioFloor_Mat'); mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.084,.105,.121,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
floor.data.materials.append(mat)
for name,position,power,size in [('Key',(-4,-6,8),1600,7),('Fill',(7,-3,6),1200,6),('Rim',(0,5,7),1800,6)]:
    lamp=bpy.data.lights.new('Settlers_V1_'+name,'AREA'); lamp.energy=power; lamp.size=size
    obj=bpy.data.objects.new(lamp.name,lamp); studio.objects.link(obj); obj.location=position
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Settlers_V1_Review_Camera'); camera_data.type='ORTHO'; camera_data.ortho_scale=8.7
camera=bpy.data.objects.new(camera_data.name,camera_data); studio.objects.link(camera); scene.camera=camera
target=Vector((0,0,.90))
try:
    for view,position in [('front',(0,-14,4.9)),('three_quarter',(4.3,-15,6.2)),('back',(-4.3,15,6.2))]:
        (WORK/'current_stage.json').write_text(json.dumps(dict(stage='review_render_'+view)),encoding='utf-8')
        camera.location=position; camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(WORK/('settlers_'+view+'.png'))
        bpy.ops.render.render(write_still=True)
finally: prefs.compute_device_type=previous_compute
camera.location=(4.3,-15,6.2); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.app.driver_namespace['settlers_v1_review']=dict(scene=scene,roots=model_roots,collections=collections,studio=studio,target=target)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT'); model_roots[0].select_set(True); bpy.context.view_layer.objects.active=model_roots[0]
(WORK/'current_stage.json').write_text(json.dumps(dict(stage='review_ready')),encoding='utf-8')
result={'scene':scene.name,'models':4,'animations':0}
