"""Baked rigid-bone Idle/Walk/Attack for the live Mana Devourer, via Blender MCP."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Euler

st=bpy.app.driver_namespace['mana_devourer']; scene=st['scene']; rig=st['rig']; parts=st['parts']
bpy.context.window.scene=scene
source=Path(r'C:\Users\felipe campos\Documents\jogo\art_source\mana_devourer_v1')
source.mkdir(parents=True,exist_ok=True); (source/'.gdignore').write_text('',encoding='utf-8')
backup=source/'mana_devourer_v1_static.blend'
if not backup.exists(): bpy.data.libraries.write(str(backup),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
if rig.animation_data:
    assert globals().get('REBAKE',False),'Existing animation; preserve edits.'
    rig.animation_data.action=None
    for tr in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(tr)
    for n in ('ManaDevourer_Idle','ManaDevourer_Walk','ManaDevourer_Attack'):
        if n in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[n])
    for m in list(scene.timeline_markers):
        if m.name.startswith('ManaDevourer_'): scene.timeline_markers.remove(m)
rig.animation_data_create()
rest={b.name:b.head_local.copy() for b in rig.data.bones}
restq={b.name:b.matrix_local.to_quaternion() for b in rig.data.bones}
centers={o['rig_bone']:sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices) for o in parts}
center=Vector((0,0,1.48)); clips={}; previous={}
for b in rig.pose.bones: b.rotation_mode='QUATERNION'
def reset():
    for b in rig.pose.bones: b.location=(0,0,0); b.rotation_quaternion=(1,0,0,0); b.scale=(1,1,1)
def pose(n,translation,rotation):
    b=rig.pose.bones[n]; b.location=restq[n].inverted()@Vector(translation)
    b.rotation_quaternion=restq[n].inverted()@rotation@restq[n]
def assembly(n,shift,tilt,local=(0,0,0),spin=(0,0,0)):
    q=Euler(tilt,'XYZ').to_quaternion(); r=Euler(spin,'XYZ').to_quaternion()
    # Rotate each piece about its own center, then tilt the whole entity around its core.
    local=Vector(local); pivot=rest[n]; piece=centers[n]
    target=center+q@(piece-center+local)+Vector(shift)
    rotation=q@r
    newpivot=target+rotation@(pivot-piece)
    pose(n,newpivot-pivot,rotation)
def action(n,end,loop,start,description):
    a=bpy.data.actions.new(n); a.use_fake_user=True; rig.animation_data.action=a; previous.clear()
    clips[n]={'action':a,'start':1,'end':end,'loop':loop,'nla_start':start,'description':description}
def bake(f):
    for b in rig.pose.bones:
        if b.name in previous and previous[b.name].dot(b.rotation_quaternion)<0: b.rotation_quaternion.negate()
        previous[b.name]=b.rotation_quaternion.copy()
        b.keyframe_insert(data_path='location',frame=f,group=b.name)
        b.keyframe_insert(data_path='rotation_quaternion',frame=f,group=b.name)
names=[b.name for b in rig.data.bones if b.name!='root']
action('ManaDevourer_Idle',73,True,1,'Slow hovering, offset shard drift and restrained counter-rotation of broken arcs.')
for f in range(1,74):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/72
    shift=(0,0,.045*math.sin(p)); tilt=(.018*math.sin(p),.012*math.sin(p),.015*math.sin(p))
    for n in names:
        if n=='core': assembly(n,shift,tilt); continue
        if n.startswith('orbit_'):
            i=int(n[-2:]); wave=math.sin(p+i*.9)-math.sin(i*.9)
            direction=(centers[n]-center).normalized()
            assembly(n,shift,tilt,direction*.018*wave,(.022*wave,.042*wave,.025*math.sin(p)))
        else:
            sign=1 if n=='arc_upper' else -1
            assembly(n,shift,tilt,(0,0,sign*.012*math.sin(p)),(0,sign*.035*math.sin(p),0))
    bake(f)
action('ManaDevourer_Walk',33,True,91,'In-place magical glide: forward lean, quicker hovering and shards trailing the core.')
for f in range(1,34):
    scene.frame_set(f); reset(); p=math.tau*(f-1)/32
    shift=(.018*math.sin(p),0,.028*math.sin(p*2)); tilt=(.105+.013*math.sin(p*2),.012*math.sin(p),.018*math.sin(p))
    for n in names:
        if n=='core': assembly(n,shift,tilt); continue
        if n.startswith('orbit_'):
            i=int(n[-2:]); wave=math.sin(p+i*.8)
            assembly(n,shift,tilt,(.015*wave,.055+.015*math.cos(p+i),.020*wave),(.025*wave,.045*wave,.025*wave))
        else:
            sign=1 if n=='arc_upper' else -1
            assembly(n,shift,tilt,(0,.04,sign*.012*math.sin(p)),(0,sign*.04*math.sin(p),0))
    bake(f)
action('ManaDevourer_Attack',37,False,141,'Gather orbitals, hold charge, drive the core forward and expand fragments, then recover.')
# Body forward/back, vertical offset, forward pitch, radial contraction/expansion, core yaw.
keys={1:(0,0,0,0,0),9:(.07,.055,-.065,-.065,-.055),12:(.08,.065,-.075,-.075,-.07),
      16:(-.27,.025,.13,.16,.075),20:(-.22,.015,.105,.14,.06),28:(-.06,.03,.025,.045,.01),37:(0,0,0,0,0)}
for f in range(1,38):
    scene.frame_set(f); reset(); lo=max(k for k in keys if k<=f); hi=min(k for k in keys if k>=f)
    t=0 if lo==hi else (f-lo)/(hi-lo); t=t*t*(3-2*t); v=[a+(b-a)*t for a,b in zip(keys[lo],keys[hi])]
    for n in names:
        shift=(0,v[0],v[1]); tilt=(v[2],0,v[4])
        if n=='core': assembly(n,shift,tilt); continue
        direction=centers[n]-center; direction.y=0; direction.normalize()
        local=direction*v[3]
        if n.startswith('orbit_'):
            local.y=-max(0,v[3])*.30
            sign=1 if centers[n].x>0 else -1
            assembly(n,shift,tilt,local,(0,sign*v[3]*.38,0))
        else:
            local.y=max(0,v[3])*.35
            assembly(n,shift,tilt,local,(0,(1 if n=='arc_upper' else -1)*v[3]*.24,0))
    bake(f)
clips['ManaDevourer_Attack']['impact_frame']=16
for n,data in clips.items():
    a=data['action']; a['loop']=data['loop']; a['fps']=24
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points: key.interpolation='LINEAR'
    events=[('LOOP_START',1),('LOOP_END',data['end'])] if data['loop'] else [('START',1),('CHARGE',9),('HOLD',12),('IMPACT',16),('FOLLOW_THROUGH',20),('RECOVERED',37)]
    for label,f in events: a.pose_markers.new(label).frame=f
rig.animation_data.action=None
for n,data in clips.items():
    tr=rig.animation_data.nla_tracks.new(); tr.name=n
    strip=tr.strips.new(n,data['nla_start'],data['action']); strip.extrapolation='NOTHING'; strip.blend_type='REPLACE'
    scene.timeline_markers.new(n,frame=data['nla_start'])
scene.render.fps=24; scene.frame_start=1; scene.frame_end=177; scene.frame_set(1)
st['clips']=clips; st['source']=str(source)
rig['notes']='Three baked rigid-bone actions. Static root; in-place glide. Material/texture unchanged.'
result={'clips':{n:{k:v for k,v in d.items() if k!='action'} for n,d in clips.items()}}
