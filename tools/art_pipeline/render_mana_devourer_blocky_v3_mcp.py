"""One view or short animation sequence per MCP call (keeps the editor responsive)."""
import bpy
from pathlib import Path
from mathutils import Vector
st=bpy.app.driver_namespace['mana_devourer_blocky_v3']
scene,rig,camera=st['scene'],st['rig'],st['camera']
bpy.context.window.scene=scene
def aim(p):
    camera.location=p
    camera.rotation_euler=(Vector((0,0,1.03))-camera.location).to_track_quat('-Z','Y').to_euler()
task=globals().get('TASK','front')
views={'front':(0,-8,1.03),'back':(-3,7,3.7),'side':(8,0,2.4),
       'game_top':(3,-5,6),'three_quarter':(3,-7,3.7)}
if task in views:
    scene.frame_set(1); aim(views[task])
    scene.render.resolution_x=900; scene.render.resolution_y=900
    scene.render.filepath=str(Path(st['out'])/'previews'/f'{task}.png')
    bpy.ops.render.render(write_still=True)
    result={'view':task}
else:
    name='ManaDevourer_'+task
    data=st['clips'][name]
    for tr in rig.animation_data.nla_tracks: tr.mute=True
    rig.animation_data.action=data['action']
    aim((3,-7,3.7))
    scene.render.resolution_x=480; scene.render.resolution_y=480
    scene.cycles.samples=8
    folder=Path(st['review'])/'frames'/task; folder.mkdir(parents=True,exist_ok=True)
    # 12 FPS retains each attack stage; source GLB remains sampled at 24 FPS.
    step=4 if task!='Attack' else 2
    frames=list(range(1,data['end'],step))
    if task=='Attack': frames.append(data['end'])
    for i,f in enumerate(frames,1):
        scene.frame_set(f); scene.render.filepath=str(folder/f'{i:04d}.png')
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action=None
    for tr in rig.animation_data.nla_tracks: tr.mute=False
    scene.cycles.samples=24; scene.frame_set(1)
    result={'clip':name,'frames':len(frames),'fps':6 if task!='Attack' else 12}
aim((3,-7,3.7))
