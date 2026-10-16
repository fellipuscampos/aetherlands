"""Save compact static game assets and editable sources via the Blender MCP.

MAGE_FINISH is a school ID, or 'review' for the final shared scene.
"""
import bpy,json,hashlib,struct,bmesh
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/dwarf_school_mages_review'
assets=bpy.app.driver_namespace['dwarf_school_mage_assets_v1']
review=bpy.app.driver_namespace['dwarf_school_mage_review_v1']; review_scene=review['scene']; camera=review_scene.camera
audit=bpy.app.driver_namespace['dwarf_school_mage_surface_audit_v1']
preferences=bpy.context.preferences.addons['cycles'].preferences
previous_compute=preferences.compute_device_type; previous_device=review_scene.cycles.device
preferences.compute_device_type='OPTIX'; preferences.get_devices()
for device in preferences.devices:
    if device.type=='OPTIX': device.use=True; review_scene.cycles.device='GPU'

def stage(value):
    (WORK/'current_stage.json').write_text(json.dumps(dict(asset=MAGE_FINISH,stage=value)),encoding='utf-8')

def render_individual(asset):
    bpy.context.window.scene=review_scene
    saved=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale,review_scene.render.resolution_x,review_scene.render.resolution_y)
    fonts={o:o.hide_render for o in review_scene.objects if o.type=='FONT'}
    index=assets.index(asset); target=review['roots'][index].location+Vector((0,0,.84))
    try:
        for i,col in enumerate(review['collections']): col.hide_render=i!=index
        for obj in fonts: obj.hide_render=True
        review_scene.render.resolution_x=review_scene.render.resolution_y=700; camera.data.ortho_scale=2.40
        for name,offset in [('front',(0,-5,1.0)),('three_quarter',(2.5,-5,1.6)),('back',(-2.5,5,1.6))]:
            stage('render_'+name); camera.location=target+Vector(offset)
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            review_scene.render.filepath=str(asset['folder']/'previews'/(name+'.png')); bpy.ops.render.render(write_still=True)
    finally:
        for col in review['collections']: col.hide_render=False
        for obj,hidden in fonts.items(): obj.hide_render=hidden
        camera.location,camera.rotation_euler,camera.data.ortho_scale,review_scene.render.resolution_x,review_scene.render.resolution_y=saved

