"""Low racial fortification rings, made in Blender through MCP.

Use the race's approved city material/atlas. Reuse the verified footprint,
UV, surface-cleanup and export operations from the human wall workflow.
"""
import bpy, bmesh, math, json, hashlib, struct, zlib, sys, ast, importlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
PIPELINE=ROOT/'tools/art_pipeline'
sys.path.insert(0,str(PIPELINE))
import human_wall_surface_cleanup as cleanup
importlib.reload(cleanup)
ART_RACE=globals().get('WALL_RACE','elf')
RACE_FOLDER={'elf':'elves','orc':'orcs','dwarf':'dwarves'}[ART_RACE]
RACE_NAME=ART_RACE.title()
OUT_ROOT=ROOT/('assets/generated/'+RACE_FOLDER+'/buildings')
WORK=ROOT/('art_source/'+ART_RACE+'_walls_review')
WORK.mkdir(parents=True,exist_ok=True); (WORK/'.gdignore').touch()
SOURCE=OUT_ROOT/f'{ART_RACE}_city_level_1_hex_v1/{ART_RACE}_city_level_1_hex_v1.blend'
source=bpy.app.driver_namespace.get(ART_RACE+'_wall_reference')
if source is None:
    source=bpy.data.scenes.get(RACE_NAME+'_City_Level_1_Hex_V1')
    if source is None:
        with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded): loaded.scenes=[RACE_NAME+'_City_Level_1_Hex_V1']
        source=loaded.scenes[0]
    bpy.app.driver_namespace[ART_RACE+'_wall_reference']=source
protected=[p for folder in (
    f'assets/generated/{RACE_FOLDER}/buildings/{ART_RACE}_city_level_1_hex_v1',
    f'assets/generated/{RACE_FOLDER}/buildings/{ART_RACE}_guardian_hall_hex_v1',
    *[f'assets/generated/{other_folder}/buildings/{other}_walls_level_{i}_hex_v1'
      for other,other_folder in (('human','humans'),('elf','elves'),('orc','orcs'),('dwarf','dwarves')) if other!=ART_RACE for i in (1,2,3)])
    for p in (ROOT/folder).glob('*') if p.is_file()]
