"""Fast textured Blender animation previews, preserving final studio settings."""
import bpy
from pathlib import Path
from mathutils import Vector

st=bpy.app.driver_namespace['troll_refinement']; scene=st['scene']; rig=st['rig']; camera=scene.camera
bpy.context.window.scene=scene
folder=Path(st['source'])/'animation_frames'; folder.mkdir(exist_ok=True)
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,camera.matrix_world.copy(),camera.data.ortho_scale)
scene.render.engine='BLENDER_WORKBENCH'; scene.render.resolution_x=640; scene.render.resolution_y=640
sh=scene.display.shading; sh.light='STUDIO'; sh.color_type='TEXTURE'; sh.show_shadows=True; sh.show_cavity=True
sh.cavity_type='BOTH'; sh.curvature_ridge_factor=.8; sh.curvature_valley_factor=.8
sh.background_type='WORLD'; scene.world.color=(.12,.14,.16)
floor=next(o for o in st['studio'].objects if o.name.endswith('_Floor')); floor.hide_render=True
for track in rig.animation_data.nla_tracks: track.mute=True
manifest={}
for name in globals().get('CLIPS',list(st['clips'])):
    data=st['clips'][name]; rig.animation_data.action=data['action']
    target_dir=folder/name; target_dir.mkdir(exist_ok=True)
    coordinates=[]
    for frame in range(data['start'],data['end']+1):
        scene.frame_set(frame); bpy.context.view_layer.update(); deps=bpy.context.evaluated_depsgraph_get()
        for obj in st['meshes']:
            ev=obj.evaluated_get(deps); me=ev.to_mesh()
            coordinates.extend(v.co.copy() for v in me.vertices); ev.to_mesh_clear()
    center=Vector(tuple((min(p[i] for p in coordinates)+max(p[i] for p in coordinates))/2 for i in range(3)))
    direction=Vector((4,-8,3.15)).normalized(); rotation=(-direction).to_track_quat('-Z','Y'); inv=rotation.inverted()
    coords=[inv@(p-center) for p in coordinates]
    lo=Vector((min(p.x for p in coords),min(p.y for p in coords),0)); hi=Vector((max(p.x for p in coords),max(p.y for p in coords),0))
    center+=rotation@((lo+hi)/2)
    camera.location=center+direction*10; camera.rotation_euler=rotation.to_euler()
    camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)*1.16
    frames=globals().get('SAMPLE_FRAMES',None)
    if frames is None: frames=range(data['start'],data['end']+(0 if data['loop'] else 1))
    paths=[]
    for frame in frames:
        scene.frame_set(frame); scene.render.filepath=str(target_dir/f'{frame:04d}.png')
        bpy.ops.render.render(write_still=True); paths.append(scene.render.filepath)
    manifest[name]={'frames':len(paths),'directory':str(target_dir),'fps':24,'loop':data['loop']}
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1); floor.hide_render=False
scene.render.engine,scene.render.resolution_x,scene.render.resolution_y=saved[:3]
camera.matrix_world=saved[3]; camera.data.ortho_scale=saved[4]
result={'animation_sequences':manifest}
