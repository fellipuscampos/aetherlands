"""Animate the LIVE edited Spider via MCP, without rebuilding any geometry/UVs."""
import bpy
import math
import json
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); NAME='Giant_Spider_V1'
OUT=ROOT/'assets/generated/spiders/giant_spider_v1'; SOURCE=ROOT/'art_source/giant_spider_v1'
SOURCE.mkdir(parents=True,exist_ok=True); (SOURCE/'.gdignore').write_text('',encoding='utf-8')
scene=bpy.context.scene; assert scene.name==NAME and bpy.context.mode=='OBJECT'
parts=[o for o in scene.objects if o.type=='MESH' and o.get('part')!='StudioGround']
objects={o['part']:o for o in parts}; assert len(parts)==31
root=bpy.data.objects[NAME+'_ROOT']; rig=bpy.data.objects.get(NAME+'_Rig')
def mesh_digest():
    value=[(o.name,[list(v.co) for v in o.data.vertices],[[list(u.uv) for u in layer.data] for layer in o.data.uv_layers]) for o in parts]
    return hashlib.sha256(json.dumps(value).encode()).hexdigest()
original=mesh_digest()
if rig:
    assert globals().get('REBAKE',False),'Rig already exists; preserve manual edits.'
    arm=rig.data; rig.animation_data.action=None
    for tr in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(tr)
    for n in ('Spider_Idle','Spider_Walk','Spider_Attack'):
        if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
    for m in list(scene.timeline_markers):
        if m.name.startswith('Spider_'): scene.timeline_markers.remove(m)
else:
    backup=SOURCE/'giant_spider_v1_static_no_green.blend'
    if not backup.exists(): bpy.data.libraries.write(str(backup),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    specs={}
    def bone(n,h,t,p): specs[n]=(Vector(h),Vector(t),p)
    bone('root',(0,0,0),(0,0,.25),None)
    bone('cephalothorax',(0,.05,.56),(0,-.60,.52),'root')
    bone('abdomen',(0,.10,.62),(0,1.10,.86),'cephalothorax')
    def endpoint(part,start):
        o=objects[part]; vertices=o.data.vertices[:4] if start else o.data.vertices[4:8]
        return sum((o.matrix_world@v.co for v in vertices),Vector())/4
    for side,k in [('l',1),('r',-1)]:
        bone('chelicera_'+side,(k*.10,-.60,.58),(k*.10,-.78,.32),'cephalothorax')
        bone('palp_'+side,(k*.24,-.60,.52),(k*.30,-.84,.36),'cephalothorax')
        for i in range(1,5):
            stem=f'Leg{i}'; hip=endpoint(stem+'_Femur_'+side,True); knee=endpoint(stem+'_Femur_'+side,False)
            tip=endpoint(stem+'_Tibia_'+side,False)
            bone(f'leg{i}_femur_{side}',hip,knee,'cephalothorax')
            bone(f'leg{i}_tibia_{side}',knee,tip,f'leg{i}_femur_{side}')
    collection=bpy.data.collections.get(NAME+'_05_RIG')
    if collection is None:
        collection=bpy.data.collections.new(NAME+'_05_RIG'); scene.collection.children.link(collection)
    arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm); collection.objects.link(rig)
    rig.parent=root
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for n,(h,t,p) in specs.items():
        b=arm.edit_bones.new(n); b.head=h; b.tail=t; b.use_deform=n!='root'
        if p: b.parent=arm.edit_bones[p]
    bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'
    for o in parts:
        world=o.matrix_world.copy(); o.vertex_groups.clear()
        o.vertex_groups.new(name=o['rig_bone']).add(list(range(len(o.data.vertices))),1,'REPLACE')
        for mod in list(o.modifiers):
            if mod.type=='ARMATURE': o.modifiers.remove(mod)
        mod=o.modifiers.new('Block_preserving_skin','ARMATURE'); mod.object=rig
        o.parent=rig; o.matrix_world=world

