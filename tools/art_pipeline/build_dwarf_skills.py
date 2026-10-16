"""Add private skill actions to approved native dwarf rigs via live MCP."""
import hashlib
import json
import math
import numpy as np
import bpy
from mathutils import Matrix, Vector, Quaternion
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT, OUT, WORK, SKILLS, FPS, roles_for, techniques_for
import animate_dwarf_troops as native
from dwarf_skill_motion import pose
from human_texture_glb import read_glb


def activate(scene, rig, role):
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks: track.mute = track.name != role
    scene.frame_set(1); scene.view_layers[0].update()


def bake(scene, rig, bones, row):
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    actions = {}
    for track in list(rig.animation_data.nla_tracks):
        if track.name in SKILLS[row['family']]: rig.animation_data.nla_tracks.remove(track)
    for role, (seconds, loop) in roles_for(row).items():
        for track in rig.animation_data.nla_tracks: track.mute = True
        action = bpy.data.actions.new(row['stem']+'_'+role)
        action.use_fake_user = True
        action['dwarf_skill_owned'] = True; action['asset'] = row['stem']
        action['loop'] = loop; action['fps'] = FPS
        action['source'] = 'Native dwarf rest joints, newly authored skill choreography'
        rig.animation_data.action = action
        frames = round(seconds*FPS)+1
        previous = {}
        for frame in range(1,frames+1):
            sampled = pose(row,role,(frame-1)/(frames-1),bones)
            evaluated = {}
            for name, data in bones.items():
                bone = rig.pose.bones[name]
                parent_pose = evaluated.get(data['parent'],Matrix.Identity(4))
                parent_rest = rest.get(data['parent'],Matrix.Identity(4))
                local_rest = parent_rest.inverted()@rest[name]
                if name in sampled['world']:
                    desired = sampled['world'][name]@rest[name]
                    bone.matrix_basis = local_rest.inverted()@parent_pose.inverted()@desired
                else:
                    bone.location = Vector(sampled['location'].get(name,(0,0,0)))
                    bone.rotation_quaternion = sampled['rotation'].get(name,Quaternion())
                bone.scale = Vector(sampled['scale'].get(name,(1,1,1)))
                evaluated[name] = parent_pose@local_rest@bone.matrix_basis
                if name in previous and previous[name].dot(bone.rotation_quaternion) < 0:
                    bone.rotation_quaternion.negate()
                previous[name] = bone.rotation_quaternion.copy()
                for prop in ('location','rotation_quaternion','scale'):
                    bone.keyframe_insert(prop,frame=frame,group=name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation = 'LINEAR'
        action.pose_markers.new('START').frame = 1
        action.pose_markers.new('HELD' if role == 'shield_wall' else 'LOOP_END' if loop else 'RECOVERED').frame = frames
        if role not in ('shield_wall','shield_wall_hold','tactical_retreat'):
            fires = (.32,.48,.64) if role == 'volley' else (.36,.63) if role == 'dismantle' else (.55,) if role == 'prepared_bombardment' else (.42,) if role == 'demolition_ammo' else (.52,) if role == 'precise_shot' else (.49,) if role == 'sneak_attack' else (.48,) if role == 'charge' else (.54,)
            for index, fire in enumerate(fires):
                action.pose_markers.new('RELEASE_'+str(index+1)).frame = round((frames-1)*fire)+1
        actions[role] = action
    rig.animation_data.action = None
    for role,action in actions.items():
        track = rig.animation_data.nla_tracks.new(); track.name = role
        strip = track.strips.new(role,1,action); strip.extrapolation = 'NOTHING'; strip.blend_type = 'REPLACE'
        track.mute = True
    return actions


def validate(scene,rig,parts,row,actions):
    inverse = {b.name:b.matrix_local.inverted() for b in rig.data.bones}
    coords = {o.name:np.array([tuple(o.matrix_world@v.co) for v in o.data.vertices]) for o in parts}
    by = {o['part']:o for o in parts}; result = {}; endpoints = {}
    for role, action in actions.items():
        activate(scene,rig,role)
        first = None; minimum = math.inf; lowest_part = ''; max_joint = 0.; span = 0.; max_step = 0.; prior = None
        for frame in range(1,round(action.frame_range[1])+1):
            scene.frame_set(frame); scene.view_layers[0].update()
            matrices = {b.name:b.matrix@inverse[b.name] for b in rig.pose.bones}
            now = np.array([np.array(b.matrix) for b in rig.pose.bones])
            if first is None: first = now.copy()
            span = max(span,float(np.max(np.abs(now-first))))
            if prior is not None: max_step = max(max_step,float(np.max(np.abs(now-prior))))
            prior = now
            for obj in parts:
                # Reins have endpoint weights; verify them per vertex too.
                groups = {group.index:group.name for group in obj.vertex_groups}
                p = coords[obj.name]
                for group_index,name in groups.items():
                    indices = [v.index for v in obj.data.vertices if any(g.group==group_index and g.weight>.99 for g in v.groups)]
                    if not indices: continue
                    matrix = np.array(matrices[name])
                    transformed = p[indices]@matrix[:3,:3].T+matrix[:3,3]
                    assert np.isfinite(transformed).all(),(row['stem'],role,frame,obj['part'])
                    low=float(transformed[:,2].min())
                    if low<minimum:minimum=low;lowest_part=obj['part']
            if row['family'] != 'siege':
                for side in ('L','R'):
                    elbow,_ = native.ends(by['body_upper_arm_'+side])
                    _,fore_top = native.ends(by['body_forearm_'+side])
                    max_joint = max(max_joint,(matrices['upper_arm_'+side]@elbow-matrices['forearm_'+side]@fore_top).length)
        seam = float(np.max(np.abs(first-now)))
        assert minimum > -.004,(row['stem'],role,'ground',minimum,lowest_part)
        assert max_joint < .00002,(row['stem'],role,'elbow separation',max_joint)
        assert span > .001,(row['stem'],role,'motionless')
        if role != 'shield_wall': assert seam < .0001,(row['stem'],role,'recovery',seam)
        endpoints[role] = (first,now.copy())
        result[role] = dict(seconds=SKILLS[row['family']][role][0],loop=SKILLS[row['family']][role][1],
            frames=round(action.frame_range[1]),min_ground_z=minimum,arm_joint_error=max_joint,
            recovery_error=seam,movement=span,max_frame_step=max_step,finite=True,
            action=action.name,independently_authored_for=row['stem'])
    if row['family']=='guardian':
        transition=float(np.max(np.abs(endpoints['shield_wall'][1]-endpoints['shield_wall_hold'][0])))
        assert transition<.00001,('shield enter/hold',transition)
        result['shield_wall']['hold_transition_error']=transition
    activate(scene,rig,'idle')
    return result


def export(scene,rig,parts,row):
    collection = bpy.data.collections.new('DWARF_SKILL_EXPORT_TEMP'); scene.collection.children.link(collection)
    verts=[]; faces=[]; uv_values=[]; face_materials=[]; materials=[]; groups={}; smooth=[]
    for obj in parts:
        offset=len(verts); verts.extend(tuple(obj.matrix_world@v.co) for v in obj.data.vertices)
        slots=[]
        for material in obj.data.materials:
            if material not in materials: materials.append(material)
            slots.append(materials.index(material))
        uv=obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            faces.append(tuple(offset+i for i in face.vertices)); face_materials.append(slots[face.material_index]); smooth.append(face.use_smooth)
            for index in face.loop_indices: uv_values.extend(uv[index].uv)
        for vertex in obj.data.vertices:
            assert len(vertex.groups)==1 and abs(vertex.groups[0].weight-1)<.00001
            name=obj.vertex_groups[vertex.groups[0].group].name
            groups.setdefault(name,[]).append(offset+vertex.index)
    mesh=bpy.data.meshes.new('DwarfBody');mesh.from_pydata(verts,[],faces);mesh.update()
    for material in materials:mesh.materials.append(material)
    for face,slot,shading in zip(mesh.polygons,face_materials,smooth):face.material_index=slot;face.use_smooth=shading
    mesh.uv_layers.new(name='UVMap').data.foreach_set('uv',uv_values)
    model=bpy.data.objects.new('DwarfBody',mesh);collection.objects.link(model);model.parent=rig
    for name,indices in groups.items():model.vertex_groups.new(name=name).add(indices,1,'REPLACE')
    modifier=model.modifiers.new('Dwarf_Rigid_Animation','ARMATURE');modifier.object=rig
    name=rig.name
    try:
        rig.name='DwarfRig';bpy.ops.object.select_all(action='DESELECT');model.select_set(True);rig.select_set(True)
        bpy.context.view_layer.objects.active=rig
        for track in rig.animation_data.nla_tracks:track.mute=False
        scene.frame_set(1)
        bpy.ops.export_scene.gltf(filepath=str(OUT/row['stem']/(row['stem']+'.glb')),
            export_format='GLB',use_selection=True,use_active_scene=True,export_animations=True,
            export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,
            export_force_sampling=True,export_frame_range=False,export_rest_position_armature=True,
            export_skins=True,export_def_bones=False,export_yup=True,export_extras=False,
            export_cameras=False,export_lights=False)
    finally:
        rig.name=name;bpy.data.objects.remove(model,do_unlink=True)
        if not mesh.users:bpy.data.meshes.remove(mesh)
        bpy.data.collections.remove(collection);activate(scene,rig,'idle')
    doc=read_glb((OUT/row['stem']/(row['stem']+'.glb')).read_bytes())[0]
    actual={a['name']:max(doc['accessors'][s['input']]['max'][0] for s in a['samplers']) for a in doc['animations']}
    assert set(actual)=={'idle','walk','attack'}|set(roles_for(row)),actual
    for role,(seconds,_) in roles_for(row).items():assert abs(actual[role]-seconds)<.0001
    return actual


def build(row):
    if bpy.context.screen and bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=bpy.data.scenes.get(row['stem']+'_MCP_Static_V2')
    if scene is None:
        with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,target):target.scenes=source.scenes
        scene=next(s for s in target.scenes if s and s.get('dwarf_factory_owned'))
    bpy.context.window.scene=scene
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and not o['part'].startswith('STUDIO_')]
    rigs=[o for o in scene.objects if o.type=='ARMATURE' and o.get('dwarf_animation_owned')]
    assert len(rigs)==1
    # Read the actual saved rig/actions; a scene left open from an earlier
    # editing session can predate the final basic-animation revision.
    old_rig=rigs[0]
    with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,target):
        target.objects=[name for name in source.objects if '_AnimationRig' in name]
    loaded=[obj for obj in target.objects if obj and obj.type=='ARMATURE']
    assert len(loaded)==1
    rig=loaded[0];scene.collection.objects.link(rig)
    for obj in parts:
        for modifier in obj.modifiers:
            if modifier.type=='ARMATURE' and modifier.object==old_rig:modifier.object=rig
    pending=[scene.collection]
    while pending:
        collection=pending.pop();pending.extend(collection.children)
        if old_rig.name in collection.objects:collection.objects.unlink(old_rig)
    activate(scene,rig,'idle');before=native.fingerprint(parts)
    basic={tr.name:tr.strips[0].action for tr in rig.animation_data.nla_tracks if tr.name in ('idle','walk','attack')}
    assert len(basic)==3
    bones=native.rig_spec(row,parts)
    assert set(bones)==set(rig.data.bones.keys())
    for name,info in bones.items():assert (rig.data.bones[name].head_local-info['head']).length<.00001,(row['stem'],name)
    scene.render.fps=FPS
    actions=bake(scene,rig,bones,row)
    validation=validate(scene,rig,parts,row,actions)
    assert before==native.fingerprint(parts),'Approved meshes/UVs/transforms changed'
    assert all(tr.strips[0].action==basic[tr.name] for tr in rig.animation_data.nla_tracks if tr.name in basic)
    clips=export(scene,rig,parts,row)
    scene['animation_clips']=list(clips);scene['dwarf_skill_revision']=1
    scene['skill_authoring']='Private actions solved on native dwarf joints, without foreign retargeting'
    scene.frame_start=1
    scene.frame_end=max(round(action.frame_range[1]) for action in list(basic.values())+list(actions.values()))
    scene.frame_set(1)
    folder=OUT/row['stem']
    bpy.data.libraries.write(str(folder/(row['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report_path=folder/(row['stem']+'_report.json');report=json.loads(report_path.read_text(encoding='utf-8'))
    report['skills']=dict(status='PASS',revision=1,source='native_dwarf_rig',fps=FPS,
        foreign_actions_used=False,basic_actions_preserved=True,approved_geometry_preserved=True,
        technique_clips=techniques_for(row),clips=validation)
    report['export']['animations']=len(clips);report['export']['sha256']=hashlib.sha256((folder/(row['stem']+'.glb')).read_bytes()).hexdigest()
    report['export']['bytes']=(folder/(row['stem']+'.glb')).stat().st_size
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    (WORK/(row['stem']+'_validation.json')).write_text(json.dumps(validation,indent=2),encoding='utf-8')
    print('DWARF_SKILLS_DONE',row['stem'],len(clips),flush=True)
    return dict(stem=row['stem'],status='PASS',clips=len(clips),new_actions=len(actions),geometry_preserved=True)
