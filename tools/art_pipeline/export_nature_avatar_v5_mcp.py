"""Audit actual sampled poses and export the four animated Avatar clips."""
import bpy,bmesh,math,json,struct,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['nature_avatar_blocky_v5_animated']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; ROOT=OUT.parents[3]; old=st['reference']
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
assert len(parts)==len(old['parts'])==86
for o,original in zip(parts,old['parts']):
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
# Sample every half frame, checking real geometry, arm attachment and rotating-core clearance.
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[]; validation={}; idle_first=None
for track in rig.animation_data.nla_tracks: track.mute=True
def transformed(o,matrices):
    return [matrices[o.vertex_groups[v.groups[0].group].name]@v.co for v in o.data.vertices]
def bounds(points):
    return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
def intersects(a,b): return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
core=next(o for o in parts if o['rig_bone']=='core')
targets=[o for o in parts if o!=core]
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags: channel_set.update((curve.data_path,curve.array_index) for curve in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3); high=Vector((-1e9,)*3)
    first=previous=None; maximum_step=joint_error=wrist_angle=core_center_error=0.; collision_checks=0
    tips={}; root_anchor_error=0.
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        frame=1+step/2; scene.frame_set(int(frame),subframe=frame%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        for bone,matrix in matrices.items():
            scales=[matrix.to_3x3().col[i].length for i in range(3)]
            assert abs(max(scales)-min(scales))<1e-5 and matrix.determinant()>0,(name,frame,bone)
            if bone!='core': assert max(abs(s-1) for s in scales)<1e-5,(name,frame,bone)
        for side,(shoulder,elbow,wrist) in st['arms'].items():
            for position,a,b in [(shoulder,'chest','upper_arm_'+side),(elbow,'upper_arm_'+side,'forearm_'+side),(wrist,'forearm_'+side,'hand_'+side)]:
                joint_error=max(joint_error,(matrices[a]@position-matrices[b]@position).length)
            wrist_angle=max(wrist_angle,math.degrees(rig.pose.bones['hand_'+side].rotation_quaternion.angle))
        assert joint_error<1e-5 and wrist_angle<15.01,(name,frame,joint_error,wrist_angle)
        posed={o.name:transformed(o,matrices) for o in parts}
        points=[p for vv in posed.values() for p in vv]
        for p in points:
            for k in range(3): low[k]=min(low[k],p[k]); high[k]=max(high[k],p[k])
        for bone in st['root_bones']:
            anchor=rig.data.bones[bone].head_local
            root_anchor_error=max(root_anchor_error,(matrices[bone]@anchor-matrices['body']@anchor).length)
            candidates=[o for o in parts if o['rig_bone']==bone]
            panel=min(candidates,key=lambda o:min(v.co.z for v in o.data.vertices))
            tip=min(range(len(panel.data.vertices)),key=lambda i:panel.data.vertices[i].co.z)
            tips.setdefault(bone,[]).append(matrices['body'].inverted()@posed[panel.name][tip])
        assert root_anchor_error<1e-5,(name,frame,'detached root',root_anchor_error)
        # The cube must remain clear of the actual posed bark, crown, arms and roots.
        if step%4==0 or name in ('Attack','Spell') and step%2==0:
            core_points=posed[core.name]; core_bounds=bounds(core_points)
            tree=None
            for target in targets:
                if not intersects(core_bounds,bounds(posed[target.name])): continue
                if tree is None: tree=BVHTree.FromPolygons(core_points,[tuple(p.vertices) for p in core.data.polygons])
                other=BVHTree.FromPolygons(posed[target.name],[tuple(p.vertices) for p in target.data.polygons])
                assert not tree.overlap(other),('Core/bark intersection',name,frame,target.name)
                collision_checks+=1
        if first is None: first=[p.copy() for p in points]
        if previous is not None: maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous,points)))
        previous=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5 and low.z>.20,(name,seam,low.z)
    assert maximum_step<.18,(name,maximum_step)
    if name=='Idle': idle_first=first
    if name in ('Attack','Spell'): assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    tip_ranges={bone:(Vector(tuple(max(v[i] for v in vv) for i in range(3)))-Vector(tuple(min(v[i] for v in vv) for i in range(3)))).length for bone,vv in tips.items()}
    assert min(tip_ranges.values())>.006,(name,'roots motion',tip_ranges)
    validation[name]=dict(samples=samples,loop=data['loop'],duration_s=data['duration_s'],description=data['description'],
      minimum_ground_clearance_m=low.z,bounds_min_m=list(low),bounds_max_m=list(high),seam_vertex_delta_m=seam,
      maximum_half_frame_vertex_step_m=maximum_step,maximum_joint_gap_m=joint_error,maximum_wrist_rotation_deg=wrist_angle,
      root_anchor_error_m=root_anchor_error,root_tip_motion_m=tip_ranges,core_collision_checks=collision_checks,
      core_clear_of_bark=True,body_and_limbs_rigid=True)
assert all(c==channels[0] for c in channels)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
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
report=dict(status='PASS',model=STEM,source_model='nature_avatar_blocky_v4',approved_textures_preserved=True,
    rigid_body_geometry_preserved=True,suspended_root_geometry_preserved=True,meshes=1,materials=1,
    triangles=triangles,bones=len(rig.data.bones),root_motion=False,fps=24,same_channels_all_clips=True,
    rest_crown_height_above_ground_m=3.,rest_height_m=2.5801127851,clips=validation,protected_files=len(st['old_hashes']))
(OUT/'animation_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