restq={b.name:b.matrix_local.to_quaternion() for b in arm.bones}
restvec={b.name:b.tail_local-b.head_local for b in arm.bones}
resttip={f'{i}_{side}':arm.bones[f'leg{i}_tibia_{side}'].tail_local.copy() for i in range(1,5) for side in ('l','r')}
for pb in rig.pose.bones: pb.rotation_mode='QUATERNION'
def reset():
    for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0); pb.scale=(1,1,1)
def rotate(n,v): rig.pose.bones[n].rotation_quaternion=restq[n].inverted()@Euler(v,'XYZ').to_quaternion()@restq[n]
def offset(v): rig.pose.bones['cephalothorax'].location=restq['cephalothorax'].inverted()@Vector(v)
targets={}; contacts={}; reach_errors=[]
def leg(i,side,target,clearance,clip,f):
    a=rig.pose.bones[f'leg{i}_femur_{side}']; b=rig.pose.bones[f'leg{i}_tibia_{side}']
    target=Vector(target); bpy.context.view_layer.update(); hip=a.head.copy()
    l1=restvec[a.name].length; l2=restvec[b.name].length
    tipverts=[objects[f'Leg{i}_Tibia_{side}'].matrix_world@v.co for v in objects[f'Leg{i}_Tibia_{side}'].data.vertices[4:8]]
    # Correct for the finite width of the block tip, rather than placing only its center on the floor.
    for iteration in range(5):
        line=target-hip; d=line.length
        if d>l1+l2-1e-5: reach_errors.append((clip,f,i,side,d-l1-l2))
        d=max(.001,min(d,l1+l2-1e-6)); direction=line.normalized()
        along=(l1*l1-l2*l2+d*d)/(2*d); high=math.sqrt(max(0,l1*l1-along*along))
        # Rear knees bow outward to clear the large edited abdomen during a lunge.
        spread=.20 if clip=='Spider_Walk' else .40
        pole=Vector(((spread if side=='l' else -spread) if i==4 else 0,0,1))
        pole=(pole-direction*pole.dot(direction)).normalized()
        knee=hip+direction*along+pole*high
        q1=restvec[a.name].rotation_difference(knee-hip)@restq[a.name]
        a.matrix=Matrix.Translation(hip)@q1.to_matrix().to_4x4(); bpy.context.view_layer.update()
        q2=restvec[b.name].rotation_difference(target-knee)@restq[b.name]
        b.matrix=Matrix.Translation(knee)@q2.to_matrix().to_4x4(); bpy.context.view_layer.update()
        skin=b.matrix@b.bone.matrix_local.inverted()
        low=min((skin@v).z for v in tipverts)
        correction=clearance-low
        if abs(correction)<1e-7: break
        if iteration<4: target.z+=correction
    targets[(clip,f,i,side)]=tuple(target)
    contacts[(clip,f,i,side)]=clearance<1e-6
def bake(f):
    for pb in rig.pose.bones:
        # Keep quaternion signs continuous for interpolation between baked samples.
        prev=previous.get(pb.name)
        if prev and prev.dot(pb.rotation_quaternion)<0: pb.rotation_quaternion.negate()
        previous[pb.name]=pb.rotation_quaternion.copy()
        pb.keyframe_insert(data_path='rotation_quaternion',frame=f,group=pb.name)
        pb.keyframe_insert(data_path='location',frame=f,group=pb.name)
clips={}; rig.animation_data_create(); previous={}
def action(n,end,loop,start,description):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear()
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':description}
    return a

action('Spider_Idle',61,True,1,'Subtle abdomen breathing, alert palps and suspended forelegs; six fixed supports.')
for f in range(1,62):
    scene.frame_set(f); reset(); t=(f-1)/60; p=math.tau*t; breath=1-math.cos(p)
    offset((0,0,.008*breath)); rotate('abdomen',(.015*math.sin(p),0,.010*math.sin(p)))
    for side,k in [('l',1),('r',-1)]:
        rotate('palp_'+side,(-.03*math.sin(p*2),0,k*.035*math.sin(p)))
        rotate('chelicera_'+side,(-.012*math.sin(p),0,k*.008*breath))
        for i in range(1,5):
            target=resttip[f'{i}_{side}'].copy(); lift=.16+.014*breath if i==1 else 0
            if i==1: target.y-=.008*math.sin(p)
            leg(i,side,target,lift,'Spider_Idle',f)
    bake(f)

