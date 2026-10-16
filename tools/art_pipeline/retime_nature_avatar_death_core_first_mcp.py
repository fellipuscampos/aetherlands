"""Collapse the core in place before releasing the already baked wooden debris."""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

st = bpy.app.driver_namespace['nature_avatar_death']
scene, rig, parts = st['scene'], st['rig'], st['parts']
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
for track in rig.animation_data.nla_tracks:
    track.mute = True
physics_action = st.get('physics_action', st['action'])
rig.animation_data.action = st['idle']
scene.frame_set(1)
base = {b.name: b.matrix.copy() for b in rig.pose.bones}
core = next(o for o in parts if o['rig_bone'] == 'core')
deform = base['core']@rig.data.bones['core'].matrix_local.inverted()
center = sum((deform@v.co for v in core.data.vertices), Vector())/len(core.data.vertices)
wood = [o['rig_bone'] for o in parts if o != core]
rig.animation_data.action = physics_action
sampled = {}
for frame in range(1, 122):
    t = (frame-1)/24
    # Preserve the approved compact fall, starting only after the core is gone.
    sample_time = max(0., min(3., (t-1.05)*1.30))
    sample = 1+sample_time*24
    scene.frame_set(int(sample), subframe=sample%1)
    sampled[frame] = {name: rig.pose.bones[name].matrix.copy() for name in wood}


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


action = bpy.data.actions.new('Nature_Avatar_Death_Core_First')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'O nucleo colapsa e some no peito; so depois a madeira desaba e repousa no chao.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 122):
    scene.frame_set(frame)
    t = (frame-1)/24
    desired = {name: matrix.copy() for name, matrix in base.items()}
    # A brief contraction and twist; the core stays inside the chest, never falls.
    strain = ease(t, 0., .16)*(1-ease(t, .16, .30))
    size = max(.00001, (1+.05*strain)*(1-ease(t, .18, .90)))
    q = Euler((math.radians(12*strain), 0, math.radians(135*ease(t, .08, .90)))).to_quaternion()
    collapse = Matrix.Translation(center)@q.to_matrix().to_4x4()@Matrix.Scale(size, 4)@Matrix.Translation(-center)
    desired['core'] = collapse@base['core']
    fade = max(.00001, 1-ease(t, 4., 4.80))
    for name in wood:
        pivot = st['contacts'][name]['pivot']
        shrink = Matrix.Translation(pivot)@Matrix.Scale(fade, 4)@Matrix.Translation(-pivot)
        desired[name] = shrink@sampled[frame][name]
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
st['physics_action'] = physics_action
st['action'] = action
st['core_first'] = dict(collapse_starts_s=.18, core_gone_s=.90, wood_held_until_s=1.05,
                        wood_physics_speed=1.30, core_falls=False)
scene.timeline_markers.clear()
for label, frame in [('NUCLEO COLAPSA', 5), ('NUCLEO SUMIU', 23), ('MADEIRA CEDE', 30),
                     ('NO CHAO', 73), ('MADEIRA DESAPARECE', 97), ('FIM', 117)]:
    scene.timeline_markers.new(label, frame=frame)
scene['description'] = 'Morte: nucleo colapsa e some primeiro; madeira cai depois. Sem particulas.'
scene.frame_set(1)
result = dict(scene=scene.name, duration_s=5, core_gone_s=.90, wood_held_until_s=1.05,
              particles_included=False, compact_fall_preserved=True)
