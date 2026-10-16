"""Blender-only context check: real terrain albedos and the game's fixed 50 degree camera pitch."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/monster_lairs_v2'
original=bpy.context.window.scene
with bpy.data.libraries.load(str(OUT/'monster_lairs_v2_catalog.blend'),link=False) as (src,dst):
    dst.scenes=list(src.scenes)
scene=dst.scenes[0]; scene.name='Lairs_V2_Map_Readability'

def terrain_mat(kind):
    material=bpy.data.materials.new('REVIEW_ONLY_terrain_'+kind); material.use_nodes=True
    shader=material.node_tree.nodes['Principled BSDF']; shader.inputs['Roughness'].default_value=.98
    shader.inputs['Specular IOR Level'].default_value=.10
    image=bpy.data.images.load(str(ROOT/'assets/textures/terrain/pixel_v1'/(kind+'_albedo.png')),check_existing=False)
    image.pack()
    texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image; texture.interpolation='Closest'
    material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
    return material

try:
    bpy.context.window.scene=scene
    collection=bpy.data.collections.new('REVIEW_ONLY_hex_terrain'); scene.collection.children.link(collection)
    mats={name:terrain_mat(name) for name in ('grass','sand','forest_floor','dry_grass')}
    roots=[ob for ob in scene.objects if ob.type=='EMPTY' and 'monster_kind' in ob]
    assert len(roots)==12
    for root in roots:
        kind=root['monster_kind']; x,y,z=root.location
        terrain='sand' if kind in ('basilisk','colossal_worm','skeleton') else ('forest_floor' if kind in ('giant_spider','arboreal_ancient','worg') else 'grass')
        if kind in ('minotaur','mana_devourer'): terrain='dry_grass'
        verts=[]
        for height in (-.035,-.001):
            for i in range(6):
                a=math.radians(60*i-30)
                verts.append((x+math.cos(a),y+math.sin(a),height))
        faces=[(5,4,3,2,1,0),(6,7,8,9,10,11)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        mesh=bpy.data.meshes.new('Review_hex_'+kind); mesh.from_pydata(verts,[],faces); mesh.update(); mesh.materials.append(mats[terrain])
        uv=mesh.uv_layers.new(name='TerrainUV')
        for p in mesh.polygons:
            for li in p.loop_indices:
                v=mesh.vertices[mesh.loops[li].vertex_index].co
                uv.data[li].uv=((v.x-x)/2+.5,(v.y-y)/2+.5)
        ob=bpy.data.objects.new('REVIEW_ONLY_hex_'+kind,mesh); collection.objects.link(ob)
    for ob in scene.objects:
        if ob.type=='LIGHT': ob.data.energy=0
    sun=bpy.data.lights.new('REVIEW_ONLY_daylight','SUN'); sun.energy=1.7; sun.angle=math.radians(8)
    ob=bpy.data.objects.new('REVIEW_ONLY_daylight',sun); scene.collection.objects.link(ob)
    ob.rotation_euler=(math.radians(26),math.radians(-24),math.radians(-28))
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    camera=scene.camera; pitch=math.radians(50)
    target=Vector((0,0,.18))
    camera.location=target+Vector((0,-14*math.cos(pitch),14*math.sin(pitch)))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=10.7
    scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED'; scene.render.threads=4
    scene.render.resolution_x=1800; scene.render.resolution_y=1400; scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/'map_readability.png')
    scene['review_note']='Blender context render only. Real terrain albedos; camera pitch 50deg; orthographic approximation of distant game perspective. No Godot integration.'
    bpy.ops.render.render(write_still=True,scene=scene.name)
    bpy.data.libraries.write(str(OUT/'map_readability.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    result=dict(status='PASS',models=len(roots),camera_pitch=50,terrain='Existing project albedos',godot_started=False)
finally:
    bpy.context.window.scene=original
