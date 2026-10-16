"""Rigid siege mechanisms; projectiles and combat effects belong to gameplay."""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector


def smooth(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3 - 2 * value)


def recoil(t, fire, recovery=.22):
    # Fast release, brief recoil peak and a slower return to the cradle.
    if t < fire:
        return 0.0
    if t < fire + .045:
        return smooth((t - fire) / .045)
    return 1 - smooth((t - fire - .045) / recovery)


def animate(g, rig):
    clips = {}; offset = 1; tier = g.ROW['tier']
    roles = ['Idle', 'Walk', 'Attack', 'DemolitionAmmo']
    if tier: roles.append('PreparedBombardment')
    for role in roles:
        end = dict(Idle=49, Walk=49, Attack=49, DemolitionAmmo=73, PreparedBombardment=97)[role]
        name = g.ROW['prefix'] + '_' + role
        action = bpy.data.actions.new(name); action.use_fake_user = True
        rig.animation_data.action = action
        fire = .40 if role == 'Attack' else .48
        strength = dict(Attack=1.0, DemolitionAmmo=1.18, PreparedBombardment=1.30).get(role, 1.0)
        fires = [fire, fire + .19] if tier == 3 else [fire]
        for frame in range(1, end + 1):
            t = (frame - 1) / (end - 1)
            rotations = {}; locations = {}
            if role == 'Walk':
                for bone in g.BONES:
                    if bone.startswith('wheel_'):
                        rotations[bone] = Quaternion(g.X, -math.tau * t)
            elif role not in ('Idle', 'Walk'):
                # Wind before release, pause at release, then wind in to reload.
                winding = smooth(t / (fire - .06)) if t < fire else 1 + smooth((t - .75) / .25)
                rotations['loader'] = Quaternion(g.X, math.tau * winding)
                shot = recoil(t, fire)
                tension = math.sin(math.pi * t) ** 2
                if tier < 2:
                    angle = (.94 * strength * shot - .055 * tension)
                    rotations['weapon'] = Quaternion(g.X, angle)
                    if tier == 1:
                        # Gravity keeps the counterweight vertical; sling trails.
                        rotations['counterweight'] = Quaternion(g.X, -angle)
                        rotations['sling'] = Quaternion(g.X, -.78 * angle)
                elif tier == 2:
                    locations['weapon'] = Vector((0, .19 * strength * shot, 0)) * g.SCALED
                    rotations['weapon'] = Quaternion(g.X, -.055 * tension)
                else:
                    for label, when in zip(('l', 'r'), fires):
                        pulse = recoil(t, when, .18)
                        locations['weapon_' + label] = Vector((0, .235 * strength * pulse, 0)) * g.SCALED
                        rotations['weapon_' + label] = Quaternion(g.X, -.060 * tension)
            for bone in rig.pose.bones:
                rotation = rotations.get(bone.name, Quaternion())
                bone.matrix_basis = Matrix.Translation(locations.get(bone.name, Vector())) @ rotation.to_matrix().to_4x4()
                bone.keyframe_insert('location', frame=frame, group=bone.name)
                bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation = 'LINEAR'
        loop = role in ('Idle', 'Walk')
        impact = round(fires[0] * (end - 1)) + 1
        action['loop'] = loop
        action['impact_frame'] = -1 if loop else impact
        action['mechanism'] = g.ROW['design']
        action.pose_markers.new('LOOP_START' if loop else 'START').frame = 1
        action.pose_markers.new('LOOP_END' if loop else 'RECOVERED').frame = end
        if not loop:
            for index, when in enumerate(fires):
                action.pose_markers.new('FIRE' if tier != 3 else 'FIRE_' + ('L', 'R')[index]).frame = round(when * (end - 1)) + 1
        clips[name] = dict(action=action, start=offset, end=end, seconds=(end-1)/24,
                           impact_frame=impact, loop=loop,
                           fire_frames=[] if loop else [round(when*(end-1))+1 for when in fires])
        offset += end + 8
    rig.animation_data.action = None
    for name, info in clips.items():
        track = rig.animation_data.nla_tracks.new(); track.name = name
        strip = track.strips.new(name, info['start'], info['action'])
        strip.extrapolation = 'NOTHING'; strip.blend_type = 'REPLACE'
        g.SCENE.timeline_markers.new(name, frame=info['start'])
    g.SCENE.frame_start = 1; g.SCENE.frame_end = offset - 9
    g.SCENE.frame_set(1)
    return clips
