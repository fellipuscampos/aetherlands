"""Compose the four completed elven machines in the open Blender through MCP."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
if str(ROOT/'tools/art_pipeline') not in sys.path: sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from elf_siege_assets import SIEGE_ASSETS, OUT

if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
preview=ROOT/'docs/previews/elf_siege'; preview.mkdir(parents=True,exist_ok=True)
# Inspect the legendary machine's real attack, with textured rendered frames.
row=SIEGE_ASSETS[-1]
with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,loaded): loaded.scenes=source.scenes
colossus=loaded.scenes[0]; bpy.context.window.scene=colossus
rig=next(o for o in colossus.objects if o.type=='ARMATURE')
for track in rig.animation_data.nla_tracks: track.is_solo=track.name.endswith('_Attack')
colossus.render.resolution_x=384; colossus.render.resolution_y=384
colossus.camera.data.ortho_scale+=.65
for frame in (115,130,142,162):
    colossus.frame_set(frame)
    colossus.render.filepath=str(preview/('colossus_attack_'+str(frame)+'.png'))
    bpy.ops.render.render(write_still=True)

scene=bpy.data.scenes.new('Elf_Siege_Four_Evolutions_Animated_Review')
bpy.context.window.scene=scene
scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=1700; scene.render.resolution_y=680
scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
scene.render.fps=24; scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
scene.world=bpy.data.worlds.new('ElfSiegeReviewWorld'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.17,.21,.20,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
roots=[]; rigs=[]
labelmat=bpy.data.materials.new('ElfSiegeLabels'); labelmat.use_nodes=True
labelmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.7,.68,.49,1)
for row in SIEGE_ASSETS:
    with bpy.data.libraries.load(str(OUT/row['stem']/(row['stem']+'.blend')),link=False) as (source,loaded): loaded.scenes=source.scenes
    original_scene=loaded.scenes[0]
    collection=bpy.data.collections.new(row['stem']+'_Review'); scene.collection.children.link(collection)
    objects=[o for o in original_scene.objects if o.type in ('EMPTY','ARMATURE') or o.get('part')]
    mapping={}
    for original in objects:
        copy=original.copy()
        if original.type=='ARMATURE': copy.data=original.data.copy()
        collection.objects.link(copy); mapping[original]=copy
    for original,copy in mapping.items():
        if original.parent in mapping: copy.parent=mapping[original.parent]
        for modifier in copy.modifiers:
            if modifier.type=='ARMATURE' and modifier.object in mapping: modifier.object=mapping[modifier.object]
        if copy.type=='ARMATURE':
            copy.animation_data.action=None; copy.animation_data.use_nla=True
            for track in copy.animation_data.nla_tracks: track.mute=False; track.is_solo=False
            rigs.append(copy)
    root=next(o for o in mapping.values() if o.type=='EMPTY' and o.parent is None)
    root.location=((row['tier']-1.5)*3.2,0,0); roots.append(root)
    curve=bpy.data.curves.new(row['stem']+'_Label','FONT'); curve.body=row['name']
    curve.align_x='CENTER'; curve.size=.17; curve.materials.append(labelmat)
    label=bpy.data.objects.new(row['stem']+'_Label',curve); collection.objects.link(label)
    label.location=(root.location.x,-1.60,.08); label.rotation_euler=(math.pi/2,0,0)
    bpy.data.scenes.remove(original_scene)
ground_data=bpy.data.meshes.new('ElfSiegeReviewGround')
ground_data.from_pydata([(-20,-20,-.01),(20,-20,-.01),(20,20,-.01),(-20,20,-.01)],[],[(0,1,2,3)])
ground=bpy.data.objects.new(ground_data.name,ground_data); scene.collection.objects.link(ground)
material=bpy.data.materials.new('ElfSiegeReviewGroundMaterial'); material.use_nodes=True
material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.085,.12,.10,1)
material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1; ground.data.materials.append(material)
for name,at,power,size in [('Key',(-5,-6,10),2700,10),('Fill',(7,-2,8),1700,8),('Rim',(0,6,9),2300,8)]:
    data=bpy.data.lights.new('ElfSiegeReview_'+name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    light=bpy.data.objects.new(data.name,data); scene.collection.objects.link(light); light.location=at
    light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ElfSiegeReviewCamera'); data.type='ORTHO'; data.ortho_scale=13.8
camera=bpy.data.objects.new(data.name,data); scene.collection.objects.link(camera); scene.camera=camera
camera.location=(5,-18,11); camera.rotation_euler=(Vector((0,0,.75))-camera.location).to_track_quat('-Z','Y').to_euler()
for name,frame in [('Idle',1),('Walk',58),('Attack',115),('DemolitionAmmo',172),('PreparedBombardment',253)]: scene.timeline_markers.new(name,frame=frame)
scene.frame_start=1; scene.frame_end=349; scene.frame_set(1)
scene.render.filepath=str(preview/'blender_review.png'); bpy.ops.render.render(write_still=True)
scene.use_preview_range=True; scene.frame_preview_start=115; scene.frame_preview_end=162; scene.frame_set(115)
scene['description']='Elven siege: pale ash mangonel, counterweight trebuchet, bronze bombard and six-wheel great torsion ballista. 19 clips; preview Attack.'
scene['preview_instructions']='Space to play/pause. Disable Preview Range to see all clips. Markers: Idle 1, Walk 58, Attack 115, DemolitionAmmo 172, PreparedBombardment 253.'
path=OUT/'elf_siege_review.blend'; bpy.data.libraries.write(str(path),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.object.select_all(action='DESELECT')
roots[-1].select_set(True); bpy.context.view_layer.objects.active=roots[-1]
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.type='MATERIAL'; area.spaces.active.overlay.show_overlays=False
# Verify the review's actual rig mapping: each machine must visibly fire.
poses=[]
for frame in (115,142):
    scene.frame_set(frame); bpy.context.view_layer.update()
    poses.append({rig.name:[value for bone in rig.pose.bones for row in bone.matrix for value in row] for rig in rigs})
movement={rig.name:max(abs(a-b) for a,b in zip(poses[0][rig.name],poses[1][rig.name])) for rig in rigs}
assert min(movement.values())>.1,movement
report=dict(status='PASS',models=len(rigs),clips=sum(len(rig.animation_data.nla_tracks) for rig in rigs),
            review_movement=movement,saved=str(path.relative_to(ROOT)),scene=scene.name)
(ROOT/'docs/elf_siege_blender_review_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.frame_set(115); bpy.ops.screen.animation_play()
result=report
