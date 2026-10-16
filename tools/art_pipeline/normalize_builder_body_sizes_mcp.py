"""Set anatomical builder height independently of hats, hair and held tools."""
import bpy,json,hashlib,shutil
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
BACKUP=ROOT/'art_source/builders_size_review/before_body_normalization'
BACKUP.mkdir(parents=True,exist_ok=True); (BACKUP.parent/'.gdignore').touch()
results=[]
for race,family,target in [('human','humans',1.8),('elf','elves',1.8),('orc','orcs',2.0),('dwarf','dwarves',1.35)]:
    stem=race+'_builder_v1'; out=ROOT/f'assets/generated/{family}/{stem}'
    backup=BACKUP/race; backup.mkdir(exist_ok=True)
    for name in [stem+'.blend',stem+'.glb',stem+'_report.json']:
        if not (backup/name).exists(): shutil.copy2(out/name,backup/name)
    scene=bpy.data.scenes.get(race.title()+'_Builder_V1')
    if scene is None:
        with bpy.data.libraries.load(str(out/(stem+'.blend')),link=False) as (available,loaded): loaded.scenes=[available.scenes[0]]
        scene=loaded.scenes[0]
    bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE'); root=rig.parent
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('builder_asset')]
    by={o['part']:o for o in parts}
    scene.frame_set(1); bpy.context.view_layer.update()
    def body_bounds():
        deps=bpy.context.evaluated_depsgraph_get()
        def coords(name):
            obj=by[name].evaluated_get(deps)
            return [obj.matrix_world@v.co for v in obj.data.vertices]
        floor=min(v.z for n in ('Foot_l','Foot_r') for v in coords(n))
        return floor,max(v.z for v in coords('Head'))
    floor,top=body_bounds(); previous_height=top-floor
    factor=target/previous_height
    rig.scale*=factor
    bpy.context.view_layer.update()
    floor,top=body_bounds()
    assert abs((top-floor)-target)<0.00001 and abs(floor)<0.00001
    vertices=[]; faces=[]; uvs=[]; spans=[]
    for obj in parts:
        start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
        faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
        uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
        spans.append((obj['animation_bone'],start,len(obj.data.vertices)))
    data=bpy.data.meshes.new(stem+'_SizedRuntime'); data.from_pydata(vertices,[],faces); data.update()
    data.materials.append(parts[0].data.materials[0]); uv=data.uv_layers.new(name='UVMap')
    for loop,value in zip(uv.data,uvs): loop.uv=value
    runtime=bpy.data.objects.new(stem+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
    groups={b.name:runtime.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1,'REPLACE')
    modifier=runtime.modifiers.new('Builder_Skin','ARMATURE'); modifier.object=rig
    for obj in scene.objects: obj.select_set(False)
    for obj in (root,rig,runtime): obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(out/(stem+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=False,export_anim_slide_to_zero=True)
    bpy.data.objects.remove(runtime,do_unlink=True)
    report=json.loads((out/(stem+'_report.json')).read_text(encoding='utf-8'))
    sizing={'reference':'anatomical foot floor to head top; excludes hair, hats and tools',
        'target_body_height_m':target,'previous_body_height_m':previous_height,
        'measured_body_height_m':top-floor,'rig_uniform_scale':list(rig.scale),
        'relative_size_adjustment':factor,'floor_m':floor,'geometry_uv_animation_keys_preserved':True}
    sizing['head_bind_vertices_gltf']=[[v.co.x*rig.scale.x,v.co.z*rig.scale.x,-v.co.y*rig.scale.x] for v in by['Head'].data.vertices]
    report['body_sizing']=sizing
    (out/(stem+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    assert hashlib.sha256((ROOT/report['source']).read_bytes()).hexdigest()==report['source_sha256']
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    results.append({'race':race,**sizing})
result={'status':'PASS','assets':results}
(ROOT/'art_source/builders_size_review/body_sizing.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
