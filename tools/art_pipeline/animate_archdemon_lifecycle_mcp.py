"""Author particle-free Summon and Death on a copy of the approved V5, via MCP."""
import bpy
import hashlib
import math
from pathlib import Path
from mathutils import Vector, Quaternion, Euler

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
SOURCE = ROOT/'assets/generated/grand_manifestations/archdemon_blocky_v5_animated'
OUT = ROOT/'art_source/archdemon_lifecycle_review'
OUT.mkdir(exist_ok=True)
(OUT/'.gdignore').write_text('')
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in SOURCE.iterdir() if p.is_file()}
with bpy.data.libraries.load(str(SOURCE/'archdemon_blocky_v5_animated.blend'), link=False) as (src, dst):
    dst.scenes = src.scenes
scene = dst.scenes[0]
scene.name = 'Arquidemonio - Invocacao e Morte'
bpy.context.window.scene = scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
parts = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
assert len(parts) == 74
for track in rig.animation_data.nla_tracks:
    track.mute = True
idle = next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name == 'Idle')
rig.animation_data.action = idle
scene.frame_set(1)
base = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}
restq = {b.name: b.matrix_local.to_quaternion() for b in rig.data.bones}
restinv = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
identity = Quaternion((1, 0, 0, 0))
axis = Vector((.18, .22, 1)).normalized()
# Preserve the actual per-vertex cloth binding, including the shared seam pivots.
bindings = [(o, [[(o.vertex_groups[g.group].name, g.weight) for g in v.groups]
                  for v in o.data.vertices]) for o in parts]


def ease(t, start, end):
    x = max(0., min(1., (t-start)/(end-start)))
    return x*x*(3-2*x)


def rot(x=0, y=0, z=0):
    return Euler(tuple(math.radians(v) for v in (x, y, z))).to_quaternion()


def pose(name, shift=(0, 0, 0), rotation=None, scale=1.):
    b = rig.pose.bones[name]
    q = restq[name]
    b.rotation_mode = 'QUATERNION'
    b.location = base[name][0]+q.inverted()@Vector(shift)
    b.rotation_quaternion = base[name][1] @ q.inverted() @ (rotation or identity) @ q
    b.scale = base[name][2]*max(.00001, scale)


def points():
    matrices = {b.name: b.matrix@restinv[b.name] for b in rig.pose.bones}
    return [sum((matrices[n]@v.co*w for n, w in bind), Vector())
            for o, rows in bindings for v, bind in zip(o.data.vertices, rows)]


