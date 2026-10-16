"""Form the continuous elemental serpent from head to tail around its cubic heart."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/elemental_dragon_v10_animated'
OUT = ROOT/'art_source/primordial_summon_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'primordial_summon_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
probe = bpy.app.driver_namespace.pop('primordial_summon_probe', None)
if probe:
    scene = probe['scene']
else:
    with bpy.data.libraries.load(str(SOURCE/'elemental_dragon_v10_animated.blend'), link=False) as (src, dst):
        dst.scenes = src.scenes
    scene = dst.scenes[0]
scene.name = 'Primordial dos Elementos - Invocacao'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 125 and len(rig.data.bones) == 91
for track in rig.animation_data.nla_tracks:
    track.mute = True
clips = {t.name: t.strips[0].action for t in rig.animation_data.nla_tracks}
idle, spell = clips['idle'], clips['spell']
rig.animation_data.action = idle
scene.frame_set(1)
idle_pose = {b.name: b.matrix.copy() for b in rig.pose.bones}
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


def scale_at(point, amount):
    return Matrix.Translation(point)@Matrix.Scale(max(.00001, amount), 4)@Matrix.Translation(-point)


# Reuse the approved coiling motion and its safe recovery to the upright rest.
sampled = {}
rig.animation_data.action = spell
for frame in range(1, 152):
    t = (frame-1)/30
    source_time = (1+6*ease(t, .65, 3.55)) if t < 3.55 else 7+ease(t, 3.55, 4.70)
    f = 1+30*source_time
    scene.frame_set(int(f), subframe=f%1)
    sampled[frame] = {b.name: b.matrix.copy() for b in rig.pose.bones}
action = bpy.data.actions.new('Primordial_Summon')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'O nucleo desperta; a serpente se forma da cabeca a cauda ao redor dele e se ergue.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 152):
    scene.frame_set(frame)
    t = (frame-1)/30
    source_pose = sampled[frame]
    desired = {name: matrix.copy() for name, matrix in source_pose.items()}
    desired['root'] = rest['root'].copy()
    desired['core'] = scale_at(source_pose['core'].translation, ease(t, .08, .65))@source_pose['core']
    # A moving tip collapses all still-unformed sections into one point. This
    # keeps the single skinned tube continuous, without thin lines or fragments.
    growth = 39*ease(t, .65, 3.25)
    lower, upper = int(growth), min(39, int(growth)+1)
    points = [source_pose[f'ring_{39-j:02d}'].translation.copy() for j in range(40)]
    tip = points[lower].lerp(points[upper], growth-lower)
    reveal = ease(t, .65, 1.05)
    for j in range(40):
        name = f'ring_{39-j:02d}'
        matrix = source_pose[name].copy()
        position = points[j] if j <= growth else tip
        width = reveal*ease(growth-j+1, 0., 1.)
        matrix.translation = position
        desired[name] = scale_at(position, width)@matrix
    head_scale = scale_at(source_pose['head'].translation, reveal)
    for name in desired:
        if name in ('head', 'jaw') or name.startswith(('antler_', 'whisker_')):
            desired[name] = head_scale@source_pose[name]
    if t >= 4.70:
        desired = {name: matrix.copy() for name, matrix in idle_pose.items()}
        desired['root'] = rest['root'].copy()
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
scene.frame_start, scene.frame_end = 1, 151
scene.render.fps = 30
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.use_nodes = False
scene.camera.data.ortho_scale = 5.6
scene.camera.location = (5, -9, 4.8)
scene.camera.rotation_euler = (Vector((0, 0, 1.70))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.timeline_markers.clear()
for label, frame in [('NUCLEO', 5), ('CABECA', 25), ('CORPO SE FORMA', 52),
                     ('CAUDA', 95), ('SE ERGUE', 112), ('REPOUSO', 143)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Summon'
scene['description'] = 'Primordial: nucleo primeiro, serpente se forma ao redor e se ergue. Sem particulas.'
scene.frame_set(1)
bpy.app.driver_namespace['primordial_summon'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected)
result = dict(scene=scene.name, duration_s=5, frames=151, fps=30, parts=125,
              bones=91, continuous_body=True, particles_included=False)
