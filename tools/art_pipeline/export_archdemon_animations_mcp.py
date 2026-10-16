"""Validate rigid animation poses and export the four named Godot clips."""
import bpy, math, json, struct, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['archdemon_blocky_v4_animated']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; ROOT=OUT.parents[3]
bpy.context.window.scene=scene
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
old=st['reference']
assert len(parts)==len(old['parts'])==74
for a,b in zip(parts,old['parts']):
    if a['rig_bone']!='core' and not a['rig_bone'].startswith('stole_side_'):
        assert [tuple(v.co) for v in a.data.vertices]==[tuple(v.co) for v in b.data.vertices],a.name
    assert [tuple(x.uv) for x in a.data.uv_layers.active.data]==[tuple(x.uv) for x in b.data.uv_layers.active.data]
for im,original in zip(st['images'],old['images']): assert Path(im.filepath_raw).read_bytes()==Path(original.filepath_raw).read_bytes()
core=next(o for o in parts if o['rig_bone']=='core')
center=rig.data.bones['core'].head_local
trees={o.name:BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons]) for o in parts}
radius=max((v.co-center).length for v in core.data.vertices)
chest_parts=[o for o in parts if o['rig_bone'] in ('chest','crown') and o!=core]
minimum_clearance=min(trees[o.name].find_nearest(center)[3] for o in chest_parts)-radius
assert minimum_clearance>.004,('Rotating cube clearance',minimum_clearance)
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[]; validation={}; idle_first=None
for track in rig.animation_data.nla_tracks: track.mute=True
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags: channel_set.update((c.data_path,c.array_index) for c in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3); high=Vector((-1e9,)*3); first=None; maximum_step=0.; previous_points=None; uniform_error=0.
    gaps={'shoulders_to_body_m':1e9,'hands_to_body_m':1e9,'hands_below_shoulders_m':1e9,'cube_to_chest_m':minimum_clearance}
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        f=1+step/2; scene.frame_set(int(f),subframe=f%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        center_pose=rig.pose.bones['core'].matrix.translation
        assert (matrices['chest']@center-center_pose).length<1e-5
        points=[]; groups={}
        inverse_body=matrices['body'].inverted()
        for o in parts:
            m=matrices[o['rig_bone']]; lengths=[m.to_3x3().col[i].length for i in range(3)]
            uniform_error=max(uniform_error,max(lengths)-min(lengths)); assert max(lengths)-min(lengths)<1e-5
            vectors=[m.to_3x3().col[i].normalized() for i in range(3)]
            assert max(abs(vectors[i].dot(vectors[j])) for i in range(3) for j in range(i+1,3))<1e-5
            vv=[m@v.co for v in o.data.vertices]; points.extend(vv)
            groups.setdefault(o['rig_bone'],[]).extend(inverse_body@v for v in vv)
            for v in vv:
                for k in range(3): low[k]=min(low[k],v[k]); high[k]=max(high[k],v[k])
        torso=groups['body']+groups['chest']
        for side,sign in [('L',-1),('R',1)]:
            shoulder=groups['shoulder_'+side]; fist=groups['fist_'+side]
            edge=max(sign*v.x for v in torso)
            gaps['shoulders_to_body_m']=min(gaps['shoulders_to_body_m'],min(sign*v.x for v in shoulder)-edge)
            gaps['hands_to_body_m']=min(gaps['hands_to_body_m'],min(sign*v.x for v in fist)-edge)
            # Moving hands may share a height with the shoulders; compare actual geometry as well.
            sm=matrices['shoulder_'+side]; fm=matrices['fist_'+side]
            for so in [o for o in parts if o['rig_bone']=='shoulder_'+side]:
                sbvh=BVHTree.FromPolygons([sm@v.co for v in so.data.vertices],[tuple(p.vertices) for p in so.data.polygons])
                for fo in [o for o in parts if o['rig_bone']=='fist_'+side]:
                    fbvh=BVHTree.FromPolygons([fm@v.co for v in fo.data.vertices],[tuple(p.vertices) for p in fo.data.polygons])
                    assert not sbvh.overlap(fbvh),(name,f,so.name,fo.name)
            gaps['hands_below_shoulders_m']=min(gaps['hands_below_shoulders_m'],min(v.z for v in shoulder)-max(v.z for v in fist))
        if first is None: first=[v.copy() for v in points]
        if previous_points is not None: maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous_points,points)))
        previous_points=points
    seam=max((a-b).length for a,b in zip(first,points)); assert seam<1e-5,(name,seam)
    assert low.z>.09,(name,'floor',low.z)
    assert gaps['shoulders_to_body_m']>.09 and gaps['hands_to_body_m']>.20,(name,gaps)
    if name=='Idle': idle_first=first
    if name in ('Attack','Spell'): assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    assert maximum_step<.20,(name,maximum_step)
    validation[name]={'samples':samples,'loop':data['loop'],'duration_s':data['duration_s'],
        'minimum_ground_clearance_m':low.z,'bounds_min_m':list(low),'bounds_max_m':list(high),
        'seam_vertex_delta_m':seam,'maximum_half_frame_vertex_step_m':maximum_step,
        'uniform_scale_error':uniform_error,'minimum_separation_m':gaps,'hand_shoulder_intersections':0,
        'core_center_fixed_inside_chest':True}
