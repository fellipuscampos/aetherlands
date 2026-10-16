"""Export the approved wings with a rotating core and collision-safe aureoles."""
import bpy,bmesh,json,struct,hashlib,math
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.geometry import closest_point_on_tri
st=bpy.app.driver_namespace['seraph_blocky_v4']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; project=OUT.parents[3]
bpy.context.window.scene=scene
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
assert len(rig.animation_data.nla_tracks)==1
scene.frame_set(1)
# Refresh packed bytes after texture revisions; glTF reads the packed source.
for image in st['images']:
    if image.packed_file: image.unpack(method='REMOVE')
    image.reload()
    image.pack()
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
triangles=0; densities=[]
for o in parts:
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert bm.calc_volume()>0,o.name
    bm.free()
    assert o.matrix_basis==Matrix.Identity(4)
    assert all(not p.use_smooth and p.area>1e-10 for p in o.data.polygons)
    assert all(len(v.groups)==1 and v.groups[0].weight==1 for v in o.data.vertices)
    o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    uv=o.data.uv_layers.active.data
    for p in o.data.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]
            length=(o.data.vertices[o.data.loops[li].vertex_index].co-o.data.vertices[o.data.loops[lj].vertex_index].co).length
            densities.append((uv[li].uv-uv[lj].uv).length*st['atlas']/length)
assert max(abs(d-64) for d in densities)<.01
coords=[v.co for o in parts for v in o.data.vertices]
low=[min(v[i] for v in coords) for i in range(3)]; high=[max(v[i] for v in coords) for i in range(3)]
assert abs(high[2]-low[2]-3)<1e-5 and low[2]>.20
# Radial bounds prove separation throughout every possible ring rotation,
# rather than checking only a few attractive poses.
center=rig.data.bones['core'].head_local
radii={}
for name in ('core','orbit_a','orbit_b','static'):
    members=[o for o in parts if (o['rig_bone']==name if name!='static' else o['rig_bone'] not in ('core','orbit_a','orbit_b'))]
    closest=1e9; furthest=0
    for o in members:
        o.data.calc_loop_triangles()
        furthest=max(furthest,max((v.co-center).length for v in o.data.vertices))
        for t in o.data.loop_triangles:
            a,b,c=(o.data.vertices[i].co for i in t.vertices)
            closest=min(closest,(closest_point_on_tri(center,a,b,c)-center).length)
    radii[name]={'min_m':closest,'max_m':furthest}
clearance={'cube_inner_m':radii['orbit_a']['min_m']-radii['core']['max_m'],
           'between_rings_m':radii['orbit_b']['min_m']-radii['orbit_a']['max_m'],
           'rings_rear_cluster_m':radii['static']['min_m']-radii['orbit_b']['max_m']}
assert min(clearance.values())>.015,clearance
# The user asked to change only the wings. Verify the complete approved
# center, all nine supporting cubes and bone pivots against the previous source.
old=bpy.app.driver_namespace['seraph_blocky_v3']
original={o.name.replace('Sacred_Seraph_Blocky_V3','Sacred_Seraph_Blocky_V4'):o for o in old['parts']}
preserved=0
for o in parts:
    if o['kind']=='wing_feather': continue
    previous=original[o.name]
    assert len(o.data.vertices)==len(previous.data.vertices)
    assert max((a.co-b.co).length for a,b in zip(o.data.vertices,previous.data.vertices))<1e-5
    preserved+=1
assert preserved==30
for bone in rig.data.bones:
    assert (bone.head_local-old['rig'].data.bones[bone.name].head_local).length<1e-5

temp=bpy.data.collections.new(st['name']+'_Export_Temporary'); scene.collection.children.link(temp)
vertices=[]; faces=[]; uv_rows=[]; groups={}
for o in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in o.data.vertices)
    groups.setdefault(o['rig_bone'],[]).extend(range(offset,len(vertices)))
    for p in o.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uv_rows.extend(tuple(o.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
me=bpy.data.meshes.new(st['name']+'_ExportMesh'); me.from_pydata(vertices,[],faces); me.update()
uv=me.uv_layers.new(name='Metric_Pixel_UV')
for li,coord in enumerate(uv_rows): uv.data[li].uv=coord
me.materials.append(st['material'])
model=bpy.data.objects.new(st['name']+'_Model',me); temp.objects.link(model); model.parent=rig
for name,indices in groups.items(): model.vertex_groups.new(name=name).add(indices,1,'REPLACE')
model.modifiers.new('Prepared_Rigid_Pivots','ARMATURE').object=rig
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (root,rig,model): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,
        use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
finally:
    bpy.data.objects.remove(model,do_unlink=True)
    if me.users==0: bpy.data.meshes.remove(me)
    bpy.data.collections.remove(temp)
raw=(OUT/(STEM+'.glb')).read_bytes(); length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length]); binary=20+length+8
assert [a['name'] for a in doc['animations']]==['Seraph_CoreOrbit']
assert abs(max(doc['accessors'][x['input']]['max'][0] for x in doc['animations'][0]['samplers'])-24)<1e-5
assert len(doc['meshes'])==1 and len(doc['materials'])==1 and len(doc['skins'])==1
assert len(doc['skins'][0]['joints'])==len(rig.data.bones)
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives'])==triangles
assert all(s['magFilter']==9728 for s in doc['samplers'])
embedded=[]
for im in doc['images']:
    view=doc['bufferViews'][im['bufferView']]; offset=binary+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[offset:offset+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with bpy.data.libraries.load(str(OUT/(STEM+'.blend'))) as (src,dst):
    assert src.scenes==[st['name']] and len(src.actions)==1 and len(src.armatures)==1
report={'name':'Serafim','school':'sacred','stage':'Model revision with slow core/orbit rotation study','shared_civilizations':True,
    'concept':'Six broad continuous voxel feather wings with irregular stepped tips and an irregular ivory, pale-grey and taupe pixel mosaic from an image-generated reference map, following the supplied reference. Approved energy cube, rear cluster and two orbiting aureoles preserved.',
    'height_m':high[2]-low[2],'ground_clearance_m':low[2],'size_m':[b-a for a,b in zip(low,high)],
    'parts':len(parts),'triangles':triangles,'prepared_bones':list(rig.data.bones.keys()),
    'animations':1,'rotation_clip':'Seraph_CoreOrbit','rotation_duration_s':24,'rotation_loop':True,
    'rear_cubes':9,'approved_center_parts_preserved':preserved,'wing_panels':6,'wing_reference':'User-provided Minecraft angel wing image','all_rotation_clearances_m':clearance,'radial_bounds':radii,'meshes':1,'materials':1,'atlas_size':st['atlas'],'texel_density_px_m':[min(densities),max(densities)],
    'pixel_filter':'NEAREST','wing_texture':'Irregular ivory, pale-grey and taupe pixel mosaic; image_gen reference material','closed_geometry':True,'rigid_weights':True,'embedded_textures_match':True,
    'references':['User-provided floating armor and spectral gold/wing references','human_sacred_cleric_v1','dwarf_sacred_cleric_v1'],
    'source_scenes':1,'previous_blender_scenes_preserved':len(st['old_scenes']),
    'gameplay_database_unchanged':True,'source_front':'Blender -Y / Godot +Z'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
st['report']=report
result=report
