"""Repair the three existing human wall assets through the running Blender MCP."""
import bpy, json, sys, hashlib, struct, shutil, importlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/human_walls_review'
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
import human_wall_surface_cleanup as cleanup
importlib.reload(cleanup)
reports=[]
states=bpy.app.driver_namespace.get('human_walls_v1',[])
for level in (1,2,3):
    stem=f'human_walls_level_{level}_hex_v1'
    name=f'Human_Walls_Level_{level}_Hex_V1'
    out=ROOT/'assets/generated/humans/buildings'/stem
    scene=bpy.data.scenes.get(name)
    if scene is None:
        with bpy.data.libraries.load(str(out/(stem+'.blend')),link=False) as (available,loaded): loaded.scenes=[name]
        scene=loaded.scenes[0]
    bpy.context.window.scene=scene
    state=next((s for s in states if s['scene']==scene),None)
    parts=state['parts'] if state else [o for o in scene.objects if o.type=='MESH' and o.get('part')]
    root=next(o for o in scene.objects if o.type=='EMPTY')
    assert all(o.matrix_world==root.matrix_world for o in parts)
    backup=WORK/'before_face_cleanup'/stem
    backup.mkdir(parents=True,exist_ok=True)
    for suffix in ('.blend','.glb','_report.json'):
        original=out/(stem+suffix)
        if not (backup/original.name).exists(): shutil.copy2(original,backup/original.name)
    old_report=json.loads((out/(stem+'_report.json')).read_text(encoding='utf-8'))
    before=cleanup.audit_coplanar(parts,include_opposing=True)
    if old_report.get('surface_cleanup') and not before:
        reports.append(dict(level=level,triangles=old_report['triangles'],**old_report['surface_cleanup']))
        continue
    temporary=bpy.data.collections.new(name+'_FACE_REPAIR_TEST')
    scene.collection.children.link(temporary)
    copies=[]
    try:
        for original in parts:
            copy=original.copy(); copy.data=original.data.copy()
            temporary.objects.link(copy); copies.append(copy)
        summary=cleanup.clean_human_wall_surfaces(copies)
        after=cleanup.audit_coplanar(copies,include_opposing=True)
        assert not after, json.dumps(dict(level=level,remaining=len(after),examples=after[:12]))
        old_vertices=[v.co for obj in parts for v in obj.data.vertices]
        new_vertices=[v.co for obj in copies for v in obj.data.vertices]
        for axis in range(3):
            assert abs(min(v[axis] for v in old_vertices)-min(v[axis] for v in new_vertices))<2e-6
            assert abs(max(v[axis] for v in old_vertices)-max(v[axis] for v in new_vertices))<2e-6
        # Successful copies replace only the mesh data of our existing pieces.
        for original,copy in zip(parts,copies):
            old=original.data
            original.data=copy.data
            original['surface_cleanup']=copy['surface_cleanup']
            if old.users==0: bpy.data.meshes.remove(old)
    finally:
        for copy in list(temporary.objects):
            data=copy.data
            bpy.data.objects.remove(copy,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
        bpy.data.collections.remove(temporary)
    visible=[o for o in parts if len(o.data.polygons)]
    triangles=sum(len(face.vertices)-2 for obj in visible for face in obj.data.polygons)
    export_collection=bpy.data.collections.new(name+'_CLEAN_EXPORT')
    scene.collection.children.link(export_collection)
    try:
        meshes=[]
        for group in ('Architecture','Faction'):
            selected=[]
            for original in visible:
                if original['group']!=group: continue
                copy=original.copy(); copy.data=original.data.copy()
                export_collection.objects.link(copy); selected.append(copy)
            if not selected: continue
            if len(selected)>1:
                with bpy.context.temp_override(active_object=selected[0],selected_editable_objects=selected,selected_objects=selected): bpy.ops.object.join()
            selected[0].name=name+'_'+group
            meshes.append(selected[0])
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for mesh in meshes: mesh.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.gltf(filepath=str(out/(stem+'.glb')),export_format='GLB',use_selection=True,
            use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,
            export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    finally:
        for obj in list(export_collection.objects):
            data=obj.data
            bpy.data.objects.remove(obj,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
        bpy.data.collections.remove(export_collection)
    raw=(out/(stem+'.glb')).read_bytes()
    size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert triangles==sum(doc['accessors'][p['indices']]['count']//3 for mesh in doc['meshes'] for p in mesh['primitives'])
    expected={im['sha256'] for im in old_report['embedded_images']}
    for im in doc['images']:
        view=doc['bufferViews'][im['bufferView']]
        image=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        assert hashlib.sha256(image).hexdigest() in expected
    summary.update(coplanar_overlaps_before=len(before),coplanar_overlaps_after=0,
                   silhouette_bounds_unchanged=True,atlas_bytes_unchanged=True,method='Visible boundary partition, interpolated original UVs')
    old_report.update(triangles=triangles,surface_cleanup=summary)
    old_report.pop('nonmanifold_edges',None)
    old_report['source_boundary_sections']=True
    (out/(stem+'_report.json')).write_text(json.dumps(old_report,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    reports.append(dict(level=level,triangles=triangles,**summary))
baseline=json.loads((WORK/'source_baseline.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest for name,digest in baseline.items())
result=dict(status='PASS',previous_city_assets_unchanged=True,levels=reports)
(WORK/'face_cleanup_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
(ROOT/'docs/human_walls_face_cleanup_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
