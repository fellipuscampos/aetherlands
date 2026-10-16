"""Requested bare-forearm correction plus rigid idle/walk, live Blender MCP."""
import bpy,bmesh,json,math,hashlib,sys,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/settlers_review'
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from dwarf_animation_motion import foot_track,solve_chain
ASSETS=bpy.app.driver_namespace['settlers_v1_assets']; REVIEW=bpy.app.driver_namespace['settlers_v1_review']
FPS=48; LENGTHS={'idle':145,'walk':73}; STARTS={'idle':1,'walk':161}
STYLE={'human':dict(stride=.36,lift=.057,swing=15,lean=2.6,bob=.008),
       'elf':dict(stride=.38,lift=.061,swing=16,lean=2.2,bob=.007),
       'dwarf':dict(stride=.18,lift=.036,swing=11,lean=3.2,bob=.006),
       'orc':dict(stride=.43,lift=.058,swing=12,lean=3.6,bob=.009)}
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)

def stage(race,value,frame=None):
    (WORK/'current_stage.json').write_text(json.dumps(dict(race=race,stage=value,frame=frame)),encoding='utf-8')
def T(p): return Matrix.Translation(Vector(p))
def Q(axis,degrees): return Quaternion(Vector(axis),math.radians(degrees))
def around(point,q): return T(point)@q.to_matrix().to_4x4()@T(-point)
def midpoint(obj): return sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
def face_end(obj,top): return sum((obj.data.vertices[i].co for i in (range(4,8) if top else range(4))),Vector())/4
def shape_hash(obj):
    return hashlib.sha256(json.dumps(dict(vertices=[list(v.co) for v in obj.data.vertices],faces=[list(f.vertices) for f in obj.data.polygons],uvs=[list(l.uv) for l in obj.data.uv_layers.active.data]),sort_keys=True).encode()).hexdigest()
def dims(obj): return np.array([(obj.data.vertices[i].co-obj.data.vertices[0].co).length for i in (1,2,4)])

def correct_forearms(asset):
    race=asset['report']['race']; by={o['part']:o for o in asset['parts']}; result=[]
    if race!='dwarf':
        backup=ROOT/'art_source/settlers_before_idle_walk'/asset['folder'].relative_to(ROOT)/(asset['root'].name+'.blend')
        with bpy.data.libraries.load(str(backup),link=False) as (src,dst):
            dst.meshes=[next(n for n in src.meshes if asset['root'].name+'_Forearm_'+side+'_Mesh' in n) for side in ('l','r')]
        for side,reference in zip(('l','r'),dst.meshes):
            obj=by['Forearm_'+side]
            for v,original in zip(obj.data.vertices,reference.vertices): v.co=original.co
            for uv,original in zip(obj.data.uv_layers.active.data,reference.uv_layers.active.data): uv.uv=original.uv
            obj.data.update()
            bpy.data.meshes.remove(reference)
    before={o['part']:shape_hash(o) for o in asset['parts']}
    if race!='dwarf':
        for side in ('l','r'):
            upper,fore=by['UpperArm_'+side],by['Forearm_'+side]
            old=np.array([list(v.co) for v in fore.data.vertices]); old_dims=dims(fore); desired=dims(upper)
            center=old.mean(axis=0); axes=np.stack([old[i]-old[0] for i in (1,2,4)],axis=1); axes/=np.linalg.norm(axes,axis=0)
            # Copy the upper arm's exact cross section and butt join both ends.
            # A 30-micron wrist inset prevents numerical coplanar slivers.
            proximal=np.array([list(upper.data.vertices[i].co) for i in range(4)])
            elbow=proximal.mean(axis=0)
            axis=np.array(upper.data.vertices[4].co-upper.data.vertices[0].co); axis/=np.linalg.norm(axis)
            wrist=np.array(face_end(by['Hand_'+side],True))
            distance=np.dot(elbow-wrist,axis)-.00003
            new=np.concatenate((proximal-axis*distance,proximal),axis=0)
            uv=fore.data.uv_layers.active.data
            for face in fore.data.polygons:
                ids=list(face.vertices); original=old[ids]; updated=new[ids]; old_uv=np.array([list(uv[i].uv) for i in face.loop_indices])
                basis=np.stack((original[1]-original[0],original[-1]-original[0]),axis=1)
                coeff=(updated-original[0])@np.linalg.pinv(basis).T
                refreshed=old_uv[0]+coeff[:,0,None]*(old_uv[1]-old_uv[0])+coeff[:,1,None]*(old_uv[-1]-old_uv[0])
                for li,value in zip(face.loop_indices,refreshed): uv[li].uv=value
            for vert,value in zip(fore.data.vertices,new): vert.co=value
            fore.data.update()
            assert np.max(abs(dims(fore)[:2]-dims(upper)[:2]))<1e-6
            result.append(dict(part=fore['part'],before=list(old_dims),after=list(dims(fore)),upper_arm=list(desired)))
    after={o['part']:shape_hash(o) for o in asset['parts']}
    changed=[n for n in before if before[n]!=after[n]]
    assert set(changed)==(set() if race=='dwarf' else {'Forearm_l','Forearm_r'}),(race,changed)
    return dict(changed_parts=changed,dwarf_unchanged=race=='dwarf',details=result,before=before,after=after)

