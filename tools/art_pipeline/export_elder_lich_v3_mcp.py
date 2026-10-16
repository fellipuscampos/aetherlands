"""Audit actual sampled poses and export the four animated Lich clips."""
import bpy,bmesh,math,json,struct,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

st=bpy.app.driver_namespace['elder_lich_blocky_v3_animated']
scene,rig,root,parts=st['scene'],st['rig'],st['root'],st['parts']
OUT=Path(st['out']); STEM=st['stem']; ROOT=OUT.parents[3]; old=st['reference']
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
for path,digest in st['old_hashes'].items(): assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
assert len(parts)==len(old['parts'])==79
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
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[]; validation={}; idle_first=None
for track in rig.animation_data.nla_tracks: track.mute=True

def transformed(o,matrices):
    return [matrices[o.vertex_groups[v.groups[0].group].name]@v.co for v in o.data.vertices]
def center(o,points): return sum(points,Vector())/len(points)
def bounds(points):
    return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
def intersects(a,b): return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))

props=[o for o in parts if o['rig_bone'] in ('staff','staff_focus','tome')]
body=[o for o in parts if o['rig_bone'] in ('head','chest','body')]
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags: channel_set.update((curve.data_path,curve.array_index) for curve in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3); high=Vector((-1e9,)*3)
    first=previous=None; maximum_step=0.; joint_error=0.; wrist_angle=0.; collision_checks=0
    cloth_tips={}; anchor_error=0.
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        frame=1+step/2; scene.frame_set(int(frame),subframe=frame%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        for bone,matrix in matrices.items():
            scales=[matrix.to_3x3().col[i].length for i in range(3)]
            assert abs(max(scales)-min(scales))<1e-5 and matrix.determinant()>0,(name,frame,bone)
            if bone!='staff_focus': assert max(abs(s-1) for s in scales)<1e-5,(name,frame,bone)
        for side,(shoulder,elbow,wrist) in st['arms'].items():
            for position,a,b in [(shoulder,'chest','upper_arm_'+side),(elbow,'upper_arm_'+side,'forearm_'+side),(wrist,'forearm_'+side,'hand_'+side)]:
                joint_error=max(joint_error,(matrices[a]@position-matrices[b]@position).length)
            wrist_angle=max(wrist_angle,math.degrees(rig.pose.bones['hand_'+side].rotation_quaternion.angle))
        assert joint_error<1e-5 and wrist_angle<35.01,(name,frame,joint_error,wrist_angle)
        posed={o.name:transformed(o,matrices) for o in parts}
        points=[p for vv in posed.values() for p in vv]
        for p in points:
            for k in range(3): low[k]=min(low[k],p[k]); high[k]=max(high[k],p[k])
        for base,cloth in st['cloth'].items():
            for o in cloth['parts']:
                for v,p in zip(o.data.vertices,posed[o.name]):
                    if o.vertex_groups[v.groups[0].group].name==base:
                        anchor_error=max(anchor_error,(p-matrices[rig.data.bones[base].parent.name]@v.co).length)
            panel=max(cloth['parts'],key=lambda o:len(o.data.vertices))
            lowest=min(range(len(panel.data.vertices)),key=lambda i:(panel.data.vertices[i].co-cloth['anchor']).dot(cloth['up']))
            tip=matrices['body'].inverted()@posed[panel.name][lowest]
            cloth_tips.setdefault(base,[]).append(tip)
        assert anchor_error<1e-5,(name,'detached cloth',anchor_error)
        # Sample collisions with the skull, cowl and torso, excluding intentional
        # staff/hand contact. Narrow phase uses the actual posed triangles.
        if step%12==0 or name in ('Attack','Spell') and step%4==0:
            boxes={o.name:bounds(posed[o.name]) for o in props+body}
            trees={}
            for prop in props:
                for target in body:
                    if not intersects(boxes[prop.name],boxes[target.name]): continue
                    for o in (prop,target):
                        if o.name not in trees: trees[o.name]=BVHTree.FromPolygons(posed[o.name],[tuple(p.vertices) for p in o.data.polygons])
                    assert not trees[prop.name].overlap(trees[target.name]),('Prop intersection',name,frame,prop.name,target.name)
                    collision_checks+=1
        if first is None: first=[p.copy() for p in points]
        if previous is not None: maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous,points)))
        previous=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5 and low.z>.09,(name,seam,low.z)
    assert maximum_step<.15,(name,maximum_step)
    if name=='Idle': idle_first=first
    if name in ('Attack','Spell'): assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    tip_ranges={base:(Vector(tuple(max(v[i] for v in vv) for i in range(3)))-Vector(tuple(min(v[i] for v in vv) for i in range(3)))).length for base,vv in cloth_tips.items()}
    assert min(tip_ranges.values())>.01,(name,'cloth motion',tip_ranges)
    validation[name]=dict(samples=samples,loop=data['loop'],duration_s=data['duration_s'],description=data['description'],
        minimum_ground_clearance_m=low.z,bounds_min_m=list(low),bounds_max_m=list(high),seam_vertex_delta_m=seam,
        maximum_half_frame_vertex_step_m=maximum_step,maximum_joint_gap_m=joint_error,maximum_wrist_rotation_deg=wrist_angle,
        cloth_anchor_error_m=anchor_error,cloth_tip_motion_m=tip_ranges,props_body_collision_checks=collision_checks,
        body_and_limbs_rigid=True)
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
report=dict(status='PASS',model=STEM,source_model='elder_lich_blocky_v2',approved_textures_preserved=True,
    rigid_body_geometry_preserved=True,cloth_surface_tessellation_only=True,meshes=1,materials=1,
    triangles=triangles,bones=len(rig.data.bones),root_motion=False,fps=24,same_channels_all_clips=True,
    rest_height_m=3.,clips=validation,protected_files=len(st['old_hashes']))
(OUT/'animation_report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
st['report']=report
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report
