"""Side-by-side dwarf casters, linked to the editable meshes."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/dwarf_school_mages_review'
assets=bpy.app.driver_namespace['dwarf_school_mage_assets_v1']
name='Dwarf_School_Mages_V1_Six_Schools_Review'
assert bpy.data.scenes.get(name) is None
scene=bpy.data.scenes.new(name); bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'; scene.frame_start=scene.frame_end=1
scene['dwarf_school_mage_owned']=True; scene['description']='Seis magos anões: Sagrada, Infernal, Necromancia, Druidismo, Arcanismo e Elementalismo. Anatomia, nariz e barba anã originais; cabelos grisalhos e vestes simples nas cores das escolas, cobre, aço, couro e pedra nos adereços.'
scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
except (RuntimeError,TypeError): pass
scene.render.resolution_x=2400; scene.render.resolution_y=950; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
world=bpy.data.worlds.new(name+'_World'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.18,.21,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6; scene.world=world
collections=[]; roots=[]
labels=['SAGRADA','INFERNAL','NECROMANCIA','DRUIDISMO','ARCANISMO','ELEMENTALISMO']
for index,asset in enumerate(assets):
    col=bpy.data.collections.new(asset['report']['name']); scene.collection.children.link(col); mapping={}
    for original in [asset['root']]+asset['parts']:
        obj=original.copy(); col.objects.link(obj); mapping[original]=obj
    for original,obj in mapping.items():
        if original.parent in mapping: obj.parent=mapping[original.parent]
    root=mapping[asset['root']]; root.location=((index-2.5)*1.80,0,0); roots.append(root); collections.append(col)
    font=bpy.data.curves.new(name+'_Label_'+asset['report']['school'],'FONT'); font.body=labels[index]
    font.align_x='CENTER'; font.size=.115; font.extrude=0
    label=bpy.data.objects.new(font.name,font); col.objects.link(label); label.location=(root.location.x,-.79,.025); label.rotation_euler=(math.pi/2,0,0)
    mat=bpy.data.materials.new(font.name+'_Material'); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.80,.77,.65,1); font.materials.append(mat)
studio=bpy.data.collections.new(name+'_Studio'); scene.collection.children.link(studio)
data=bpy.data.meshes.new(name+'_Floor'); data.from_pydata([(-30,-30,-.025),(30,-30,-.025),(30,30,-.025),(-30,30,-.025)],[],[(0,1,2,3)])
floor=bpy.data.objects.new(data.name,data); studio.objects.link(floor)
mat=bpy.data.materials.new(name+'_FloorMaterial'); mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.084,.105,.121,1); mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
floor.data.materials.append(mat)
for label,position,power,size in [('Key',(-4,-6,8),1600,7),('Fill',(7,-3,6),1200,6),('Rim',(0,5,7),1800,6)]:
    data=bpy.data.lights.new(name+'_'+label,'AREA'); data.energy=power; data.size=size
    obj=bpy.data.objects.new(data.name,data); studio.objects.link(obj); obj.location=position
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new(name+'_Camera'); data.type='ORTHO'; data.ortho_scale=11.5
camera=bpy.data.objects.new(data.name,data); studio.objects.link(camera); scene.camera=camera
target=Vector((0,-.03,0.80)); camera.location=(0,-17,4.1); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
try:
    (WORK/'current_stage.json').write_text(json.dumps(dict(stage='review_first_render')),encoding='utf-8')
    scene.render.filepath=str(WORK/'dwarf_mages_front.png'); bpy.ops.render.render(write_still=True)
finally: prefs.compute_device_type=previous_compute
bpy.app.driver_namespace['dwarf_school_mage_review_v1']=dict(scene=scene,roots=roots,collections=collections,studio=studio,target=target)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT'); roots[0].select_set(True); bpy.context.view_layer.objects.active=roots[0]
result=dict(scene=scene.name,models=6,render='art_source/dwarf_school_mages_review/dwarf_mages_front.png')
