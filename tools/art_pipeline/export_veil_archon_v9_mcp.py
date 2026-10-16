"""Audit actual sampled poses and export the four animated Avatar clips."""
import bpy,bmesh,math,json,struct,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['veil_archon_blocky_v9_animated']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; ROOT=OUT.parents[3]; old=st['reference']
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
approved=[o for o in old['parts'] if o['kind']!='orbit']
assert len(parts)==len(approved)==47
assert not any(o['kind']=='orbit' for o in parts) and 'orbit' not in rig.data.bones
for o,original in zip(parts,approved):
    if not o.get('articulated_cloth'):
        assert [tuple(v.co) for v in o.data.vertices]==[tuple(v.co) for v in original.data.vertices],o.name
        assert [tuple(v.uv) for v in o.data.uv_layers.active.data]==[tuple(v.uv) for v in original.data.uv_layers.active.data],o.name
    else:
        for v in original.data.vertices: assert min((v.co-n.co).length for n in o.data.vertices)<1e-6
    bm=bmesh.new(); bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume()>0,o.name
    bm.free()
    assert o.matrix_basis==Matrix.Identity(4)
    assert all(not p.use_smooth and p.area>1e-10 for p in o.data.polygons),o.name
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in o.data.vertices),o.name
for im,reference in zip(st['images'],old['images']): assert Path(im.filepath_raw).read_bytes()==Path(reference.filepath_raw).read_bytes()
# Sample actual evaluated half frames: rigid plates, loop seams, ground and collision clearance.
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[];validation={};idle_first=None
for track in rig.animation_data.nla_tracks:track.mute=True
core=next(o for o in parts if o['kind']=='core')
plate_parts=[o for o in parts if o['kind']=='plate'];targets=[o for o in parts if o!=core]
faces={o.name:[tuple(p.vertices) for p in o.data.polygons] for o in parts}
def bounds(points):
    return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
def overlaps(a,b):return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
for name,data in st['clips'].items():
    rig.animation_data.action=data['action'];channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags:channel_set.update((curve.data_path,curve.array_index) for curve in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3);high=Vector((-1e9,)*3);first=previous=None
    maximum_step=0.;core_checks=plate_checks=collision_poses=0
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        frame=1+step/2;scene.frame_set(int(frame),subframe=frame%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        for bone,matrix in matrices.items():
            scales=[matrix.to_3x3().col[i].length for i in range(3)]
            assert abs(max(scales)-min(scales))<1e-5 and matrix.determinant()>0,(name,frame,bone)
            if bone!='core':assert max(abs(s-1) for s in scales)<1e-5,(name,frame,bone)
        posed={o.name:[matrices[o['rig_bone']]@v.co for v in o.data.vertices] for o in parts}
        points=[p for vv in posed.values() for p in vv]
        frame_low,frame_high=bounds(points);low=Vector(tuple(min(low[i],frame_low[i]) for i in range(3)));high=Vector(tuple(max(high[i],frame_high[i]) for i in range(3)))
        if step%4==0 or name in ('Attack','Spell'):
            # Strip the shared shell rotation for stable and efficient collision bounds.
            inverse=matrices['shell'].inverted()
            local={o.name:[inverse@p for p in posed[o.name]] for o in parts}
            boxes={n:bounds(vv) for n,vv in local.items()};trees={}
            def tree(o):
                if o.name not in trees:trees[o.name]=BVHTree.FromPolygons(local[o.name],faces[o.name])
                return trees[o.name]
            for target in targets:
                if not overlaps(boxes[core.name],boxes[target.name]):continue
                assert not tree(core).overlap(tree(target)),('Core intersection',name,frame,target.name)
                core_checks+=1
            for i,a in enumerate(plate_parts):
                for b in plate_parts[i+1:]:
                    if not overlaps(boxes[a.name],boxes[b.name]):continue
                    assert not tree(a).overlap(tree(b)),('Runic plates intersect',name,frame,a.name,b.name)
                    plate_checks+=1
            collision_poses+=1
        if first is None:first=[p.copy() for p in points]
        if previous is not None:maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous,points)))
        previous=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5 and low.z>.20,(name,seam,low.z)
    assert maximum_step<.18,(name,maximum_step)
    if name=='Idle':idle_first=first
    if name in ('Attack','Spell'):assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    validation[name]=dict(samples=samples,loop=data['loop'],duration_s=data['duration_s'],description=data['description'],
      minimum_ground_clearance_m=low.z,bounds_min_m=list(low),bounds_max_m=list(high),seam_vertex_delta_m=seam,
      maximum_half_frame_vertex_step_m=maximum_step,collision_poses_checked=collision_poses,
      core_collision_checks=core_checks,runic_plate_collision_checks=plate_checks,
      core_clear_of_plates_and_lattice=True,runic_plate_intersections=0,rigid_parts=True)
