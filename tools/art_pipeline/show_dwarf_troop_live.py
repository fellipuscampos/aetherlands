"""Leave the large one-handed maul visible in the actual Blender viewport."""
import bpy

scene=bpy.data.scenes['dwarf_blade_hero_v1_MCP_Static_V2']
bpy.context.window.scene=scene
for area in bpy.context.window.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active
        space.shading.type='MATERIAL'
        space.shading.use_scene_lights=True
        space.shading.use_scene_world=True
        space.overlay.show_overlays=False
        space.region_3d.view_perspective='CAMERA'
        space.region_3d.view_camera_zoom=10
result={'scene':scene.name,'visible_model':'dwarf_blade_hero_v1','shading':'material','mcp':'live'}
