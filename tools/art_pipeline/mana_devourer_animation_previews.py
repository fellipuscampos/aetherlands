"""Fast textured animation review renders in Blender MCP, fitted to the complete motion."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['mana_devourer']; scene=st['scene']; rig=st['rig']; camera=scene.camera
folder=Path(st['source'])/'animation_frames'; folder.mkdir(exist_ok=True)
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,camera.matrix_world.copy(),camera.data.ortho_scale)
floor=bpy.data.objects[st['name']+'_StudioGround']; floor.hide_render=True
scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=640; scene.render.resolution_y=640
sh=scene.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'; sh.show_shadows=True; sh.show_cavity=True
sh.cavity_type='BOTH'; sh.background_type='WORLD'; scene.world.color=(.13,.15,.17)
# Workbench must display albedo, not the separate emission mask.
for node in st['material'].node_tree.nodes: node.select=False
node=next(n for n in st['material'].node_tree.nodes if n.type=='TEX_IMAGE' and n.image==st['images'][0])
node.select=True; st['material'].node_tree.nodes.active=node
for tr in rig.animation_data.nla_tracks: tr.mute=True
manifest={}
try:
    points=[]
    for data in st['clips'].values():
        rig.animation_data.action=data['action']
        for f in range(1,data['end']+1,2):
            scene.frame_set(f); dep=bpy.context.evaluated_depsgraph_get()
            for o in st['parts']:
                ev=o.evaluated_get(dep); me=ev.to_mesh(); points.extend(ev.matrix_world@v.co for v in me.vertices); ev.to_mesh_clear()
    direction=Vector((4,-9,3.6)).normalized(); rotation=(-direction).to_track_quat('-Z','Y'); inv=rotation.inverted()
    coords=[inv@p for p in points]
    lo=Vector(tuple(min(p[i] for p in coords) for i in range(3))); hi=Vector(tuple(max(p[i] for p in coords) for i in range(3)))
    center=rotation@((lo+hi)/2); camera.location=center+direction*10
    camera.rotation_euler=rotation.to_euler(); camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)*1.15
    for name in globals().get('CLIPS',list(st['clips'])):
        data=st['clips'][name]; rig.animation_data.action=data['action']; dest=folder/name; dest.mkdir(exist_ok=True)
        frames=globals().get('SAMPLE_FRAMES',range(1,data['end']+(0 if data['loop'] else 1)))
        for f in frames:
            scene.frame_set(f); scene.render.filepath=str(dest/f'{f:04d}.png'); bpy.ops.render.render(write_still=True)
        manifest[name]={'frames':len(frames),'directory':str(dest),'fps':24}
finally:
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks: tr.mute=False
    scene.frame_set(1); floor.hide_render=False
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y=saved[:3]
    camera.matrix_world=saved[3]; camera.data.ortho_scale=saved[4]
result={'previews':manifest}
