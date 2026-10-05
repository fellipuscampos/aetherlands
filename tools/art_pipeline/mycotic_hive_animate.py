"""Rigid-bone rig + baked Idle for the live Mycotic Hive V3, via Blender MCP.
The hive is stationary: the Idle is a heartbeat travelling through the orb's blocks.
- Orb_Core, Orb_X, Orb_Y, Orb_Z swell on a double beat (lub-dub), each block a few frames
  after the previous one, so the squares visibly pulse in sequence; each crossing block
  swells most along its long axis.
- The berries (children of Orb_Z) ride its top and pulse harder, later in the beat.
- The claws flex outward a little as the orb swells; the horn sways slowly.
- Trunk and roots stay on the root bone (anchored).
Bones are rigid (one bone per part, weight 1). Run REBAKE=True to rebuild.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

st=bpy.app.driver_namespace['mycotic_hive']; NAME=st['name']; scene=st['scene']; parts=st['parts']; root=st['root']
bpy.context.window.scene=scene
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\mycotic_hive_v3')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
backup=source/'mycotic_hive_v3_static.blend'
if NAME+'_Rig' in bpy.data.objects:
    assert globals().get('REBAKE',False),'Rig exists; preserve edits (REBAKE=True to rebuild).'
    old=bpy.data.objects[NAME+'_Rig']
    for o in parts:
        for m in list(o.modifiers): o.modifiers.remove(m)
        o.vertex_groups.clear(); o.parent=root
    arm=old.data; bpy.data.objects.remove(old,do_unlink=True); bpy.data.armatures.remove(arm)
    if 'Hive_Idle' in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions['Hive_Idle'])
else:
    for stale in (bpy.data.actions.get('Hive_Idle'),bpy.data.armatures.get(NAME+'_Skeleton')):
        if stale is not None: (bpy.data.actions if isinstance(stale,bpy.types.Action) else bpy.data.armatures).remove(stale)
    bpy.data.libraries.write(str(backup),{scene},path_remap='RELATIVE',fake_user=True,compress=True)

ORB=Vector((0,0,1.55))
def polar(deg,r,z=0.0): a=math.radians(deg); return Vector((r*math.cos(a),r*math.sin(a),z))
CLAW_AZ={'Claw_1':300,'Claw_2':70,'Claw_3':180}
bones={'root':((0,0,0),(0,0,.3),None),
       'orb_core':(ORB,ORB+Vector((0,0,.3)),'root'),'orb_x':(ORB,ORB+Vector((0,0,.3)),'root'),
       'orb_y':(ORB,ORB+Vector((0,0,.3)),'root'),'orb_z':(ORB,ORB+Vector((0,0,.3)),'root'),
       'berry_1':((.30,-.30,2.17),(.30,-.30,2.37),'orb_z'),'berry_2':((-.30,.24,2.17),(-.30,.24,2.33),'orb_z'),
       'horn':((0,0,2.30),(.04,.04,2.58),'root')}
for part,az in CLAW_AZ.items():
    base=polar(az,.22,.86); bones[part.lower()]=(base,base+Vector((0,0,.4)),'root')
part_bone={'Orb_Core':'orb_core','Orb_X':'orb_x','Orb_Y':'orb_y','Orb_Z':'orb_z','Berry_1':'berry_1','Berry_2':'berry_2',
           'Horn':'horn','Claw_1':'claw_1','Claw_2':'claw_2','Claw_3':'claw_3'}
arm=bpy.data.armatures.new(NAME+'_Skeleton'); rig=bpy.data.objects.new(NAME+'_Rig',arm)
bpy.data.collections[NAME+'_03_TRUNK_ROOTS'].objects.link(rig); rig.parent=root
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in bones.items():
    b=arm.edit_bones.new(n); b.head=h; b.tail=t; b.roll=0; b.use_deform=True
    if parent: b.parent=arm.edit_bones[parent]; b.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT'); arm.display_type='STICK'
for o in parts:
    bone=part_bone.get(o['part'],'root'); o['rig_bone']=bone
    o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    mod=o.modifiers.new('Rigid_Hive_Parts','ARMATURE'); mod.object=rig; o.parent=rig
rig['notes']='Rigid one-bone-per-part rig. root anchors trunk and roots; orb blocks, berries, claws and horn pulse.'

# Heartbeat: a strong beat and a softer second beat inside each 72-frame cycle.
FRAMES=72
def beat(f):
    t=((f-1)%FRAMES)/FRAMES
    def bump(c,w):
        d=min(abs(t-c),1-abs(t-c)); return math.exp(-(d/w)**2)
    return min(1.0,bump(.12,.055)+.62*bump(.30,.06))
DELAY={'orb_core':0,'orb_x':3,'orb_y':6,'orb_z':9,'berry_1':13,'berry_2':16,'claw_1':5,'claw_2':7,'claw_3':9}
rest={b.name:b.matrix_local.to_3x3() for b in arm.bones}
def bone_scale(n,world_scale):
    R=rest[n]; M=R.transposed()@Matrix.Diagonal(Vector(world_scale))@R
    return (M[0][0],M[1][1],M[2][2])
def bone_rotation(n,q_world):
    R=rest[n].to_quaternion(); return R.inverted()@q_world@R
action=bpy.data.actions.new('Hive_Idle'); action.use_fake_user=True
rig.animation_data_create(); rig.animation_data.action=action
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
for f in range(1,FRAMES+2):
    scene.frame_set(f)
    for b in rig.pose.bones: b.location=(0,0,0); b.rotation_quaternion=(1,0,0,0); b.scale=(1,1,1)
    pb=rig.pose.bones
    k=beat(f-DELAY['orb_core']); pb['orb_core'].scale=bone_scale('orb_core',(1+.05*k,)*3)
    for n,axis in (('orb_x',0),('orb_y',1),('orb_z',2)):
        k=beat(f-DELAY[n]); s=[1+.04*k]*3; s[axis]=1+.09*k; pb[n].scale=bone_scale(n,s)
    for n in ('berry_1','berry_2'):
        k=beat(f-DELAY[n]); pb[n].scale=bone_scale(n,(1+.22*k,)*3)
    for part,az in CLAW_AZ.items():
        n=part.lower(); k=beat(f-DELAY[n])
        tangent=Vector((-math.sin(math.radians(az)),math.cos(math.radians(az)),0))
        pb[n].rotation_quaternion=bone_rotation(n,Quaternion(tangent,.04*k))
    p=math.tau*(f-1)/FRAMES
    sway=Quaternion((1,0,0),.045*math.sin(p))@Quaternion((0,1,0),.035*math.sin(p+1.3))
    pb['horn'].rotation_quaternion=bone_rotation('horn',sway)
    for b in pb:
        if b.name=='root': continue
        b.keyframe_insert(data_path='rotation_quaternion',frame=f,group=b.name)
        b.keyframe_insert(data_path='scale',frame=f,group=b.name)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in bag.fcurves:
                for key in fc.keyframe_points: key.interpolation='LINEAR'
action['loop']=True; action['fps']=24
for label,f in (('LOOP_START',1),('BEAT',10),('SECOND_BEAT',23),('LOOP_END',FRAMES+1)): action.pose_markers.new(label).frame=f
rig.animation_data.action=None
track=rig.animation_data.nla_tracks.new(); track.name='Hive_Idle'
strip=track.strips.new('Hive_Idle',1,action); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
scene.render.fps=24; scene.frame_start=1; scene.frame_end=FRAMES+1; scene.frame_set(1)
clips={'Hive_Idle':{'action':action,'start':1,'end':FRAMES+1,'loop':True,'nla_start':1,
       'description':'Heartbeat travelling through the orb blocks (core, then X, Y, Z), berries pulsing harder, claws flexing outward, slow horn sway; trunk and roots anchored.'}}
st['rig']=rig; st['clips']=clips; st['source']=str(source)
result={'bones':len(arm.bones),'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
