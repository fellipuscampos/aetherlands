"""Collapse the elemental heart and dissolve the sinking serpent from tail to head."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Matrix, Vector, Euler, Quaternion

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/primordial_summon_v1'
OUT = ROOT/'art_source/primordial_death_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for folder in (ROOT/'assets/generated/grand_manifestations').iterdir()
             if folder.is_dir() and folder.name != 'primordial_death_v1'
             for p in folder.iterdir() if p.is_file()}
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
with bpy.data.libraries.load(str(SOURCE/'primordial_summon.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Primordial dos Elementos - Morte'
bpy.context.window.scene = scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 125 and len(rig.data.bones) == 91
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: b.matrix.copy() for b in rig.pose.bones}
core = base['core'].translation.copy()
base_points = [base[f'ring_{39-j:02d}'].translation.copy() for j in range(40)]
lengths = [(base_points[j+1]-base_points[j]).length for j in range(39)]


def ease(t, a, b):
    x = max(0., min(1., (t-a)/(b-a)))
    return x*x*(3-2*x)


def rot(x=0, y=0, z=0):
    return Euler(tuple(math.radians(v) for v in (x, y, z))).to_matrix().to_4x4()


def scale_at(point, amount):
    return Matrix.Translation(point)@Matrix.Scale(max(.00001, amount), 4)@Matrix.Translation(-point)


def smooth_chain(targets):
    # Follow a smooth centerline by distance, rather than projecting directly
    # onto a compressed next target, which can fold a segment back on itself.
    curve = [targets[0].copy()]
    for j in range(39):
        p0, p1 = targets[max(0, j-1)], targets[j]
        p2, p3 = targets[j+1], targets[min(39, j+2)]
        for step in range(1, 9):
            u = step/8
            curve.append(.5*((2*p1)+(-p0+p2)*u+
                         (2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u))
    tangent = (curve[-1]-curve[-2]).normalized()
    for _ in range(80):
        curve.append(curve[-1]+tangent*.25)
    points, cursor = [curve[0]], 1
    for length in lengths:
        origin = points[-1]
        while (curve[cursor]-origin).length < length:
            cursor += 1
        a, b = curve[cursor-1], curve[cursor]
        lo, hi = 0., 1.
        for _ in range(23):
            fraction = (lo+hi)/2
            if (a.lerp(b, fraction)-origin).length < length:
                lo = fraction
            else:
                hi = fraction
        points.append(a.lerp(b, (lo+hi)/2))
    return points


action = bpy.data.actions.new('Primordial_Death')
action.use_fake_user = True
action['loop'] = False
action['description'] = 'Nucleo colapsa; uma onda percorre a coluna e a serpente cede por trechos, afundando.'
rig.animation_data.action = action
previous = {}
for frame in range(1, 152):
    scene.frame_set(frame)
    t = (frame-1)/30
    depth = .28*ease(t, .95, 2.0)+.62*ease(t, 2., 3.4)+2.70*ease(t, 3.4, 4.8)
    targets, flow = [], []
    for j, point in enumerate(base_points):
        u = j/39
        # Loss of support travels down the chain instead of rotating it as a block.
        loss = ease(t, .85+.80*u, 2.45+.85*u)
        envelope = ease(t, .78+.45*u, 1.20+.45*u)*(1-ease(t, 3.15, 4.25))
        phase = math.tau*(.70*(t-.78)-1.25*u)
        wave = envelope*math.sin(phase)
        bend = rot(58*loss+14*wave, 9*envelope*math.cos(phase), -9*loss+6*wave)
        target = core+bend.to_3x3()@(point-core)
        target += Vector((.22*wave, .14*envelope*math.cos(phase), -.26*loss-depth))
        targets.append(target)
        flow.append(wave)
    # Connected segments keep their original lengths as each one follows the
    # delayed target. The independent section frames follow the new centerline.
    points = [p.copy() for p in base_points] if t < .78 else smooth_chain(targets)
    desired = {name: matrix.copy() for name, matrix in base.items()}
    desired['root'] = base['root'].copy()
    for j in range(39):
        name = f'spine_{j:02d}'
        old = (base_points[j+1]-base_points[j]).normalized()
        new = (points[j+1]-points[j]).normalized()
        matrix = (old.rotation_difference(new).to_matrix()@base[name].to_3x3()).to_4x4()
        matrix.translation = points[j]
        desired[name] = matrix
    collapse = Matrix.Translation(core)@rot(0, 0, 150*ease(t, .10, .84))@Matrix.Translation(-core)
    desired['core'] = scale_at(core, 1-ease(t, .10, .84))@collapse@base['core']
    # Keep the tube continuous as its tail retracts toward the remaining body.
    remaining = 39*(1-ease(t, 1.55, 4.10))
    lower, upper = int(remaining), min(39, int(remaining)+1)
    tip = points[lower].lerp(points[upper], remaining-lower)
    last = 1-ease(t, 3.95, 4.65)
    for j in range(40):
        name = f'ring_{39-j:02d}'
        previous_index, next_index = max(0, j-1), min(39, j+1)
        old = (base_points[previous_index]-base_points[next_index]).normalized()
        new = (points[previous_index]-points[next_index]).normalized()
        turn = Quaternion(new, math.radians(5*flow[j]))@old.rotation_difference(new)
        matrix = (turn.to_matrix()@base[name].to_3x3()).to_4x4()
        position = points[j] if j <= remaining else tip
        matrix.translation = position
        width = last*ease(remaining-j+1, 0., 1.)
        desired[name] = scale_at(position, width)@matrix
    old = (base_points[0]-base_points[1]).normalized()
    new = (points[0]-points[1]).normalized()
    head_follow = Matrix.Translation(points[0])@old.rotation_difference(new).to_matrix().to_4x4()@Matrix.Translation(-base_points[0])
    head_position = (head_follow@base['head']).translation
    head_deform = scale_at(head_position, last)@head_follow
    for name in desired:
        if name in ('head', 'jaw') or name.startswith(('antler_', 'whisker_')):
            desired[name] = head_deform@base[name]
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
# A review-only floor makes the downward motion visible. It never enters the GLB.
floor_mesh = bpy.data.meshes.new('Primordial_Death_Studio_Floor')
floor_mesh.from_pydata([(-15,-15,0),(15,-15,0),(15,15,0),(-15,15,0)], [], [(0,1,2,3)])
floor = bpy.data.objects.new('Primordial_Death_Studio_Floor', floor_mesh)
scene.collection.objects.link(floor)
mat = bpy.data.materials.new('Primordial_Death_Studio_Floor_Matte')
mat.diffuse_color = (.115, .155, .18, 1)
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (.115, .155, .18, 1)
bsdf.inputs['Roughness'].default_value = .9
floor_mesh.materials.append(mat)
floor.hide_select = True
scene.frame_start, scene.frame_end = 1, 151
scene.render.fps = 30
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.use_nodes = False
scene.camera.data.ortho_scale = 5.3
scene.camera.location = (5, -9, 5.3)
scene.camera.rotation_euler = (Vector((0, 0, 1.15))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.timeline_markers.clear()
for label, frame in [('NUCLEO COLAPSA', 5), ('ONDA PELA COLUNA', 28), ('CAUDA SE DESFAZ', 49),
                     ('AFUNDA', 75), ('ULTIMO SUSPIRO', 117), ('FIM', 145)]:
    scene.timeline_markers.new(label, frame=frame)
scene['preview_clip'] = 'Death'
scene['description'] = 'Morte: nucleo colapsa, serpente agoniza e afunda, desfazendo-se da cauda a cabeca.'
scene.frame_set(1)
bpy.app.driver_namespace['primordial_death'] = dict(scene=scene, rig=rig, parts=parts,
    action=action, idle=idle, out=str(OUT), source=str(SOURCE), protected=protected)
result = dict(scene=scene.name, duration_s=5, frames=151, fps=30, parts=125,
              bones=91, continuous_body=True, particles_included=False)
