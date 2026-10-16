"""Build a blocky mulberry bush with silk cocoons through live Blender MCP."""
import bpy
import bmesh
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/resources/silk/silk_mulberry_v1'
STEM='silk_mulberry_v1'
assert not (OUT/(STEM+'.glb')).exists(), 'Preserve existing asset.'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'previews').mkdir(exist_ok=True)
previous_scenes=[s.name for s in bpy.data.scenes]
scene=bpy.data.scenes.new('Silk_Resource_V1'); bpy.context.window.scene=scene
root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
root['resource_id']='silk'; root['tile_radius']=1.0

# Bark and foliage echo the forest kit. Ivory woven cocoons provide the
# distinctive resource silhouette rather than generic flowers or fruit.
palette=[(83,56,34),(130,91,48),(44,83,39),(65,111,44),(92,138,57),
         (177,158,111),(224,213,172),(246,240,212),(103,143,62)]
size,cell=256,64
pixels=np.ones((size,size,4),dtype=np.float32); pixels[:,:,:3]=(.18,.26,.12)
for region,color in enumerate(palette):
    rng=np.random.default_rng(141026+region); yy,xx=np.mgrid[:cell,:cell]
    tile=np.zeros((cell,cell,3)); tile[:]=color
    tile+=rng.integers(-6,7,(32,32)).repeat(2,0).repeat(2,1)[:,:,None]
    if region in (0,1):
        tile[((xx//2*19+yy//15*7)%23)<3]-=16
        tile[(xx%13==2)&(yy%23<16)]+=9
    elif region in (2,3,4,8):
        tile[((xx//4*13+yy//4*23)%37)<5]+=12
        tile[((xx//3*11+yy//3*17)%41)<4]-=11
    else:
        # Fine silk wrapping, visible as short bands on the capsule bodies.
        tile[(yy%4==0)&(xx%7<5)]-=9
        tile[(yy%4==1)&(xx%5<3)]+=5
        tile[(xx%6==0)&(yy%9<6)]-=4
    pixels[(region//4)*cell:(region//4+1)*cell,
           (region%4)*cell:(region%4+1)*cell,:3]=np.clip(tile/255,0,1)
image=bpy.data.images.new(STEM+'_albedo',size,size,alpha=False)
image.pixels.foreach_set(pixels.ravel()); image.filepath_raw=str(OUT/(STEM+'_albedo.png'))
image.file_format='PNG'; image.save(); image.pack()
material=bpy.data.materials.new(STEM+'_Pixel_Material'); material.use_nodes=True
material.use_backface_culling=True
bsdf=material.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value=.92
bsdf.inputs['Specular IOR Level'].default_value=.18
texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image
texture.interpolation='Closest'; material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])

vertices,faces,regions,parts=[],[],[],[]
def add_part(name,verts,polys,paints):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],polys); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>1e-10,name
    bm.to_mesh(data); bm.free(); offset=len(vertices)
    vertices.extend(tuple(v.co) for v in data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in data.polygons)
    regions.extend(paints); parts.append(name); bpy.data.meshes.remove(data)

def block(name,x0,x1,y0,y1,z0,z1,leaf=False):
    verts=[(x,y,z) for z in (z0,z1) for x,y in [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]]
    polys=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    paints=[2,4,3,2,3,4] if leaf else [0,1,1,0,0,1]
    add_part(name,verts,polys,paints)

block('Trunk',-.045,.045,-.04,.04,0,.35)
block('Root_left',-.14,-.035,-.035,.035,0,.045)
block('Root_right',.035,.13,-.035,.035,0,.04)
block('Root_front',-.035,.035,-.13,-.03,0,.035)
block('Left_branch',-.22,-.035,-.025,.025,.19,.245)
block('Right_branch',.035,.23,-.025,.025,.235,.285)
block('Front_branch',-.025,.025,-.24,-.015,.18,.23)
block('Main_leaves',-.19,.19,-.16,.16,.28,.52,True)
block('Crown_leaves',-.13,.13,-.12,.13,.52,.64,True)
block('Left_leaves',-.35,-.08,-.13,.13,.22,.43,True)
block('Right_leaves',.10,.33,-.08,.19,.30,.50,True)
block('Front_leaves',-.13,.20,-.30,-.10,.21,.41,True)
block('Rear_leaves',-.15,.14,.12,.29,.32,.52,True)

def cocoon(name,x,y,z,width,depth,height,horizontal=False):
    # A closed stepped capsule with square cross section, no round bevels.
    verts=[]
    for level,factor in [(0,.60),(.15,.60),(.15,1),(.85,1),(.85,.60),(1,.60)]:
        for dx,dy in [(-width,-depth),(width,-depth),(width,depth),(-width,depth)]:
            point=Vector((dx*factor,dy*factor,height*(level-.5)))
            if horizontal: point=Matrix.Rotation(math.pi/2,3,'Y')@point
            verts.append(tuple(point+Vector((x,y,z))))
    polys=[(3,2,1,0),(20,21,22,23)]; paints=[5,7]
    for ring in range(5):
        for i in range(4):
            j=(i+1)%4
            polys.append((ring*4+i,ring*4+j,(ring+1)*4+j,(ring+1)*4+i))
            paints.append([6,5,6,7][i] if ring==2 else 6)
    add_part(name,verts,polys,paints)

cocoon('Front_cocoon_left',-.065,-.313,.29,.037,.029,.14)
cocoon('Front_cocoon_right',.125,-.311,.335,.034,.029,.13)
cocoon('Left_cocoon',-.36,-.045,.31,.028,.034,.14)
cocoon('Right_cocoon',.339,.075,.405,.029,.034,.14)
cocoon('Upper_front_cocoon',-.015,-.168,.485,.034,.029,.14)
cocoon('Rear_cocoon',-.08,.30,.435,.034,.028,.13)
cocoon('Crown_cocoon',.015,.005,.653,.027,.033,.15,True)

data=bpy.data.meshes.new(STEM+'_Mesh'); data.from_pydata(vertices,[],faces); data.update()
obj=bpy.data.objects.new('Silk_Mulberry',data); scene.collection.objects.link(obj)
obj.parent=root; data.materials.append(material)
uv=data.uv_layers.new(name='Pixel_Atlas')
for face,region in zip(data.polygons,regions):
    face.use_smooth=False; axis=max(range(3),key=lambda j:abs(face.normal[j]))
    axes=[j for j in range(3) if j!=axis]
    coords=[Vector((data.vertices[data.loops[i].vertex_index].co[axes[0]],
                    data.vertices[data.loops[i].vertex_index].co[axes[1]])) for i in face.loop_indices]
    lower=Vector((min(c.x for c in coords),min(c.y for c in coords)))
    for index,coord in zip(face.loop_indices,coords):
        local=(coord-lower)*64; assert max(local)<56
        uv.data[index].uv=Vector(((region%4)*cell+4+local.x,(region//4)*cell+4+local.y))/size
data.calc_loop_triangles(); bm=bmesh.new(); bm.from_mesh(data)
assert all(e.is_manifold for e in bm.edges)
assert all(p.area>1e-10 for p in data.polygons)
bm.free()
radius=max(math.hypot(v.co.x,v.co.y) for v in data.vertices)
assert radius<.46
height=max(v.co.z for v in data.vertices); assert abs(height-.68)<1e-6
report=dict(asset=STEM,resource='silk',method='live Blender MCP',
    vertices=len(data.vertices),triangles=len(data.loop_triangles),cocoons=7,
    foliage_clusters=6,footprint_radius=radius,height=.68,
    materials=1,texture_size=[size,size],texture_filter='nearest',
    style='cuboid foliage and stepped silk capsules',closed_components=True,
    previous_scenes=previous_scenes)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for item in scene.objects: item.select_set(False)
root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
    use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
    export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')

world=bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.29,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.6
for name,position,power,scale in [('Key',(2,-3,4),240,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
    ld=bpy.data.lights.new(name,'AREA'); ld.energy=power; ld.shape='DISK'; ld.size=scale
    light=bpy.data.objects.new(name,ld); scene.collection.objects.link(light); light.location=position
    light.rotation_euler=(Vector((0,0,.28))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
camera=bpy.data.objects.new('Silk_Preview_Camera',cd); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=800; scene.render.resolution_y=800; scene.render.resolution_percentage=100
scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
for view,position,scale,aim in [('three_quarter',(1.8,-2.6,1.85),1.3,(0,0,.31)),
                              ('game_top',(1.8,-2.9,4.9),2.0,(0,0,.15)),
                              ('top',(0,0,5),1.2,(0,0,0))]:
    camera.location=position; cd.ortho_scale=scale
    camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(1.8,-2.6,1.85); cd.ortho_scale=1.3
camera.rotation_euler=(Vector((0,0,.31))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert set(previous_scenes).issubset({s.name for s in bpy.data.scenes})
result=report
