"""Compose the twenty completed elf scenes in the open Blender, using MCP."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPE=ROOT/'tools/art_pipeline'
if str(PIPE) not in sys.path: sys.path.insert(0,str(PIPE))
from elf_troop_assets import ASSETS, OUT, FAMILIES

scene=bpy.data.scenes.new('Elf_Troops_Refined_20_Model_Review')
bpy.context.window.scene=scene
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_cancel(restore_frame=False)
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1400; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
scene.world=bpy.data.worlds.new('Elf_Review_World')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.23,.23,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
model_roots=[]
head_checks=[]
label_material=bpy.data.materials.new('Elf_Review_Label_Material'); label_material.use_nodes=True
label_material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.76,.68,.44,1)
label_material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=1
for index,row in enumerate(ASSETS):
    # Use the exact saved scene, rather than any possibly edited in-memory draft.
    with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,loaded):
        loaded.scenes=[source.scenes[0]]
    source_scene=loaded.scenes[0]
    bpy.context.window.scene=source_scene
    bpy.context.view_layer.update()
    objects=[o for o in source_scene.objects if o.type in ('EMPTY','ARMATURE') or (o.type=='MESH' and o.get('region') not in (None,'studio'))]
    heads=[o for o in objects if o.get('part')=='Head']
    assert len(heads)==1 and len(heads[0].data.vertices)==8 and len(heads[0].data.polygons)==6
    head_parts=[o for o in objects if o.get('rig_bone')=='head' and o.get('region')!='elf_ear']
    closed=heads[0].get('region') in ('greathelm','great_helm')
    if closed or row['source_stem'] in ('swordsman_v1','blade_hero_v1'):
        assert head_parts==heads
    measured=max((o.matrix_world@v.co).z for o in head_parts for v in o.data.vertices)
    if row['family']!='cavalry': assert abs(measured-row['character_height_m'])<.00001,(row['stem'],measured)
    head_checks.append(dict(stem=row['stem'],head_blocks=1,closed_helmet=closed,
                           external_head_parts=[o.get('part') for o in head_parts if o not in heads],
                           standing_height_m=measured if row['family']!='cavalry' else row['character_height_m']))
    bpy.context.window.scene=scene
    collection=bpy.data.collections.new(row['stem']+'_Review'); scene.collection.children.link(collection)
    mapping={}
    for original in objects:
        copy=original.copy()
        if original.type=='ARMATURE': copy.data=original.data.copy()
        collection.objects.link(copy); mapping[original]=copy
    for original,copy in mapping.items():
        if original.parent in mapping: copy.parent=mapping[original.parent]
        for modifier in copy.modifiers:
            if modifier.type=='ARMATURE' and modifier.object in mapping:
                modifier.object=mapping[modifier.object]
        if copy.type=='ARMATURE':
            copy.animation_data.action=None
            copy.animation_data.use_nla=True
            for track in copy.animation_data.nla_tracks:
                track.mute=False
                track.is_solo=False
            for bone in copy.pose.bones: bone.matrix_basis.identity()
    root=next(o for o in mapping.values() if o.type=='EMPTY' and o.parent is None)
    root.location=Vector(((row['tier']-1.5)*2.4,(index//4)*3.8,0))
    root['name_pt']=row['name']; root['family']=row['family']; root['tier']=row['tier']
    model_roots.append(root)
    font=bpy.data.curves.new(row['stem']+'_Label','FONT')
    font.body=row['name']+'\n'+('2 m • Lendário' if row['tier']==3 else '1,80 m')
    font.align_x='CENTER'; font.size=.14
    font.materials.append(label_material)
    text=bpy.data.objects.new(row['stem']+'_Label',font); collection.objects.link(text)
    text.location=(root.location.x,root.location.y-.80,.08)
    text.rotation_euler=(math.pi/2,0,0)
    bpy.data.scenes.remove(source_scene)
floor_data=bpy.data.meshes.new('Elf_Review_Ground')
floor_data.from_pydata([(-18,-10,-.01),(18,-10,-.01),(18,30,-.01),(-18,30,-.01)],[],[(0,1,2,3)])
floor=bpy.data.objects.new('Elf_Review_Ground',floor_data); scene.collection.objects.link(floor)
material=bpy.data.materials.new('Elf_Review_Ground_Material'); material.diffuse_color=(.12,.17,.16,1)
material.use_nodes=True
material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.035,.060,.048,1)
material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=1
floor.data.materials.append(material)
for name,at,power,size in [('Key',(-8,-8,15),4500,15),('Fill',(10,4,14),3500,12),('Back',(-5,20,12),2500,10)]:
    data=bpy.data.lights.new('Elf_Review_'+name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    light=bpy.data.objects.new(data.name,data); scene.collection.objects.link(light); light.location=at
    light.rotation_euler=(Vector((0,7,1))-light.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Elf_Review_Camera'); camera_data.type='ORTHO'; camera_data.ortho_scale=22
camera=bpy.data.objects.new('Elf_Review_Camera',camera_data); scene.collection.objects.link(camera)
target=Vector((0,7.6,1)); camera.location=(13,-18,21)
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera=camera
scene.frame_set(1)
scene.frame_start=1
scene.frame_end=round(max(strip.frame_end for o in scene.objects if o.type=='ARMATURE' for track in o.animation_data.nla_tracks for strip in track.strips))
scene['description']='Refined elves: mirrored eyes, single-block closed helmets, practical elven fabrics/armor and legendary gold; five classes, four evolutions.'
(ROOT/'docs/elf_troops_head_blender_validation.json').write_text(json.dumps(dict(status='PASS',verified=len(head_checks),assets=head_checks),indent=2),encoding='utf-8')
scene.render.filepath=str(ROOT/'docs/previews/elf_troops/blender_roster.png')
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(OUT/'elf_troops_review.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
model_roots[0].select_set(True); bpy.context.view_layer.objects.active=model_roots[0]
result=dict(scene=scene.name,models=len(model_roots),saved=str(OUT/'elf_troops_review.blend'),pipeline='Open Blender MCP')
