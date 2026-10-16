"""Reveal the core, then assemble the Avatar from its own wooden parts via MCP."""
import bpy
import hashlib
import math
import random
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/nature_avatar_blocky_v5_animated'
OUT = ROOT/'art_source/nature_avatar_summon_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'nature_avatar_summon_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
with bpy.data.libraries.load(str(SOURCE/'nature_avatar_blocky_v5_animated.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Avatar da Natureza - Montagem'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 86 and len(rig.data.bones) == 18
for track in rig.animation_data.nla_tracks:
    track.mute = True
clips = {t.name: t.strips[0].action for t in rig.animation_data.nla_tracks}
idle = clips['Idle']


def geometry():
    inverse = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
    mats = {b.name: b.matrix@inverse[b.name] for b in rig.pose.bones}
    return {o.name: [mats[o.vertex_groups[v.groups[0].group].name]@v.co
                     for v in o.data.vertices] for o in parts}


# Reference deformed vertices before adding independent assembly joints.
reference = {}
for name, clip in clips.items():
    rig.animation_data.action = clip
    end = int(clip.frame_range[1])
    for frame in (1, (end+1)//2, end):
        scene.frame_set(frame)
        reference[name, frame] = geometry()
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
wood = [o for o in parts if o['rig_bone'] != 'core']
bindings = {}
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for index, obj in enumerate(wood):
    parent = obj['rig_bone']
    center = sum((v.co for v in obj.data.vertices), Vector())/len(obj.data.vertices)
    bone = rig.data.edit_bones.new(f'assemble_{index:03d}')
    bone.head = center
    bone.tail = center+Vector((0, 0, .12))
    bone.parent = rig.data.edit_bones[parent]
    bone.use_connect = False
    bindings[obj.name] = dict(bone=bone.name, parent=parent, center=center)
bpy.ops.object.mode_set(mode='OBJECT')
for obj in wood:
    data = bindings[obj.name]
    obj['source_rig_bone'] = data['parent']
    obj['rig_bone'] = data['bone']
    obj.vertex_groups.clear()
    obj.vertex_groups.new(name=data['bone']).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
identity = Quaternion((1, 0, 0, 0))
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


def rot(x=0, y=0, z=0):
    return Euler(tuple(math.radians(v) for v in (x, y, z))).to_quaternion()


def pose(name, shift=(0, 0, 0), rotation=None, scale=1.):
    b = rig.pose.bones[name]
    q = restq[name]
    b.rotation_mode = 'QUATERNION'
    b.location = q.inverted()@Vector(shift)
    b.rotation_quaternion = q.inverted()@(rotation or identity)@q
    b.scale = (scale,)*3


# Explicit identity channels keep these new child joints inert in the four old clips.
for name, clip in clips.items():
    rig.animation_data.action = clip
    for frame in (1, int(clip.frame_range[1])):
        scene.frame_set(frame)
        for data in bindings.values():
            pose(data['bone'])
            b = rig.pose.bones[data['bone']]
            for path in ('location', 'rotation_quaternion', 'scale'):
                b.keyframe_insert(data_path=path, frame=frame, group=b.name)
preserved_error = 0.
for (name, frame), expected in reference.items():
    rig.animation_data.action = clips[name]
    scene.frame_set(frame)
    actual = geometry()
    preserved_error = max(preserved_error, max((p-q).length for o in parts
                           for p, q in zip(actual[o.name], expected[o.name])))
assert preserved_error < 1e-5, preserved_error

# Deterministic staging: torso first, crown, arms, then dangling roots.
for index, obj in enumerate(wood):
    data = bindings[obj.name]
    rng = random.Random(1700+index)
    parent = data['parent']
    if parent in ('body', 'chest'):
        start = .65+rng.uniform(0, .35)
    elif parent == 'crown':
        start = 1.03+rng.uniform(0, .38)
    elif 'arm' in parent or 'hand' in parent:
        start = 1.42+rng.uniform(0, .40)
    else:
        start = 2.05+rng.uniform(0, .42)
    angle = index*2.3999632297
    radius = rng.uniform(1.50, 1.95)
    data.update(start=start, duration=rng.uniform(1.10, 1.45),
                seed=Vector((radius*math.cos(angle), radius*.65*math.sin(angle), rng.uniform(.45, 2.95))),
                tumble=rot(rng.uniform(-100, 100), rng.uniform(-95, 95), rng.uniform(-140, 140)),
                spin=rng.uniform(35, 80))

rig.animation_data.action = None
action = bpy.data.actions.new('Nature_Avatar_Summon_Assembly')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'O nucleo surge sozinho; 85 pecas de madeira orbitam e se encaixam ao redor dele.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    for b in rig.pose.bones:
        pose(b.name)
    wake = ease(t, 3.55, 4.05)*(1-ease(t, 4.05, 4.80))
    pose('body', (0, 0, .055*wake), rot(-1.5*wake))
    # The cube is the only visible geometry during the opening beat.
    reveal = ease(t, .08, .62)
    turn = 85*ease(t, .10, 1.45)*(1-ease(t, 3.30, 4.65))
    pose('core', (0, -.27-.12*ease(t, .10, .70)*(1-ease(t, 3.4, 4.65)), 0),
         rot(0, 0, turn), max(.00001, reveal))
    for data in bindings.values():
        age = t-data['start']
        arrive = ease(age, .10, data['duration'])
        seed = data['seed'].copy()
        # Each wooden piece sweeps through a short arc, then locks to its original joint.
        around = rot(0, 0, data['spin']*ease(age, 0, data['duration']))
        pivot = Vector((0, 0, 1.65))
        seed = pivot+around@(seed-pivot)
        seed.y = max(.45, seed.y)
        center = seed.lerp(data['center'], arrive)
        center.y += .80*math.sin(math.pi*arrive)
        center.z += .12*math.sin(math.pi*arrive)
        scale = max(.00001, ease(age, 0, .30))*(.45+.55*arrive)
        scale = max(.00001, scale)
        q = data['tumble'].slerp(identity, arrive)
        pose(data['bone'], center-data['center'], q, scale)
    if frame >= 117:
        for name, (location, quaternion, scale) in base.items():
            b = rig.pose.bones[name]
            b.location, b.rotation_quaternion, b.scale = location, quaternion, scale
    for b in rig.pose.bones:
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
scene.timeline_markers.clear()
for label, frame in [('NUCLEO', 5), ('MADEIRA SURGE', 19), ('TRONCO', 45),
                     ('BRACOS', 65), ('RAIZES', 87), ('COMPLETO', 105)]:
    scene.timeline_markers.new(label, frame=frame)
scene.frame_start, scene.frame_end = 1, 121
scene.render.fps = 24
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.use_nodes = False
scene.camera.data.ortho_scale = 5.3
scene.camera.location = (3, -11, 4.6)
scene.camera.rotation_euler = (Vector((0, 0, 1.55))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
for c in scene.collection.children:
    if 'Studio' in c.name:
        c.hide_viewport = False
        c.hide_select = True
scene['preview_clip'] = 'Summon'
scene['description'] = 'Nucleo primeiro; madeira se forma e monta o Avatar. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['nature_avatar_summon'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, bindings=bindings, out=str(OUT), source=str(SOURCE),
    protected=protected, original_clip_vertex_error=preserved_error,
    original_bones=list(base), reference=reference)
result = dict(scene=scene.name, duration_s=5, frames=121, bones=len(rig.data.bones),
              parts=86, independently_assembled_parts=len(wood), original_clip_vertex_error=preserved_error,
              particles_included=False)
