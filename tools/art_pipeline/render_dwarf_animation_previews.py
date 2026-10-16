"""Render actual animated source rigs in the live Blender, preserving studios."""
from pathlib import Path
import bpy
from mathutils import Vector
from dwarf_troop_assets import ASSETS, OUT, WORK
from animate_dwarf_troops import activate
from dwarf_animation_motion import LENGTHS, IMPACT, FPS


def render_family(family, contacts_only=False, tier=2, frame_step=2):
    assert frame_step in (1, 2)
    row = next(r for r in ASSETS if r['family'] == family and r['tier'] == tier)
    scene = bpy.data.scenes[row['stem']+'_MCP_Static_V2']
    rig = next(o for o in scene.objects if o.get('dwarf_animation_owned'))
    camera = scene.camera
    saved = (scene.render.engine, scene.render.resolution_x, scene.render.resolution_y,
             scene.render.resolution_percentage, camera.matrix_world.copy(), camera.data.ortho_scale)
    bpy.context.window.scene = scene
    label = family if tier == 2 else family+'_tier'+str(tier)
    folder = WORK/'animation_frames'/label
    folder.mkdir(parents=True, exist_ok=True)
    with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
        try:
            scene.render.engine = 'BLENDER_WORKBENCH'
            scene.render.resolution_x = scene.render.resolution_y = 560
            scene.render.resolution_percentage = 100
            sh = scene.display.shading
            sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_shadows = True
            sh.show_cavity = True; sh.cavity_type = 'BOTH'; sh.background_type = 'WORLD'
            scene.world.color = (.13, .15, .17)
            for obj in scene.objects:
                if obj.type != 'MESH' or not obj.get('part') or obj['part'].startswith('STUDIO_'): continue
                for material in obj.data.materials:
                    node = next(n for n in material.node_tree.nodes if n.type == 'TEX_IMAGE')
                    material.node_tree.nodes.active = node
            target = Vector((0, -.14, 1.15 if family == 'cavalry' else 1.02 if family == 'siege' else .88))
            direction = Vector((5, -10, 3.6)).normalized()
            camera.location = target+direction*12
            camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
            camera.data.ortho_scale = 3.8 if family == 'cavalry' else 3.25 if family == 'siege' else 2.3
            for clip in ('idle', 'walk', 'attack'):
                activate(scene, rig, clip)
                dest = folder/clip; dest.mkdir(exist_ok=True)
                n = LENGTHS[family][clip]
                frames = list(range(1, n+1, frame_step))
                contacts = [1, 1+round(9*FPS/24), IMPACT[family], min(n, IMPACT[family]+round(6*FPS/24)), n] if clip == 'attack' else [1, 1+(n-1)//4, 1+(n-1)//2, 1+3*(n-1)//4, n]
                frames = sorted(set(contacts if contacts_only else frames+contacts))
                for frame in frames:
                    scene.frame_set(frame); scene.view_layers[0].update()
                    scene.render.filepath = str(dest/f'{frame:04d}.png')
                    bpy.ops.render.render(write_still=True, scene=scene.name)
                print('DWARF_ANIMATION_RENDER '+family+' '+clip, flush=True)
        finally:
            scene.render.engine, scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = saved[:4]
            camera.matrix_world = saved[4]; camera.data.ortho_scale = saved[5]
            activate(scene, rig, 'idle')
