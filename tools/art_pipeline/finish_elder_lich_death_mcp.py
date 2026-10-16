"""Validate Death, then export an isolated Lich review through the live Blender."""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

st = bpy.app.driver_namespace['elder_lich_death']
scene, rig, parts = st['scene'], st['rig'], st['parts']
OUT = Path(st['out'])
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
for path, digest in st['protected'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest
for track in rig.animation_data.nla_tracks:
    track.mute = True
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}


def geometry():
    matrices = {b.name: b.matrix@inverse[b.name] for b in rig.pose.bones}
    rows = {o.name: [matrices[o.vertex_groups[v.groups[0].group].name]@v.co
                     for v in o.data.vertices] for o in parts}
    return matrices, rows


def bounds(points):
    return tuple(min(p[i] for p in points) for i in range(3)), tuple(max(p[i] for p in points) for i in range(3))


rig.animation_data.action = st['idle']
scene.frame_set(1)
_, idle = geometry()
rig.animation_data.action = st['action']
low, high = Vector((1e9,)*3), Vector((-1e9,)*3)
first = previous = None
max_step = joint_gap = wrist_angle = anchor_error = 0.
submersion = {}
props = [o for o in parts if o['rig_bone'] in ('staff', 'staff_focus', 'tome')]
body = [o for o in parts if o['rig_bone'] in ('body', 'chest', 'head')]
collision_checks = 0
for half in range(241):
    f = 1+half/2
    scene.frame_set(int(f), subframe=f%1)
    matrices, rows = geometry()
    assert all(abs(matrices['root'][i][j]-float(i == j)) < 1e-6 for i in range(4) for j in range(4))
    points = [p for o in parts for p in rows[o.name]]
    assert all(math.isfinite(x) for p in points for x in p)
    for p in points:
        for i in range(3):
            low[i] = min(low[i], p[i])
            high[i] = max(high[i], p[i])
    # Full-size geometry deliberately passes below the terrain; no shrink/fade.
    assert all(abs(s-1.) < 1e-5 for b in rig.pose.bones for s in b.scale)
    if f in (1., 25., 49., 73., 97., 121.):
        minimum, maximum = bounds(points)
        submersion[(f-1)/24] = dict(minimum=list(minimum), maximum=list(maximum),
                                  fraction_vertices_above_floor=sum(p.z>0 for p in points)/len(points))
    for side in ('L','R'):
        joints = [rig.data.bones[n+'_'+side].head_local for n in ('upper_arm','forearm','hand')]
        for p, a, b in [(joints[0], 'chest', 'upper_arm_'+side), (joints[1], 'upper_arm_'+side, 'forearm_'+side), (joints[2], 'forearm_'+side, 'hand_'+side)]:
            joint_gap = max(joint_gap, (matrices[a]@p-matrices[b]@p).length)
        q=rig.pose.bones['hand_'+side].rotation_quaternion
        wrist_angle = max(wrist_angle, math.degrees(2*math.acos(min(1.,abs(q.w)))))
    for o in parts:
        name=o['rig_bone']
        if name.startswith(('cape_', 'robe_')) and name in rig.data.bones:
            for v,p in zip(o.data.vertices,rows[o.name]):
                if o.vertex_groups[v.groups[0].group].name == name:
                    anchor_error=max(anchor_error,(p-matrices[rig.data.bones[name].parent.name]@v.co).length)
    if half%6==0 and f<=97:
        boxes={o.name:bounds(rows[o.name]) for o in props+body}
        trees={}
        for prop in props:
            for target in body:
                a,b=boxes[prop.name],boxes[target.name]
                if not all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3)): continue
                for o in (prop,target):
                    if o.name not in trees:
                        trees[o.name]=BVHTree.FromPolygons(rows[o.name],[tuple(p.vertices) for p in o.data.polygons])
                assert not trees[prop.name].overlap(trees[target.name]),('prop collision',f,prop.name,target.name)
                collision_checks+=1
    if first is None: first=[p.copy() for p in points]
    if previous is not None:
        max_step=max(max_step,max((a-b).length for a,b in zip(previous,points)))
    previous=points
