"""Fast textured animation review renders of the Squire V1 in Blender MCP (Workbench,
albedo), framed to the complete motion, studio floor visible (feet on the ground read).
Frames go to art_source/squire_v1/animation_frames."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['squire']; scene=st['scene']; rig=st['rig']; camera=scene.camera; mat=st['material']
folder=Path(st['source'])/'animation_frames'; folder.mkdir(exist_ok=True)
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,camera.matrix_world.copy(),camera.data.ortho_scale)
scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=640; scene.render.resolution_y=640
sh=scene.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'; sh.show_shadows=True; sh.show_cavity=True
sh.cavity_type='BOTH'; sh.background_type='WORLD'; scene.world.color=(.13,.15,.17)
for node in mat.node_tree.nodes: node.select=False
node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.label=='Base Color'); node.select=True; mat.node_tree.nodes.active=node
for tr in rig.animation_data.nla_tracks: tr.mute=True
manifest={}
try:
    target=Vector((0,-.16,.90)); direction=Vector((5,-8,3.4)).normalized()
    camera.location=target+direction*12; camera.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=2.5
    for name,data in st['clips'].items():
        rig.animation_data.action=data['action']; dest=folder/name; dest.mkdir(exist_ok=True)
        for old in dest.glob('*.png'): old.unlink()
        frames=range(data['start'],data['end']+(0 if data['loop'] else 1))
        for f in frames:
            scene.frame_set(f); scene.render.filepath=str(dest/f'{f:04d}.png'); bpy.ops.render.render(write_still=True)
        manifest[name]={'frames':len(frames),'directory':str(dest),'fps':24}
finally:
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks: tr.mute=False
    scene.frame_set(1)
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y=saved[:3]
    camera.matrix_world=saved[3]; camera.data.ortho_scale=saved[4]
result={'previews':manifest}
