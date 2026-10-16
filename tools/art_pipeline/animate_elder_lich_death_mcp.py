"""Animate the Lich struggling against a sinking death, through live Blender MCP."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/elder_lich_summon_v1'
OUT = ROOT/'art_source/elder_lich_death_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in [SOURCE, ROOT/'assets/generated/grand_manifestations/elder_lich_blocky_v3_animated']
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
with bpy.data.libraries.load(str(SOURCE/'elder_lich_summon.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Lich Anciao - Morte Agonia'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
identity = Quaternion((1, 0, 0, 0))
arms = {side: tuple(rig.data.bones[n+'_'+side].head_local.copy()
                    for n in ('upper_arm', 'forearm', 'hand')) for side in ('L', 'R')}


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


def beat(t, a, peak, end):
    return ease(t, a, peak)*(1-ease(t, peak, end))


def stages(t, rows):
    for (a, x), (b, y) in zip(rows, rows[1:]):
        if t <= b:
            return x+(y-x)*ease(t, a, b)
    return rows[-1][1]


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
action = bpy.data.actions.new('Elder_Lich_Death_Agony')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Agoniza, tenta se erguer apoiado no cajado e afunda inteiro, sem encolher.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    for b in rig.pose.bones:
        pose(b.name)
    shock = beat(t, 0, .16, .60)
    weaken = ease(t, .15, .95)
    effort1 = beat(t, .72, 1.10, 1.62)
    effort2 = beat(t, 1.80, 2.18, 2.78)
    last_effort = beat(t, 2.82, 3.12, 3.58)
    effort = effort1+.85*effort2+.50*last_effort
    spent = ease(t, 3.15, 4.35)
    depth = stages(t, [(0, 0), (.42, .025), (.90, .22), (1.30, .30),
                      (1.78, .68), (2.26, .76), (2.80, 1.32), (3.20, 1.55),
                      (3.70, 2.08), (4.22, 2.66), (4.80, 3.65), (5, 3.65)])
    strain = (effort1+.7*effort2+.4*last_effort)*math.sin(t*math.tau*7.2)
    sway = -3.5*effort1+4*effort2-2.5*last_effort
    body_q = rot(-5*shock+15*weaken-7*effort+5*spent,
                 2*weaken+sway*.5, sway)
    chest_q = rot(9*weaken-8*effort+5*spent+.7*strain, 0, -sway*.55)
    pose('body', (.018*sway, -.035*weaken, -depth+.025*shock), body_q)
    pose('chest', rotation=chest_q)
    pose('head', rotation=rot(-13*shock+18*weaken-40*effort+7*spent+1.7*strain,
                              3*effort1-5*effort2, -5*effort1+8*effort2-3*last_effort))
    hand_world = rot(5*weaken-4*effort, 0, -2*effort1)
    arm('L', (-.025*weaken, -.045*weaken-.035*effort, .04*weaken+.145*effort-.035*spent),
        (body_q@chest_q).inverted()@hand_world)
    arm('R', (.025*weaken, -.055*weaken-.035*effort2, .13*effort1+.065*effort2-.04*spent),
        rot(10*weaken-18*effort1+9*spent, 4*effort2, 6*weaken))
    for index, name in enumerate(cloth):
        cape = name.startswith('cape_')
        side = name.startswith('robe_side_')
        drag = 3*weaken-2*effort+2*spent
        flutter = .6*strain*math.sin(index*.7+t*3)
        for j, suffix in [(1, '_middle'), (2, '_hem')]:
            angle = (drag+flutter)*(1 if cape else .5)*j/2
            if side:
                sign = -1 if name.endswith('_L') else 1
                pose(name+suffix, rotation=rot(0, -sign*angle))
            else:
                pose(name+suffix, rotation=rot(angle))
    for index, side in enumerate(('left', 'center', 'right')):
        pose('spectral_tail_'+side, rotation=rot(-3*weaken+2*effort, (index-1)*weaken))
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
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.fps = 24
scene.use_nodes = False
scene.camera.data.ortho_scale = 4.8
scene.camera.location = (3, -11, 4.6)
scene.camera.rotation_euler = (Vector((0, 0, 1.55))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.timeline_markers.clear()
for label, frame in [('REAGE', 5), ('PRIMEIRO ESFORCO', 27), ('SEGUNDO ESFORCO', 53),
                     ('ULTIMO SUSPIRO', 76), ('SUBMERGE', 102), ('FIM', 116)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Death'
scene['description'] = 'Afunda enquanto agoniza. Sem particulas ou encolhimento.'
scene.frame_set(1)
bpy.app.driver_namespace['elder_lich_death'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected,
    prop_names={'staff', 'staff_focus', 'tome'})
result = dict(scene=scene.name, duration_s=5, frames=121, particles_included=False, death='sinking agony')
