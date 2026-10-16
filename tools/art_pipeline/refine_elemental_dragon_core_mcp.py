"""Give the free elemental heart clearance for its future rotation."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM=globals().get('DRAGON_STEM','elemental_dragon_v1'); OUT=ROOT/'assets/generated/grand_manifestations'/STEM
st=bpy.app.driver_namespace[STEM]; scene=st['scene']; rig=st['rig']; root=st['root']; parts=st['parts']
bpy.context.window.scene=scene
if 'DRAGON_CORE_DELTA' in globals():
    delta=Vector(DRAGON_CORE_DELTA)
else:
    factor=-st['report']['core_center_m'][1]/.96
    delta=Vector((0,-.14*factor,0))
for obj in parts:
    if obj['rig_bone']=='core':
        for vertex in obj.data.vertices: vertex.co+=delta
        obj.data.update()
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones['core'].head+=delta; rig.data.edit_bones['core'].tail+=delta
bpy.ops.object.mode_set(mode='OBJECT')
vertices=[]; faces=[]; uvs=[]; groups={}
for obj in parts:
    start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    for v in obj.data.vertices:
        for influence in v.groups:
            name=obj.vertex_groups[influence.group].name
            groups.setdefault(name,[]).append((start+v.index,influence.weight))
data=bpy.data.meshes.new(STEM+'_Runtime_Core_Clearance'); data.from_pydata(vertices,[],faces); data.update()
data.materials.append(parts[0].data.materials[0]); uv=data.uv_layers.new(name='PixelUV')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
for name,rows in groups.items():
    group=runtime.vertex_groups.new(name=name)
    for index,weight in rows: group.add([index],weight,'REPLACE')
runtime.modifiers.new('Dragon_Skin','ARMATURE').object=rig
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=False,export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
bpy.data.objects.remove(runtime,do_unlink=True)
st['report']['core_center_m']=list(rig.data.bones['core'].head_local)
coords=[v.co for obj in parts for v in obj.data.vertices]
st['report']['size_m']=[max(v[j] for v in coords)-min(v[j] for v in coords) for j in range(3)]
(OUT/(STEM+'_report.json')).write_text(json.dumps(st['report'],indent=2),encoding='utf-8')
camera=scene.camera
for view,pos in [('three_quarter',(5,-9,4.4)),('front',(0,-9,2.1)),('back',(-5,9,4.3)),('side',(9,-.3,3.4))]:
    camera.location=pos; camera.rotation_euler=(Vector((0,-.1,1.8))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(5,-9,4.4); camera.rotation_euler=(Vector((0,-.1,1.8))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result={'core_center':st['report']['core_center_m'],'height_m':st['report']['height_m']}
