"""Rebake only this independent animation scene, keeping all source models intact."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Euler,Quaternion
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='nature_avatar_blocky_v5_animated'; NAME='Nature_Avatar_Blocky_V5_Animated'
OUT=ROOT/'assets/generated/grand_manifestations'/STEM; REVIEW=ROOT/'art_source'/f'{STEM}_review'
old=bpy.app.driver_namespace['nature_avatar_blocky_v4']
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
root=bpy.data.objects[NAME+'_ROOT']; rig=bpy.data.objects[NAME+'_Rig']
parts=[o for o in bpy.data.collections[NAME+'_Entity'].objects if o.type=='MESH']
# Match the preserved source order, which is also used by the rigid mesh and UV audit.
parts.sort(key=lambda o:next(i for i,n in enumerate(old['parts']) if o.name==n.name.replace(old['name'],NAME)))
mat=bpy.data.materials[NAME+'_Ancient_Roots_Green_Core']
images=[next(n.image for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and suffix in n.image.name) for suffix in ('albedo','emission')]
studio=bpy.data.collections[NAME+'_Studio']; camera=scene.camera
protected=dict(old['old_hashes'])
for ext in ('glb','blend'):
    p=Path(old['out'])/(old['stem']+'.'+ext)
    protected[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
old_scenes=[name for name in bpy.data.scenes.keys() if name!=NAME]
if rig.animation_data:
    rig.animation_data.action=None
    for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action.name.startswith(NAME+'_'): bpy.data.actions.remove(action)
scene.timeline_markers.clear()
exec((ROOT/'tools/art_pipeline/nature_avatar_animation_motion.py').read_text(encoding='utf-8'),globals())