def rig_specs(asset):
    by={o['part']:o for o in asset['parts']}; bones={}
    def add(name,point): bones[name]=Vector(point)
    add('root',(0,0,0)); add('hips',midpoint(by['Pelvis']))
    add('chest',face_end(by['Belly'],False)); add('head',face_end(by['Head'],False))
    chains={}
    for side in ('l','r'):
        a=face_end(by['UpperArm_'+side],True); b=face_end(by['UpperArm_'+side],False); c=face_end(by['Forearm_'+side],False)
        add('upper_arm_'+side,a); add('forearm_'+side,b); add('hand_'+side,c)
        chains['arm_'+side]=(a,b,c,midpoint(by['Hand_'+side]))
        a=face_end(by['Thigh_'+side],True)
        b=(face_end(by['Thigh_'+side],False)+face_end(by['Shin_'+side],True))/2
        c=face_end(by['Shin_'+side],False)
        add('thigh_'+side,a); add('shin_'+side,b); add('foot_'+side,c)
        chains['leg_'+side]=(a,b,c)
    return bones,chains


def correct_tool_grips(asset,chains,original=None):
    """Set the two tool grips from the approved static bind geometry.

    The elf hand has a fixed -50 degree roll in pose(); its staff needs the
    inverse bind rotation to stay upright. Both handles still cross the fist.
    Loading the static reference makes rebuilding an animation idempotent.
    """
    race=asset['report']['race']
    if race not in ('elf','orc'): return []
    tools=[o for o in asset['parts'] if (o['part']=='Walking_staff' or o['part'].startswith('Staff_'))] if race=='elf' else [o for o in asset['parts'] if o['part'].startswith('Mallet_')]
    if original is None:
        path=ROOT/'art_source/settlers_before_idle_walk'/asset['folder'].relative_to(ROOT)/(asset['root'].name+'.blend')
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):
            dst.meshes=[next(n for n in src.meshes if asset['root'].name+'_'+o['part']+'_Mesh' in n) for o in tools]
        original={o['part']:[v.co.copy() for v in mesh.vertices] for o,mesh in zip(tools,dst.meshes)}
        for mesh in dst.meshes: bpy.data.meshes.remove(mesh)
    grip=chains['arm_r'][3]
    if race=='elf':
        transform=T(grip)@Q((1,0,0),50).to_matrix().to_4x4()@T(-grip)@T((0,-.035,0))
    else:
        rotation=Q((0,0,1),-18).to_matrix().to_4x4()@Q((1,0,0),80).to_matrix().to_4x4()
        transform=T(grip)@rotation@T(-grip)
    for obj in tools:
        for vertex,point in zip(obj.data.vertices,original[obj['part']]): vertex.co=transform@point
        obj.data.update()
    return [o['part'] for o in tools]