clips = {}
for clip, duration in [('Summon', 4.), ('Death', 3.5)]:
    action = bpy.data.actions.new('Archdemon_'+clip)
    action.use_fake_user = True
    action['loop'] = False
    action['description'] = 'Armadura se reune ao redor do nucleo.' if clip == 'Summon' else 'Perda de sustentacao, queda das maos e colapso da armadura.'
    rig.animation_data.action = action
    previous = {}
    end = round(duration*24)+1
    for f in range(1, end+1):
        scene.frame_set(f)
        t = (f-1)/24
        for name in base:
            pose(name)
        if clip == 'Summon':
            rise = ease(t, .15, 1.80)
            charge = ease(t, 1.25, 1.90)*(1-ease(t, 2.10, 3.65))
            body_scale = ease(t, .10, .65)
            body_shift = Vector((0, 0, -.52*(1-rise)+.13*charge))
            body_rot = rot(-8*(1-rise)-2*charge)
            pose('body', body_shift, body_rot, body_scale)
            pose('core', rotation=Quaternion(axis, -2*math.tau*(1-ease(t, .15, 3.35))),
                 scale=1.)
            pose('crown', (0, 0, .35*(1-ease(t, .75, 1.90))),
                 rot(0, 0, -20*(1-ease(t, .75, 1.90))), ease(t, .55, 1.05))
            for side, sign, lag in [('L', -1, 0), ('R', 1, .10)]:
                gather = 1-ease(t, .70+lag, 1.85+lag)
                hands = 1-ease(t, 1.0+lag, 2.40+lag)
                pose('shoulder_'+side, (sign*.38*gather, .10*gather, .16*gather),
                     rot(0, sign*14*gather, sign*12*gather), ease(t, .55+lag, 1.10+lag))
                pose('fist_'+side, (sign*(.55*hands+.08*charge), .18*hands-.12*charge, -.32*hands+.20*charge),
                     rot(-15*hands, sign*12*hands, sign*20*hands), ease(t, .85+lag, 1.30+lag))
            mantle_amount = 1-ease(t, .8, 2.65)
            cloth_amount = math.sin(math.pi*ease(t, .25, 3.8))
        else:
            shock = ease(t, 0, .16)*(1-ease(t, .16, .52))
            fail = ease(t, .42, 2.35)
            body_scale = 1-ease(t, 2.45, 3.32)
            body_shift = Vector((0, -.07*fail+.06*shock, .09*shock-.92*fail))
            body_rot = rot(-7*shock+23*fail, -6*fail, 4*fail)
            pose('body', body_shift, body_rot, body_scale)
            pose('chest', rotation=rot(7*fail))
            pose('core', rotation=Quaternion(axis, math.radians(155)*ease(t, .05, 1.85)),
                 scale=1-ease(t, 1.65, 2.65))
            pose('crown', (0, .04*fail, -.035*fail), rot(8*fail, -6*fail))
            for side, sign, lag in [('L', -1, 0), ('R', 1, .15)]:
                sag = ease(t, .45+lag, 2.18+lag)
                drop = ease(t, .65+lag, 2.25+lag)
                pose('shoulder_'+side, (sign*.10*sag, .07*sag, -.10*sag), rot(0, sign*7*sag, sign*7*sag))
                pose('fist_'+side, (sign*.22*drop, -.15*drop, -.66*drop),
                     rot(15*drop, sign*12*drop, -sign*16*drop), 1-ease(t, 2.30+lag, 3.20+lag))
            mantle_amount = ease(t, .30, 2.30)
            cloth_amount = ease(t, .15, .55)*(1-ease(t, 2.0, 3.2))
        for name in ('mantle_upper_l', 'mantle_upper_r', 'mantle_lower_l', 'mantle_lower_r'):
            sign = -1 if name.endswith('_l') else 1
            direction = 1 if clip == 'Summon' else -1
            pose(name, (sign*.14*mantle_amount, .16*mantle_amount, direction*.14*mantle_amount),
                 rot(0, 0, sign*10*mantle_amount))
        for band in ('front', 'side'):
            for side, sign in [('L', -1), ('R', 1)]:
                for i in range(1, 4):
                    lag = .70*i+(.35 if side == 'R' else 0)
                    angle = cloth_amount*(math.sin(t*math.tau/1.5-lag)-math.sin(-lag))*2.3*i/3
                    pose(f'stole_{band}_{side}_{i}', rotation=rot(angle) if band == 'front' else rot(0, -sign*angle))
        bpy.context.view_layer.update()
        correction = max(0., .045-min(p.z for p in points()))
        body_shift.z += correction
        pose('body', body_shift, body_rot, body_scale)
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
    clips[clip] = dict(action=action, duration_s=duration, end_frame=end)

scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.fps = 24
scene.camera.data.ortho_scale = 4.95
scene.camera.location = (3, -11, 4.3)
scene.camera.rotation_euler = (Vector((0, 0, 1.65))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
for c in scene.collection.children:
    if 'Studio' in c.name:
        c.hide_viewport = False
        c.hide_select = True
scene.use_nodes = False
rig.animation_data.action = clips['Summon']['action']
scene.frame_start = 1
scene.frame_end = 97
scene.frame_set(1)
bpy.app.driver_namespace['archdemon_lifecycle'] = dict(
    scene=scene, rig=rig, parts=parts, bindings=bindings, clips=clips, idle=idle,
    base=base, out=str(OUT), source=str(SOURCE), protected=protected)
revision = ROOT/'tools/art_pipeline/revise_archdemon_death_ground_mcp.py'
exec(compile(revision.read_text(encoding='utf-8'), str(revision), 'exec'), {'__name__': '__main__'})
result = {'scene': scene.name, 'clips': {n: d['duration_s'] for n, d in clips.items()},
          'parts': len(parts), 'bones': len(rig.data.bones), 'particles_included': False}
