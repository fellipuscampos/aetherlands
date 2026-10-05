"""Re-export the saved Minotaur source blend to the game GLB (standalone, no MCP
session needed) and optionally re-render the review stills/animation frames.
Never writes the .blend back. Run headless with Blender 5.2:

    blender.exe -b --factory-startup assets/generated/minotaurs/minotaur_blocky_v1/minotaur_blocky_v1.blend \
        --python tools/art_pipeline/minotaur_blocky_export.py -- [--previews FRAMES_DIR]

Same export as minotaur_blocky_animation_save.py: two skinned meshes (Body,
Labrys) joined from temporary copies, one glTF clip per NLA track.
--previews renders the five Cycles stills (rest pose) and the EEVEE frame
sequences; encode them with encode_minotaur_previews.py <FRAMES_DIR>.
"""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
FRAMES_DIR=args[args.index('--previews')+1] if '--previews' in args else None
NAME='Minotaur_Blocky_V1'
OUT=Path(bpy.data.filepath).resolve().parent
PROJECT=OUT.parents[3]
scene=bpy.data.scenes[NAME]; bpy.context.window.scene=scene
root=bpy.data.objects[NAME+'_ROOT']; rig=bpy.data.objects[NAME+'_Rig']
meshes=[o for o in rig.children if o.type=='MESH']
assert all(len([m for m in o.modifiers if m.type=='ARMATURE' and m.object==rig])==1 for o in meshes)
tracks=sorted(t.name for t in rig.animation_data.nla_tracks)
# The packed atlas must be byte-identical (in pixels) to the PNG the UVs were painted for.
import hashlib
def digest(image): return hashlib.md5(bytes(round(v*255) for v in image.pixels[:])).hexdigest()
disk=bpy.data.images.load(str(OUT/'minotaur_blocky_v1_atlas.png'),check_existing=False)
assert digest(bpy.data.images[NAME+'_PixelAtlas'])==digest(disk), 'Packed atlas differs from minotaur_blocky_v1_atlas.png: run minotaur_blocky_repack_atlas.py'
bpy.data.images.remove(disk)
assert tracks==['Minotaur_Attack','Minotaur_Idle','Minotaur_Walk'],tracks

if FRAMES_DIR:
    for t in rig.animation_data.nla_tracks: t.mute=True
    rig.animation_data.action=None
    for pb in rig.pose.bones: pb.location=(0,0,0); pb.rotation_quaternion=(1,0,0,0)
    scene.frame_set(1); bpy.context.view_layer.update()
    camera=scene.camera; target=Vector((0,-.15,1.30))
    views={'three_quarter':(6,-12,5.6),'front':(0,-12,1.2),'side':(12,0,2.0),'back':(-6,12,5.0),'game_top':(5,-7,11)}
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=1000
    for view,off in views.items():
        camera.location=target+Vector(off); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=target+Vector(views['three_quarter']); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    for t in rig.animation_data.nla_tracks: t.mute=False
    # Reuse the MCP preview script unchanged, through the same state it expects.
    clips={}
    for t in rig.animation_data.nla_tracks:
        a=t.strips[0].action; clips[t.name]={'action':a,'end':int(t.strips[0].action_frame_end),'loop':bool(a.get('loop'))}
    bpy.app.driver_namespace['minotaur_animation']={'name':NAME,'scene':scene,'rig':rig,'clips':clips}
    code=(PROJECT/'tools/art_pipeline/minotaur_blocky_animation_previews.py').read_text(encoding='utf-8')
    namespace={'FRAMES_DIR':FRAMES_DIR}; exec(code,namespace)
    print('PREVIEWS',json.dumps(namespace['result']))

rig.animation_data.action=None
for t in rig.animation_data.nla_tracks: t.mute=False
scene.frame_start=1; scene.frame_end=137; scene.frame_set(1); bpy.context.view_layer.update()
export=bpy.data.collections.new(NAME+'_EXPORT_TMP'); scene.collection.children.link(export)
joined=[]
for label,members in [('Body',[o for o in meshes if o.get('bone')!='weapon']),('Labrys',[o for o in meshes if o.get('bone')=='weapon'])]:
    assert members,label
    copies=[]
    for o in members:
        c=o.copy(); c.data=o.data.copy(); export.objects.link(c); copies.append(c)
    with bpy.context.temp_override(active_object=copies[0],selected_editable_objects=copies,selected_objects=copies):
        bpy.ops.object.join()
    obj=copies[0]; obj.name=NAME+'_'+label; obj.data.name=NAME+'_'+label+'_Mesh'; obj.parent=rig
    joined.append(obj)
glb=OUT/'minotaur_blocky_v1.glb'
bpy.ops.object.select_all(action='DESELECT')
for o in joined+[rig,root]: o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
 export_animations=True,export_animation_mode='NLA_TRACKS',export_anim_slide_to_zero=True,export_force_sampling=True,
 export_frame_range=False,export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False)
for o in joined: o.data.calc_loop_triangles()
triangles=sum(len(o.data.loop_triangles) for o in joined)

report_path=OUT/'minotaur_blocky_v1_report.json'
report=json.loads(report_path.read_text(encoding='utf-8'))
report['triangles']=triangles; report['editable_parts']=len(meshes)
report['user_edits']=('Final model edited by the user in Blender: Hump, Elbow_l/r, Knee_l/r and AnkleBand_l/r removed; '
                      'Abdomen/Pelvis/Belt widened (scale applied, UV/paint rebuilt at 64 px/m).')
report['glb']['exported_from']=bpy.data.filepath
report_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
print('EXPORTED',json.dumps({'glb':str(glb),'triangles':triangles,'parts':len(meshes),'clips':tracks}))