assert all(c==channels[0] for c in channels)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
scene.frame_set(1)

# Export a temporary assembled mesh, without joining the editable source pieces.
temporary=bpy.data.collections.new(st['name']+'_Export'); scene.collection.children.link(temporary)
vertices=[]; faces=[]; uvrows=[]; groups={}; triangles=0
for o in parts:
    offset=len(vertices); vertices.extend(tuple(v.co) for v in o.data.vertices)
    for v in o.data.vertices: groups.setdefault(o.vertex_groups[v.groups[0].group].name,[]).append(offset+v.index)
    o.data.calc_loop_triangles(); triangles+=len(o.data.loop_triangles)
    for p in o.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices)); uvrows.extend(tuple(o.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
mesh=bpy.data.meshes.new(st['name']+'_ExportMesh'); mesh.from_pydata(vertices,[],faces); mesh.update()
uv=mesh.uv_layers.new(name='Metric_Pixel_UV')
for i,row in enumerate(uvrows): uv.data[i].uv=row
mesh.materials.append(st['material'])
model=bpy.data.objects.new(st['name']+'_Model',mesh); temporary.objects.link(model); model.parent=rig
for bone,indices in groups.items(): model.vertex_groups.new(name=bone).add(indices,1,'REPLACE')
model.modifiers.new('Articulated_Pivots','ARMATURE').object=rig
try:
    bpy.ops.object.select_all(action='DESELECT')
    for o in (root,rig,model): o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    kwargs=dict(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
        export_force_sampling=True,export_frame_range=False,export_skins=True,export_def_bones=False,
        export_yup=True,export_cameras=False,export_lights=False)
    if 'export_optimize_animation_size' in bpy.ops.export_scene.gltf.get_rna_type().properties: kwargs['export_optimize_animation_size']=False
    bpy.ops.export_scene.gltf(**kwargs)
finally:
    bpy.data.objects.remove(model,do_unlink=True); bpy.data.meshes.remove(mesh); bpy.data.collections.remove(temporary)
raw=(OUT/(STEM+'.glb')).read_bytes(); length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]); binary=28+length
assert {a['name'] for a in doc['animations']}==set(st['clips'])
for a in doc['animations']:
    assert abs(max(doc['accessors'][s['input']]['max'][0] for s in a['samplers'])-st['clips'][a['name']]['duration_s'])<1e-5
assert len(doc['meshes'])==len(doc['materials'])==len(doc['skins'])==1
assert len(doc['skins'][0]['joints'])==len(rig.data.bones)
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives'])==triangles
embedded=[]
for image in doc['images']:
    view=doc['bufferViews'][image['bufferView']]; offset=binary+view.get('byteOffset',0)
    embedded.append(hashlib.sha256(raw[offset:offset+view['byteLength']]).hexdigest())
assert sorted(embedded)==sorted(hashlib.sha256(Path(im.filepath_raw).read_bytes()).hexdigest() for im in st['images'])
assert all(s['magFilter']==9728 for s in doc['samplers'])
report=dict(status='PASS',model=STEM,source_model='veil_archon_blocky_v8',approved_textures_preserved=True,
    rigid_body_geometry_preserved=True,retained_plates_lattice_and_core_preserved=True,external_purple_trails_removed=6,meshes=1,materials=1,
    triangles=triangles,bones=len(rig.data.bones),root_motion=False,fps=24,same_channels_all_clips=True,
    impact_time_s=.875,cast_time_s=2.,retained_parts=47,clips=validation,protected_files=len(st['old_hashes']))
(OUT/'animation_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
