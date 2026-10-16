"""Collapse the Archon core, then bake the compact fall of its runic plates via MCP."""
import bpy
import hashlib
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/veil_archon_summon_v1'
OUT = ROOT/'art_source/veil_archon_death_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'veil_archon_death_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(str(SOURCE/'veil_archon_summon.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Arconte do Veu - Morte'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 47 and len(rig.data.bones) == 39
assert scene.rigidbody_world is None
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: b.matrix.copy() for b in rig.pose.bones}
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
deforms = {name: matrix@inverse[name] for name, matrix in base.items()}
plates = [o for o in parts if o['kind'] == 'plate']
rows = {o['rig_bone']: [deforms[o['rig_bone']]@v.co for v in o.data.vertices] for o in plates}
assert len(rows) == 34
helpers = bpy.data.collections.new('Veil_Death_Physics_Temporary')
scene.collection.children.link(helpers)
bpy.ops.object.select_all(action='DESELECT')
proxies, centers, releases = {}, {}, {}
boxes = {o['rig_bone']: tuple((min(v[i] for v in rows[o['rig_bone']]),
                               max(v[i] for v in rows[o['rig_bone']])) for i in range(3)) for o in plates}
colors = {}
# Nearby plate hulls can touch even where the detailed geometry has a gap.
# Separate starting hulls so those contacts cannot eject the runestones.
neighbors = {n: {m for m in rows if m != n and
                all(boxes[n][i][0]-.025 <= boxes[m][i][1] and boxes[m][i][0]-.025 <= boxes[n][i][1]
                    for i in range(3))} for n in rows}
for name in sorted(neighbors, key=lambda n: -len(neighbors[n])):
    occupied = {colors[n] for n in neighbors[name] if n in colors}
    available = [i for i in range(19) if i not in occupied]
    assert available, ('Too many overlapping starting hulls', name)
    colors[name] = available[0]


def rot(x=0, y=0, z=0):
    return Euler(tuple(math.radians(v) for v in (x, y, z))).to_quaternion()


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


for index, obj in enumerate(plates):
    name = obj['rig_bone']
    vertices = rows[name]
    center = sum(vertices, Vector())/len(vertices)
    centers[name] = center
    mesh = bpy.data.meshes.new('Veil_FallProxy_'+name)
    mesh.from_pydata([v-center for v in vertices], [], [tuple(p.vertices) for p in obj.data.polygons])
    mesh.update()
    proxy = bpy.data.objects.new('Veil_FallProxy_'+name, mesh)
    helpers.objects.link(proxy)
    proxy.location = center
    proxy.rotation_mode = 'QUATERNION'
    proxy.hide_render = True
    proxy.display_type = 'WIRE'
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    bpy.ops.rigidbody.object_add()
    rb = proxy.rigid_body
    dimensions = [max(v[i] for v in vertices)-min(v[i] for v in vertices) for i in range(3)]
    rb.mass = max(.4, min(3., math.prod(dimensions)*90))
    rb.collision_shape = 'CONVEX_HULL'
    rb.use_margin = True
    rb.collision_margin = .001
    rb.friction = .95
    rb.restitution = .025
    rb.linear_damping = .72
    rb.angular_damping = .72
    rb.use_deactivation = True
    # Only the runic plates participate in the fall simulation.
    rb.collision_collections = tuple(i == colors[name] for i in range(20))
    rng = random.Random(2300+index)
    seed = int(obj['rune_seed'])
    release = 33+seed%7
    kick = Vector((-center.x*.05, -center.y*.05, .01))
    angles = (rng.uniform(-7, 7), rng.uniform(-7, 7), rng.uniform(-5, 5))
    releases[name] = release
    rb.kinematic = True
    rb.keyframe_insert(data_path='kinematic', frame=1)
    rb.keyframe_insert(data_path='kinematic', frame=release-1)
    rb.kinematic = False
    rb.keyframe_insert(data_path='kinematic', frame=release)
    for frame, amount in [(1, 0.), (max(2, release-4), 0.), (release-1, 1.)]:
        proxy.location = center+kick*amount
        proxy.rotation_quaternion = rot(*(a*amount for a in angles))
        proxy.keyframe_insert(data_path='location', frame=frame)
        proxy.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    for layer in proxy.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'CONSTANT' if 'kinematic' in curve.data_path else 'LINEAR'
    proxy.select_set(False)
    proxies[name] = proxy


def obstacle(name, center, half):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(x*half[0], y*half[1], z*half[2]) for x, y, z in
                     [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                      (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]], [],
                     [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    obj = bpy.data.objects.new(name, mesh)
    helpers.objects.link(obj)
    obj.location = center
    obj.hide_render = True
    obj.display_type = 'WIRE'
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.rigidbody.object_add()
    rb = obj.rigid_body
    rb.type = 'PASSIVE'
    rb.collision_shape = 'BOX'
    rb.use_margin = True
    rb.collision_margin = .001
    rb.friction = .95
    rb.restitution = 0.
    rb.collision_collections = (True,)*20
    obj.select_set(False)
    return obj


obstacles = [obstacle('Veil_Death_Floor', (0, 0, -.25), (8, 8, .25))]
for suffix, center, half in [
        ('L', (-1.70, 0, 1.8), (.05, 1.9, 2)),
        ('R', (1.70, 0, 1.8), (.05, 1.9, 2)),
        ('B', (0, 1.70, 1.8), (1.9, .05, 2)),
        ('F', (0, -1.70, 1.8), (1.9, .05, 2))]:
    obstacles.append(obstacle('Veil_Death_Compact_'+suffix, center, half))
world = scene.rigidbody_world
world.substeps_per_frame = 32
world.solver_iterations = 50
world.point_cache.frame_start, world.point_cache.frame_end = 1, 121
scene.frame_start, scene.frame_end = 1, 121
scene.render.fps = 24
scene.gravity = (0, 0, -9.81)
simulated = {}
for frame in range(1, 98):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    simulated[frame] = {name: p.evaluated_get(graph).matrix_world.copy()@Matrix.Translation(-centers[name])
                        for name, p in proxies.items()}
contacts = {}
for name, vertices in rows.items():
    points = [simulated[97][name]@v for v in vertices]
    contacts[name] = dict(bottom=min(p.z for p in points), top=max(p.z for p in points),
                          pivot=Vector((sum(p.x for p in points)/len(points),
                                        sum(p.y for p in points)/len(points), 0)))
action = bpy.data.actions.new('Veil_Archon_Death_Core_Collapse')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Nucleo e estrutura colapsam; placas runicas caem, repousam e desaparecem.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    desired = {name: matrix.copy() for name, matrix in base.items()}
    origin = rig.data.bones['core'].head_local
    for name, start, end, turn in [('core', .10, .76, 135), ('lattice', .64, 1.13, -30)]:
        amount = ease(t, start, end)
        size = max(.00001, 1-amount)
        spin = rot(0, 0, turn*amount).to_matrix().to_4x4()
        collapse = Matrix.Translation(origin)@spin@Matrix.Scale(size, 4)@Matrix.Translation(-origin)
        desired[name] = collapse@base[name]
    for name in proxies:
        transform = simulated[min(frame, 97)][name]
        fade = max(.00001, 1-ease(t, 4., 4.80))
        pivot = contacts[name]['pivot']
        shrink = Matrix.Translation(pivot)@Matrix.Scale(fade, 4)@Matrix.Translation(-pivot)
        desired[name] = shrink@transform@base[name]
    for b in rig.pose.bones:
        kwargs = dict(matrix=desired[b.name], matrix_local=b.bone.matrix_local, invert=True)
        if b.parent:
            kwargs.update(parent_matrix=desired[b.parent.name], parent_matrix_local=b.parent.bone.matrix_local)
        b.rotation_mode = 'QUATERNION'
        b.matrix_basis = b.bone.convert_local_to_pose(**kwargs)
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion) < 0:
            b.rotation_quaternion.negate()
        previous[b.name] = b.rotation_quaternion.copy()
        for path in ('location', 'rotation_quaternion', 'scale'):
            b.keyframe_insert(data_path=path, frame=frame, group=b.name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = 'LINEAR'
bpy.ops.rigidbody.world_remove()
for obj in [*proxies.values(), *obstacles]:
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
bpy.data.collections.remove(helpers)
scene.frame_start, scene.frame_end = 1, 121
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.use_nodes = False
scene.camera.data.ortho_scale = 5.5
scene.camera.location = (4, -10, 7.0)
scene.camera.rotation_euler = (Vector((0, 0, 1.05))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.timeline_markers.clear()
for label, frame in [('NUCLEO COLAPSA', 4), ('ESTRUTURA SOME', 22), ('PLACAS CAEM', 33),
                     ('NO CHAO', 76), ('PLACAS DESAPARECEM', 97), ('FIM', 117)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Death'
scene['description'] = 'Morte: nucleo e estrutura colapsam; placas caem no chao e desaparecem. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['veil_archon_death'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected,
    contacts=contacts, releases=releases,
    simulation='Blender Bullet, gravity -9.81, 32 substeps, 50 solver iterations')
result = dict(scene=scene.name, duration_s=5, falling_plates=34, parts=47, bones=39, particles_included=False,
              settled_min_z=min(c['bottom'] for c in contacts.values()),
              settled_max_z=max(c['top'] for c in contacts.values()))
