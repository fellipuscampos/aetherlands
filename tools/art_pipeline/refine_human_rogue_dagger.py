"""Clarify the first rogue's blade gesture before deriving all later stages (MCP)."""
import bpy, math, json, ast
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); PIPE=ROOT/'tools/art_pipeline'
st=bpy.app.driver_namespace['human_rogue_siege_rogue_v1']; NAME=st['name']; PREFIX='Rogue'
scene=st['scene']; rig=st['rig']; parts=st['parts']; root=st['root']; bpy.context.window.scene=scene
for track in list(rig.animation_data.nla_tracks):
    if track.name in ('Rogue_Attack','Rogue_SneakAttack'): rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action=None
oldclips={n:d for n,d in st['clips'].items() if n in ('Rogue_Idle','Rogue_Walk')}
for name in ('Rogue_Attack','Rogue_SneakAttack'):
    old=bpy.data.actions.get(name)
    if old: bpy.data.actions.remove(old)
anim=(PIPE/'warrior_animate.py').read_text(encoding='utf-8')
exec(anim[anim.index('def P(n):'):anim.index("override={'Shoulder_l'")])
arm=rig.data; rest={b.name:b.matrix_local.copy() for b in arm.bones}; bones={b.name:None for b in arm.bones}; ORDER=list(bones)
exec(anim[anim.index('def Tm(v):'):anim.index('# Idle:')])
tree=ast.parse((PIPE/'human_rogue_siege_live.py').read_text(encoding='utf-8'))
node=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='gesture')
exec(compile(ast.Module(body=[node],type_ignores=[]),'<refine-dagger>','exec'))
import hashlib
node=next(n for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name=='action_signature')
exec(compile(ast.Module(body=[node],type_ignores=[]),'<signature>','exec'))
gesture('Attack',33,.035,8,12,(-28,-28,65),(-8,12,0),.14)
gesture('SneakAttack',57,.17,17,8,(-35,-38,120),(-14,24,0),.19)
for n,d in clips.items():
    d['nla_start']=oldclips['Rogue_Walk']['nla_start']+48 if n.endswith('_Attack') else 201
    action=d['action']; action['loop']=False; action['fps']=24
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points: k.interpolation='LINEAR'
    action.pose_markers.new('START').frame=1; action.pose_markers.new('IMPACT').frame=d['impact_frame']; action.pose_markers.new('RECOVERED').frame=d['end']
    track=rig.animation_data.nla_tracks.new(); track.name=n
    strip=track.strips.new(n,d['nla_start'],action); strip.extrapolation='NOTHING'
    st['animation_validation']['samples'][n]['min_z']=round(stats[n]['min_z'],6)
    st['animation_validation']['samples'][n]['curve_sha256']=action_signature(action)
    assert stats[n]['min_z']>-.01
st['clips']={**oldclips,**clips}; rig.animation_data.action=None; scene.frame_set(1)
result={'refined':list(clips),'ground_minima':{n:stats[n]['min_z'] for n in clips}}
