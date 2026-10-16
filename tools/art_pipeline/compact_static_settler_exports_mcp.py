"""Single-mesh static GLBs; keep every editable source part in each BLEND."""
import bpy,json,hashlib,struct
from pathlib import Path

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']
review=bpy.app.driver_namespace['settlers_v1_review']['scene']
for asset in assets:
    scene=asset['scene']; root=asset['root']; stem=root.name; parts=asset['parts']
    bpy.context.window.scene=scene
    (WORK/'current_stage.json').write_text(json.dumps(dict(asset=stem,stage='compact_static_glb')),encoding='utf-8')
    vertices=[]; faces=[]; uvs=[]
    material=parts[0].data.materials[0]
    for obj in parts:
        assert obj.matrix_basis.is_identity and obj.data.materials[0]==material
        offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
        faces.extend(tuple(i+offset for i in p.vertices) for p in obj.data.polygons)
        uvs.extend(tuple(loop.uv) for loop in obj.data.uv_layers.active.data)
    data=bpy.data.meshes.new(stem+'_StaticExport_TEMP'); data.from_pydata(vertices,[],faces); data.update()
    uv=data.uv_layers.new(name='UVMap'); assert len(uv.data)==len(uvs)
    for loop,value in zip(uv.data,uvs): loop.uv=value
    data.materials.append(material)
    obj=bpy.data.objects.new(stem+'_StaticMesh_TEMP',data); scene.collection.objects.link(obj); obj.parent=root
    obj['asset_stage']='static_preview'; obj['editable_parts_preserved_in_blend']=True
    try:
        for item in scene.objects: item.select_set(False)
        root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
        path=asset['folder']/(stem+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
        raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
        assert len(doc['meshes'])==len(doc['materials'])==len(doc['images'])==1
        assert len(doc['meshes'][0]['primitives'])==1
        primitive=doc['meshes'][0]['primitives'][0]
        triangles=doc['accessors'][primitive['indices']]['count']//3
        assert triangles==asset['report']['geometry']['triangles']
        view=doc['bufferViews'][doc['images'][0]['bufferView']]
        embedded=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        digest=hashlib.sha256((asset['folder']/(stem+'_albedo.png')).read_bytes()).hexdigest()
        assert hashlib.sha256(embedded).hexdigest()==digest
        assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
        assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
        assert all(s.get('magFilter')==9728 for s in doc['samplers'])
        assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE' and not doc['materials'][0].get('doubleSided',False)
        asset['report']['export']=dict(bytes=len(raw),triangles=triangles,meshes=1,surfaces=1,materials=1,atlas_sha256=digest,animations=0,skins=0,cameras=0,lights=0,static_mesh_joined=True,editable_source_parts=len(parts))
    finally:
        bpy.data.objects.remove(obj,do_unlink=True)
        if data.users==0: bpy.data.meshes.remove(data)
    root.select_set(True); bpy.context.view_layer.objects.active=root
    assert len(scene.objects)==len(parts)+1
    scene['settler_report']=json.dumps(asset['report'],ensure_ascii=False)
    bpy.data.libraries.write(str(asset['folder']/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    (asset['folder']/(stem+'_report.json')).write_text(json.dumps(asset['report'],ensure_ascii=False,indent=2),encoding='utf-8')
bpy.context.window.scene=review
report_path=ROOT/'docs/settlers_blender_validation.json'
report=json.loads(report_path.read_text(encoding='utf-8')); report['assets']=[a['report'] for a in assets]; report['static_glb_meshes_per_asset']=1
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'modeling_validation.json').write_text(json.dumps(dict(status='PASS',assets=[a['report'] for a in assets]),ensure_ascii=False,indent=2),encoding='utf-8')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT'); root=bpy.app.driver_namespace['settlers_v1_review']['roots'][0]; root.select_set(True); bpy.context.view_layer.objects.active=root
bpy.data.libraries.write(str(WORK/'settlers_four_civilizations_review.blend'),{review},path_remap='RELATIVE',fake_user=True,compress=True)
(WORK/'current_stage.json').write_text(json.dumps(dict(stage='complete',assets=4)),encoding='utf-8')
result={'verified':4,'meshes_per_glb':1,'surfaces_per_glb':1,'animations':0,'editable_blend_parts_preserved':True,'active_scene':review.name}
