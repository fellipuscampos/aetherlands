"""Rigid articulation of APPROVED meshes, authored in the live Blender MCP.

Exactly three Action datablocks per family are linked to all four variants.
The siege contract includes throwing-arm AND recoil channels: each machine
binds its geometry to the mechanism it actually has. No per-tier choreography.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Quaternion

from dwarf_troop_assets import ASSETS, OUT, WORK, ROOT
import dwarf_animation_motion as motion
import importlib
importlib.reload(motion)

FPS = motion.FPS
LEGS = ('L_front', 'R_front', 'L_hind', 'R_hind')


def fingerprint(parts):
    result = {}
    for obj in parts:
        payload = dict(vertices=[list(v.co) for v in obj.data.vertices],
                       faces=[list(p.vertices) for p in obj.data.polygons],
                       uv=[list(v.uv) for v in obj.data.uv_layers.active.data],
                       matrix=[list(r) for r in obj.matrix_world])
        result[obj['part']] = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    return result


def ends(obj):
    # Return +local Z, -local Z; arms point from -Z to +Z.
    size = max(v.co.z for v in obj.data.vertices)
    return obj.matrix_world @ Vector((0, 0, size)), obj.matrix_world @ Vector((0, 0, -size))


def rig_spec(row, parts):
    by = {o['part']: o for o in parts}
    bones = {}
    # All humanoid bone axes are world axes at rest. Distinct tier rest-arm
    # positions can therefore share quaternion-only animation channels.
    def add(name, pivot=(0, 0, 0), parent=None, axis=(0, 1, 0)):
        bones[name] = dict(head=Vector(pivot), parent=parent, axis=Vector(axis).normalized())
    add('root')
    family, tier = row['family'], row['tier']
    if family == 'siege':
        radius = [.205, .225, .25, .29][tier]
        width = [.79, .93, 1.02, 1.18][tier]
        length = [1.05, 1.28, 1.16, 1.47][tier]
        z = radius * 1.6
        add('chassis', parent='root')
        for side, s in [('L', -1), ('R', 1)]:
            for end, y in [('front', -length*.38), ('hind', length*.38)]:
                add('wheel_'+side+'_'+end, (s*(width/2+.094), y, radius), 'root')
        pivot = (0, -.10, z+.38) if tier == 0 else (0, -.04, z+.98) if tier == 1 else (0, 0, 0)
        add('throwing_arm', pivot, 'chassis')
        attach = Vector((0, -.28, z+.72)) if tier == 1 else Vector(pivot)
        add('counterweight', attach, 'throwing_arm')
        sling = Vector((0, .46, z+1.39)) if tier == 1 else Vector(pivot)
        add('sling', sling, 'throwing_arm')
        payload = by['loaded_stone'].location if tier == 0 else by['sling_stone'].location if tier == 1 else Vector()
        add('payload', payload, 'throwing_arm' if tier == 0 else 'sling')
        # Origin stays at zero, so the same local recoil translation works on
        # differently pitched barrels without a variant-specific position track.
        axis = Vector((0, 1.01, -.24)) if tier == 2 else Vector((0, .46, -.76)) if tier == 3 else Vector((0, 1, 0))
        # Axis is carried by an unanimated parent. The animated child therefore
        # has IDENTICAL local translations in every exported siege clip.
        add('recoil_axis', (0, 0, 0), 'chassis', axis)
        add('recoil', (0, 0, 0), 'recoil_axis', axis)
        add('piston_L', parent='chassis'); add('piston_R', parent='chassis')
        for obj in parts:
            name = obj['part']; group = 'chassis'
            if name.startswith('wheel_'):
                center = obj.location
                # spoke origins share wheel Y; tire/wood/hub centers do too.
                side = 'L' if center.x < 0 else 'R'
                end = 'front' if center.y < 0 else 'hind'
                group = 'wheel_'+side+'_'+end
            elif name in ('mangonel_arm', 'stone_cup', 'torsion_shaft', 'trebuchet_arm'):
                group = 'throwing_arm'
            elif name == 'counterweight' or name.startswith('counterweight_hanger_'):
                group = 'counterweight'
            elif name == 'sling_pocket' or name.startswith('sling_rope_'):
                group = 'sling'
            elif name in ('loaded_stone', 'sling_stone'):
                group = 'payload'
            elif name.startswith(('bombard_barrel', 'bombard_copper_band', 'bombard_breech', 'fuse_pan',
                                  'colossus_siege_mortar', 'mortar_copper_band')):
                group = 'recoil'
            elif name.startswith('piston_rod_'):
                group = 'piston_L' if '-1' in name else 'piston_R'
            obj['animation_bone'] = group
        return bones
    mount = family == 'cavalry'
    lift = .71 if mount else 0
    if mount:
        add('mount_body', (0, .045, .82), 'root')
        add('mount_neck', (0, -.29, .84), 'mount_body')
        add('mount_head', (0, -.47, .86), 'mount_neck')
        for leg in LEGS:
            thigh, shin = by['ram_thigh_'+leg], by['ram_shin_'+leg]
            add('mount_thigh_'+leg, thigh['joint_start'], 'mount_body')
            add('mount_shin_'+leg, shin['joint_start'], 'mount_thigh_'+leg)
            add('mount_hoof_'+leg, shin['joint_end'], 'mount_shin_'+leg)
    add('pelvis', (0, 0, .495+lift), 'mount_body' if mount else 'root')
    add('chest', (0, 0, .70+lift), 'pelvis')
    add('head', (0, -.015, 1.02+lift), 'chest')
    for side, sign in [('L', -1), ('R', 1)]:
        elbow, start = ends(by['body_upper_arm_'+side])
        wrist, _ = ends(by['body_forearm_'+side])
        add('upper_arm_'+side, start, 'chest')
        add('forearm_'+side, elbow, 'upper_arm_'+side)
        add('hand_'+side, wrist, 'forearm_'+side)
        bones['hand_'+side]['grip'] = by['body_hand_'+side].matrix_world.translation.copy()
        if mount:
            # Seated thighs point toward local +Z (standing thighs are -Z).
            knee, hip = ends(by['body_thigh_'+side])
            ankle = by['body_shin_'+side].location - Vector((0, 0, .09))
        else:
            hip = Vector((sign*.14, -.025, .4275))
            knee = Vector((sign*.14, -.025, .295))
            ankle = Vector((sign*.14, -.025, .155))
        add('thigh_'+side, hip, 'pelvis')
        add('shin_'+side, knee, 'thigh_'+side)
        add('foot_'+side, ankle, 'shin_'+side)
    for obj in parts:
        obj['animation_bone'] = obj['future_bone']
        assert obj['animation_bone'] in bones, (obj.name, obj['animation_bone'])
    return bones


def create_rig(scene, row, parts, bones):
    arm = bpy.data.armatures.new(row['stem']+'_AnimationSkeleton')
    rig = bpy.data.objects.new(row['stem']+'_AnimationRig', arm)
    scene.collection.objects.link(rig)
    rig['dwarf_animation_owned'] = True
    rig['shared_family'] = row['family']
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True); scene.view_layers[0].objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name, data in bones.items():
        bone = arm.edit_bones.new(name)
        bone.head = data['head']; bone.tail = bone.head + data['axis']*.10
        if data['parent']:
            bone.parent = arm.edit_bones[data['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'STICK'; rig.show_in_front = True
    for obj in parts:
        obj.vertex_groups.clear()
        obj.vertex_groups.new(name=obj['animation_bone']).add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
        modifier = obj.modifiers.new('Dwarf_Rigid_Animation', 'ARMATURE'); modifier.object = rig
        # Reins bend between the rider's hand and the ram's bridle. Both ends
        # stay attached instead of sliding with the whole head as a rigid bar.
        if obj['part'].startswith('rein_'):
            obj.vertex_groups.clear()
            hand = obj.vertex_groups.new(name='hand_L')
            head = obj.vertex_groups.new(name='mount_head')
            top = max(v.co.z for v in obj.data.vertices)
            for vertex in obj.data.vertices:
                (head if vertex.co.z > 0 else hand).add([vertex.index], 1.0, 'REPLACE')
            # beam() runs from hand (-local Z) to bridle (+local Z).
    for bone in rig.pose.bones: bone.rotation_mode = 'QUATERNION'
    return rig


def clear_rig(scene, parts):
    for obj in parts:
        for mod in list(obj.modifiers):
            if mod.name.startswith('Dwarf_Rigid_Animation'): obj.modifiers.remove(mod)
        obj.vertex_groups.clear()
    for obj in list(scene.objects):
        if obj.get('dwarf_animation_owned'):
            data = obj.data; bpy.data.objects.remove(obj, do_unlink=True)
            if data.users == 0: bpy.data.armatures.remove(data)


def bake_actions(scene, rig, bones, family):
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    actions = {}
    rig.animation_data_create()
    for clip, frames in motion.LENGTHS[family].items():
        action = bpy.data.actions.new('Dwarf_'+family+'_'+clip)
        action.use_fake_user = True
        action['shared_family'] = family; action['loop'] = clip != 'attack'; action['fps'] = FPS
        action['motion_revision'] = motion.REVISION
        action['impact_frame'] = motion.IMPACT[family] if clip == 'attack' else -1
        action['description'] = motion.DESCRIPTIONS[family][clip]
        rig.animation_data.action = action
        previous = {}
        for frame in range(1, frames+1):
            pose = motion.pose(family, clip, frame, bones)
            # Hierarchical FK + IK generated in world space for legs; storing
            # rotations only keeps arm-rest offsets in each skin intact.
            evaluated = {}
            for name, data in bones.items():
                bone = rig.pose.bones[name]
                parent_pose = evaluated.get(data['parent'], Matrix.Identity(4))
                parent_rest = rest.get(data['parent'], Matrix.Identity(4))
                local_rest = parent_rest.inverted() @ rest[name]
                if name in pose.get('world', {}):
                    desired = pose['world'][name] @ rest[name]
                    bone.matrix_basis = local_rest.inverted() @ parent_pose.inverted() @ desired
                else:
                    bone.location = Vector(pose.get('location', {}).get(name, (0, 0, 0)))
                    bone.rotation_quaternion = pose.get('rotation', {}).get(name, Quaternion())
                bone.scale = Vector(pose.get('scale', {}).get(name, (1, 1, 1)))
                evaluated[name] = parent_pose @ local_rest @ bone.matrix_basis
            scene.view_layers[0].update()
            for bone in rig.pose.bones:
                if bone.name in previous and previous[bone.name].dot(bone.rotation_quaternion) < 0:
                    bone.rotation_quaternion.negate()
                previous[bone.name] = bone.rotation_quaternion.copy()
                bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
                if bone.name in motion.TRANSLATED[family]:
                    bone.keyframe_insert('location', frame=frame, group=bone.name)
                if family == 'siege' and bone.name == 'payload':
                    bone.keyframe_insert('scale', frame=frame, group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation = 'LINEAR'
        action.pose_markers.new('START').frame = 1
        action.pose_markers.new('RECOVERED' if clip == 'attack' else 'LOOP_END').frame = frames
        if clip == 'attack': action.pose_markers.new('IMPACT').frame = motion.IMPACT[family]
        actions[clip] = action
    rig.animation_data.action = None
    return actions


def assign_actions(scene, rig, actions, family):
    rig.animation_data_create()
    for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
    for clip, action in actions.items():
        track = rig.animation_data.nla_tracks.new(); track.name = clip
        strip = track.strips.new(clip, 1, action)
        strip.extrapolation = 'NOTHING'; strip.blend_type = 'REPLACE'
        track.mute = clip != 'idle'
    rig.animation_data.action = None
    scene.render.fps = FPS; scene.frame_start = 1; scene.frame_end = motion.LENGTHS[family]['idle']
    scene['animation_family'] = family; scene['animation_clips'] = ['idle', 'walk', 'attack']
    scene.frame_set(1); scene.view_layers[0].update()


def activate(scene, rig, clip):
    for track in rig.animation_data.nla_tracks: track.mute = track.name != clip
    scene.frame_end = motion.LENGTHS[rig['shared_family']][clip]
    scene.frame_set(1); scene.view_layers[0].update()


def export(scene, rig, parts, row, actions):
    folder = OUT/row['stem']; path = folder/(row['stem']+'.glb')
    copies = []; original_name = rig.name
    try:
        activate(scene, rig, 'idle')
        # The first frame of idle is exactly the approved rest model.
        for obj in parts:
            clone = obj.copy(); clone.data = obj.data.copy()
            clone.data.transform(obj.matrix_world)
            clone.parent = None; clone.matrix_world = Matrix.Identity(4)
            for mod in list(clone.modifiers): clone.modifiers.remove(mod)
            scene.collection.objects.link(clone); copies.append(clone)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in copies: obj.select_set(True)
        scene.view_layers[0].objects.active = copies[0]
        bpy.ops.object.join()
        copies = [copies[0]]
        obj = copies[0]; obj.name = 'DwarfBody'; obj.parent = rig
        # Remove construction-only extras from the merged runtime object.
        for key in list(obj.keys()): del obj[key]
        mod = obj.modifiers.new('Dwarf_Rigid_Animation', 'ARMATURE'); mod.object = rig
        rig.name = 'DwarfRig'
        # glTF NLA mode exports one animation per named track. Muted tracks
        # must be enabled for export; strips have disjoint export groups.
        for track in rig.animation_data.nla_tracks: track.mute = False
        rig.select_set(True); scene.view_layers[0].objects.active = rig
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
            use_selection=True, use_active_scene=True, export_animations=True,
            export_animation_mode='NLA_TRACKS', export_force_sampling=True,
            export_skins=True, export_yup=True, export_extras=False,
            export_cameras=False, export_lights=False, export_anim_slide_to_zero=True)
    finally:
        rig.name = original_name
        for obj in copies:
            data = obj.data; bpy.data.objects.remove(obj, do_unlink=True)
            if data.users == 0: bpy.data.meshes.remove(data)
        activate(scene, rig, 'idle')
    raw = path.read_bytes(); length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length]); binary = raw[28+length:]
    assert sorted(a['name'] for a in doc['animations']) == ['attack', 'idle', 'walk']
    assert len(doc['skins']) == 1 and len(doc['meshes']) == 1
    assert len(doc['materials']) == 1 and len(doc['images']) == 1
    image = doc['bufferViews'][doc['images'][0]['bufferView']]
    png = binary[image.get('byteOffset', 0):image.get('byteOffset', 0)+image['byteLength']]
    assert hashlib.sha256(png).hexdigest() == hashlib.sha256((folder/(row['stem']+'_albedo.png')).read_bytes()).hexdigest()
    assert all(s['magFilter'] == 9728 for s in doc['samplers'])
    return dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
                meshes=1, skins=1, animations=3, embedded_png_matches=True, nearest_filter=True)


def validate(scene, rig, parts, row, actions, before):
    family = row['family']
    assert before == fingerprint(parts), 'Rigging changed an approved mesh, UV or object transform.'
    result = dict(stem=row['stem'], status='PASS', motion_revision=motion.REVISION, approved_meshes_unchanged=True,
                  shared_actions={clip: action.name for clip, action in actions.items()}, clips={})
    root = {b.name: b.matrix_local.inverted() for b in rig.data.bones}
    coordinates = {o.name: [o.matrix_world@v.co for v in o.data.vertices] for o in parts}
    by = {o['part']: o for o in parts}
    for clip in ('idle', 'walk', 'attack'):
        activate(scene, rig, clip)
        matrices = []; min_ground = 1e9; max_grip = 0.; max_joint = 0.; moved = 0.
        first = None; last = None
        reference_rotations = {}; angular_span = {}; angular_step = {}; previous_rotations = {}
        min_elbow_flex = 1e9; max_elbow_flex = -1e9
        for frame in range(1, motion.LENGTHS[family][clip]+1):
            scene.frame_set(frame); scene.view_layers[0].update()
            delta = {b.name: b.matrix@root[b.name] for b in rig.pose.bones}
            for bone in rig.pose.bones:
                rotation = bone.matrix_basis.to_quaternion()
                reference_rotations.setdefault(bone.name, rotation.copy())
                angular_span[bone.name] = max(angular_span.get(bone.name, 0.),
                    math.degrees(reference_rotations[bone.name].rotation_difference(rotation).angle))
                if bone.name in previous_rotations:
                    angular_step[bone.name] = max(angular_step.get(bone.name, 0.),
                        math.degrees(previous_rotations[bone.name].rotation_difference(rotation).angle))
                previous_rotations[bone.name] = rotation.copy()
            current = {n: [list(r) for r in m] for n, m in delta.items()}
            if first is None: first = current
            last = current
            moved = max(moved, max(abs(m[r][c]-Matrix.Identity(4)[r][c]) for m in delta.values() for r in range(4) for c in range(4)))
            ground_parts = [o for o in parts if o['part'].startswith('body_foot_')]
            if family == 'cavalry': ground_parts = [by['ram_hoof_'+leg] for leg in LEGS]
            if family == 'siege': ground_parts = [o for o in parts if o['part'].startswith('wheel_') and o['part'].endswith('_tire')]
            for obj in ground_parts:
                min_ground = min(min_ground, min((delta[obj['animation_bone']]@v).z for v in coordinates[obj.name]))
            for side in ('L', 'R') if family != 'siege' else ():
                elbow, shoulder = ends(by['body_upper_arm_'+side])
                wrist, fore_top = ends(by['body_forearm_'+side])
                max_joint = max(max_joint, (delta['upper_arm_'+side]@elbow-delta['forearm_'+side]@fore_top).length)
                if family not in ('siege', 'cavalry') and side == ('R' if family == 'guardian' else 'L'):
                    upper_axis = elbow-shoulder
                    lower_axis = delta['upper_arm_'+side].to_3x3().inverted()@delta['forearm_'+side].to_3x3()@(wrist-fore_top)
                    signed_bend = math.degrees(math.atan2(upper_axis.cross(lower_axis).x, upper_axis.dot(lower_axis)))
                    assert -40 < signed_bend < -14, (row['stem'], clip, frame, 'free elbow must flex forward', signed_bend)
                    min_elbow_flex = min(min_elbow_flex, -signed_bend)
                    max_elbow_flex = max(max_elbow_flex, -signed_bend)
            for obj in parts:
                if not obj.parent or not obj.parent.get('grip_hand'): continue
                hand = by[obj.parent['grip_hand']]
                hand_delta = delta[hand['animation_bone']]
                max_grip = max(max_grip, (delta[obj['animation_bone']]@obj.parent.matrix_world.translation-hand_delta@hand.matrix_world.translation).length)
        seam = max(abs(first[n][r][c]-last[n][r][c]) for n in first for r in range(4) for c in range(4))
        assert seam < 1e-4, (row['stem'], clip, 'seam/recovery', seam)
        assert min_ground > -.004, (row['stem'], clip, 'foot penetration', min_ground)
        assert max_grip < 1e-5 and max_joint < 1e-5, (row['stem'], clip, max_grip, max_joint)
        if family == 'siege' and clip == 'idle': assert moved < 1e-5
        else: assert moved > .001, (family, clip, 'motionless')
        if family != 'siege':
            # Check relative joint motion: inherited torso rotation alone does
            # not satisfy the request that both arms participate.
            threshold = .5 if clip == 'idle' else 2. if family == 'cavalry' else 5.
            for name in ('upper_arm_L', 'upper_arm_R', 'chest'):
                assert angular_span[name] > threshold, (family, clip, name, 'insufficient joint motion', angular_span[name])
        result['clips'][clip] = dict(frames=motion.LENGTHS[family][clip], fps=FPS,
            loop=clip != 'attack', loop_or_recovery_error=seam, min_ground_z=min_ground,
            max_grip_error=max_grip, max_arm_joint_error=max_joint, max_motion=moved,
            joint_angular_span_degrees=angular_span, max_joint_step_degrees=angular_step,
            free_arm_elbow_flexion_degrees=dict(min=min_elbow_flex,max=max_elbow_flex) if family not in ('siege','cavalry') else None,
            impact_frame=motion.IMPACT[family] if clip == 'attack' else None)
    activate(scene, rig, 'idle')
    return result


def build_family(family, rebuild=False):
    if bpy.context.screen.is_animation_playing and bpy.context.scene.get('dwarf_animation_review_owned'):
        bpy.ops.screen.animation_play()
    rows = [r for r in ASSETS if r['family'] == family]
    existing = [a for a in bpy.data.actions if a.get('shared_family') == family and a.name.startswith('Dwarf_')]
    assert rebuild or not existing, 'Shared actions already exist; --rebuild required.'
    for action in existing: bpy.data.actions.remove(action)
    actions = None; reports = []
    for row in rows:
        scene = bpy.data.scenes.get(row['stem']+'_MCP_Static_V2')
        if scene is None:
            path = OUT/row['stem']/(row['stem']+'.blend')
            with bpy.data.libraries.load(str(path)) as (source, target): target.scenes = source.scenes
            scene = next(s for s in target.scenes if s and s.get('dwarf_factory_owned'))
        bpy.context.window.scene = scene
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            parts = [o for o in scene.objects if o.type == 'MESH' and o.get('part') and not o['part'].startswith('STUDIO_')]
            clear_rig(scene, parts); scene.view_layers[0].update()
            before = fingerprint(parts)
            bones = rig_spec(row, parts)
            rig = create_rig(scene, row, parts, bones)
            if actions is None: actions = bake_actions(scene, rig, bones, family)
            assign_actions(scene, rig, actions, family)
            validation = validate(scene, rig, parts, row, actions, before)
            exported = export(scene, rig, parts, row, actions)
            folder = OUT/row['stem']
            for obj in scene.objects:
                if obj.type == 'EMPTY' and obj.get('race') == 'dwarf': obj['asset_stage'] = 'animated_troop'
            bpy.data.libraries.write(str(folder/(row['stem']+'.blend')), {scene},
                path_remap='RELATIVE', fake_user=True, compress=True)
            report_path = folder/(row['stem']+'_report.json')
            report = json.loads(report_path.read_text(encoding='utf-8'))
            report['stage'] = 'animated_troops'; report['export'] = exported
            report['animation'] = validation
            report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
            reports.append(validation)
            print('DWARF_ANIMATED '+row['stem'], flush=True)
    assert len(actions) == 3 and all(action.users >= 4 for action in actions.values())
    family_report = dict(family=family, status='PASS', authored_actions=3,
        shared_by_four_variants=True, action_names=[a.name for a in actions.values()], variants=reports)
    (WORK/(family+'_animation_validation.json')).write_text(json.dumps(family_report, indent=2), encoding='utf-8')
    # A reusable Blender library contains the three actual Action datablocks,
    # not copies per troop. Each troop source references these same live actions.
    library = OUT/'animations'; library.mkdir(exist_ok=True)
    bpy.data.libraries.write(str(library/(family+'_actions.blend')), set(actions.values()), fake_user=True, compress=True)
    (library/(family+'_manifest.json')).write_text(json.dumps(dict(family=family, fps=FPS, motion_revision=motion.REVISION,
        clips={clip: dict(action=action.name, frames=motion.LENGTHS[family][clip], loop=clip != 'attack',
            description=motion.DESCRIPTIONS[family][clip], impact_frame=motion.IMPACT[family] if clip == 'attack' else None)
            for clip, action in actions.items()}, variants=[r['stem'] for r in rows]),
        ensure_ascii=False, indent=2), encoding='utf-8')
