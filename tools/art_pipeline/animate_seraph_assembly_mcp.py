"""Core-first Seraph assembly, authored through the live Blender MCP."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
OUT = ROOT/'art_source/seraph_summon_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
source = ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated'
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'seraph_summon_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
with bpy.data.libraries.load(str(source/'seraph_blocky_v4_animated.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Serafim - Invocacao Nucleo Primeiro'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 36 and len(rig.data.bones) == 11
for track in rig.animation_data.nla_tracks:
    track.mute = True
clips = {t.name: t.strips[0].action for t in rig.animation_data.nla_tracks}
idle = clips['Idle']
original_bones = list(rig.data.bones.keys())


def geometry():
    mats = {b.name: b.matrix@rig.data.bones[b.name].matrix_local.inverted() for b in rig.pose.bones}
    return {o.name: [sum((mats[o.vertex_groups[g.group].name]@v.co*g.weight
                         for g in v.groups), Vector()) for v in o.data.vertices] for o in parts}


reference = {}
for name, clip in clips.items():
    rig.animation_data.action = clip
    for frame in (1, int((clip.frame_range[1]+1)//2), int(clip.frame_range[1])):
        scene.frame_set(frame)
        reference[name, frame] = geometry()
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
bindings, wing_bindings = {}, {}
identity = Quaternion((1, 0, 0, 0))
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for index, obj in enumerate(parts):
    parent = obj['rig_bone']
    if obj.get('kind') == 'wing_feather':
        root = rig.data.edit_bones[parent].head.copy()
        center = sum((v.co for v in obj.data.vertices), Vector())/len(obj.data.vertices)
        direction = (center-root).normalized()
        length = max((v.co-root).dot(direction) for v in obj.data.vertices)
        nodes = [parent]
        for station in range(1, 4):
            bone = rig.data.edit_bones.new(f'{parent}_flow_{station}')
            bone.head = root+direction*length*station/3
            bone.tail = bone.head+Vector((0, 0, .1))
            bone.parent = rig.data.edit_bones[parent]
            nodes.append(bone.name)
        wing_bindings[obj.name] = dict(parent=parent, root=root, direction=direction,
                                       length=length, bones=nodes)
    elif obj.get('kind') != 'light' and parent not in ('orbit_a', 'orbit_b'):
        center = sum((v.co for v in obj.data.vertices), Vector())/len(obj.data.vertices)
        bone = rig.data.edit_bones.new(f'assemble_{index:02d}')
        bone.head = center
        bone.tail = center+Vector((0, 0, .1))
        bone.parent = rig.data.edit_bones[parent]
        bindings[obj.name] = dict(bone=bone.name, parent=parent, center=center, index=index)
bpy.ops.object.mode_set(mode='OBJECT')
for obj in parts:
    if obj.name in bindings:
        data = bindings[obj.name]
        obj['source_rig_bone'] = data['parent']
        obj['rig_bone'] = data['bone']
        obj.vertex_groups.clear()
        obj.vertex_groups.new(name=data['bone']).add(list(range(len(obj.data.vertices))), 1., 'REPLACE')
    elif obj.name in wing_bindings:
        data = wing_bindings[obj.name]
        obj.vertex_groups.clear()
        groups = [obj.vertex_groups.new(name=name) for name in data['bones']]
        for v in obj.data.vertices:
            u = max(0., min(1., (v.co-data['root']).dot(data['direction'])/data['length']))*3
            i = min(2, int(u))
            weight = u-i
            if weight < 1:
                groups[i].add([v.index], 1-weight, 'REPLACE')
            if weight > 0:
                groups[i+1].add([v.index], weight, 'REPLACE')
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
    b.scale = (max(.00001, scale),)*3


new_bones = set(rig.data.bones.keys())-set(original_bones)
for clip in clips.values():
    rig.animation_data.action = clip
    for frame in (1, int(clip.frame_range[1])):
        scene.frame_set(frame)
        for name in new_bones:
            pose(name)
            for path in ('location', 'rotation_quaternion', 'scale'):
                rig.pose.bones[name].keyframe_insert(data_path=path, frame=frame, group=name)
preserved_error = 0.
for (name, frame), expected in reference.items():
    rig.animation_data.action = clips[name]
    scene.frame_set(frame)
    actual = geometry()
    preserved_error = max(preserved_error, max((p-q).length for obj in parts
        for p, q in zip(expected[obj.name], actual[obj.name])))
assert preserved_error < 1e-5, preserved_error

action = bpy.data.actions.new('Seraph_Summon_Core_First')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Nucleo isolado; ouro e aureolas se montam; seis asas crescem e se abrem em ondas.'
rig.animation_data.action = action
core_center = rig.data.bones['core'].head_local.copy()
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    for b in rig.pose.bones:
        pose(b.name)
    pose('body', (0, 0, .22*(1-ease(t, 1.2, 4.65))), rot(-3*(1-ease(t, 1.2, 4.65))))
    pulse = 1+.055*math.sin(math.pi*ease(t, .65, 1.15))+.025*math.sin(math.pi*ease(t, 2.7, 4.15))
    pose('core', rotation=rot(12*(1-ease(t, .1, 3.9)), -14*(1-ease(t, .1, 3.9)),
                             110*(1-ease(t, .1, 4.15))),
         scale=max(.00001, ease(t, .08, .65))*pulse)
    for name, start, turns, axis in [
            ('orbit_a', 1.05, 1, (.9, .22, .28)),
            ('orbit_b', 1.30, -1, (.16, .06, 1))]:
        arrival = ease(t, start+.4, start+1.35)
        pose(name, (0, 1.35*(1-arrival), .32*(1-arrival)),
             Quaternion(Vector(axis).normalized(), math.tau*turns*(1-ease(t, start, 3.65))),
             ease(t, start, start+.5))
    for obj in parts:
        if obj.name not in bindings:
            continue
        data = bindings[obj.name]
        parent, index = data['parent'], data['index']
        if parent == 'core':
            start = .91+.028*(index-1)
            arrive = ease(t, start+.06, start+.78)
            radial = (data['center']-core_center).normalized()
            shift = radial*.48*(1-arrive)
            shift += Vector((.12*math.sin(math.pi*arrive), .18*(1-arrive), .1*math.sin(math.pi*arrive)))
            rotation = rot(0, 42*(1-arrive), 65*(1-arrive))
        elif parent == 'body':
            start = 1.55+.12*(index-13)
            arrive = ease(t, start+.10, start+.85)
            shift = Vector((0, .65*(1-arrive), (.35 if index == 14 else -.23)*(1-arrive)))
            rotation = rot(0, 0, 35*(1-arrive))
        else:
            band = parent.split('_')[1]
            start = {'crown': 1.80, 'main': 2.03, 'lower': 2.26}[band]
            start += .10 if obj.get('kind') == 'bright_gold' else 0
            start += .045 if parent.endswith('_R') else 0
            arrive = ease(t, start+.05, start+.65)
            sign = -1 if parent.endswith('_L') else 1
            shift = Vector((sign*.10*(1-arrive), .28*(1-arrive), .12*math.sin(math.pi*arrive)))
            rotation = rot(0, sign*35*(1-arrive), 0)
        pose(data['bone'], shift, rotation, ease(t, start, start+.33))
    for data in wing_bindings.values():
        name = data['parent']
        band = name.split('_')[1]
        sign = -1 if name.endswith('_L') else 1
        start = {'crown': 2.05, 'main': 2.30, 'lower': 2.55}[band]+(.065 if sign == 1 else 0)
        age = t-start
        unfurl = ease(age, .12, 1.25)
        follow = math.sin(math.pi*ease(age, .65, 1.95))
        fold = {'crown': -18, 'main': -40, 'lower': 32}[band]
        pose(name, rotation=rot(0, sign*(fold*(1-unfurl)+4*follow), sign*10*(1-unfurl)),
             scale=ease(age, 0, .95))
        for station, bone in enumerate(data['bones'][1:], 1):
            u = station/3
            flow = math.sin(math.pi*ease(age, .12+.10*u, 1.75+.15*u))
            pose(bone, (0, .04*u*flow, .075*math.sin(math.pi*u)*flow),
                 rot(0, sign*9*u*flow, sign*2*u*flow))
    settle = ease(t, 4.35, 4.90)
    for b in rig.pose.bones:
        location, rotation, scale = base.get(b.name, (Vector(), identity, Vector((1, 1, 1))))
        b.location = b.location.lerp(location, settle)
        b.rotation_quaternion = b.rotation_quaternion.slerp(rotation, settle)
        b.scale = b.scale.lerp(scale, settle)
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
for label, frame in [('NUCLEO SOZINHO', 5), ('OURO', 23), ('AUREOLAS', 27),
                     ('ESTRUTURA', 39), ('ASAS EM ONDA', 51), ('REPOUSO', 119)]:
    scene.timeline_markers.new(label, frame=frame)
scene.frame_start, scene.frame_end = 1, 121
scene.render.fps = 24
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.camera.data.ortho_scale = 7.0
scene.camera.location = (3, -10, 4.8)
scene.camera.rotation_euler = (Vector((0, 0, 2.05))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.view_settings.view_transform = 'Standard'
scene.use_nodes = False
studio = next(c for c in scene.collection.children if 'Studio' in c.name)
studio.hide_viewport = False
studio.hide_select = True
scene['instructions'] = 'Espaco: play/pausa. Shift+Seta Esquerda: inicio. Invocacao: 1-121, 24 fps.'
scene['description'] = action['description']
scene.frame_set(1)
bpy.app.driver_namespace['seraph_summon'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, studio=studio, out=str(OUT), source=str(source),
    protected=protected, original_clip_vertex_error=preserved_error,
    bindings=bindings, wing_bindings=wing_bindings, original_bones=original_bones)
result = dict(scene=scene.name, duration_s=5, frames=121, parts=len(parts),
              bones=len(rig.data.bones), assembly_controls=len(bindings),
              wing_flow_controls=18, original_clip_vertex_error=preserved_error)