def part_bone(obj):
    part=obj['part']
    if part.startswith('Shoulder'): return 'chest'
    if part in ('Pelvis',): return 'hips'
    if part in ('Chest','Belly'): return 'chest'
    if part=='Head': return 'head'
    names={'UpperArm':'upper_arm','Forearm':'forearm','Hand':'hand','Thigh':'thigh','Shin':'shin','Foot':'foot'}
    for prefix,bone in names.items():
        if part.startswith(prefix+'_'): return bone+'_'+part[-1].lower()
    bone=obj.get('future_bone','chest').lower()
    return 'hips' if bone in ('pelvis','hips') else bone

def create_rig(asset,bones):
    scene=asset['scene']; root=asset['root']; stem=root.name
    assert not any(o.get('settler_animation_owned') for o in scene.objects),'Settler already rigged'
    data=bpy.data.armatures.new(stem+'_Skeleton'); rig=bpy.data.objects.new(stem+'_Rig',data); scene.collection.objects.link(rig); rig.parent=root
    rig['settler_animation_owned']=True; rig['race']=asset['report']['race']; rig.show_in_front=True; data.display_type='STICK'
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,point in bones.items():
        bone=data.edit_bones.new(name); bone.head=point; bone.tail=point+Vector((0,.1,0))
        if name!='root': bone.parent=data.edit_bones['root']
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in asset['parts']:
        bone=part_bone(obj); assert bone in bones,(obj['part'],bone)
        obj['animation_bone']=bone; obj.vertex_groups.clear(); obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1.,'REPLACE')
        modifier=obj.modifiers.new('Settler_Rigid_Skin','ARMATURE'); modifier.object=rig
    for bone in rig.pose.bones: bone.rotation_mode='QUATERNION'
    return rig

def pose(race,clip,fraction,bones,chains):
    p=math.tau*fraction; wave=(1-math.cos(p))/2; style=STYLE[race]; result={name:Matrix.Identity(4) for name in bones}
    if clip=='idle':
        hips=Matrix.Identity(4)
        chest=T((0,0,.004*wave))@around(bones['chest'],Q((1,0,0),.45*math.sin(p)))
        head=chest@around(bones['head'],Q((0,0,1),.8*math.sin(p)))
    else:
        drop=.050 if race=='orc' else .038
        hips=T((.003*math.sin(p),0,-drop+style['bob']*(1-math.cos(2*p))/2))@around(bones['hips'],Q((0,0,1),.65*math.sin(p)))
        chest=hips@around(bones['chest'],Q((1,0,0),style['lean']+.45*math.sin(2*p)))@around(bones['chest'],Q((0,0,1),-1.7*math.sin(p)))
        head=chest@around(bones['head'],Q((1,0,0),-style['lean']*.40))
    result.update(hips=hips,chest=chest,head=head)
    for side in ('l','r'):
        a,b,c=chains['leg_'+side]
        if clip=='idle': result.update({'thigh_'+side:Matrix.Identity(4),'shin_'+side:Matrix.Identity(4),'foot_'+side:Matrix.Identity(4)})
        else:
            foot=foot_track(fraction+(0 if side=='l' else .5),c,style['stride'],style['lift'],duty=.62)
            hip=hips@a; l1=(b-a).length; l2=(c-b).length
            assert (foot-hip).length<l1+l2-1e-5,(race,'unreachable foot',fraction,side,(foot-hip).length,l1+l2)
            thigh,shin,actual=solve_chain(a,b,c,hip,foot,Vector((0,-1,0)))
            result.update({'thigh_'+side:thigh,'shin_'+side:shin,'foot_'+side:T(actual-c)})
        a,b,c,grip=chains['arm_'+side]; sign=1 if side=='l' else -1
        if race=='elf' and side=='r':
            if clip=='idle':
                # Keep the long walking stick upright through the breathing loop.
                target_grip=chest@grip+Vector((0,-.110,.065+.009*wave))
            else:
                target_grip=chest@grip+Vector((0,-.110+.020*math.sin(p),.090+.014*math.sin(p)))
            # A slightly extended wrist puts the fingers in front of the
            # forearm. The staff's bind geometry compensates this fixed roll.
            hand_rotation=Q((1,0,0),-50).to_matrix().to_4x4()
            desired=T(target_grip)@hand_rotation@T(-grip); target=desired@c
            # Front is -Y. Bend the elbow behind the wrist, like a normal
            # flexed arm, instead of driving the forearm backwards.
            upper,fore,actual=solve_chain(a,b,c,chest@a,target,chest.to_3x3()@Vector((-.12,1,0)))
            assert (actual-target).length<1e-5,(race,'staff arm unreachable',clip,fraction)
            result.update({'upper_arm_'+side:upper,'forearm_'+side:fore,'hand_'+side:desired})
        else:
            amplitude=.7 if clip=='idle' else style['swing']
            if race=='human' and side=='l' and clip=='walk': amplitude=10
            if race=='orc' and side=='r' and clip=='walk': amplitude=7
            rotation=Q((1,0,0),sign*amplitude*math.sin(p))
            upper=chest@around(a,rotation)
            flex=(.45*wave if clip=='idle' else 3.0+2.2*(1-math.cos(p))/2)
            fore=upper@around(b,Q((1,0,0),-flex))
            result.update({'upper_arm_'+side:upper,'forearm_'+side:fore,'hand_'+side:fore})
    return result

