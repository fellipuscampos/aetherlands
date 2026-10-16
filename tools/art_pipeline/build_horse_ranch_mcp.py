"""A shared horse paddock and open shelter, built through live Blender MCP.

Preserve the approved horse geometry and painted coat in a single atlas.
Create an isolated scene and restore the active Blender scene after export.
"""
import bpy
import bmesh
import math
import json
import hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = 'horse_ranch_v1'
OUT = ROOT / 'assets/generated/improvements' / STEM
assert not (OUT / (STEM + '.glb')).exists() or bool(globals().get('REBUILD_HORSE_RANCH_V1', False)), 'Do not overwrite an existing export without an explicit rebuild.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = set(bpy.data.scenes)
scene = bpy.data.scenes.new('Horse_Ranch_V1_Shared')
bpy.context.window.scene = scene

try:
    palette = {
        'earth_side': (66,55,43), 'earth_top': (99,79,53),
        'rock_dark': (67,65,76), 'rock_side': (91,85,102), 'rock_top': (121,111,129), 'tunnel': (35,32,41),
        'wood_dark': (67,46,32), 'wood': (112,78,47), 'wood_top': (151,111,67),
        'wood_end': (133,94,56), 'iron_dark': (39,46,52), 'iron': (87,99,105),
        'copper': (137,101,64), 'rope': (152,131,88),
        'hay': (168,133,57), 'hay_light': (195,161,76),
        'thatch': (125,98,51), 'thatch_top': (165,134,69),
        'grass': (88,103,46), 'grass_light': (106,117,54),
    }
    width,height,cell = 1024,512,64
    pixels = np.ones((height,width,4),dtype=np.float32)
    pixels[:,:,:3] = (.08,.10,.12)

    slots = {}
    yy,xx = np.mgrid[:cell,:cell]
    for index,(name,color) in enumerate(palette.items()):
        tx,ty = index%8,index//8
        slots[name] = (tx,ty)
        rng = np.random.default_rng(151026+index)
        paint = np.empty((cell,cell,3)); paint[:] = color
        paint += rng.integers(-7,8,(32,32)).repeat(2,0).repeat(2,1)[:,:,None]
        if name.startswith('wood'):
            paint[((xx//2 + yy//17) % 13 == 0)] -= 16
            paint[(yy%23<2)&(xx%17<10)] += 9
            if name=='wood_end': paint[((xx-30)**2+(yy-30)**2)//45%5==0] -= 9
        elif name.startswith('rock') or name.startswith('earth'):
            paint[((xx//4*13+yy//3*7)%29)<3] -= 13
            paint[((xx//3*11+yy//5*19)%47)<3] += 10
        elif name.startswith('hay') or name.startswith('thatch'):
            paint[(yy%9<2)&(xx%11<9)] -= 19
            paint[(xx%19<2)&(yy%7<5)] += 11
        elif name=='copper': paint[(yy%27<2)&(xx%21<12)] += 13
        elif name=='rope': paint[(xx+yy)%7<2] -= 17
        x,y = tx*cell,ty*cell
        pixels[y:y+cell,x:x+cell,:3] = np.clip(paint/255,0,1)


    def image_file(suffix, values):
        image = bpy.data.images.new(STEM+suffix,width,height,alpha=False)
        image.colorspace_settings.name='sRGB'
        image.pixels.foreach_set(values.ravel())
        image.filepath_raw=str(OUT/(STEM+suffix+'.png'))
        image.file_format='PNG'; image.save(); image.pack()
        return image

    material=bpy.data.materials.new(STEM+'_Pixel_Atlas')
    material.use_nodes=True; material.use_backface_culling=True
    bsdf=material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value=.83
    bsdf.inputs['Specular IOR Level'].default_value=.18
    source_path=ROOT/'assets/generated/resources/horses/horse_resource_v1/horse_resource_v1.blend'
    source_hash=hashlib.sha256(source_path.read_bytes()).hexdigest()
    with bpy.data.libraries.load(str(source_path),link=False) as (available,loaded):
        loaded.objects=[name for name in available.objects if name.startswith('horse_resource_v1_Horse')]
    horse_parts=sorted(loaded.objects,key=lambda obj:obj.name)
    assert len(horse_parts)==19
    source_image=next(n.image for n in horse_parts[0].data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
    assert tuple(source_image.size)==(512,512)
    source_pixels=np.empty(512*512*4,dtype=np.float32)
    source_image.pixels.foreach_get(source_pixels)
    source_pixels=source_pixels.reshape(512,512,4)
    pixels[:,512:,:]=source_pixels
    assert np.array_equal(pixels[:,512:,:],source_pixels)
    tex=material.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=image_file('_albedo',pixels); tex.interpolation='Closest'
    material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

    vertices,faces,face_uvs,parts=[],[],[],[]
    BOX_FACES=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    PAINTS={
        'earth':['earth_side','earth_top','earth_side','earth_side','earth_side','earth_side'],
        'rock':['rock_dark','rock_top','rock_side','rock_dark','rock_side','rock_side'],
        'wood':['wood_dark','wood_top','wood','wood_end','wood','wood_end'],
        'iron':['iron_dark','iron','iron','iron_dark','iron','iron'],
        'copper':['iron_dark','copper','copper','copper','copper','copper'],
        'rope':['rope']*6,'tunnel':['tunnel']*6,
        'hay':['hay']*6,'thatch':['thatch','thatch_top','thatch','thatch','thatch','thatch'],
        'grass':['grass','grass_light','grass','grass','grass','grass'],
    }

    def part(name,verts,polys,paints):
        offset=len(vertices)
        vertices.extend(tuple(v) for v in verts)
        for poly,paint in zip(polys,paints):
            faces.append(tuple(offset+i for i in poly))
            points=[Vector(verts[i]) for i in poly]
            normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
            axis=max(range(3),key=lambda i:abs(normal[i]))
            axes=[(1,2),(0,2),(0,1)][axis]
            coords=[Vector((p[axes[0]],p[axes[1]])) for p in points]
            low=Vector((min(p.x for p in coords),min(p.y for p in coords)))
            uvcoords=[]
            for coord in coords:
                local=(coord-low)*44
                assert max(local)<56,(name,local)
                pixel_coord=Vector(slots[paint])*cell+Vector((4,4))+local
                uvcoords.append((pixel_coord.x/width,pixel_coord.y/height))
            face_uvs.append(uvcoords)
        parts.append({'name':name,'vertices':len(verts),'faces':len(polys)})

    def box(name,center,extent,paint='wood',angle=0):
        cx,cy,cz=center; sx,sy,sz=extent
        verts=[]
        for z in (-sz/2,sz/2):
            for x,y in [(-sx/2,-sy/2),(sx/2,-sy/2),(sx/2,sy/2),(-sx/2,sy/2)]:
                verts.append((cx+x*math.cos(angle)-y*math.sin(angle),cy+x*math.sin(angle)+y*math.cos(angle),cz+z))
        part(name,verts,BOX_FACES,PAINTS[paint])

    def beam(name,a,b,width,depth,paint='wood'):
        a,b=Vector(a),Vector(b)
        axis=(b-a).normalized()
        guide=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))
        u=axis.cross(guide).normalized()*width/2
        v=axis.cross(u).normalized()*depth/2
        verts=[tuple(p+du*u+dv*v) for p in (a,b) for du,dv in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        part(name,verts,BOX_FACES,PAINTS[paint])

    outline=[(-.59,-.42),(-.36,-.61),(.37,-.58),(.62,-.26),(.60,.38),(.33,.60),(-.40,.58),(-.62,.25)]
    verts=[(x,y,z) for z in (0,.035) for x,y in outline]
    polys=[tuple(reversed(range(8))),tuple(range(8,16))]
    polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    part('Paddock_earth',verts,polys,['earth_side','earth_top']+['earth_side']*8)
    box('Pasture_patch_left',(-.23,-.12,.038),(.43,.53,.006),'grass')
    box('Pasture_patch_right',(.24,.18,.038),(.35,.41,.006),'grass')

    # Low rails leave the animals readable; two shelter posts also support fencing.
    posts=[(-.55,-.48),(-.18,-.50),(.18,-.50),(.55,-.48),(.55,.04),(.55,.51),(.02,.51)]
    for i,(x,y) in enumerate(posts):
        box('Fence_post_'+str(i),(x,y,.18),(.048,.048,.29),'wood')
    segments=[((-.55,-.48),(-.55,.06)),((-.55,.06),(-.55,.51)),
              ((-.55,.51),(.02,.51)),((.02,.51),(.55,.51)),
              ((.55,.51),(.55,.04)),((.55,.04),(.55,-.48)),
              ((-.55,-.48),(-.18,-.50)),((.18,-.50),(.55,-.48))]
    for i,(a,b) in enumerate(segments):
        for z in (.13,.265):
            beam('Fence_rail_'+str((i,z)),(*a,z),(*b,z),.025,.035)
    # Inward-open entrance gate with a clear central path.
    ga,gb=Vector((-.18,-.50,0)),Vector((-.085,-.35,0))
    for z in (.13,.265):
        beam('Open_gate_rail_'+str(z),ga+Vector((0,0,z)),gb+Vector((0,0,z)),.025,.035)
    box('Gate_end',(*gb.xy,.20),(.035,.035,.20),'wood')
    beam('Gate_diagonal',ga+Vector((0,0,.13)),gb+Vector((0,0,.265)),.018,.022)
    box('Gate_hinge',(-.18,-.50,.20),(.055,.055,.025),'iron')

    # Open front and sides; lean-to roof stays behind the visible horses.
    for x in (-.55,-.07):
        box('Shelter_front_post_'+str(x),(x,.06,.34),(.055,.055,.61),'wood')
        box('Shelter_back_post_'+str(x),(x,.51,.30),(.055,.055,.53),'wood')
    box('Shelter_front_beam',(-.31,.06,.65),(.56,.065,.07),'wood')
    box('Shelter_back_beam',(-.31,.51,.58),(.56,.065,.07),'wood')
    for x in (-.55,-.07):
        beam('Shelter_side_beam_'+str(x),(x,.03,.675),(x,.54,.588),.045,.05)
        beam('Shelter_brace_'+str(x),(x,.06,.45),(x,.23,.62),.026,.034)
    for i,x in enumerate((-.532,-.421,-.310,-.199,-.088)):
        beam('Straw_roof_panel_'+str(i),(x,.02,.69),(x,.55,.60),.108,.045,'thatch')
    for i,(x,y,z,extent) in enumerate([(-.36,.34,.13,(.24,.24,.19)),(-.17,.37,.095,(.12,.19,.12))]):
        box('Hay_bale_'+str(i),(x,y,z),extent,'hay')
        for side in (-1,1):
            box('Hay_binding_'+str((i,side)),(x+side*extent[0]*.27,y,z+extent[2]/2+.003),(.009,extent[1],.009),'rope')

    # Feed trough: a dry bed of hay, low enough for the animals.
    box('Trough_bottom',(.405,-.285,.085),(.215,.25,.035),'wood')
    for side in (-1,1):
        box('Trough_side_'+str(side),(.405+side*.097,-.285,.14),(.021,.25,.11),'wood')
        box('Trough_end_'+str(side),(.405,-.285+side*.114,.14),(.174,.022,.11),'wood')
    box('Trough_hay',(.405,-.285,.125),(.17,.20,.055),'hay')

    def horse(name,base,scale,angle):
        # Copy every source vertex and UV. Repack only the atlas coordinates.
        for source in horse_parts:
            offset=len(vertices)
            for vertex in source.data.vertices:
                x,y,z=vertex.co*scale
                vertices.append((base[0]+x*math.cos(angle)-y*math.sin(angle),
                                 base[1]+x*math.sin(angle)+y*math.cos(angle),base[2]+z))
            for poly in source.data.polygons:
                faces.append(tuple(offset+i for i in poly.vertices))
                face_uvs.append(tuple(((source.data.uv_layers.active.data[i].uv.x*512+512)/width,
                                       source.data.uv_layers.active.data[i].uv.y*512/height) for i in poly.loop_indices))
            parts.append({'name':name+'_'+source['source_part'],'vertices':len(source.data.vertices),'faces':len(source.data.polygons)})
    horse('Horse_foreground',(-.23,-.16,.041),.74,0)
    horse('Horse_right',(.27,.16,.041),.76,-.35)

    data=bpy.data.meshes.new(STEM+'_Mesh')
    data.from_pydata(vertices,[],faces); data.update()
    uv=data.uv_layers.new(name='PixelAtlas')
    for face,coords in zip(data.polygons,face_uvs):
        for i,coord in zip(face.loop_indices,coords): uv.data[i].uv=coord
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),'Each independently modeled solid must be closed.'
    bm.to_mesh(data); bm.free(); data.update(); data.calc_loop_triangles()
    assert all(p.area>1e-10 for p in data.polygons)
    radius=max(math.hypot(v.co.x,v.co.y) for v in data.vertices)
    model_height=max(v.co.z for v in data.vertices)
    assert radius<.83,(radius,model_height)
    assert model_height<.85,(radius,model_height)
    assert min(v.co.z for v in data.vertices)>-.000001
    assert len(data.loop_triangles)<1600,len(data.loop_triangles)
    root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
    root['improvement_id']='v2_improvement_horse_ranch'
    root['resource_id']='horses'; root['shared_civilizations']='human,elf,orc,dwarf'
    obj=bpy.data.objects.new(STEM+'_Paddock_and_Horses',data)
    scene.collection.objects.link(obj); obj.parent=root; data.materials.append(material)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    assert hashlib.sha256(source_path.read_bytes()).hexdigest()==source_hash
    report=dict(asset=STEM,improvement='v2_improvement_horse_ranch',resource='horses',
        method='live Blender MCP localhost:9876',source_asset=str(source_path.relative_to(ROOT)),
        source_sha256=source_hash,source_geometry_preserved=True,source_painted_pixels_preserved=True,
        horse_count=2,horse_scales=[.74,.76],source_parts_per_horse=19,
        concept='Fenced horse paddock, open timber shelter, feed trough and hay bales',
        materials=1,meshes=1,vertices=len(data.vertices),triangles=len(data.loop_triangles),
        footprint_radius=radius,height=model_height,ground_origin=True,closed_components=True,
        texture_size=[width,height],texture_filter='nearest',animations=0,lights=0,
        shared_civilizations=['human','elf','orc','dwarf'],parts=parts)
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    world=bpy.data.worlds.new(STEM+'_Studio'); scene.world=world; world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.20,.24,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.55
    for name,pos,power,area in [('Key',(2,-3,4),220,3),('Fill',(-3,-1,2),110,3),('Rim',(1,3,3),170,2)]:
        light_data=bpy.data.lights.new(STEM+'_'+name,'AREA'); light_data.energy=power; light_data.size=area
        light=bpy.data.objects.new(light_data.name,light_data); scene.collection.objects.link(light)
        light.location=pos; light.rotation_euler=(Vector((0,0,.3))-light.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new(STEM+'_Camera'); cd.type='ORTHO'
    camera=bpy.data.objects.new(cd.name,cd); scene.collection.objects.link(camera); scene.camera=camera
    scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
    scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
    scene.render.film_transparent=True; scene.view_settings.view_transform='Standard'
    for name,pos,extent,aim in [('three_quarter',(2,-3,2.1),1.85,(0,0,.29)),
                              ('game_top',(1.8,-2.9,4.9),1.95,(0,0,.14)),
                              ('top',(0,0,5),1.65,(0,0,0))]:
        camera.location=pos; cd.ortho_scale=extent
        camera.rotation_euler=(Vector(aim)-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'previews'/(name+'.png')); bpy.ops.render.render(write_still=True)
    camera.location=(2,-3,2.1); cd.ortho_scale=1.85
    camera.rotation_euler=(Vector((0,0,.29))-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    assert previous_scenes.issubset(set(bpy.data.scenes))
    result=report
finally:
    bpy.context.window.scene=previous_scene