if MAGE_FINISH!='review':
    asset=next(a for a in assets if a['report']['school']==MAGE_FINISH)
    scene=asset['scene']; root=asset['root']; stem=asset['report']['stem']; folder=asset['folder']; parts=asset['parts']; report=asset['report']
    bpy.context.window.scene=scene; bpy.context.view_layer.update(); stage('final_geometry_checks')
    for part in parts:
        if 'settler_asset' in part: del part['settler_asset']
        part['dwarf_school_mage_asset']=True
    exposed,hidden=audit(parts); assert not exposed
    assert root.matrix_basis.is_identity and len(scene.objects)==len(parts)+1
    assert all(o.animation_data is None and o.type!='ARMATURE' for o in scene.objects)
    assert hashlib.sha256((ROOT/report['source']).read_bytes()).hexdigest()==report['source_sha256']
    report['source_preserved']=True
    report.update(blend=(folder/(stem+'.blend')).relative_to(ROOT).as_posix(),glb=(folder/(stem+'.glb')).relative_to(ROOT).as_posix(),texture=(folder/(stem+'_albedo.png')).relative_to(ROOT).as_posix())
    points=[]; vertices=[]; faces=[]; uvs=[]; triangles=0; max_uv_error=0
    for obj in parts:
        assert obj.matrix_basis.is_identity and not obj.modifiers and len(obj.data.materials)==1 and obj.data.materials[0]==asset['material']
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0 and all(f.calc_area()>1e-10 for f in bm.faces); bm.free()
        assert all(not p.use_smooth for p in obj.data.polygons)
        points.extend(v.co for v in obj.data.vertices)
        offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
        faces.extend(tuple(i+offset for i in p.vertices) for p in obj.data.polygons)
        triangles+=sum(len(p.vertices)-2 for p in obj.data.polygons)
        uv=obj.data.uv_layers.active.data; uvs.extend(tuple(loop.uv) for loop in uv)
        for p in obj.data.polygons:
            loops=list(p.loop_indices)
            for a,b in zip(loops,loops[1:]+loops[:1]):
                edge=(obj.data.vertices[obj.data.loops[a].vertex_index].co-obj.data.vertices[obj.data.loops[b].vertex_index].co).length
                max_uv_error=max(max_uv_error,abs((uv[a].uv-uv[b].uv).length*512/edge-64))
    assert triangles==report['geometry']['triangles'] and max_uv_error<.01
    lo=[min(p[i] for p in points) for i in range(3)]; hi=[max(p[i] for p in points) for i in range(3)]; assert abs(lo[2])<.00001
    report['geometry'].update(bounds_min=lo,bounds_max=hi,dimensions=[hi[i]-lo[i] for i in range(3)],uv_density_max_error=max_uv_error)
    report['surface_validation'].update(status='PASS',exposed_coplanar_pairs=0,hidden_coplanar_pairs=len(hidden),backface_culling=True)
    hashes={}
    for node in asset['material'].node_tree.nodes:
        if node.type!='TEX_IMAGE': continue
        image=node.image; suffix='emission' if Path(image.filepath_raw).stem.endswith('_emission') else 'albedo'
        digest=hashlib.sha256((folder/(stem+'_'+suffix+'.png')).read_bytes()).hexdigest()
        assert image.packed_file and hashlib.sha256(image.packed_file.data).hexdigest()==digest
        assert node.interpolation=='Closest'; hashes[suffix]=digest
    assert len(hashes)==2
    data=bpy.data.meshes.new(stem+'_Export_TEMP'); data.from_pydata(vertices,[],faces); data.update()
    uv=data.uv_layers.new(name='UVMap'); assert len(uv.data)==len(uvs)
    for loop,value in zip(uv.data,uvs): loop.uv=value
    data.materials.append(asset['material'])
    obj=bpy.data.objects.new(stem+'_Export_TEMP',data); scene.collection.objects.link(obj); obj.parent=root
    try:
        stage('export_glb')
        for item in scene.objects: item.select_set(False)
        obj.select_set(True); root.select_set(True); bpy.context.view_layer.objects.active=obj
        path=folder/(stem+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
        raw=path.read_bytes(); assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
        size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
        assert len(doc['meshes'])==len(doc['materials'])==1 and len(doc['images'])==2
        assert len(doc['meshes'][0]['primitives'])==1
        p=doc['meshes'][0]['primitives'][0]; assert doc['accessors'][p['indices']]['count']//3==triangles
        embedded_hashes=[]
        for img in doc['images']:
            view=doc['bufferViews'][img['bufferView']]; offset=view.get('byteOffset',0)
            embedded_hashes.append(hashlib.sha256(binary[offset:offset+view['byteLength']]).hexdigest())
        assert sorted(embedded_hashes)==sorted(hashes.values())
        assert all(s.get('magFilter')==9728 for s in doc['samplers'])
        assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE' and not doc['materials'][0].get('doubleSided',False)
        assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
        assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
        report['export']=dict(status='PASS',bytes=len(raw),triangles=triangles,meshes=1,surfaces=1,materials=1,embedded_images=2,atlas_hashes=hashes,animations=0,skins=0,cameras=0,lights=0,static_mesh_joined=True,editable_source_parts=len(parts))
        report['game_usage']=dict(units='meters',model_scale_multiplier=1.0,pivot='feet_at_origin',blender_front='-Y',godot_front='+Z',stage='static_model_review',game_database_changed=False)
    finally:
        bpy.data.objects.remove(obj,do_unlink=True)
        if data.users==0: bpy.data.meshes.remove(data)
    stage('save_editable_blend'); assert len(scene.objects)==len(parts)+1
    root.select_set(True); bpy.context.view_layer.objects.active=root; scene['mage_report']=json.dumps(report,ensure_ascii=False)
    bpy.data.libraries.write(str(folder/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    (folder/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    render_individual(asset)
    result=dict(status='PASS',school=MAGE_FINISH,triangles=triangles,meshes=1,materials=1,source_saved=True)
else:
    bpy.context.window.scene=review_scene
    for view,position in [('front',(0,-17,4.1)),('three_quarter',(3.5,-17,5)),('back',(-3.5,17,5))]:
        stage('render_review_'+view); camera.location=position
        camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
        review_scene.render.filepath=str(WORK/('dwarf_mages_'+view+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=(3.5,-17,5); camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
    bpy.ops.object.select_all(action='DESELECT'); review['roots'][0].select_set(True); bpy.context.view_layer.objects.active=review['roots'][0]
    stage('save_review_blend')
    bpy.data.libraries.write(str(WORK/'dwarf_school_mages_six_schools_review.blend'),{review_scene},path_remap='RELATIVE',fake_user=True,compress=True)
    output=dict(status='PASS',models=6,pipeline='Live Blender MCP localhost:9876',animations=0,rigging_deferred=True,exposed_coplanar_pairs=0,review_blend='art_source/dwarf_school_mages_review/dwarf_school_mages_six_schools_review.blend',assets=[a['report'] for a in assets])
    (ROOT/'docs/dwarf_school_mages_blender_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    (WORK/'modeling_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    (WORK/'manifest.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    result={k:v for k,v in output.items() if k!='assets'}
stage('complete')
preferences.compute_device_type=previous_compute; review_scene.cycles.device=previous_device
