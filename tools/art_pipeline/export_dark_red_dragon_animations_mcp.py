"""Export all six reviewed clips and render representative poses in live Blender."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
STEM='dark_red_dragon_v5_animated'; st=bpy.app.driver_namespace[STEM]
scene=st['scene']; rig=st['rig']; root=st['root']; parts=st['parts']; OUT=st['out']; material=st['material']
bpy.context.window.scene=scene
helper=(ROOT/'tools/art_pipeline/build_elemental_dragon_mcp.py').read_text(encoding='utf-8')
start=helper.index('# Runtime: one material'); end=helper.index('\ndef aim(obj,point):',start)
export=helper[start:end].replace('export_animations=False,',
    "export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,export_frame_range=False,export_optimize_animation_size=False,")
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
exec(compile(export,'dragon_animated_export','exec'),globals())
clips={name:{key:value for key,value in data.items() if key!='action'} for name,data in st['clips'].items()}
report={'name':'Dragao vermelho escuro','pipeline':'live Blender MCP','stem':STEM,
    'base_asset':'dark_red_dragon_v4','rest_geometry_height_m':3.0,'rest_geometry_unchanged':True,
    'meshes':1,'materials':1,'triangles':triangles,'bones':len(rig.data.bones),
    'animations':clips,'mouth_socket':'mouth_fire','mouth_forward_axis':'bone local +Y',
    'fire_particles':False,'root_motion':False,'fps':24,'validation':st['validation']}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
poses=OUT/'previews/poses'; poses.mkdir(exist_ok=True)
for track in rig.animation_data.nla_tracks: track.mute=True
camera=scene.camera; target=Vector((.35,.25,1.45))
camera.location=target+Vector((6,-10,5.0)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=6.5
frames={'Dragon_Idle_Ground':1,'Dragon_Idle_Flying':13,'Dragon_Walk_Ground':10,
        'Dragon_Walk_Flying':15,'Dragon_Attack_Ground':31,'Dragon_Attack_Flying':31}
for name,frame in frames.items():
    rig.animation_data.action=st['clips'][name]['action']; scene.frame_set(frame)
    scene.render.filepath=str(poses/(name+'.png')); bpy.ops.render.render(write_still=True)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
scene.frame_end=st['clips']['Dragon_Idle_Ground']['end']
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.region_3d.view_location=target
        area.spaces.active.region_3d.view_distance=6.5
        area.spaces.active.region_3d.view_perspective='ORTHO'
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.overlay.show_overlays=False
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for path,digest in st['protected'].items(): assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
print(json.dumps({'glb':str(OUT/(STEM+'.glb')),'clips':list(clips),'bones':len(rig.data.bones),'unchanged_reference_files':len(st['protected'])}))
