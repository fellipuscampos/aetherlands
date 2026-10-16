"""Rebake the isolated work scene without repeating its mesh/UV preparation."""
import bpy,math,json,shutil,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='elder_lich_blocky_v3_animated'; NAME='Elder_Lich_Blocky_V3_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM
REVIEW=ROOT/'art_source'/f'{STEM}_review'
old=bpy.app.driver_namespace['elder_lich_blocky_v2']
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
entity=bpy.data.collections[NAME+'_Entity']; studio=bpy.data.collections[NAME+'_Studio']
rig=next(o for o in entity.objects if o.type=='ARMATURE')
root=rig.parent; parts=[o for o in entity.objects if o.type=='MESH']
camera=scene.camera; mat=parts[0].data.materials[0]
images=[next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and suffix in n.image.name) for suffix in ('albedo','emission')]
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    path=Path(old['out'])/(old['stem']+'.'+ext)
    protected[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
old_scenes=[s.name for s in bpy.data.scenes if s!=scene]
cloth={}
for base in ('robe_front_L','robe_front_R','robe_side_L','robe_side_R','cape_left','cape_center','cape_right'):
    group=[o for o in parts if o['rig_bone']==base]; panel=max(group,key=lambda o:len(o.data.vertices))
    up=Euler(panel['local_rotation'],'XYZ').to_matrix()@Vector((0,0,1)); anchor=rig.data.bones[base].head_local.copy()
    joints=[base,base+'_middle',base+'_hem']
    cuts=[(rig.data.bones[n].head_local-anchor).dot(up) for n in joints[1:]]
    cloth[base]=dict(up=up,anchor=anchor,cuts=cuts,joints=joints,parts=group)
rig.animation_data_create(); rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action.name.startswith(NAME+'_'): bpy.data.actions.remove(action,do_unlink=True)
source=(ROOT/'tools/art_pipeline/animate_elder_lich_v3_mcp.py').read_text(encoding='utf-8')
exec(source.split('rig.animation_data_create()\n',1)[1],globals())
