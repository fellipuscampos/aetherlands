"""Save one animated mage and add its rig to the existing racial review."""
import bpy,json,struct,hashlib
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/school_mages_animation_review'
assets=bpy.app.driver_namespace[MAGE_RACE+'_school_mage_assets_v1']; review=bpy.app.driver_namespace[MAGE_RACE+'_school_mage_review_v1']
asset=next(a for a in assets if a['report']['school']==MAGE_SCHOOL)
scene=asset['scene']; root=asset['root']; rig=asset['rig']; parts=asset['parts']; folder=asset['folder']; report=asset['report']; stem=root.name
assert report['animation']['status']=='PASS' and report['animations']==3
bpy.context.window.scene=scene; scene.frame_set(1); bpy.context.view_layer.update()
(WORK/'current_stage.json').write_text(json.dumps(dict(asset=stem,stage='export_animated_glb')),encoding='utf-8')
vertices=[]; faces=[]; uvs=[]; spans=[]
for obj in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    faces.extend(tuple(i+offset for i in p.vertices) for p in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    spans.append((obj['animation_bone'],offset,len(obj.data.vertices)))
hashes={}
for node in asset['material'].node_tree.nodes:
    if node.type!='TEX_IMAGE': continue
    image=node.image; suffix='emission' if Path(image.filepath_raw).stem.endswith('_emission') else 'albedo'
    digest=hashlib.sha256((folder/(stem+'_'+suffix+'.png')).read_bytes()).hexdigest()
    assert image.packed_file and hashlib.sha256(image.packed_file.data).hexdigest()==digest
    assert node.interpolation=='Closest'; hashes[suffix]=digest
assert len(hashes)==2
data=bpy.data.meshes.new(stem+'_MageRuntimeExport_TEMP'); data.from_pydata(vertices,[],faces); data.update(); data.materials.append(asset['material'])
uv=data.uv_layers.new(name='UVMap')
for loop,value in zip(uv.data,uvs): loop.uv=value
obj=bpy.data.objects.new(stem+'_Body',data); scene.collection.objects.link(obj); obj.parent=rig
groups={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
for bone,start,count in spans: groups[bone].add(list(range(start,start+count)),1.,'REPLACE')
modifier=obj.modifiers.new('Mage_Rigid_Skin','ARMATURE'); modifier.object=rig
try:
    for item in scene.objects: item.select_set(False)
    for item in (obj,rig,root): item.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for track in rig.animation_data.nla_tracks: track.mute=False; track.is_solo=False
    path=folder/(stem+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_anim_slide_to_zero=True)
    raw=path.read_bytes(); size=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+size]); binary=raw[28+size:]
    assert sorted(a['name'] for a in doc['animations'])==['idle','spell','walk']
    assert len(doc['skins'])==len(doc['meshes'])==len(doc['materials'])==1 and len(doc['images'])==2
    assert len(doc['meshes'][0]['primitives'])==1 and len(doc['skins'][0]['joints'])==16
    p=doc['meshes'][0]['primitives'][0]; assert 'JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes']
    assert doc['accessors'][p['indices']]['count']//3==report['geometry']['triangles']
    embedded=[]
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']]; offset=view.get('byteOffset',0)
        embedded.append(hashlib.sha256(binary[offset:offset+view['byteLength']]).hexdigest())
    assert sorted(embedded)==sorted(hashes.values()) and all(s.get('magFilter')==9728 for s in doc['samplers'])
    report['export']=dict(status='PASS',bytes=len(raw),triangles=report['geometry']['triangles'],meshes=1,surfaces=1,materials=1,skins=1,bones=16,animations=3,clips=['idle','walk','spell'],atlas_hashes=hashes,editable_source_parts=len(parts),cameras=0,lights=0)
finally:
    bpy.data.objects.remove(obj,do_unlink=True)
    if data.users==0: bpy.data.meshes.remove(data)
report['game_usage']=dict(units='meters',model_scale_multiplier=1.0,pivot='feet_at_origin',blender_front='-Y',godot_front='+Z',stage='animated_review',game_database_changed=False,spell_clip='spell',spell_release_seconds=report['animation']['spell_release_seconds'])
scene.use_preview_range=True; scene.frame_preview_start=241; scene.frame_preview_end=385; scene.frame_set(1)
scene['mage_report']=json.dumps(report,ensure_ascii=False)
bpy.data.libraries.write(str(folder/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
(folder/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
# Review meshes still reference the approved editable data; only skinning is added.
index=assets.index(asset); col=review['collections'][index]; review_root=review['roots'][index]
old=[o for o in col.objects if o.type=='ARMATURE' and o.get('mage_animation_asset')==stem]
for old_rig in old:
    for o in col.objects:
        for mod in list(o.modifiers):
            if mod.type=='ARMATURE' and mod.object==old_rig: o.modifiers.remove(mod)
    bpy.data.objects.remove(old_rig,do_unlink=True)
copy=rig.copy(); copy.data=rig.data.copy(); copy.name=stem+'_ReviewRig'; col.objects.link(copy); copy.parent=review_root
asset['review_rig']=copy
by={o['part']:o for o in parts}
for obj in list(col.objects):
    if obj.type!='MESH' or obj.get('part') not in by: continue
    bone=by[obj['part']]['animation_bone']; obj['animation_bone']=bone
    obj.vertex_groups.clear(); obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1.,'REPLACE')
    modifier=obj.modifiers.new('Mage_Rigid_Skin','ARMATURE'); modifier.object=copy
bpy.context.window.scene=review['scene']; review['scene'].frame_set(1)
(WORK/'current_stage.json').write_text(json.dumps(dict(asset=stem,stage='saved',animations=3)),encoding='utf-8')
result=dict(status='PASS',asset=stem,clips=['idle','walk','spell'],meshes=1,skins=1,bones=16,source_saved=True)