baseline={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
(WORK/'source_baseline.json').write_text(json.dumps(baseline,indent=2),encoding='utf-8')
source_material=next(o.data.materials[0] for o in source.objects if o.type=='MESH' and o.get('region')=='foundation')
images={n.image for n in source_material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image}
assert all(im.packed_file for im in images)
image_hashes={im.name:hashlib.sha256(bytes(im.packed_file.data)).hexdigest() for im in images}
ATLAS_SIZE=next(n.image.size[0] for n in source_material.node_tree.nodes if n.type=='TEX_IMAGE' and 'albedo' in n.image.name)
assert ATLAS_SIZE==1024
tiles={}
for obj in source.objects:
    region=obj.get('region')
    if obj.type!='MESH' or not region or region=='studio': continue
    uv=obj.data.uv_layers.active
    for face in obj.data.polygons:
        if len(face.vertices)!=4: continue
        points=[uv.data[i].uv.copy() for i in face.loop_indices]
        lo=Vector((min(v.x for v in points),min(v.y for v in points)))
        hi=Vector((max(v.x for v in points),max(v.y for v in points)))
        area=abs(sum(points[i].x*points[(i+1)%4].y-points[(i+1)%4].x*points[i].y for i in range(4)))*.5
        if (hi.x-lo.x)*(hi.y-lo.y)<1e-9 or area/((hi.x-lo.x)*(hi.y-lo.y))<.995: continue
        tiles.setdefault(region,[]).append((lo,hi,(hi-lo)*ATLAS_SIZE/128))
required_regions={
    'elf':('foundation','stone','cutstone','timber','door','roof','roof_dark','gold','faction'),
    'orc':('foundation','stone','timber','door','roof','iron','iron_light','bone','faction'),
    'dwarf':('foundation','stone','cutstone','door','roof','roof_dark','iron','iron_light','bronze','glow','faction'),
}[ART_RACE]
assert all(tiles.get(r) for r in required_regions)
NORMALS=[Vector((math.cos(math.radians(i*60)),math.sin(math.radians(i*60)))) for i in range(6)]
OUTER_LIMIT=.985*math.sqrt(3)/2
CITY_LIMIT=.84*math.sqrt(3)/2
WALL_RADIUS=.94; APOTHEM=WALL_RADIUS*math.sqrt(3)/2

# Keep the proven hex alignment and source-island mapping; adjust atlas size.
class AtlasSize(ast.NodeTransformer):
    def visit_Constant(self,node):
        return ast.copy_location(ast.Name(id='ATLAS_SIZE',ctx=ast.Load()),node) if node.value==2048 else node
tree=ast.parse((PIPELINE/'build_human_walls_mcp.py').read_text(encoding='utf-8'))
for node in ast.walk(tree):
    if isinstance(node,ast.FunctionDef) and node.name in ('clip_to_tile','prism','rectangle','edge_box'):
        module=ast.Module(body=[AtlasSize().visit(node)],type_ignores=[])
        ast.fix_missing_locations(module)
        exec(compile(module,'<shared_wall_primitives>','exec'))

results=[]; states=[]
for level in (1,2,3):
    stem=f'{ART_RACE}_walls_level_{level}_hex_v1'; name=f'{RACE_NAME}_Walls_Level_{level}_Hex_V1'
    out=OUT_ROOT/stem
    if (out/(stem+'.glb')).exists():
        report=json.loads((out/(stem+'_report.json')).read_text(encoding='utf-8'))
        assert report['status']=='PASS' and report['race']==ART_RACE
        results.append(report)
        scene=bpy.data.scenes.get(name)
        if scene: states.append(dict(scene=scene,parts=[o for o in scene.objects if o.type=='MESH' and o.get('part')],out=out))
        continue
    previous=bpy.data.scenes.get(name)
    if previous:
        assert all(o.name.startswith(name) for o in previous.objects)
        bpy.data.batch_remove(ids={previous,*previous.objects})
    out.mkdir(parents=True,exist_ok=True)
    scene=bpy.data.scenes.new(name); bpy.context.window.scene=scene
    root=bpy.data.objects.new(name,None); scene.collection.objects.link(root)
    root['race']=ART_RACE; root['fortification_level']=level; root['tile_radius']=1.0
    root['wall_radius']=WALL_RADIUS; root['low_decorative_wall']=True
    material=source_material.copy(); material.name=name+'_Approved_'+RACE_NAME+'_City_Material'
    parts=[]; footprints=[]

    exec((PIPELINE/(ART_RACE+'_walls_geometry.py.inc')).read_text(encoding='utf-8'))

    overlaps_before=cleanup.audit_coplanar(parts,include_opposing=True)
    surface_cleanup=cleanup.clean_human_wall_surfaces(parts)
    overlaps_after=cleanup.audit_coplanar(parts,include_opposing=True)
    assert not overlaps_after,json.dumps(overlaps_after[:10])
    surface_cleanup.update(coplanar_overlaps_before=len(overlaps_before),coplanar_overlaps_after=0,
        audit_includes_opposing_normals=True,atlas_bytes_unchanged=True)
    vertices=[v.co for obj in parts for v in obj.data.vertices]
    triangles=sum(len(p.vertices)-2 for obj in parts for p in obj.data.polygons)
    maximum=max(n.dot(Vector((v.x,v.y))) for v in vertices for n in NORMALS)
    height=max(v.z for v in vertices)
    assert maximum<=OUTER_LIMIT+2e-6 and height<.40 and min(v.z for v in vertices)>-1e-6
    temporary=bpy.data.collections.new(name+'_EXPORT_TEMP'); scene.collection.children.link(temporary)
    try:
        meshes=[]
        for group in ('Architecture','Faction'):
            selected=[]
            for original in parts:
                if original['group']!=group or not original.data.polygons: continue
                copy=original.copy(); copy.data=original.data.copy()
                temporary.objects.link(copy); selected.append(copy)
            if not selected: continue
            if len(selected)>1:
                with bpy.context.temp_override(active_object=selected[0],selected_editable_objects=selected,selected_objects=selected): bpy.ops.object.join()
            selected[0].name=name+'_'+group; meshes.append(selected[0])
        bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
        for obj in meshes: obj.select_set(True)
        bpy.context.view_layer.objects.active=root
        bpy.ops.export_scene.gltf(filepath=str(out/(stem+'.glb')),export_format='GLB',use_selection=True,
            use_active_scene=True,export_animations=False,export_skins=False,export_yup=True,
            export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    finally:
        for obj in list(temporary.objects):
            data=obj.data; bpy.data.objects.remove(obj,do_unlink=True)
            if data.users==0: bpy.data.meshes.remove(data)
        bpy.data.collections.remove(temporary)
    raw=(out/(stem+'.glb')).read_bytes(); size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert triangles==sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    assert not doc.get('skins') and not doc.get('animations') and not doc.get('cameras')
    assert all(s.get('magFilter')==9728 for s in doc['samplers'])
    embedded=[]
    for im in doc['images']:
        view=doc['bufferViews'][im['bufferView']]
        png=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        digest=hashlib.sha256(png).hexdigest(); assert digest in image_hashes.values()
        embedded.append(dict(name=im['name'],sha256=digest,bytes=len(png)))
    report=dict(status='PASS',name=name,stem=stem,race=ART_RACE,fortification_level=level,
        display_name={1:'Muralhas I',2:'Muralhas II',3:'Fortaleza'}[level],pipeline='Blender 5.2 MCP localhost:9876',
        material_source=str(SOURCE.relative_to(ROOT)),texture_reuse='Byte-identical approved '+ART_RACE+' city atlas; existing UV islands sampled',
        embedded_images=embedded,triangles=triangles,editable_parts=len(parts),runtime_meshes=len(doc['meshes']),
        source_boundary_sections=True,surface_cleanup=surface_cleanup,shade='Flat',height=height,
        native_tile_radius=1.0,scales_with='City.tile_radius',pointy_hex=True,wall_center_radius=WALL_RADIUS,
        max_half_plane=maximum,tile_half_plane=math.sqrt(3)/2,minimum_city_foundation_clearance=min(footprints),
        city_foundation_radius=.84,includes_ground_plate=False,includes_city=False,
        bounds_blender=dict(min=[min(v[i] for v in vertices) for i in range(3)],max=[max(v[i] for v in vertices) for i in range(3)]),
        design=DESIGN_BY_LEVEL[level])
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    states.append(dict(scene=scene,root=root,parts=parts,out=out)); results.append(report)

assert baseline=={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
bpy.app.driver_namespace[ART_RACE+'_walls_v1']=states
validation=dict(status='PASS',previous_city_and_completed_walls_unchanged=True,protected_files=len(protected),levels=results)
(WORK/'blender_validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/('docs/'+ART_RACE+'_walls_blender_validation.json')).write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='PASS',levels=[{k:r[k] for k in ('stem','height','triangles','minimum_city_foundation_clearance')} for r in results])))
