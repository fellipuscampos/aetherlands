"""Simulate detached armor hitting the floor; bake the result into the existing rig.

Run via Blender MCP after animate_archdemon_lifecycle_mcp.py, before finish/export.
No simulation helpers or particles are included in the resulting character asset.
"""
import bpy
import json
import math
import shutil
from pathlib import Path
from mathutils import Vector, Matrix, Euler

st = bpy.app.driver_namespace['archdemon_lifecycle']
scene, rig, parts = st['scene'], st['rig'], st['parts']
OUT = Path(st['out'])
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
assert scene.rigidbody_world is None, 'Keep any existing physics setup intact.'
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = st['idle']
scene.frame_set(1)
base_pose = {b.name: b.matrix.copy() for b in rig.pose.bones}
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
deforms = {n: base_pose[n]@inverse[n] for n in base_pose}


def group_for_bone(name):
    if name.startswith('stole_'):
        return name.rsplit('_', 1)[0]
    return name


bone_groups = {b.name: group_for_bone(b.name) for b in rig.data.bones
               if b.name != 'root' and not b.name.startswith('vanish_')}
group_vertices, group_faces = {}, {}
for obj, binds in st['bindings']:
    group = group_for_bone(obj['rig_bone'])
    vertices = group_vertices.setdefault(group, [])
    faces = group_faces.setdefault(group, [])
    offset = len(vertices)
    vertices.extend(sum((deforms[n]@v.co*w for n, w in bind), Vector())
                    for v, bind in zip(obj.data.vertices, binds))
    faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
assert len(group_vertices) == 16

# Back up the previous review once, so the approved Summon can be compared after export.
previous_export = OUT/'archdemon_lifecycle.glb'
baseline_export = OUT/'before_ground_death.glb'
if previous_export.exists() and not baseline_export.exists():
    shutil.copy2(previous_export, baseline_export)

helpers = bpy.data.collections.new('Archdemon_Death_Physics_Temporary')
scene.collection.children.link(helpers)
bpy.ops.object.select_all(action='DESELECT')
proxies, centers, releases = {}, {}, {}
for index, (name, vertices) in enumerate(group_vertices.items()):
    center = sum(vertices, Vector())/len(vertices)
    centers[name] = center
    mesh = bpy.data.meshes.new('FallProxy_'+name)
    mesh.from_pydata([v-center for v in vertices], [], group_faces[name])
    mesh.update()
    proxy = bpy.data.objects.new('FallProxy_'+name, mesh)
    helpers.objects.link(proxy)
    proxy.location = center
    proxy.rotation_mode = 'QUATERNION'
    proxy.display_type = 'WIRE'
    proxy.hide_render = True
    bpy.context.view_layer.objects.active = proxy
    proxy.select_set(True)
    bpy.ops.rigidbody.object_add()
    body = proxy.rigid_body
    body.mass = 4. if name in ('chest', 'body') else (2. if name.startswith(('fist', 'shoulder')) else .7)
    body.collision_shape = 'CONVEX_HULL'
    body.use_margin = True
    body.collision_margin = .002
    body.friction = .98
    body.restitution = .035 if name.startswith('fist') else .015
    body.linear_damping = .78
    body.angular_damping = .76
    body.use_deactivation = True
    # The core starts inside a hollow breastplate, and cloth rests against armor.
    # Separate collision layers prevent convex proxy hulls from ejecting these parts.
    layer = 1 if name == 'core' else (2 if name.startswith('stole_') else 0)
    body.collision_collections = tuple(i == layer for i in range(20))
    sign = -1 if name.endswith(('_L', '_l')) else 1
    if name.startswith('fist'):
        release, kick = (6 if sign < 0 else 9), Vector((-sign*.085, .005, .01))
        angles = (sign*6, 8, sign*5)
    elif name.startswith('shoulder'):
        release, kick = (10 if sign < 0 else 13), Vector((-sign*.10, 0, .01))
        angles = (sign*5, sign*8, -sign*5)
    elif name == 'crown':
        release, kick, angles = 16, Vector((.015, -.02, .01)), (10, 4, -4)
    elif name == 'chest':
        release, kick, angles = 14, Vector((0, .01, 0)), (-9, 2, 1)
    elif name == 'body':
        release, kick, angles = 18, Vector((0, 0, 0)), (8, -3, 1)
    elif name == 'core':
        release, kick, angles = 15, Vector((0, -.015, .01)), (7, 7, 6)
    elif name.startswith('mantle'):
        release, kick, angles = 8+(index%4), Vector((-sign*.09, -.06, 0)), (6, sign*5, sign*6)
    else:
        release, kick, angles = 18+(index%3), Vector((-sign*.015, -.015, 0)), (10, sign*3, 0)
    releases[name] = release
    body.kinematic = True
    body.keyframe_insert(data_path='kinematic', frame=1)
    body.keyframe_insert(data_path='kinematic', frame=release-1)
    body.kinematic = False
    body.keyframe_insert(data_path='kinematic', frame=release)
    for frame, fraction in [(1, 0.), (max(2, release-4), 0.), (release-1, 1.)]:
        proxy.location = center+kick*fraction
        proxy.rotation_quaternion = Euler(tuple(math.radians(a)*fraction for a in angles)).to_quaternion()
        proxy.keyframe_insert(data_path='location', frame=frame)
        proxy.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    for layer_action in proxy.animation_data.action.layers:
        for strip in layer_action.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'CONSTANT' if 'kinematic' in curve.data_path else 'LINEAR'
    proxy.select_set(False)
    proxies[name] = proxy

