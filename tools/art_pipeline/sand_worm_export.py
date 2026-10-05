"""Save the animated Sand Worm V1 as an isolated editable blend and export one skinned GLB
(Model + rig, albedo atlas embedded, Worm_Idle / Worm_Attack / Worm_Burrow / Worm_Emerge
clips with location, rotation AND scale channels). The GLB binary is inspected: embedded PNG
must equal the atlas on disk, nearest sampler, clip lengths, triangles, scale channels."""
import bpy
import bmesh
import json
import hashlib
import struct
import shutil
import tempfile
from pathlib import Path
from mathutils import Matrix

st=bpy.app.driver_namespace['sand_worm']; scene=st['scene']; parts=st['parts']; rig=st['rig']; root=st['root']; out=Path(st['out'])
clips=st['clips']; report=st['report']
assert st['animation_validation']['problems']==[]
for n in clips: assert (out/'previews/animations'/f'{n}.mp4').is_file() and (out/'previews/animations'/f'{n}.gif').is_file()
bpy.context.window.scene=scene; rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
images=[n.image for n in st['material'].node_tree.nodes if n.type=='TEX_IMAGE']
for image in images: assert bytes(image.packed_file.data)==Path(image.filepath_raw).read_bytes(),image.name
triangles=0
for o in parts:
    assert o.matrix_basis==Matrix.Identity(4),o.name
    me=o.data; me.calc_loop_triangles(); triangles+=len(me.loop_triangles)
    bm=bmesh.new(); bm.from_mesh(me); assert all(e.is_manifold for e in bm.edges),o.name; bm.free()
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in me.vertices),o.name

# Export joined copies so the editable source keeps every part separate.
collection=bpy.data.collections.new(st['name']+'_EXPORT_TEMP'); scene.collection.children.link(collection)
copies=[]
for o in parts:
    c=o.copy(); c.data=o.data.copy(); collection.objects.link(c); copies.append(c)
orphan=[c.data for c in copies[1:]]
with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies): bpy.ops.object.join()
model=copies[0]; model.name=st['name']+'_Model'; model.data.name=st['name']+'_Model_Mesh'; model.parent=rig
for me in orphan:
    if me.users==0: bpy.data.meshes.remove(me)
assert len([m for m in model.modifiers if m.type=='ARMATURE'])==1
glb=out/'sand_worm_v1.glb'
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (model,rig,root): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,
        export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
finally:
    me=model.data; bpy.data.objects.remove(model,do_unlink=True); bpy.data.meshes.remove(me); bpy.data.collections.remove(collection)

raw=glb.read_bytes(); assert raw[:4]==b'glTF'; length,kind=struct.unpack_from('<II',raw,12)
gltf=json.loads(raw[20:20+length]); binary_start=20+length+8
embedded=[]
for image in gltf['images']:
    view=gltf['bufferViews'][image['bufferView']]; start=binary_start+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[start:start+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in images)
assert len(gltf['skins'])==1 and len(gltf['skins'][0]['joints'])==len(rig.data.bones)
assert len(gltf['meshes'])==1 and len(gltf['materials'])==1
assert sorted(a['name'] for a in gltf['animations'])==sorted(clips)
durations={}
for animation in gltf['animations']:
    durations[animation['name']]=max(gltf['accessors'][s['input']]['max'][0] for s in animation['samplers'])
    assert abs(durations[animation['name']]-(clips[animation['name']]['end']-1)/24)<1e-5
    assert any(c['target']['path']=='scale' for c in animation['channels']),animation['name']
assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984) for s in gltf['samplers'])
assert sum(gltf['accessors'][p['indices']]['count']//3 for p in gltf['meshes'][0]['primitives'])==triangles

report['rig']={'bones':list(rig.data.bones.keys()),'hierarchy':'flat: every bone is a child of root',
               'skinning':'Rigid, one bone per part (weight 1)','part_bones':{o['part']:o['rig_bone'] for o in parts}}
report['animations']={n:{k:v for k,v in d.items() if k!='action'}|{'seconds':durations[n]} for n,d in clips.items()}
report['animation_validation']=st['animation_validation']
report['glb']={'file':glb.name,'meshes':1,'materials':1,'skins':1,'joints':len(rig.data.bones),'triangles':triangles,
               'embedded_textures_match_png':True,'clips':durations,'channels':'location, rotation, scale on every bone'}
report['status']='Sand Worm V1 with Worm_Idle, Worm_Attack, Worm_Burrow, Worm_Emerge; GLB and packed atlas validated'
report['rig_bone_map']={o['part']:o['rig_bone'] for o in parts}
scene['status']=report['status']
source=out/'sand_worm_v1.blend'
bpy.data.libraries.write(str(source),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
with tempfile.TemporaryDirectory(prefix='sand_worm_check_') as folder:
    tmp=Path(folder)/'check.blend'; shutil.copyfile(source,tmp)
    with bpy.data.libraries.load(str(tmp)) as (src,dst): data={'scenes':list(src.scenes),'actions':list(src.actions),'armatures':list(src.armatures)}
assert data['scenes']==[st['name']] and sorted(data['actions'])==sorted(clips) and len(data['armatures'])==1
report['source_validation']=data
(out/'sand_worm_v1_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result={'glb':str(glb),'triangles':triangles,'clips':durations,'source_validation':data}
