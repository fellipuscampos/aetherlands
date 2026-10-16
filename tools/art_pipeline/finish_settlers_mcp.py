"""Export and render one settler, or save the full side-by-side final review."""
import bpy, json, struct, hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']
review=bpy.app.driver_namespace['settlers_v1_review']
audit=bpy.app.driver_namespace['settlers_v1_surface_audit']
review_scene=review['scene']; camera=review_scene.camera
prefs=bpy.context.preferences.addons['cycles'].preferences
previous_compute=prefs.compute_device_type
try:
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    if any(d.type=='OPTIX' and d.use for d in prefs.devices): review_scene.cycles.device='GPU'
except (RuntimeError,TypeError): pass

def stage(value):
    (WORK/'current_stage.json').write_text(json.dumps(dict(asset=SETTLER_FINISH,stage=value)),encoding='utf-8')

try:
    if SETTLER_FINISH!='review':
        asset=next(a for a in assets if a['report']['race']==SETTLER_FINISH)
        scene=asset['scene']; root=asset['root']; folder=asset['folder']; report=asset['report']
        stem=root.name; stage('geometry_final_checks')
        bpy.context.window.scene=scene; bpy.context.view_layer.update()
        exposed,hidden=audit(asset['parts']); assert not exposed,[(r['a'],r['b']) for r in exposed]
        report['surface_validation']=dict(status='PASS',exposed_coplanar_pairs=0,hidden_coplanar_pairs=len(hidden),backface_culling=True)
        assert root.matrix_basis.is_identity and root.animation_data is None
        assert not any(o.type=='ARMATURE' for o in scene.objects)
        assert all(o.animation_data is None for o in scene.objects)
        assert hashlib.sha256((ROOT/report['source']).read_bytes()).hexdigest()==report['source_sha256'],'Read-only source changed'
        for obj in scene.objects: obj.select_set(False)
        for obj in [root]+asset['parts']: obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        stage('export_glb')
        path=folder/(stem+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,export_cameras=False,export_lights=False,export_extras=True)
        raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
        doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
        assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
        assert len(doc['materials'])==len(doc['images'])==1
        assert len(doc['meshes'])==len(asset['parts'])
        assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
        assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
        assert all(s.get('magFilter')==9728 for s in doc['samplers'])
        assert doc['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE'
        assert not doc['materials'][0].get('doubleSided',False)
        tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
        assert tris==report['geometry']['triangles']
        view=doc['bufferViews'][doc['images'][0]['bufferView']]
        png=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        atlas_sha=hashlib.sha256((folder/(stem+'_albedo.png')).read_bytes()).hexdigest()
        assert hashlib.sha256(png).hexdigest()==atlas_sha
        report['export']=dict(bytes=len(raw),triangles=tris,meshes=len(doc['meshes']),materials=1,atlas_sha256=atlas_sha,animations=0,skins=0,cameras=0,lights=0)
        report['source_preserved']=True
        # Source file deliberately contains only this character's editable meshes.
        scene['settler_report']=json.dumps(report,ensure_ascii=False)
        stage('save_individual_blend')
        bpy.data.libraries.write(str(folder/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
        (folder/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        # Render the exact same mesh datablocks in the common lit review studio.
        bpy.context.window.scene=review_scene
        saved_position=camera.location.copy(); saved_rotation=camera.rotation_euler.copy(); saved_scale=camera.data.ortho_scale
        old_resolution=(review_scene.render.resolution_x,review_scene.render.resolution_y)
        hidden_fonts={o:o.hide_render for o in review_scene.objects if o.type=='FONT'}
        index=assets.index(asset); target=review['roots'][index].location+Vector((0,.05,report['geometry']['dimensions'][2]/2))
        try:
            for i,col in enumerate(review['collections']): col.hide_render=i!=index
            for obj in hidden_fonts: obj.hide_render=True
            review_scene.render.resolution_x=review_scene.render.resolution_y=700
            camera.data.ortho_scale=report['geometry']['dimensions'][2]*1.40
            for name,offset in [('front',(0,-5,1.45)),('three_quarter',(2.6,-5,2.2)),('back',(-2.6,5,2.2))]:
                stage('render_'+name)
                camera.location=target+Vector(offset); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
                review_scene.render.filepath=str(folder/'previews'/(name+'.png'))
                bpy.ops.render.render(write_still=True)
        finally:
            for col in review['collections']: col.hide_render=False
            for obj,hidden_value in hidden_fonts.items(): obj.hide_render=hidden_value
            camera.location=saved_position; camera.rotation_euler=saved_rotation; camera.data.ortho_scale=saved_scale
            review_scene.render.resolution_x,review_scene.render.resolution_y=old_resolution
        result={'asset':stem,'triangles':tris,'parts':len(asset['parts']),'status':'PASS','exposed_coplanar_pairs':0}
    else:
        bpy.context.window.scene=review_scene
        for view,position in [('front',(0,-14,4.9)),('three_quarter',(4.3,-15,6.2)),('back',(-4.3,15,6.2))]:
            stage('render_final_'+view); camera.location=position
            camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
            review_scene.render.filepath=str(WORK/('settlers_'+view+'.png'))
            bpy.ops.render.render(write_still=True)
        camera.location=(4.3,-15,6.2); camera.rotation_euler=(review['target']-camera.location).to_track_quat('-Z','Y').to_euler()
        for area in bpy.context.screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.shading.type='MATERIAL'
                area.spaces.active.region_3d.view_perspective='CAMERA'
                area.spaces.active.overlay.show_overlays=False
        bpy.ops.object.select_all(action='DESELECT'); review['roots'][0].select_set(True); bpy.context.view_layer.objects.active=review['roots'][0]
        stage('save_review_blend')
        bpy.data.libraries.write(str(WORK/'settlers_four_civilizations_review.blend'),{review_scene},path_remap='RELATIVE',fake_user=True,compress=True)
        output=dict(status='PASS',verified=4,pipeline='Live Blender MCP localhost:9876',animations=0,rigging_deferred=True,exposed_coplanar_pairs=0,review_scene=review_scene.name,review_blend='art_source/settlers_review/settlers_four_civilizations_review.blend',assets=[a['report'] for a in assets])
        (ROOT/'docs/settlers_blender_validation.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
        result={k:v for k,v in output.items() if k!='assets'}
finally: prefs.compute_device_type=previous_compute
stage('complete')