def bake(asset,rig,bones,chains):
    race=asset['report']['race']; scene=asset['scene']; actions={}; rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
    rig.animation_data_create()
    for clip,count in LENGTHS.items():
        action=bpy.data.actions.new(asset['root'].name+'_'+clip); action.use_fake_user=True; action['loop']=True; action['fps']=FPS
        action['description']='Respiração suave com ferramentas presas.' if clip=='idle' else 'Caminhada no lugar com pés nivelados, joelhos articulados e balanço de carga.'
        rig.animation_data.action=action; previous={}
        for frame in range(1,count+1):
            if frame%32==1: stage(race,'bake_'+clip,frame)
            desired=pose(race,clip,(frame-1)/(count-1),bones,chains)
            for name,delta in desired.items():
                bone=rig.pose.bones[name]; bone.matrix_basis=rest[name].inverted()@delta@rest[name]
                if name in previous and previous[name].dot(bone.rotation_quaternion)<0: bone.rotation_quaternion.negate()
                previous[name]=bone.rotation_quaternion.copy()
                bone.keyframe_insert('rotation_quaternion',frame=frame,group=name); bone.keyframe_insert('location',frame=frame,group=name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation='LINEAR'
        action.pose_markers.new('LOOP_START').frame=1; action.pose_markers.new('LOOP_END').frame=count
        actions[clip]=action
    rig.animation_data.action=None
    for bone in rig.pose.bones: bone.matrix_basis.identity()
    for clip,action in actions.items():
        track=rig.animation_data.nla_tracks.new(); track.name=clip
        strip=track.strips.new(clip,STARTS[clip],action); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'; track.mute=False
    scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=233; scene.frame_set(1)
    scene.timeline_markers.clear()
    for clip,start in STARTS.items(): scene.timeline_markers.new(clip.upper(),frame=start)
    scene['animation_clips']=['idle','walk']; scene['walk_in_place']=True
    return actions

def validate(asset,rig,bones,chains,shape_reference):
    scene=asset['scene']; race=asset['report']['race']; by={o['part']:o for o in asset['parts']}; inverse={b.name:b.matrix_local.inverted() for b in rig.data.bones}; clips={}
    assert {o['part']:shape_hash(o) for o in asset['parts']}==shape_reference,'Skinning modified approved geometry/UVs'
    for obj in asset['parts']:
        bm=bmesh.new(); bm.from_mesh(obj.data); assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0; bm.free()
        assert len(obj.vertex_groups)==1 and all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-7 for v in obj.data.vertices)
    for clip,count in LENGTHS.items():
        first=None; maximum_loop=0; min_floor=1e9; max_joint=0; max_ground_contact=0; max_slide=0; moved=0; previous=None; max_step=0
        previous_stance={}; speed=STYLE[race]['stride']/.62/((LENGTHS['walk']-1)/FPS)
        for frame in range(1,count+1):
            scene.frame_set(STARTS[clip]+frame-1); scene.view_layers[0].update()
            delta={b.name:b.matrix@inverse[b.name] for b in rig.pose.bones}
            data=np.array([[c for row in m for c in row] for m in delta.values()])
            if first is None: first=data.copy()
            if previous is not None: max_step=max(max_step,float(np.max(abs(data-previous))))
            previous=data.copy(); moved=max(moved,float(np.max(abs(data-first))))
            assert np.max(abs(np.array(delta['root'])-np.eye(4)))<1e-7,'Root drift'
            assert all(abs(m.to_3x3().determinant()-1)<1e-5 for m in delta.values()),'Non-rigid scaling'
            for obj in asset['parts']:
                transform=delta[obj['animation_bone']]
                min_floor=min(min_floor,min((transform@v.co).z for v in obj.data.vertices))
            for side in ('l','r'):
                a,b,c=chains['leg_'+side]; aa,bb,cc,_=chains['arm_'+side]
                max_joint=max(max_joint,(delta['thigh_'+side]@a-delta['hips']@a).length,(delta['thigh_'+side]@b-delta['shin_'+side]@b).length,(delta['shin_'+side]@c-delta['foot_'+side]@c).length,
                              (delta['upper_arm_'+side]@aa-delta['chest']@aa).length,(delta['upper_arm_'+side]@bb-delta['forearm_'+side]@bb).length,(delta['forearm_'+side]@cc-delta['hand_'+side]@cc).length)
                if clip=='walk':
                    fraction=(frame-1)/(count-1); phase=(fraction+(0 if side=='l' else .5))%1
                    obj=by['Foot_'+side]; footmin=min((delta['foot_'+side]@v.co).z for v in obj.data.vertices)
                    if phase<.62:
                        max_ground_contact=max(max_ground_contact,abs(footmin))
                        world_point=delta['foot_'+side]@c+Vector((0,-speed*(frame-1)/FPS,0))
                        if side in previous_stance and phase>previous_stance[side][0]: max_slide=max(max_slide,(world_point-previous_stance[side][1]).length)
                        previous_stance[side]=(phase,world_point)
                    else: previous_stance.pop(side,None)
        maximum_loop=float(np.max(abs(data-first)))
        assert maximum_loop<1e-5,(race,clip,'loop',maximum_loop)
        assert min_floor>-.00002,(race,clip,'floor penetration',min_floor)
        assert max_joint<.00002,(race,clip,'joint detached',max_joint)
        assert moved>.005,(race,clip,'no motion')
        assert max_step<.11,(race,clip,'pose jump',max_step)
        assert max_ground_contact<.00002 and max_slide<.00002,(race,clip,'foot slide',max_ground_contact,max_slide)
        clips[clip]=dict(frames=count,seconds=(count-1)/FPS,loop_error=maximum_loop,min_ground_z=min_floor,max_joint_gap=max_joint,max_pose_step=max_step,max_planted_foot_z_error=max_ground_contact,max_planted_foot_slide_at_recommended_speed=max_slide,movement=moved)
    scene.frame_set(1); scene.view_layers[0].update()
    return dict(status='PASS',fps=FPS,bones=len(bones),rigid_skinning=True,root_motion=False,walk_speed_m_per_s=STYLE[race]['stride']/.62/((LENGTHS['walk']-1)/FPS),clips=clips)

