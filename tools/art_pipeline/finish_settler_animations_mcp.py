"""Export one animated settler with one skinned runtime mesh and two clips."""
import bpy,json,struct,hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']; review=bpy.app.driver_namespace['settlers_v1_review']
asset=next(a for a in assets if a['report']['race']==SETTLER_RACE)
scene=asset['scene']; root=asset['root']; rig=asset['rig']; parts=asset['parts']; folder=asset['folder']; report=asset['report']; stem=root.name
bpy.context.window.scene=scene; scene.frame_set(1); bpy.context.view_layer.update()
points=[v.co for item in parts for v in item.data.vertices]
lo=[min(p[i] for p in points) for i in range(3)]; hi=[max(p[i] for p in points) for i in range(3)]
report['geometry'].update(bounds_min=lo,bounds_max=hi,dimensions=[round(hi[i]-lo[i],6) for i in range(3)])
(WORK/'current_stage.json').write_text(json.dumps(dict(race=SETTLER_RACE,stage='export_animated_glb')),encoding='utf-8')
vertices=[]; faces=[]; uvs=[]; spans=[]
for obj in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(i+offset for i in p.vertices) for p in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices)))
data=bpy.data.meshes.new(stem+'_RuntimeExport_TEMP'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(parts[0].data.materials[0])
uv=data.uv_layers.new(name='UVMap')
for loop,value in zip(uv.data,uvs): loop.uv=value
obj=bpy.data.objects.new(stem+'_Body',data); scene.collection.objects.link(obj); obj.parent=rig
groups={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1.,'REPLACE')
modifier=obj.modifiers.new('Settler_Rigid_Skin','ARMATURE'); modifier.object=rig
try:
    for item in scene.objects: item.select_set(False)
    for item in (obj,rig,root): item.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for track in rig.animation_data.nla_tracks: track.mute=False; track.is_solo=False
    path=folder/(stem+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
    raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert sorted(a['name'] for a in doc['animations'])==['idle','walk']
    assert len(doc['skins'])==len(doc['meshes'])==len(doc['images'])==len(doc['materials'])==1
    assert len(doc['meshes'][0]['primitives'])==1
    assert len(doc['skins'][0]['joints'])==16
    primitive=doc['meshes'][0]['primitives'][0]; assert 'JOINTS_0' in primitive['attributes'] and 'WEIGHTS_0' in primitive['attributes']
    assert doc['accessors'][primitive['indices']]['count']//3==report['geometry']['triangles']
    view=doc['bufferViews'][doc['images'][0]['bufferView']]; embedded=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
    texture_sha=hashlib.sha256((folder/(stem+'_albedo.png')).read_bytes()).hexdigest()
    assert hashlib.sha256(embedded).hexdigest()==texture_sha
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    report['export']=dict(bytes=len(raw),triangles=report['geometry']['triangles'],meshes=1,surfaces=1,materials=1,skins=1,bones=16,animations=2,clips=['idle','walk'],atlas_sha256=texture_sha,editable_source_parts=len(parts),cameras=0,lights=0)
finally:
    bpy.data.objects.remove(obj,do_unlink=True)
    if data.users==0: bpy.data.meshes.remove(data)
scene.use_preview_range=True; scene.frame_preview_start=1; scene.frame_preview_end=145; scene.frame_set(1)
scene['settler_report']=json.dumps(report,ensure_ascii=False)
bpy.data.libraries.write(str(folder/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
(folder/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.context.window.scene=review['scene']; review['scene'].frame_set(161)
result={'asset':stem,'status':'PASS','animations':['idle','walk'],'meshes':1,'skins':1,'bones':16}
