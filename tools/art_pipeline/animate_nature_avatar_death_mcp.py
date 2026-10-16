"""Simulate and bake the Avatar's wooden body collapsing around its fallen core."""
import bpy
import hashlib
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/nature_avatar_summon_v1'
OUT = ROOT/'art_source/nature_avatar_death_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'nature_avatar_death_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(str(SOURCE/'nature_avatar_summon.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Avatar da Natureza - Morte'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 86 and len(rig.data.bones) == 103
assert scene.rigidbody_world is None
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: b.matrix.copy() for b in rig.pose.bones}
inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
deforms = {name: matrix@inverse[name] for name, matrix in base.items()}
rows = {o['rig_bone']: [deforms[o['rig_bone']]@v.co for v in o.data.vertices] for o in parts}
assert len(rows) == 86
helpers = bpy.data.collections.new('Nature_Death_Physics_Temporary')
scene.collection.children.link(helpers)
bpy.ops.object.select_all(action='DESELECT')
proxies, centers, releases = {}, {}, {}
boxes = {o['rig_bone']: tuple((min(v[i] for v in rows[o['rig_bone']]),
                               max(v[i] for v in rows[o['rig_bone']])) for i in range(3)) for o in parts}
colors = {'core': 19}
# Interlocking facets already overlap in the approved model. Give overlapping
# starting hulls different collision layers instead of letting Bullet eject them.
neighbors = {n: {m for m in rows if m != n and m != 'core' and
                all(boxes[n][i][0]-.025 <= boxes[m][i][1] and boxes[m][i][0]-.025 <= boxes[n][i][1]
                    for i in range(3))} for n in rows if n != 'core'}
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


for index, obj in enumerate(parts):
    name = obj['rig_bone']
    vertices = rows[name]
    center = sum(vertices, Vector())/len(vertices)
    centers[name] = center
    mesh = bpy.data.meshes.new('Nature_FallProxy_'+name)
    mesh.from_pydata([v-center for v in vertices], [], [tuple(p.vertices) for p in obj.data.polygons])
    mesh.update()
    proxy = bpy.data.objects.new('Nature_FallProxy_'+name, mesh)
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
    # The core stays visibly separate from the interlocking hollow wooden body.
    rb.collision_collections = tuple(i == colors[name] for i in range(20))
    rng = random.Random(2300+index)
    parent = obj.get('source_rig_bone', name)
    if name == 'core':
        release = 16
        kick = Vector((.01, -.025, .025))
        angles = (11, -8, 13)
    else:
        release = (10 if 'arm' in parent or 'hand' in parent else
                   15 if parent in ('body', 'chest') else 20)+rng.randrange(0, 5)
        # A slight inward velocity keeps the fallen wood close to the unit's tile.
        kick = Vector((-center.x*.035, -center.y*.025, .015))
        angles = (rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(-4, 4))
    releases[name] = release
    rb.kinematic = True
    rb.keyframe_insert(data_path='kinematic', frame=1)
    rb.keyframe_insert(data_path='kinematic', frame=release-1)
    rb.kinematic = False
    rb.keyframe_insert(data_path='kinematic', frame=release)
    for frame, amount in [(1, 0.), (max(2, release-5), 0.), (release-1, 1.)]:
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


obstacles = [obstacle('Nature_Death_Floor', (0, 0, -.25), (8, 8, .25))]
for suffix, center, half in [
        ('L', (-1.43, 0, 1.8), (.05, 1.6, 2)),
        ('R', (1.43, 0, 1.8), (.05, 1.6, 2)),
        ('B', (0, 1.28, 1.8), (1.6, .05, 2)),
        ('F', (0, -1.28, 1.8), (1.6, .05, 2))]:
    obstacles.append(obstacle('Nature_Death_Compact_'+suffix, center, half))
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
action = bpy.data.actions.new('Nature_Avatar_Death_Collapse')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'A madeira perde sustentacao, cai ao redor do nucleo e repousa antes de desaparecer.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    desired = {name: matrix.copy() for name, matrix in base.items()}
    for name in proxies:
        transform = simulated[min(frame, 97)][name]
        fade = max(.00001, 1-ease(t, 3.15 if name == 'core' else 4., 3.75 if name == 'core' else 4.80))
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
scene.camera.data.ortho_scale = 5.0
scene.camera.location = (4, -10, 6.0)
scene.camera.rotation_euler = (Vector((0, 0, 1.12))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.timeline_markers.clear()
for label, frame in [('PERDE SUSTENTACAO', 9), ('MADEIRA CAI', 20), ('NO CHAO', 65),
                     ('NUCLEO SE APAGA', 77), ('MADEIRA DESAPARECE', 97), ('FIM', 117)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Death'
scene['description'] = 'Morte: a madeira cai perto do nucleo, repousa e desaparece. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['nature_avatar_death'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected,
    contacts=contacts, releases=releases,
    simulation='Blender Bullet, gravity -9.81, 32 substeps, 50 solver iterations')
result = dict(scene=scene.name, duration_s=5, pieces=86, bones=103, particles_included=False,
              settled_min_z=min(c['bottom'] for c in contacts.values()),
              settled_max_z=max(c['top'] for c in contacts.values()))
# Final direction: keep the compact physical fall, with the core collapsing first.
revision = ROOT/'tools/art_pipeline/retime_nature_avatar_death_core_first_mcp.py'
exec(compile(revision.read_text(encoding='utf-8'), str(revision), 'exec'))
