"""Audit the Mana Devourer, save an isolated editable blend, export a single skinned GLB."""
import bpy
import bmesh
import math
import json
import hashlib
import struct
import shutil
import tempfile
from pathlib import Path
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['mana_devourer']; scene=st['scene']; parts=st['parts']; rig=st['rig']; root=st['root']; out=Path(st['out'])
clips=st.get('clips',{})
if clips:
    assert st['animation_validation']['surface_crossings']==[]
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks: track.mute=False
    scene.frame_set(1)
bpy.context.window.scene=scene; triangles=0; vertices=0; densities=[]; trees={}
for o in parts:
    assert o.matrix_basis==Matrix.Identity(4),o.name
    me=o.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles); vertices+=len(me.vertices)
    bm=bmesh.new(); bm.from_mesh(me); assert all(e.is_manifold for e in bm.edges),o.name; bm.free()
    assert all(p.area>1e-10 and not p.use_smooth for p in me.polygons)
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in me.vertices)
    uv=me.uv_layers.active.data
    for p in me.polygons:
        loops=list(p.loop_indices)
        for i,li in enumerate(loops):
            lj=loops[(i+1)%len(loops)]; length=(me.vertices[me.loops[li].vertex_index].co-me.vertices[me.loops[lj].vertex_index].co).length
            if length>1e-8: densities.append((uv[li].uv-uv[lj].uv).length*st['size']/length)
    trees[o.name]=BVHTree.FromPolygons([v.co for v in me.vertices],[list(p.vertices) for p in me.polygons])
assert max(abs(d-64) for d in densities)<.01
crossings=[]
for i,a in enumerate(parts):
    for b in parts[i+1:]:
        if trees[a.name].overlap(trees[b.name]): crossings.append((a.name,b.name))
assert not crossings,crossings
rects=[(it['x']-2,it['y']-2,it['x']+it['w']+2,it['y']+it['h']+2) for it in st['islands']]
for i,a in enumerate(rects):
    assert a[0]>=0 and a[1]>=0 and a[2]<=st['size'] and a[3]<=st['size']
    for b in rects[i+1:]: assert not (a[0]<b[2] and b[0]<a[2] and a[1]<b[3] and b[1]<a[3])
for image in st['images']: assert bytes(image.packed_file.data)==Path(image.filepath_raw).read_bytes()
assert clips or rig.animation_data is None

# Export joined copies so the editable source keeps its seven distinct components.
collection=bpy.data.collections.new(st['name']+'_EXPORT_TEMP'); scene.collection.children.link(collection)
copies=[]
for o in parts:
    copy=o.copy(); copy.data=o.data.copy(); collection.objects.link(copy); copies.append(copy)
orphan_meshes=[o.data for o in copies[1:]]
with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies): bpy.ops.object.join()
model=copies[0]; model.name=st['name']+'_Model'; model.parent=rig
for me in orphan_meshes:
    if me.users==0: bpy.data.meshes.remove(me)
glb=out/'mana_devourer_v1.glb'
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (model,rig,root): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=bool(clips),export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,
        export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
finally:
    me=model.data; bpy.data.objects.remove(model,do_unlink=True); bpy.data.meshes.remove(me); bpy.data.collections.remove(collection)

# Inspect the actual binary, including its embedded PNGs and game-visible sampler.
raw=glb.read_bytes(); assert raw[:4]==b'glTF'; length,kind=struct.unpack_from('<II',raw,12)
gltf=json.loads(raw[20:20+length]); binary_start=20+length+8
embedded=[]
for image in gltf['images']:
    view=gltf['bufferViews'][image['bufferView']]; start=binary_start+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[start:start+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
assert len(gltf['skins'])==1 and len(gltf['skins'][0]['joints'])==8
assert len(gltf['meshes'])==1 and len(gltf['materials'])==1
assert sorted(a['name'] for a in gltf.get('animations',[]))==sorted(clips)
for animation in gltf.get('animations',[]):
    duration=max(gltf['accessors'][s['input']]['max'][0] for s in animation['samplers'])
    expected=(clips[animation['name']]['end']-1)/24
    assert abs(duration-expected)<1e-5,(animation['name'],duration,expected)
assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984) for s in gltf['samplers'])
assert sum(gltf['accessors'][p['indices']]['count']//3 for p in gltf['meshes'][0]['primitives'])==triangles
material=gltf['materials'][0]; assert 'emissiveTexture' in material
coords=[v.co for o in parts for v in o.data.vertices]
lo=[min(v[i] for v in coords) for i in range(3)]; hi=[max(v[i] for v in coords) for i in range(3)]
report={'name':st['name'],'display_name':'Devorador de Mana','pipeline':'Blender MCP localhost:9876',
 'references':['troll_blocky_v3','goblin_raider_v3'],'parts':7,'triangles':triangles,'modeling_vertices':vertices,
 'bounds_min':lo,'bounds_max':hi,'size_m':[b-a for a,b in zip(lo,hi)],'ground_clearance_m':lo[2],
 'texture':{'size':[st['size'],st['size']],'maps':['albedo','emission'],'density_px_m':64,
            'measured_min':min(densities),'measured_max':max(densities),'islands':len(st['islands']),'padding_px':2,'filter':'NEAREST'},
 'geometry':{'closed':True,'flat_shaded':True,'part_surface_crossings':0,'transforms_applied':True,'interior_blocks':0},
 'rig':{'bones':list(rig.data.bones.keys()),'skinning':'Rigid normalized weights','actions':list(clips)},
 'glb':{'meshes':1,'materials':1,'skins':1,'joints':8,'embedded_textures_match_png':True,
        'emission_strength':material.get('extensions',{}).get('KHR_materials_emissive_strength',{}).get('emissiveStrength',1)},
 'front':'-Y in Blender / +Z in glTF','pivot':'Ground projection at origin; baked floating offset',
 'integration':'Asset ready for import; no gameplay/database entry.'}
if clips:
    report['animations']={n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}
    report['animation_validation']=st['animation_validation']
bpy.ops.object.select_all(action='DESELECT'); root.select_set(True); bpy.context.view_layer.objects.active=root
scene['status']='Mana Devourer with Idle/Walk/Attack; GLB and packed atlases validated' if clips else 'Mana Devourer static asset, rig prepared, GLB and packed atlases validated'
source=out/'mana_devourer_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='mana_devourer_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst): data={'scenes':list(src.scenes),'actions':list(src.actions),'armatures':list(src.armatures)}
assert data['scenes']==[st['name']] and sorted(data['actions'])==sorted(clips) and len(data['armatures'])==1
report['source_validation']=data; st['report']=report
(out/'mana_devourer_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
