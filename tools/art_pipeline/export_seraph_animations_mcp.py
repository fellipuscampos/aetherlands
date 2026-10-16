"""Validate rigid animation poses and export the four named Godot clips."""
import bpy, math, json, struct, hashlib
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['seraph_blocky_v4_animated']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; ROOT=OUT.parents[3]
bpy.context.window.scene=scene
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
old=st['reference']
assert len(parts)==len(old['parts'])==36
for a,b in zip(parts,old['parts']):
    assert [tuple(v.co) for v in a.data.vertices]==[tuple(v.co) for v in b.data.vertices]
    assert [tuple(x.uv) for x in a.data.uv_layers.active.data]==[tuple(x.uv) for x in b.data.uv_layers.active.data]
    assert a['rig_bone']==b['rig_bone']
for im,original in zip(st['images'],old['images']):
    assert Path(im.filepath_raw).read_bytes()==Path(original.filepath_raw).read_bytes()
trees={o.name:BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons]) for o in parts}
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
wing_parts=[o for o in parts if o['kind']=='wing_feather']
baseline_trees={o.name:trees[o.name] for o in wing_parts}
baseline_overlaps={(a.name,b.name) for i,a in enumerate(wing_parts) for b in wing_parts[i+1:] if baseline_trees[a.name].overlap(baseline_trees[b.name])}
channels=[]; validation={}; idle_first=None
for track in rig.animation_data.nla_tracks: track.mute=True
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']
    channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                channel_set.update((c.data_path,c.array_index) for c in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3); high=Vector((-1e9,)*3); first=None; maximum_step=0.; previous_points=None
    gaps={'cube_inner_m':1e9,'between_rings_m':1e9,'rings_wings_and_cubes_m':1e9}; uniform_error=0.
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        f=1+step/2; scene.frame_set(int(f),subframe=f%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        center=rig.pose.bones['core'].matrix.translation
        for n in ('orbit_a','orbit_b'): assert (rig.pose.bones[n].matrix.translation-center).length<1e-5
        radius={n:[1e9,0.] for n in ('core','orbit_a','orbit_b','static')}; points=[]; posed_wings={}
        for o in parts:
            m=matrices[o['rig_bone']]; lengths=[m.to_3x3().col[i].length for i in range(3)]
            uniform_error=max(uniform_error,max(lengths)-min(lengths))
            assert max(lengths)-min(lengths)<1e-5
            vectors=[m.to_3x3().col[i].normalized() for i in range(3)]
            assert max(abs(vectors[i].dot(vectors[j])) for i in range(3) for j in range(i+1,3))<1e-5
            vv=[m@v.co for v in o.data.vertices]; points.extend(vv)
            for v in vv:
                for k in range(3): low[k]=min(low[k],v[k]); high[k]=max(high[k],v[k])
            group=o['rig_bone'] if o['rig_bone'] in ('core','orbit_a','orbit_b') else 'static'
            nearest=trees[o.name].find_nearest(m.inverted()@center)
            radius[group][0]=min(radius[group][0],nearest[3]*lengths[0])
            radius[group][1]=max(radius[group][1],max((v-center).length for v in vv))
            if o in wing_parts: posed_wings[o.name]=BVHTree.FromPolygons(vv,[tuple(p.vertices) for p in o.data.polygons])
        for i,a in enumerate(wing_parts):
            for b in wing_parts[i+1:]:
                if (a.name,b.name) not in baseline_overlaps:
                    assert not posed_wings[a.name].overlap(posed_wings[b.name]),(name,f,'new wing intersection',a.name,b.name)
        current={'cube_inner_m':radius['orbit_a'][0]-radius['core'][1],
                 'between_rings_m':radius['orbit_b'][0]-radius['orbit_a'][1],
                 'rings_wings_and_cubes_m':radius['static'][0]-radius['orbit_b'][1]}
        for k,v in current.items(): gaps[k]=min(gaps[k],v)
        assert min(current.values())>.012,(name,f,current)
        if first is None: first=[v.copy() for v in points]
        if previous_points is not None: maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous_points,points)))
        previous_points=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5,(name,seam)
    assert low.z>.09,(name,'floor clearance',low.z)
    if name=='Idle': idle_first=first
    if name in ('Attack','Spell'): assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    assert maximum_step<.35,(name,maximum_step)
    validation[name]={'samples':samples,'loop':data['loop'],'duration_s':data['duration_s'],
        'minimum_ground_clearance_m':low.z,'bounds_min_m':list(low),'bounds_max_m':list(high),
        'seam_vertex_delta_m':seam,'maximum_half_frame_vertex_step_m':maximum_step,
        'uniform_scale_error':uniform_error,'minimum_separation_m':gaps,'new_wing_intersections':0}
assert all(c==channels[0] for c in channels),'All clips must reset identical transform channels.'
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
st['animation_validation']=validation

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
assert len(doc['skins'][0]['joints'])==11
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives'])==2072
embedded=[]
for image in doc['images']:
    view=doc['bufferViews'][image['bufferView']]; offset=binary+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[offset:offset+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
assert all(s['magFilter']==9728 for s in doc['samplers'])
report={'status':'PASS','model':STEM,'geometry_and_uv_unchanged':True,'textures_unchanged':True,
        'meshes':1,'materials':1,'triangles':triangles,'bones':11,'root_motion':False,'fps':24,
        'same_channels_all_clips':True,'rest_height_m':3.,'prepared_wing_pairs':3,
        'clips':validation,'static_wing_overlap_pairs':len(baseline_overlaps),'protected_files':len(st['old_hashes'])}
(OUT/'animation_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
st['report']=report
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
