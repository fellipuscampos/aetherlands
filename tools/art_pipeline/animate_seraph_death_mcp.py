"""Create an independent, particle-free Seraph Death in the live Blender MCP."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/seraph_summon_v1'
OUT = ROOT/'art_source/seraph_death_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in [SOURCE, ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated']
             for p in folder.iterdir() if p.is_file()}
with bpy.data.libraries.load(str(SOURCE/'seraph_summon.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
scene.name = 'Serafim - Morte'
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 36
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
action = bpy.data.actions.new('Seraph_Death')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Impacto, perda de sustentacao, asas cedendo, aureolas caindo e colapso do nucleo.'
rig.animation_data.action = action
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
restinv = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
identity = Quaternion((1, 0, 0, 0))
axes = {'core': Vector((.18, .22, 1)).normalized(),
        'orbit_a': Vector((.9, .22, .28)).normalized(),
        'orbit_b': Vector((.16, .06, 1)).normalized()}


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


def pose(name, shift=(0, 0, 0), rotation=None, scale=1.):
    b = rig.pose.bones[name]
    b.rotation_mode = 'QUATERNION'
    q = restq[name]
    b.location = q.inverted() @ Vector(shift)
    b.rotation_quaternion = q.inverted() @ (rotation or identity) @ q
    b.scale = (max(.00001, scale),)*3


previous = {}
floor_corrections = []
for f in range(1, 86):
    scene.frame_set(f)
    t = (f-1)/24
    for b in rig.pose.bones:
        b.rotation_mode = 'QUATERNION'
        b.location = (0, 0, 0)
        b.rotation_quaternion = identity
        b.scale = (1, 1, 1)
    shock = ease(t, 0, .17)*(1-ease(t, .17, .52))
    slump = ease(t, .38, 2.25)
    collapse = 1-ease(t, 2.40, 3.30)
    tremor = math.sin(t*math.tau*3.5)*.6*ease(t, .1, .3)*(1-ease(t, .6, 1.3))
    body_shift = Vector((0, .07*shock-.12*slump, .12*shock-1.22*slump))
    body_rotation = Euler(tuple(math.radians(x) for x in (
        -7*shock+24*slump, -9*slump+tremor, -6*slump))).to_quaternion()
    pose('body', body_shift, body_rotation, collapse)
    # Damped angular motion stops as both aureoles lose their alignment.
    for name, tilt, start, end, spin_sign in [
            ('core', 25, 1.72, 2.72, 1),
            ('orbit_a', 48, 2.00, 2.95, 1),
            ('orbit_b', -58, 1.90, 2.85, -1)]:
        spin = math.radians(110)*spin_sign*ease(t, .10, 1.80)
        sag = ease(t, .32 if name == 'orbit_b' else .48, 1.95)
        rotation = Euler((math.radians(tilt)*sag, 0, 0)).to_quaternion() @ Quaternion(axes[name], spin)
        shift = (0, -.10*sag, -.32*sag) if name != 'core' else (0, 0, -.08*sag)
        size = (1+.09*shock)*(1-ease(t, start, end))
        pose(name, shift, rotation, size)
    # Left and right lag slightly: the wings lose support rather than flipping rigidly.
    for band, onset, sweep_end, lift_end, flare in [
            ('main', .28, 53, -27, 7),
            ('lower', .42, 43, 20, 4),
            ('crown', .55, 30, -22, 3)]:
        for side, sign, delay in [('L', -1, 0), ('R', 1, .12)]:
            fall = ease(t, onset+delay, 2.12+delay)
            sweep = sweep_end*fall-flare*shock
            lift = lift_end*fall+flare*.5*shock
            rotation = Quaternion((0, 0, 1), math.radians(sign*sweep)) @ Quaternion((0, 1, 0), math.radians(-sign*lift))
            size = 1-ease(t, 2.32+delay, 3.15+delay)
            pose('wing_'+band+'_'+side, rotation=rotation, scale=size)
    # Keep the articulated wing tips above the ground throughout the fall.
    bpy.context.view_layer.update()
    matrices = {b.name: b.matrix@restinv[b.name] for b in rig.pose.bones}
    lowest = min((matrices[o['rig_bone']]@v.co).z for o in parts for v in o.data.vertices)
    correction = max(0., .035-lowest)
    body_shift.z += correction
    pose('body', body_shift, body_rotation, collapse)
    floor_corrections.append(correction)
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion) < 0:
            b.rotation_quaternion.negate()
        previous[b.name] = b.rotation_quaternion.copy()
        for path in ('location', 'rotation_quaternion', 'scale'):
            b.keyframe_insert(data_path=path, frame=f, group=b.name)

for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = 'LINEAR'
scene.timeline_markers.clear()
for name, frame in [('IMPACTO', 5), ('PERDA DE SUSTENTACAO', 18),
                    ('QUEDA', 37), ('NUCLEO SE EXTINGUE', 59), ('FIM', 81)]:
    action.pose_markers.new(name).frame = frame
    scene.timeline_markers.new(name, frame=frame)
scene.frame_start = 1
scene.frame_end = 85
scene.render.fps = 24
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.use_nodes = False
scene['instructions'] = 'Morte: 1-85, 24 fps. Espaco: play/pausa. Shift+Seta Esquerda: inicio. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['seraph_death'] = dict(
    scene=scene, rig=rig, parts=parts, action=action, idle=idle,
    out=str(OUT), protected=protected, max_floor_correction=max(floor_corrections))
result = {'scene': scene.name, 'clip': 'Death', 'duration_s': 3.5,
          'frames': 85, 'particles_included': False}
