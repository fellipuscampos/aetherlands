"""Close comparison of the actual approved head and six restored mage heads."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/human_school_mages_review'
r=bpy.app.driver_namespace['human_school_mage_review_v1']; scene=r['scene']; camera=scene.camera
bpy.context.window.scene=scene
base=bpy.app.driver_namespace['human_school_mage_base']; original=next(o for o in base.objects if o.get('part')=='Head')
data=bpy.data.meshes.new('OriginalHumanHeadComparison_TEMP'); data.from_pydata([original.matrix_world@v.co for v in original.data.vertices],[],[tuple(f.vertices) for f in original.data.polygons]); data.update()
uv=data.uv_layers.new(name='UVMap')
for to,fr in zip(uv.data,original.data.uv_layers.active.data): to.uv=fr.uv
data.materials.append(original.data.materials[0])
reference=bpy.data.objects.new('OriginalHumanHeadComparison_TEMP',data); scene.collection.objects.link(reference); reference.location.x=-2.25
positions=[root.location.copy() for root in r['roots']]
old=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath)
fonts={o:o.hide_render for o in scene.objects if o.type=='FONT'}
preferences=bpy.context.preferences.addons['cycles'].preferences; previous_compute=preferences.compute_device_type; previous_device=scene.cycles.device
try:
    preferences.compute_device_type='OPTIX'; preferences.get_devices()
    for device in preferences.devices:
        if device.type=='OPTIX': device.use=True; scene.cycles.device='GPU'
    for i,root in enumerate(r['roots']): root.location.x=(i-2.5)*.65
    for o in fonts: o.hide_render=True
    target=Vector((-.3,-.05,1.66)); camera.location=target+Vector((0,-8,.35)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=4.6; scene.render.resolution_x=2400; scene.render.resolution_y=600
    scene.render.filepath=str(WORK/'original_head_restoration_comparison.png'); bpy.ops.render.render(write_still=True)
finally:
    for root,p in zip(r['roots'],positions): root.location=p
    for o,hidden in fonts.items(): o.hide_render=hidden
    camera.location,camera.rotation_euler,camera.data.ortho_scale,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath=old
    preferences.compute_device_type=previous_compute; scene.cycles.device=previous_device
    bpy.data.batch_remove(ids=[reference,data])
result=dict(status='PASS',comparison='original human head, sacred, infernal, necromancy, druidism, arcanism, elementalism')