idle_points=[p for o in parts for p in idle[o.name]]
join_error=max((p-q).length for p,q in zip(first,idle_points))
assert join_error<1e-5,join_error
assert joint_gap<1e-5 and anchor_error<1e-5,(joint_gap,anchor_error)
assert max_step<.25,max_step
assert max(p.z for p in points)<-.05
assert submersion[0.]['maximum'][2]>3.
assert submersion[2.]['minimum'][2]<-.25
assert submersion[3.]['maximum'][2]<2.
assert submersion[4.]['maximum'][2]<.8
assert submersion[5.]['fraction_vertices_above_floor']==0

# Preserve every original vertex binding and UV while joining only a temporary export mesh.
vertices, faces, uvrows, groups = [], [], [], {}
for obj in parts:
    offset = len(vertices)
    vertices.extend(tuple(v.co) for v in obj.data.vertices)
    for v in obj.data.vertices:
        assert len(v.groups) == 1
        groups.setdefault(obj.vertex_groups[v.groups[0].group].name, []).append(offset+v.index)
    for p in obj.data.polygons:
        faces.append(tuple(offset+i for i in p.vertices))
        uvrows.extend(tuple(obj.data.uv_layers.active.data[li].uv) for li in p.loop_indices)
mesh = bpy.data.meshes.new('Elder_Lich_Death_ExportMesh')
mesh.from_pydata(vertices, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metric_Pixel_UV')
for i, row in enumerate(uvrows):
    uv.data[i].uv = row
mesh.materials.append(parts[0].data.materials[0])
model = bpy.data.objects.new('Elder_Lich', mesh)
scene.collection.objects.link(model)
model.parent = rig
for name, indices in groups.items():
    model.vertex_groups.new(name=name).add(indices, 1, 'REPLACE')
model.modifiers.new('Approved_Pivots', 'ARMATURE').object = rig
rig.animation_data.action = None
old = next((t for t in rig.animation_data.nla_tracks if t.name == 'Death'), None)
if old is not None:
    rig.animation_data.nla_tracks.remove(old)
track = rig.animation_data.nla_tracks.new()
track.name = 'Death'
track.strips.new('Death', 1, st['action']).extrapolation = 'NOTHING'
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_set(1)
try:
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (rig.parent, rig, model):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'elder_lich_death.glb'), export_format='GLB',
        use_selection=True, use_active_scene=True, export_animations=True,
        export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
        export_force_sampling=True, export_frame_range=False, export_skins=True,
        export_def_bones=False, export_yup=True, export_cameras=False, export_lights=False,
        export_optimize_animation_size=False)
finally:
    bpy.data.objects.remove(model, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = st['action']
raw = (OUT/'elder_lich_death.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
assert {a['name'] for a in doc['animations']} == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon', 'Death'}
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 37
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives']) == 1548
report = dict(status='PASS', via='Blender MCP live', duration_s=5, frames=121, samples=241,
              fps=24, parts=79, bones=37, particles_included=False, root_motion=False,
              initial_to_idle_vertex_error_m=join_error, bounds_min=list(low), bounds_max=list(high),
              maximum_half_frame_step_m=max_step, joint_gap_m=joint_gap,
              maximum_wrist_angle_deg=wrist_angle, cloth_anchor_error_m=anchor_error,
              prop_body_collision_checks=collision_checks, prop_body_intersections=0,
              death_style='sinks while agonizing', sinking_samples=submersion,
              full_size_throughout=True, final_all_vertices_below_floor=True,
              original_asset_files_unchanged=True)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
st['report'] = report
bpy.ops.object.select_all(action='DESELECT')
rig.parent.select_set(True)
bpy.context.view_layer.objects.active = rig.parent
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        space.shading.use_scene_world = space.shading.use_scene_lights = True
        space.overlay.show_overlays = False
        space.region_3d.view_perspective = 'CAMERA'
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/'elder_lich_death.blend'), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
result = report
