"""Author the Elder Lich emerging from the ground, using the live Blender MCP."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/elder_lich_blocky_v3_animated'
OUT = ROOT/'art_source/elder_lich_summon_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.iterdir() if p.is_file()}
with bpy.data.libraries.load(str(SOURCE/'elder_lich_blocky_v3_animated.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Lich Anciao - Invocacao'
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 79
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
identity = Quaternion((1, 0, 0, 0))
arms = {side: tuple(rig.data.bones[n+'_'+side].head_local.copy()
                    for n in ('upper_arm', 'forearm', 'hand')) for side in ('L', 'R')}


def ease(t, start, end):
    x = max(0., min(1., (t-start)/(end-start)))
    return x*x*(3-2*x)


def rot(x=0, y=0, z=0):
    return Euler(tuple(math.radians(v) for v in (x, y, z))).to_quaternion()


def pose(name, shift=(0, 0, 0), rotation=None):
    b = rig.pose.bones[name]
    q = restq[name]
    b.rotation_mode = 'QUATERNION'
    b.location = q.inverted()@Vector(shift)
    b.rotation_quaternion = q.inverted()@(rotation or identity)@q
    b.scale = (1, 1, 1)


def arm(side, shift, desired_hand=identity):
    # Same two-segment solver and wrist limit as the approved combat clips.
    shoulder, elbow, wrist = arms[side]
    target = wrist+Vector(shift)
    upper0, fore0 = elbow-shoulder, wrist-elbow
    a, b = upper0.length, fore0.length
    delta = target-shoulder
    distance, direction = delta.length, delta.normalized()
    assert abs(a-b)+.002 < distance < a+b-.002, (side, shift, distance)
    along = (a*a-b*b+distance*distance)/(2*distance)
    bend = (upper0-direction*upper0.dot(direction)).normalized()
    solved_elbow = shoulder+direction*along+bend*math.sqrt(max(0, a*a-along*along))
    upper = upper0.rotation_difference(solved_elbow-shoulder)
    fore = fore0.rotation_difference(target-solved_elbow)
    wrist_delta = fore.inverted()@desired_hand
    if wrist_delta.w < 0:
        wrist_delta.negate()
    limit = math.radians(35)
    hand = desired_hand if wrist_delta.angle <= limit else fore@identity.slerp(wrist_delta, limit/wrist_delta.angle)
    pose('upper_arm_'+side, rotation=upper)
    pose('forearm_'+side, rotation=upper.inverted()@fore)
    pose('hand_'+side, rotation=fore.inverted()@hand)


cloth = ('robe_front_L', 'robe_front_R', 'robe_side_L', 'robe_side_R',
         'cape_left', 'cape_center', 'cape_right')
action = bpy.data.actions.new('Elder_Lich_Summon')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Emerge do chao, desperta, ergue cajado e grimorio e se acomoda no repouso.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 98):
    scene.frame_set(frame)
    t = (frame-1)/24
    for name in base:
        pose(name)
    rise = ease(t, .12, 2.12)
    straighten = ease(t, .80, 2.55)
    gesture = ease(t, .90, 1.85)*(1-ease(t, 2.15, 3.70))
    breath = math.sin(math.pi*ease(t, 1.60, 3.80))
    pose('body', (0, 0, -3.55*(1-rise)+.08*gesture+.025*breath), rot(8*(1-straighten)))
    pose('chest', rotation=rot(3*(1-straighten)))
    pose('head', rotation=rot(14*(1-straighten)+5*gesture, 0, -2*gesture))
    arm('L', (-.018*gesture, -.07*gesture, .10*gesture), rot(6*gesture))
    arm('R', (-.025*gesture, -.08*gesture, .18*gesture), rot(-10*gesture))
    pose('tome', (0, 0, .018*gesture), rot(-4*gesture))
    for index, name in enumerate(cloth):
        cape = name.startswith('cape_')
        side = name.startswith('robe_side_')
        for j, suffix in [(1, '_middle'), (2, '_hem')]:
            lag = .45*j+.26*index
            flutter = math.sin(math.pi*ease(t, .5, 3.8))*math.sin(t*math.tau/2.-lag)
            drag = (1-straighten)*ease(t, .1, .8)
            angle = ((2.3 if cape else 1.)*drag + (1.2 if cape else .55)*flutter)*j/2
            if side:
                sign = -1 if name.endswith('_L') else 1
                pose(name+suffix, rotation=rot(0, -sign*angle))
            else:
                pose(name+suffix, rotation=rot(angle))
    for index, side in enumerate(('left', 'center', 'right')):
        wave = math.sin(math.pi*ease(t, .3, 3.8))*math.sin(t*math.tau/2.-index*.65)
        pose('spectral_tail_'+side, rotation=rot(3*wave, wave))
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
for label, frame in [('EMERGE DO CHAO', 7), ('DESPERTA', 28), ('CAJADO E GRIMORIO', 45), ('REPOUSO', 90)]:
    scene.timeline_markers.new(label, frame=frame)
    action.pose_markers.new(label).frame = frame
scene.frame_start, scene.frame_end = 1, 97
scene.render.fps = 24
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.camera.data.ortho_scale = 4.8
scene.camera.location = (3, -11, 4.6)
scene.camera.rotation_euler = (Vector((0, 0, 1.60))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
for c in scene.collection.children:
    if 'Studio' in c.name:
        c.hide_viewport = False
        c.hide_select = True
scene.use_nodes = False
scene['description'] = 'Invocacao: emerge do solo e termina no repouso. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['elder_lich_summon'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, arms=arms, cloth=cloth, out=str(OUT), source=str(SOURCE), protected=protected)
result = dict(scene=scene.name, clip='Summon', duration_s=4, frames=97,
              bones=len(rig.data.bones), parts=len(parts), particles_included=False)
