"""Audit and export the static nature avatar with embedded pixel maps and rigid skin."""
import bpy,bmesh,json,struct,hashlib
from pathlib import Path
from mathutils import Matrix
st=bpy.app.driver_namespace['nature_avatar_blocky_v3']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; project=OUT.parents[3]
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
assert rig.animation_data is None
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
triangles=0; densities=[]
for o in parts:
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert bm.calc_volume()>0,o.name
    bm.free()
    assert o.matrix_basis==Matrix.Identity(4)
    assert all(not p.use_smooth and p.area>1e-10 for p in o.data.polygons),o.name
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
assert abs(high[2]-low[2]-3)<1e-5 and abs(low[2])<1e-5
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
        use_active_scene=True,export_animations=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
finally:
    bpy.data.objects.remove(model,do_unlink=True)
    if me.users==0: bpy.data.meshes.remove(me)
    bpy.data.collections.remove(temp)
raw=(OUT/(STEM+'.glb')).read_bytes(); length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length]); binary=20+length+8
assert not doc.get('animations')
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
    assert src.scenes==[st['name']] and len(src.actions)==0 and len(src.armatures)==1
report={'name':'Avatar da Natureza','school':'druidism','stage':'Static model only','shared_civilizations':True,
    'concept':'Ancient root sovereign: broad asymmetric fused root shoulders, strong contiguous trunk masses, narrow hollow abdomen, sculpted root crown, dense low square fists and dark bark framing an exposed green cube core.',
    'height_m':high[2]-low[2],'ground_clearance_m':low[2],'size_m':[b-a for a,b in zip(low,high)],
    'parts':len(parts),'triangles':triangles,'prepared_bones':list(rig.data.bones.keys()),
    'core':'Single exposed emissive green cube, separate rigid pivot inside the upper root arch','animations':0,'meshes':1,'materials':1,'atlas_size':st['atlas'],'texel_density_px_m':[min(densities),max(densities)],
    'pixel_filter':'NEAREST','closed_geometry':True,'rigid_weights':True,'embedded_textures_match':True,
    'references':['User-supplied Root Brute Rot concept image','assets/generated/nature/temperate_forest_v1','assets/generated/elves/elf_druid_v1','assets/generated/ancient_golems/ancient_golem_v2',
        'assets/generated/grand_manifestations/seraph_blocky_v4_animated','assets/generated/grand_manifestations/archdemon_blocky_v5_animated','assets/generated/grand_manifestations/elder_lich_blocky_v3_animated'],
    'revision':3,'source_scenes':1,'previous_blender_scenes_preserved':len(st['old_scenes']),
    'gameplay_database_unchanged':True,'source_front':'Blender -Y / Godot +Z'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
result=report