assert all(c==channels[0] for c in channels)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1); st['animation_validation']=validation

# Assemble one export mesh without joining objects in the user's large file.
temporary=bpy.data.collections.new(st['name']+'_Export'); scene.collection.children.link(temporary)
vertices=[]; faces=[]; uvrows=[]; groups={}; triangles=0
for o in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in o.data.vertices)
    groups.setdefault(o['rig_bone'],[]).extend(range(offset,len(vertices)))
    o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    for p in o.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uvrows.extend(tuple(o.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
me=bpy.data.meshes.new(st['name']+'_ExportMesh'); me.from_pydata(vertices,[],faces); me.update()
uv=me.uv_layers.new(name='Metric_Pixel_UV')
for i,row in enumerate(uvrows): uv.data[i].uv=row
me.materials.append(st['material'])
model=bpy.data.objects.new(st['name']+'_Model',me); temporary.objects.link(model); model.parent=rig
for n,indices in groups.items(): model.vertex_groups.new(name=n).add(indices,1,'REPLACE')
model.modifiers.new('Rigid_Pivots','ARMATURE').object=rig
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (root,rig,model): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    kwargs=dict(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,
        use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
    if 'export_optimize_animation_size' in bpy.ops.export_scene.gltf.get_rna_type().properties: kwargs['export_optimize_animation_size']=False
    bpy.ops.export_scene.gltf(**kwargs)
finally:
    bpy.data.objects.remove(model,do_unlink=True)
    bpy.data.meshes.remove(me); bpy.data.collections.remove(temporary)
raw=(OUT/(STEM+'.glb')).read_bytes(); length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]); binary=28+length
assert {a['name'] for a in doc['animations']}==set(st['clips'])
for a in doc['animations']:
    assert abs(max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])-st['clips'][a['name']]['duration_s'])<1e-5
assert len(doc['meshes'])==len(doc['materials'])==len(doc['skins'])==1
assert len(doc['skins'][0]['joints'])==29
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives'])==1084
embedded=[]
for image in doc['images']:
    view=doc['bufferViews'][image['bufferView']]; offset=binary+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[offset:offset+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
assert all(s['magFilter']==9728 for s in doc['samplers'])
report={'status':'PASS','model':STEM,'armor_pixels_preserved':True,
        'side_stoles_attached':True,'core_is_cube_inside_chest':True,
        'meshes':1,'materials':1,'triangles':triangles,'bones':29,'root_motion':False,'fps':24,
        'same_channels_all_clips':True,'rest_height_m':3.,'clips':validation,
        'protected_files':len(st['old_hashes'])}
(OUT/'animation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
st['report']=report
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