for asset in ASSETS:
    race=asset['report']['race']; scene=asset['scene']; bpy.context.window.scene=scene; scene.frame_set(1)
    if race not in globals().get('SETTLER_ANIMATE_RACES',('human','elf','dwarf','orc')): continue
    # Recover only this task's own generated draft rigs after a failed motion check.
    for old_rig in [o for o in scene.objects if o.get('settler_animation_owned')]:
        old_actions=[a for a in bpy.data.actions if a.name.startswith(asset['root'].name+'_') and a.get('fps')==48 and a.get('loop') is True]
        for part in asset['parts']:
            for modifier in list(part.modifiers):
                if modifier.type=='ARMATURE' and modifier.object==old_rig: part.modifiers.remove(modifier)
            part.vertex_groups.clear()
        armature=old_rig.data; bpy.data.objects.remove(old_rig,do_unlink=True)
        if armature.users==0: bpy.data.armatures.remove(armature)
        for action in old_actions:
            if action.users<=1 and action.name.startswith(asset['root'].name+'_'): bpy.data.actions.remove(action)
    asset['root']['no_animations']=False
    stage(race,'bare_forearms')
    correction=correct_forearms(asset); asset['arm_correction']=correction
    exposed,hidden=bpy.app.driver_namespace['settlers_v1_surface_audit'](asset['parts'])
    assert not exposed,(race,[(r['a'],r['b']) for r in exposed])
    stage(race,'create_rig'); bones,chains=rig_specs(asset); rig=create_rig(asset,bones)
    asset.update(rig=rig,bones=bones,chains=chains)
    tool_correction=correct_tool_grips(asset,chains)
    correction['after']={o['part']:shape_hash(o) for o in asset['parts']}
    asset['report']['tool_grip_bind_correction']=tool_correction
    actions=bake(asset,rig,bones,chains); asset['actions']=actions
    stage(race,'validate_motion'); animation=validate(asset,rig,bones,chains,correction['after'])
    asset['animation']=animation
    asset['report']['arm_correction']={k:v for k,v in correction.items() if k not in ('before','after')}
    asset['report']['animation']=animation; asset['report']['animations']=2; asset['report']['rigging_deferred']=False; asset['report']['static_review']=False
    asset['report']['geometry']['animations']=2; asset['report']['geometry']['rigs']=1
    asset['report']['surface_validation'].update(hidden_coplanar_pairs=len(hidden),exposed_coplanar_pairs=0)
    (asset['folder']/(asset['root'].name+'_report.json')).write_text(json.dumps(asset['report'],ensure_ascii=False,indent=2),encoding='utf-8')
    (WORK/('animation_'+race+'_validation.json')).write_text(json.dumps(dict(race=race,arm_correction=asset['report']['arm_correction'],animation=animation),indent=2),encoding='utf-8')
    print('SETTLER_ANIMATED',race,'bones',len(bones),'clips',list(animation['clips']))

