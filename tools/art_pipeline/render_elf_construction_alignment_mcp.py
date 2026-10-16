"""Preview the unplated site against the virtual pointy-top map tile."""
import bpy,math
from mathutils import Vector
a=bpy.app.driver_namespace['elf_construction_v1']; scene=a['scene']; studio=a['studio']
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
scene.frame_set(1)
name='Elf_Construction_Map_Tile_Outline_Preview'
outline=scene.objects.get(name)
if outline is None:
    vertices=[(r*math.cos(-math.pi/6+i*math.tau/6),r*math.sin(-math.pi/6+i*math.tau/6),.003) for r in (.989,1.009) for i in range(6)]
    faces=[(i,i+6,(i+1)%6+6,(i+1)%6) for i in range(6)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    outline=bpy.data.objects.new(name,mesh); studio.objects.link(outline); outline['preview_only']=True
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Base Color'].default_value=(.015,.36,.49,1); bsdf.inputs['Roughness'].default_value=1
    mesh.materials.append(mat)
camera=scene.camera; old=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale)
outline.hide_render=False; outline.hide_set(False)
camera.location=(0,0,7); camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.ortho_scale=2.35
scene.render.filepath=str(a['out']/'previews/hex_alignment.png'); bpy.ops.render.render(write_still=True)
outline.hide_render=True; outline.hide_set(True)
camera.location,camera.rotation_euler,camera.data.ortho_scale=old
bpy.data.libraries.write(str(a['out']/(a['out'].name+'.blend')),{scene},fake_user=True,compress=True)
result={'status':'PASS','reference':'Map tile radius 1; corners -30 + i*60 degrees','reserved_footprint_radius':.9,'ground_plate':False,'reference_exported':False}
