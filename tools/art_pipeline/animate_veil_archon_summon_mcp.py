"""Unfold the Archon's runic crowns into its floating shell via live Blender MCP."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/veil_archon_blocky_v9_animated'
OUT = ROOT/'art_source/veil_archon_summon_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'veil_archon_summon_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
probe = bpy.app.driver_namespace.pop('veil_summon_probe', None)
if probe:
    scene = probe['scene']
else:
    with bpy.data.libraries.load(str(SOURCE/'veil_archon_blocky_v9_animated.blend'), link=False) as (src, dst):
        dst.scenes = src.scenes
    scene = dst.scenes[0]
scene.name = 'Arconte do Veu - Invocacao'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 47 and len(rig.data.bones) == 39
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
identity = Quaternion((1, 0, 0, 0))
center = rig.data.bones['core'].head_local.copy()
panels = []
for obj in parts:
    if obj['kind'] != 'plate':
        continue
    name = obj['rig_bone']
    seed = int(obj['rune_seed'])
    pivot = rig.data.bones[name].head_local.copy()
    target = pivot-center
    angle = math.tau*(seed//2)/17
    start = Vector((1.65*math.cos(angle), 1.65*math.sin(angle), -.40 if seed%2 else .40))
    normal = Euler(obj['local_rotation'], 'XYZ').to_matrix()@Vector((0, -1, 0))
    panels.append(dict(name=name, seed=seed, pivot=pivot, start=start,
                       target=target, arc=start.normalized().rotation_difference(target.normalized()),
                       facing=normal.rotation_difference(start.normalized())))


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


action = bpy.data.actions.new('Veil_Archon_Summon')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'A estrutura luminosa surge; duas coroas runicas giram e se fecham ao redor do nucleo.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    for b in rig.pose.bones:
        pose(b.name)
    spin = ease(t, .30, 4.45)
    breath = math.sin(math.pi*ease(t, 2.65, 4.70))**2
    pose('entity', (0, 0, .055*breath), rot(0, 0, 360*spin))
    pose('lattice', scale=max(.00001, ease(t, .08, .85)))
    pose('core', rotation=rot(0, 0, -720*ease(t, .85, 4.45)),
         scale=max(.00001, ease(t, .85, 1.55)))
    for data in panels:
        lag = .012*(data['seed']%8)
        appear = ease(t, .32+lag, 1.05+lag)
        close = ease(t, 1.30+lag, 3.45+lag)
        direction = identity.slerp(data['arc'], close)@data['start'].normalized()
        radius = data['start'].length*(1-close)+data['target'].length*close
        position = center+direction*radius
        q = data['facing'].slerp(identity, close)
        pose(data['name'], position-data['pivot'], q,
             max(.00001, appear*(.42+.58*close)))
    if frame >= 115:
        for b in rig.pose.bones:
            b.location, b.rotation_quaternion, b.scale = base[b.name]
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
scene.frame_start, scene.frame_end = 1, 121
scene.render.fps = 24
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.use_nodes = False
scene.camera.data.ortho_scale = 5.1
scene.camera.location = (3, -11, 5.2)
scene.camera.rotation_euler = (Vector((0, 0, 1.65))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
for collection in scene.collection.children:
    if 'Studio' in collection.name:
        collection.hide_viewport = False
        collection.hide_select = True
scene.timeline_markers.clear()
for label, frame in [('ESTRUTURA LUMINOSA', 4), ('COROAS RUNICAS', 16), ('NUCLEO', 29),
                     ('CASCA SE FECHA', 62), ('COMPLETO', 88), ('REPOUSO', 115)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Summon'
scene['description'] = 'Arconte: coroas de placas runicas se fecham ao redor do nucleo. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['veil_archon_summon'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected,
    panels=panels)
result = dict(scene=scene.name, duration_s=5, frames=121, bones=39, parts=47, particles_included=False)
