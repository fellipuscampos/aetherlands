"""Six animated four-tier review scenes, with the same eighteen shared Actions."""
import bpy
import sys
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:/Users/felipe campos/Documents/jogo')
sys.path.insert(0, str(ROOT/'tools/art_pipeline'))
from dwarf_troop_assets import ASSETS, OUT
from dwarf_animation_motion import LENGTHS, FPS

if bpy.context.screen.is_animation_playing and bpy.context.scene.get('dwarf_animation_review_owned'):
    bpy.ops.screen.animation_play()

scenes = []
for family in dict.fromkeys(r['family'] for r in ASSETS):
    name = 'Dwarf_Animations_'+family+'_Review'
    old = bpy.data.scenes.get(name)
    if old:
        assert old.get('dwarf_animation_review_owned')
        for obj in list(old.objects):
            if len(obj.users_scene) == 1: bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name)
    scene['dwarf_animation_review_owned'] = True
    scene['family'] = family
    scene['description'] = 'Quatro evoluções usando as mesmas Actions idle/walk/attack. Selecione a classe em Scene.'
    rows = [r for r in ASSETS if r['family'] == family]
    source = None
    for row in rows:
        source = bpy.data.scenes[row['stem']+'_MCP_Static_V2']
        originals = [o for o in source.objects if o.type in ('EMPTY', 'ARMATURE')
            or o.type == 'MESH' and o.get('part') and not o['part'].startswith('STUDIO_')]
        display = bpy.data.objects.new(row['stem']+'_ReviewPlacement', None)
        scene.collection.objects.link(display)
        display.location.x = (row['tier']-1.5)*2.35
        clones = {}
        for obj in originals:
            clone = obj.copy(); clone.name = row['stem']+'_Review_'+obj.name
            scene.collection.objects.link(clone); clones[obj] = clone
        for original, clone in clones.items():
            clone.parent = clones.get(original.parent, display)
            for mod in clone.modifiers:
                if mod.type == 'ARMATURE': mod.object = clones[mod.object]
        rig = next(o for o in clones.values() if o.type == 'ARMATURE')
        rig.hide_viewport = False
        for track in rig.animation_data.nla_tracks: track.mute = track.name != ('attack' if family == 'warrior' else 'idle')
        label_data = bpy.data.curves.new(row['stem']+'_ReviewLabel', 'FONT')
        label_data.body = row['name']; label_data.align_x = 'CENTER'; label_data.size = .105
        label = bpy.data.objects.new(row['stem']+'_ReviewLabel', label_data)
        scene.collection.objects.link(label)
        label.location = (display.location.x, -.70, -.003)
    scene.world = source.world
    floor = next(o for o in source.objects if o.get('part') == 'STUDIO_floor').copy()
    scene.collection.objects.link(floor)
    for light in [o for o in source.objects if o.type == 'LIGHT']:
        clone = light.copy(); scene.collection.objects.link(clone)
    camera = source.camera.copy(); camera.data = source.camera.data.copy()
    scene.collection.objects.link(camera); scene.camera = camera
    target = Vector((0, -.15, 1.0 if family == 'cavalry' else .85))
    direction = Vector((1.5, -15, 5)).normalized()
    camera.location = target+direction*15
    camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    # Blender's AUTO camera fit uses horizontal scale for this 2:1 render.
    camera.data.ortho_scale = 10.8
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = 1800; scene.render.resolution_y = 900
    scene.render.fps = FPS
    scene.display.shading.light = 'STUDIO'; scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True; scene.display.shading.show_cavity = True
    scene.view_settings.view_transform = 'Standard'
    scene.frame_start = 1
    scene.frame_end = LENGTHS[family]['attack' if family == 'warrior' else 'idle']
    scene.frame_set(1)
    scenes.append(scene)

actions = [a for a in bpy.data.actions if a.get('shared_family') and a.name.startswith('Dwarf_')]
assert len(actions) == 18
bpy.data.libraries.write(str(OUT/'dwarf_troops_animation_review.blend'), set(scenes),
    path_remap='RELATIVE', fake_user=True, compress=True)
scene = bpy.data.scenes['Dwarf_Animations_warrior_Review']
bpy.context.window.scene = scene
scene.frame_set(1)
with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
    bpy.ops.object.select_all(action='DESELECT')
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        area.spaces.active.region_3d.view_perspective = 'CAMERA'
        area.spaces.active.region_3d.view_camera_zoom = 8
        area.spaces.active.shading.type = 'SOLID'
        area.spaces.active.shading.color_type = 'TEXTURE'
        area.spaces.active.shading.show_cavity = True
        area.spaces.active.overlay.show_overlays = False
        area.tag_redraw()
scene.render.filepath = str(ROOT/'docs/previews/dwarf_troops/animations/blender_four_warriors.png')
scene.frame_set(1+round(9*FPS/24))
bpy.ops.render.render(write_still=True, scene=scene.name)
scene.frame_set(1)
if not bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_play()
result = dict(status='PASS', classes=6, models=24, action_datablocks=18,
              active_scene=scene.name, playing='attack', saved_review=str(OUT/'dwarf_troops_animation_review.blend'))
