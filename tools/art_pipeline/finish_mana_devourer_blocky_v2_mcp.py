"""Validate, export and save only the new Mana Devourer scene through Blender MCP."""
import bpy, bmesh, json, struct, math, hashlib
from pathlib import Path
from mathutils import Vector, Matrix

st=bpy.app.driver_namespace['mana_devourer_blocky_v2']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']
bpy.context.window.scene=scene
scene.frame_set(1)
assert set(st['old_scenes']).issubset(set(bpy.data.scenes.keys()))
project=OUT.parents[3]
for name,digest in st['old_hashes'].items():
    assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name

for o in parts:
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert bm.calc_volume()>0,o.name
    bm.free()
    assert len(o.data.vertices)==8 and len(o.data.polygons)==6
    assert all(not p.use_smooth and p.area>1e-10 for p in o.data.polygons)
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in o.data.vertices)
    assert o.matrix_basis==Matrix.Identity(4)

# Check the evaluated geometry through all three actions, including the exact
# loop seam, bone transforms and actual floating floor clearance.
validation={}; minimum=100
for track in rig.animation_data.nla_tracks: track.mute=True
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']
    endpoints=[]; bounds_min=[100.]*3; bounds_max=[-100.]*3
    for f in range(1,data['end']+1):
        scene.frame_set(f)
        dg=bpy.context.evaluated_depsgraph_get()
        for b in rig.pose.bones:
            assert all(math.isfinite(v) for row in b.matrix for v in row)
        assert rig.pose.bones['root'].matrix_basis==Matrix.Identity(4)
        coords=[]
        for o in parts:
            evaluated=o.evaluated_get(dg)
            coords.extend(evaluated.matrix_world@v.co for v in evaluated.data.vertices)
        for axis in range(3):
            bounds_min[axis]=min(bounds_min[axis],min(v[axis] for v in coords))
            bounds_max[axis]=max(bounds_max[axis],max(v[axis] for v in coords))
        if f in (1,data['end']): endpoints.append(coords)
    seam=max((a-b).length for a,b in zip(*endpoints))
    assert seam<1e-5,(name,seam)
    assert bounds_min[2]>.10,(name,bounds_min)
    minimum=min(minimum,bounds_min[2])
    validation[name]={'frames_checked':data['end'],'duration_s':(data['end']-1)/24,
        'loop':data['loop'],'seam_max_m':seam,'bounds_min':bounds_min,'bounds_max':bounds_max,
        'root_static':True,'finite_bones':True}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)

temp=bpy.data.collections.new(st['name']+'_Export_Temporary'); scene.collection.children.link(temp)
copies=[]
for o in parts:
    c=o.copy(); c.data=o.data.copy(); temp.objects.link(c); copies.append(c)
old_meshes=[o.data for o in copies]
with bpy.context.temp_override(active_object=copies[0],selected_objects=copies,selected_editable_objects=copies):
    bpy.ops.object.join()
model=copies[0]; model.name=st['name']+'_Model'; model.parent=rig
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (root,rig,model): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',
        export_anim_slide_to_zero=True,export_force_sampling=True,export_frame_range=False,
        export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
finally:
    bpy.data.objects.remove(model,do_unlink=True)
    for me in old_meshes:
        if me.users==0: bpy.data.meshes.remove(me)
    bpy.data.collections.remove(temp)
raw=(OUT/(STEM+'.glb')).read_bytes(); length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length]); binary=20+length+8
assert len(doc['meshes'])==1 and len(doc['skins'])==1 and len(doc['materials'])==1
assert len(doc['skins'][0]['joints'])==len(rig.data.bones)
assert {a['name'] for a in doc['animations']}==set(st['clips'])
assert all(s['magFilter']==9728 for s in doc['samplers'])
assert 'emissiveTexture' in doc['materials'][0]
embedded=[]
for im in doc['images']:
    view=doc['bufferViews'][im['bufferView']]; offset=binary+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[offset:offset+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
for a in doc['animations']:
    duration=max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])
    assert abs(duration-validation[a['name']]['duration_s'])<1e-5
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with bpy.data.libraries.load(str(OUT/(STEM+'.blend'))) as (src,dst):
    assert src.scenes==[st['name']]
    assert len(src.actions)==3 and len(src.armatures)==1
report={'name':st['name'],'display_name':'Devorador de Mana','parts':len(parts),'triangles':len(parts)*12,
    'bones':len(rig.data.bones),'atlas_size':st['atlas'],'materials':1,'meshes':1,
    'geometry':'Only closed flat cuboids; no bevels, organic anatomy, spheres or painted fake aperture.',
    'concept':'Disconnected folded cubic mass surrounding a real void. Violet intake, cyan-white exhaust.',
    'pivot':'Ground origin; native Godot dimensions; +Z front after export; static root.',
    'minimum_clearance_m':minimum,'animations':validation,'references':['ancient_golem_v2','troll_blocky_v3','mana_devourer_v1'],
    'previous_asset_files_preserved':len(st['old_hashes']),'previous_scenes_preserved':len(st['old_scenes']),
    'scenes_after':len(bpy.data.scenes),'embedded_textures_match':True,'pixel_filter':'NEAREST'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
st['report']=report
result=report
