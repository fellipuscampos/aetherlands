"""Remove just the two eyebrow pieces from the animated dragon, keeping its idle intact."""
import bpy,json,hashlib,shutil
from pathlib import Path

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
STEM='elemental_dragon_v5_animated'; OUT=ROOT/'assets/generated/grand_manifestations'/STEM
state=bpy.app.driver_namespace[STEM]; scene=state['scene']; rig=state['rig']; root=state['root']
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
bpy.context.window.scene=scene
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
scene.frame_end=181; scene.frame_set(1)
removed=[o for o in state['parts'] if o['part'].startswith('Brow_')]
assert len(removed)==2 and {o['part'] for o in removed}=={'Brow_-1','Brow_1'}
backup=ROOT/'art_source/elemental_dragon_review/before_eyebrow_removal'
backup.mkdir(parents=True,exist_ok=True); (backup/'.gdignore').touch()
for extension in ('blend','glb'):
    source=OUT/(STEM+'.'+extension); assert not (backup/source.name).exists()
    shutil.copy2(source,backup/source.name)
shutil.copy2(OUT/(STEM+'_report.json'),backup/(STEM+'_report.json'))

def animation_fingerprint():
    result=[]
    for track in rig.animation_data.nla_tracks:
        for strip in track.strips:
            curves=[]
            for layer in strip.action.layers:
                for action_strip in layer.strips:
                    for bag in action_strip.channelbags:
                        for curve in bag.fcurves:
                            curves.append((curve.data_path,curve.array_index,[(tuple(k.co),k.interpolation) for k in curve.keyframe_points]))
            result.append((track.name,strip.frame_start,strip.frame_end,curves))
    return hashlib.sha256(repr(result).encode()).hexdigest()

animation_before=animation_fingerprint()
parts=[o for o in state['parts'] if o not in removed]
geometry_before=hashlib.sha256(repr([(o['part'],[tuple(v.co) for v in o.data.vertices]) for o in parts]).encode()).hexdigest()
removed_names=[o['part'] for o in removed]
for obj in removed: bpy.data.objects.remove(obj,do_unlink=True)
state['parts']=parts
vertices=[]; polygons=[]; uvs=[]; groups={}; triangles=0
for obj in parts:
    start=len(vertices); vertices.extend(tuple(v.co) for v in obj.data.vertices)
    polygons.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
    uvs.extend(tuple(l.uv) for l in obj.data.uv_layers.active.data)
    obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    for v in obj.data.vertices:
        for g in v.groups: groups.setdefault(obj.vertex_groups[g.group].name,[]).append((start+v.index,g.weight))
data=bpy.data.meshes.new(STEM+'_Runtime_No_Eyebrows'); data.from_pydata(vertices,[],polygons); data.update()
data.materials.append(parts[0].data.materials[0]); uv=data.uv_layers.new(name='PixelUV')
for loop,value in zip(uv.data,uvs): loop.uv=value
runtime=bpy.data.objects.new(STEM+'_Body',data); scene.collection.objects.link(runtime); runtime.parent=rig
for name,influences in groups.items():
    group=runtime.vertex_groups.new(name=name)
    for index,weight in influences: group.add([index],weight,'REPLACE')
runtime.modifiers.new('Dragon_Skin','ARMATURE').object=rig
for obj in scene.objects: obj.select_set(False)
for obj in (root,rig,runtime): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,
    export_skins=True,export_def_bones=False,export_yup=True,export_cameras=False,export_lights=False,export_anim_slide_to_zero=True)
bpy.data.objects.remove(runtime,do_unlink=True)
assert animation_fingerprint()==animation_before
assert hashlib.sha256(repr([(o['part'],[tuple(v.co) for v in o.data.vertices]) for o in parts]).encode()).hexdigest()==geometry_before
report=state['report']; report.update(parts=len(parts),triangles=triangles,eyebrows=False)
report['face_revision']={'removed_parts':removed_names,'remaining_geometry_unchanged':True,'idle_keyframes_unchanged':True,'animation_fingerprint':animation_before}
report['animation'].pop('geometry_unchanged',None)
report['animation']['geometry_unchanged_except_removed_eyebrows']=True
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
for label,frame in [('idle_start',1),('idle_high',46),('idle_mid',91),('idle_low',136)]:
    scene.frame_set(frame); scene.render.filepath=str(OUT/'previews'/(label+'.png')); bpy.ops.render.render(write_still=True)
scene.frame_set(1)
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
result=report['face_revision']|{'parts':len(parts),'triangles':triangles}
