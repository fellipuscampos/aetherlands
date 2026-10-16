"""Verify the final held-tool geometry and original settler preservation."""
import bpy,hashlib,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
CONFIG=globals().get('BUILDER_CONFIG',{})
RACE=CONFIG.get('race','human'); STEM=RACE+'_builder_v1'
OUT=ROOT/f"assets/generated/{CONFIG.get('family','humans')}/{STEM}"
scene=bpy.data.scenes[RACE.title()+'_Builder_V1']; scene.frame_set(1); scene.view_layers[0].update()
rig=next(o for o in scene.objects if o.type=='ARMATURE')
parts={o['part']:o for o in scene.objects if o.type=='MESH' and o.get('builder_asset')}
assert not any(n.startswith(('Clipboard','Building_plan','Plan_fold','Survey_scroll')) for n in parts)
assert [n for n,o in parts.items() if o.get('animation_bone')=='hand_l']==['Hand_l']
delta=rig.pose.bones['hand_r'].matrix@rig.data.bones['hand_r'].matrix_local.inverted()
def center(name): return sum((delta@v.co for v in parts[name].data.vertices),Vector())/len(parts[name].data.vertices)
shaft=[delta@v.co for v in parts['Hammer_handle'].data.vertices]
axis=(shaft[4]-shaft[0]).normalized()
# Allow the sub-degree wrist rotation in the inherited breathing pose.
upright_dot=axis.dot(Vector((0,0,1)))
assert upright_dot>math.cos(math.radians(1))
forward=(center('Hammer_striking_face')-center('Hammer_head')).normalized()
forward_dot=forward.dot(Vector((0,-1,0)))
assert forward_dot>math.cos(math.radians(1))
report=json.loads((OUT/(STEM+'_report.json')).read_text(encoding='utf-8'))
assert hashlib.sha256((ROOT/report['source']).read_bytes()).hexdigest()==report['source_sha256']
result={'status':'PASS','left_hand_empty':True,'upright_hammer':True,'striking_face_forward':True,'settler_source_unchanged':True}
result.update(shaft_tilt_degrees=math.degrees(math.acos(min(1,max(-1,upright_dot)))),striking_face_angle_degrees=math.degrees(math.acos(min(1,max(-1,forward_dot)))))
(OUT/'source_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
