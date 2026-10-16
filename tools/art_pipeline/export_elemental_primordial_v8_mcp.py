"""Audit and export the static Veil Archon with embedded pixel maps and rigid skin."""
import bpy,bmesh,json,struct,hashlib
from pathlib import Path
from mathutils import Matrix
st=bpy.app.driver_namespace['elemental_primordial_blocky_v8']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; project=OUT.parents[3]
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
assert rig.animation_data is None
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
# Verify the requested scope against the approved V6, including the original pixel painting.
import numpy as np
old=bpy.app.driver_namespace['elemental_primordial_blocky_v6']
old_parts={o.name.removeprefix('Elemental_Primordial_Blocky_V6_'):o for o in old['parts']}
old_islands={it['obj'].name.removeprefix('Elemental_Primordial_Blocky_V6_')+'|'+str(it['polygon']):it for it in old['islands']}
old_pixels=np.asarray(old['images'][0].pixels[:],dtype=np.float32).reshape(old['atlas'],old['atlas'],4)
new_pixels=np.asarray(st['images'][0].pixels[:],dtype=np.float32).reshape(st['atlas'],st['atlas'],4)
for o in parts:
    label=o['source_part_label']
    if label in old_parts:
        before=old_parts[label]
        assert len(o.data.vertices)==len(before.data.vertices)
        assert max((a.co-b.co).length for a,b in zip(o.data.vertices,before.data.vertices))<1e-6,label
for it in st['islands']:
    o=it['obj'];key=o['source_part_label']+'|'+str(it['polygon'])
    tile=new_pixels[it['y']:it['y']+it['h'],it['x']:it['x']+it['w'],:3]
    if o['kind']=='crystal':assert len(np.unique(tile.reshape(-1,3),axis=0))<=4,key
    elif key in old_islands:
        before=old_islands[key]
        original=old_pixels[before['y']:before['y']+before['h'],before['x']:before['x']+before['w'],:3]
        assert tile.shape==original.shape and np.max(np.abs(tile-original))<1e-7,key
assert not any('Long_Outer_Foot' in o.name or 'Foot_Stone_Plane' in o.name for o in parts)
assert len([o for o in parts if 'Pointed_Crab_Tarsus' in o.name])==2
assert not any(any(tag in o.name for tag in ['Main_Dark_Hand','Inner_Hand_Hook','Hand_Base']) for o in parts)
assert len([o for o in parts if 'Fixed_Crab_Pincer' in o.name])==2
assert len([o for o in parts if 'Mobile_Crab_Pincer' in o.name])==2
for label in ('L','R'):
    assert rig.data.bones['pincer_'+label].parent.name=='forearm_'+label

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
assert max(abs(d-64) for d in densities)<.05
coords=[v.co for o in parts for v in o.data.vertices]
low=[min(v[i] for v in coords) for i in range(3)]; high=[max(v[i] for v in coords) for i in range(3)]
assert abs(high[2]-low[2]-3)<1e-5 and abs(low[2])<1e-5
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import math
core=next(o for o in parts if o['rig_bone']=='core'); center=rig.data.bones['core'].head_local
targets=[(o,BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])) for o in parts if o!=core]
core_samples=0
for axis in ('X','Y','Z'):
    for step in range(48):
        R=Matrix.Rotation(math.tau*step/48,3,axis)
        tree=BVHTree.FromPolygons([center+R@(v.co-center) for v in core.data.vertices],[tuple(p.vertices) for p in core.data.polygons])
        for o,other in targets: assert not tree.overlap(other),('Core clearance',axis,step,o.name)
        core_samples+=1
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
report={'name':'Primordial dos Elementos','school':'elementalism','stage':'Static model only','shared_civilizations':True,
    'concept':'Close-up-reference crab limbs: the entire lower arm is a large continuous claw with an elongated lower opening and a tapered hinged opposing jaw. Rear walking legs follow a down-up-down zigzag with bent terminal blades. Approved V6 torso, face, upper arms, crystal shapes and cubic heart retained. Cyan crystals use irregular pixel mottling without bar graphics or painted line diagrams. Three meters tall.',
    'height_m':high[2]-low[2],'ground_clearance_m':low[2],'size_m':[b-a for a,b in zip(low,high)],
    'parts':len(parts),'triangles':triangles,'prepared_bones':list(rig.data.bones.keys()),
    'core':'One cyan cubic heart deep inside the mineral torso, partially visible through the oblique breast rocks','animations':0,'meshes':1,'materials':1,'atlas_size':st['atlas'],'texel_density_px_m':[min(densities),max(densities)],
    'core_full_rotation_clearance_samples':core_samples,'core_rotation_axes':['X','Y','Z'],'pixel_filter':'NEAREST','closed_geometry':True,'rigid_weights':True,'embedded_textures_match':True,
    'references':['User supplied black-rock monster with large cyan back crystals','assets/generated/wargs/warg_v1','assets/generated/basilisks/basilisk_blocky_v1','scripts/data/V2MagicContent.gd: Elementalism and Primordial dos Elementos',
 'assets/generated/humans/human_elementalist_v1',
 'assets/generated/humans/buildings/elemental_observatory_hex_v1',
 'assets/generated/humans/buildings/elemental_ritual_hex_v1',
 'assets/generated/grand_manifestations/veil_archon_blocky_v9_animated',
 'assets/generated/grand_manifestations/archdemon_blocky_v5_animated'],
 'revision':8,'blocky_prism_geometry':True,'stepped_corners':True,'elemental_components':['charcoal_body','cyan_crystal_columns','six_luminous_eyes','recessed_cube_heart'],'crab_legs':True,'crab_pincers':True,'opposing_pincer_jaws':True,'mammalian_feet':False,'painted_crystal_graphics':False,'crystal_pixel_texture':True,'integrated_large_claws':True,'double_bend_walking_legs':True,'approved_carapace_face_upper_arms_preserved':True,'source_scenes':1,'previous_blender_scenes_preserved':len(st['old_scenes']),
    'gameplay_database_unchanged':True,'source_front':'Blender -Y / Godot +Z'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
result=report