action('Spider_Walk',33,True,81,'Alternating tetrapods, 62% stance; eight legs step with planted support and lifted recovery.')
def path(t):
    t%=1
    if t<.62: return -.13+.26*t/.62,0
    u=(t-.62)/.38; ease=u*u*(3-2*u)
    return .13-.26*ease,.105*math.sin(math.pi*u)**1.5
for f in range(1,34):
    scene.frame_set(f); reset(); t=(f-1)/32; p=math.tau*t
    offset((.012*math.sin(p),0,-.012+.009*math.cos(p*2)))
    rotate('cephalothorax',(.018*math.sin(p*2),.012*math.sin(p),.012*math.sin(p)))
    rotate('abdomen',(.015*math.sin(p*2-.3),0,-.018*math.sin(p)))
    for side,k in [('l',1),('r',-1)]:
        rotate('palp_'+side,(-.04-.025*math.sin(p+k*.4),0,k*.025))
        for i in range(1,5):
            phase=0 if (i%2==1)==(side=='l') else .5
            dy,lift=path(t+phase); target=resttip[f'{i}_{side}']+Vector((0,dy,0))
            leg(i,side,target,lift,'Spider_Walk',f)
    bake(f)
clips['Spider_Walk']['suggested_translation_mps']=.26/(.62*32/24)

attack=action('Spider_Attack',37,False,131,'Raise forelegs, recoil, quick forward bite at frame 15, follow-through and recovery.')
# Forward offset, body height, body pitch, foreleg clearance, foreleg forward reach, fang pitch.
stages={1:(0,0,0,.16,0,0),8:(.04,.08,-.10,.40,-.08,-.30),
        11:(.055,.105,-.13,.47,-.10,-.36),15:(-.26,-.045,.13,.045,-.24,.20),
        18:(-.28,-.05,.14,.025,-.26,.23),25:(-.10,.035,-.03,.25,-.08,-.08),37:(0,0,0,.16,0,0)}
for f in range(1,38):
    scene.frame_set(f); reset(); lo=max(k for k in stages if k<=f); hi=min(k for k in stages if k>=f)
    u=0 if lo==hi else (f-lo)/(hi-lo); u=u*u*(3-2*u)
    v=[a+(b-a)*u for a,b in zip(stages[lo],stages[hi])]; strength=math.sin(math.pi*(f-1)/36)
    offset((0,v[0],v[1])); rotate('cephalothorax',(v[2],0,0)); rotate('abdomen',(-v[2]*.5,0,0))
    for side,k in [('l',1),('r',-1)]:
        rotate('chelicera_'+side,(v[5],0,k*-.08*strength)); rotate('palp_'+side,(-.15*strength,0,k*.10*strength))
        for i in range(1,5):
            target=resttip[f'{i}_{side}'].copy()
            if i==1: target+=Vector((k*.04*strength,v[4],0))
            leg(i,side,target,v[3] if i==1 else 0,'Spider_Attack',f)
    bake(f)
clips['Spider_Attack']['impact_frame']=15
assert not reach_errors,reach_errors[:5]
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation='LINEAR'
    events=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else [('START',1),('ANTICIPATION',11),('IMPACT',15),('FOLLOW_THROUGH',18),('RECOVERED',37)]
    for label,f in events: a.pose_markers.new(label).frame=f
rig.animation_data.action=None
for n,data in clips.items():
    track=rig.animation_data.nla_tracks.new(); track.name=n
    strip=track.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=167; scene.frame_set(1)
rig['notes']='31 live edited mesh parts. Rigid skin, analytic two-segment legs baked into FK. No geometry or UV regeneration.'
rig['walk_in_place_speed_mps']=clips['Spider_Walk']['suggested_translation_mps']
assert original==mesh_digest()
bpy.app.driver_namespace['spider_animation']={'name':NAME,'scene':scene,'rig':rig,'meshes':parts,'clips':clips,
 'source':str(SOURCE),'out':str(OUT),'targets':targets,'contacts':contacts,'geometry_digest':original}
result={'bones':len(arm.bones),'parts':len(parts),'geometry_uvs_unchanged':True,
 'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