# Add matching rigs to the existing four-character review; keep every approved mesh.
scene=REVIEW['scene']; bpy.context.window.scene=scene
for index,asset in enumerate(ASSETS):
    root=REVIEW['roots'][index]; col=REVIEW['collections'][index]
    root['no_animations']=False
    rig=asset['rig'].copy(); rig.data=asset['rig'].data.copy(); rig.name=asset['root'].name+'_ReviewRig'; col.objects.link(rig); rig.parent=root
    asset['review_rig']=rig
    for obj in col.objects:
        if obj.type!='MESH' or not obj.get('settler_asset'): continue
        bone=part_bone(obj); obj['animation_bone']=bone; obj.vertex_groups.clear(); obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1.,'REPLACE')
        modifier=obj.modifiers.new('Settler_Rigid_Skin','ARMATURE'); modifier.object=rig
scene.render.fps=FPS; scene.frame_start=1; scene.frame_end=233; scene.timeline_markers.clear()
scene.timeline_markers.new('IDLE — 1 a 145',frame=1); scene.timeline_markers.new('WALK — 161 a 233',frame=161)
scene.use_preview_range=True; scene.frame_preview_start=161; scene.frame_preview_end=233; scene.frame_set(161)
scene['description']='Quatro colonizadores animados. IDLE: quadros 1–145. WALK no lugar: 161–233. Prévia configurada para caminhar em loop.'
scene['animation_clips']=['idle','walk']; scene['walk_in_place']=True
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D': area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.overlay.show_overlays=False
bpy.ops.object.select_all(action='DESELECT'); rig=ASSETS[0]['review_rig']; rig.select_set(True); bpy.context.view_layer.objects.active=rig
(ROOT/'docs/settlers_animation_blender_validation.json').write_text(json.dumps(dict(status='PASS',verified=4,clips=8,fps=48,review_scene=scene.name,assets=[dict(race=a['report']['race'],animation=a['animation'],arm_correction=a['report']['arm_correction']) for a in ASSETS]),ensure_ascii=False,indent=2),encoding='utf-8')
stage('all','animation_ready')
result={'status':'PASS','models':4,'clips':8,'fps':48,'active_scene':scene.name,'preview':'walk'}
