"""Temporary Squire reference at actual 1.80 m; excluded from saved model and GLB."""
import bpy
from pathlib import Path
from mathutils import Vector

exec(Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\guardian_hall_state.py').read_text(encoding='utf-8'))
st = bpy.app.driver_namespace['guardian_hall']
scene = st['scene']
bpy.context.window.scene = scene
source_file = Path(r'C:\Users\felipe campos\Documents\jogo\assets\generated\humans\squire_v1\squire_v1.blend')
with bpy.data.libraries.load(str(source_file), link=False) as (source, loaded):
    loaded.scenes = ['Squire_V1']
source_scene = loaded.scenes[0]
unit = [obj for obj in source_scene.objects if
        (obj.type == 'ARMATURE' or (obj.get('part') and obj.get('region') != 'studio')
         or obj.name.startswith('Squire_V1_ROOT') or obj.name.startswith('Squire_V1_Rig'))]
temporary = bpy.data.collections.new('Guardian_Hall_Scale_Reference_TEMP')
scene.collection.children.link(temporary)
copies = {}
for obj in unit:
    copy = obj.copy()
    temporary.objects.link(copy)
    copy['preview_only'] = True
    copies[obj] = copy
for obj, copy in copies.items():
    if obj.parent in copies:
        copy.parent = copies[obj.parent]
    else:
        copy.parent = None
        copy.location += Vector((-.56, -1.75, .393))
    for modifier in copy.modifiers:
        if modifier.type == 'ARMATURE' and modifier.object in copies:
            modifier.object = copies[modifier.object]
scene.frame_set(1)
scene.view_layers[0].update()
camera = scene.camera
camera.location = (11, -17, 12.5)
camera.data.ortho_scale = 15.6
camera.rotation_euler = (st['target'] - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(Path(st['out']) / 'previews/scale_with_squire.png')
try:
    bpy.ops.render.render(write_still=True)
finally:
    for obj in list(temporary.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(temporary)
    # Remove only the appended reference scene and its now-unlinked objects.
    originals = list(source_scene.objects)
    bpy.data.scenes.remove(source_scene)
    for obj in originals:
        if not obj.users_scene:
            bpy.data.objects.remove(obj, do_unlink=True)
camera.location = (12, -17, 13)
camera.rotation_euler = (st['target'] - camera.location).to_track_quat('-Z', 'Y').to_euler()
result = {'render': scene.render.filepath, 'reference': 'Squire 1.80m; preview only'}