floor_mesh = bpy.data.meshes.new('Death_Collision_Floor')
floor_mesh.from_pydata([(-10,-10,-.05),(10,-10,-.05),(10,10,-.05),(-10,10,-.05),
                       (-10,-10,.05),(10,-10,.05),(10,10,.05),(-10,10,.05)], [],
                      [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
floor = bpy.data.objects.new('Death_Collision_Floor', floor_mesh)
helpers.objects.link(floor)
floor.location.z = -.05
floor.hide_render = True
floor.display_type = 'WIRE'
floor.select_set(True)
bpy.context.view_layer.objects.active = floor
bpy.ops.rigidbody.object_add()
floor.rigid_body.type = 'PASSIVE'
floor.rigid_body.collision_shape = 'BOX'
floor.rigid_body.use_margin = True
floor.rigid_body.collision_margin = .001
floor.rigid_body.friction = .9
floor.rigid_body.collision_collections = (True,)*20
floor.select_set(False)
# Temporary bounds keep collision impulses from scattering debris across nearby
# tiles. They affect only the authoring simulation and are absent from the asset.
walls = []
for name, center, half in [
        ('L', (-1.10, 0, 1.65), (.05, 1.3, 1.7)),
        ('R', (1.10, 0, 1.65), (.05, 1.3, 1.7)),
        ('B', (0, 1.15, 1.65), (1.3, .05, 1.7)),
        ('F', (0, -1.15, 1.65), (1.3, .05, 1.7))]:
    mesh = bpy.data.meshes.new('Death_Compact_Bound_'+name)
    mesh.from_pydata([(x*half[0], y*half[1], z*half[2])
                     for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                   (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]], [],
                    [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    obj = bpy.data.objects.new('Death_Compact_Bound_'+name, mesh)
    helpers.objects.link(obj)
    obj.location = center
    obj.hide_render = True
    obj.display_type = 'WIRE'
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.rigidbody.object_add()
    obj.rigid_body.type = 'PASSIVE'
    obj.rigid_body.collision_shape = 'BOX'
    obj.rigid_body.use_margin = True
    obj.rigid_body.collision_margin = .001
    obj.rigid_body.friction = .85
    obj.rigid_body.restitution = 0.
    obj.rigid_body.collision_collections = (True,)*20
    obj.select_set(False)
    walls.append(obj)
world = scene.rigidbody_world
world.substeps_per_frame = 12
world.solver_iterations = 40
world.point_cache.frame_start = 1
world.point_cache.frame_end = 121
scene.frame_start, scene.frame_end = 1, 121
scene.render.fps = 24
scene.gravity = (0, 0, -9.81)

# Sample the actual Bullet solution sequentially and hold its settled pose afterward.
simulated = {}
for frame in range(1, 98):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    simulated[frame] = {name: proxy.evaluated_get(graph).matrix_world.copy() @ Matrix.Translation(-centers[name])
                        for name, proxy in proxies.items()}
contact = {}
settled_vertices = []
for name, vertices in group_vertices.items():
    transform = simulated[97][name]
    posed = [transform@v for v in vertices]
    settled_vertices.extend(posed)
    contact[name] = dict(bottom=min(v.z for v in posed), top=max(v.z for v in posed),
                         pivot=[sum(v[i] for v in posed)/len(posed) for i in range(2)]+[0.])

# Add leaf pivots for disappearance, so shrinking a waist cannot drag distant
# independent children across the scene between sampled frames. Each cloth strip
# shares one world-space shrink pivot, preserving its seams while disappearing.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, group in bone_groups.items():
    leaf_name = 'vanish_'+name
    if leaf_name not in rig.data.edit_bones:
        leaf = rig.data.edit_bones.new(leaf_name)
        leaf.parent = rig.data.edit_bones[name]
        leaf.head = deforms[name].inverted()@centers[group]
        leaf.tail = leaf.head+Vector((0, 0, .12))
bpy.ops.object.mode_set(mode='OBJECT')
for obj in parts:
    for group in obj.vertex_groups:
        if not group.name.startswith('vanish_'):
            group.name = 'vanish_'+group.name
st['bindings'] = [(o, [[(o.vertex_groups[g.group].name, g.weight) for g in v.groups]
                       for v in o.data.vertices]) for o in parts]
reset_actions = {st['idle'], st['clips']['Summon']['action']}
reset_actions.update(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name != 'Death')
for reset_action in reset_actions:
    rig.animation_data.action = reset_action
    for name in bone_groups:
        b = rig.pose.bones['vanish_'+name]
        b.rotation_mode = 'QUATERNION'
        b.location = (0, 0, 0)
        b.rotation_quaternion = (1, 0, 0, 0)
        b.scale = (1, 1, 1)
        for frame in (1, round(reset_action.frame_range[1])):
            for path in ('location', 'rotation_quaternion', 'scale'):
                b.keyframe_insert(data_path=path, frame=frame, group=b.name)

# Convert each independent component back to its original bone hierarchy.
# The leaf pivots above handle disappearance after all pieces are on the floor.
action = bpy.data.actions.new('Archdemon_Death_Ground')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Pecas caem com gravidade e colisao no piso, repousam no chao e so depois desaparecem.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    transform = simulated[min(frame, 97)]
    x = max(0., min(1., (frame-97)/16))
    scale = max(.00001, 1-x*x*(3-2*x))
    desired = {'root': base_pose['root']}
    for name, group in bone_groups.items():
        desired[name] = transform[group] @ base_pose[name]
    for b in rig.pose.bones:
        if b.name.startswith('vanish_'):
            b.rotation_mode = 'QUATERNION'
            b.location = (0, 0, 0)
            b.rotation_quaternion = (1, 0, 0, 0)
            b.scale = (scale,)*3
            for path in ('location', 'rotation_quaternion', 'scale'):
                b.keyframe_insert(data_path=path, frame=frame, group=b.name)
            continue
        bone = b.bone
        kwargs = dict(matrix=desired[b.name], matrix_local=bone.matrix_local, invert=True)
        if bone.parent:
            kwargs.update(parent_matrix=desired[bone.parent.name], parent_matrix_local=bone.parent.matrix_local)
        b.rotation_mode = 'QUATERNION'
        b.matrix_basis = bone.convert_local_to_pose(**kwargs)
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion) < 0:
            b.rotation_quaternion.negate()
        previous[b.name] = b.rotation_quaternion.copy()
        for path in ('location', 'rotation_quaternion', 'scale'):
            b.keyframe_insert(data_path=path, frame=frame, group=b.name)
for layer_action in action.layers:
    for strip in layer_action.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = 'LINEAR'
st['clips']['Death'] = dict(action=action, duration_s=5., end_frame=121)
st['ground_death'] = dict(groups=bone_groups, contacts=contact, releases=releases,
                         settled_bounds_min=[min(v[i] for v in settled_vertices) for i in range(3)],
                         settled_bounds_max=[max(v[i] for v in settled_vertices) for i in range(3)],
                         compact_landing=True, landing_limit_xy=[2.1, 2.2],
                         full_size_until_frame=97, disappears_after_landing=True,
                         visibility_leaf_bones=len(bone_groups),
                         simulation='Blender Bullet, gravity -9.81, 12 substeps, 40 solver iterations')
(OUT/'ground_death_simulation.json').write_text(json.dumps(st['ground_death'], indent=2), encoding='utf-8')
# Helpers are intentionally absent from the saved scene and exported model.
bpy.ops.rigidbody.world_remove()
for obj in [*proxies.values(), floor, *walls]:
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
bpy.data.collections.remove(helpers)
scene.frame_start, scene.frame_end = 1, 121
scene.frame_set(1)
scene['preview_clip'] = 'Death'
scene.timeline_markers.clear()
for label, frame in [('PECAS SE SOLTAM', 6), ('QUEDA E IMPACTOS', 25), ('REPOUSO NO CHAO', 73),
                     ('DESAPARECE', 97), ('FIM', 113)]:
    scene.timeline_markers.new(label, frame=frame)
result = {'clip': 'Death', 'duration_s': 5, 'parts_groups': len(proxies),
          'floor_contacts': contact, 'disappearance_starts_s': 4., 'particles_included': False}
