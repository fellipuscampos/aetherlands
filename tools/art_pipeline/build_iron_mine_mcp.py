"""A stepped iron quarry with manual extraction hoist, built through live Blender MCP.

Preserve the approved cubic ore and copy its painted mineral texels.
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
STEM = 'iron_mine_v1'
OUT = ROOT / 'assets/generated/improvements' / STEM
assert not (OUT / (STEM + '.glb')).exists() or bool(globals().get('REBUILD_IRON_MINE_V1', False)), 'Do not overwrite an existing export without an explicit rebuild.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = set(bpy.data.scenes)
scene = bpy.data.scenes.new('Iron_Mine_V1_Shared')
bpy.context.window.scene = scene

try:
    palette = {
        'earth_side': (66,55,43), 'earth_top': (99,79,53),
        'rock_dark': (43,47,51), 'rock_side': (64,69,73), 'rock_top': (88,95,100), 'tunnel': (35,32,41),
        'wood_dark': (67,46,32), 'wood': (112,78,47), 'wood_top': (151,111,67),
        'wood_end': (133,94,56), 'iron_dark': (39,46,52), 'iron': (87,99,105),
        'copper': (137,101,64), 'rope': (152,131,88),
        'ore_0': (43,47,51), 'ore_1': (64,69,73), 'ore_2': (88,95,100),
        'ore_3': (133,71,43), 'ore_4': (179,98,50), 'ore_5': (212,132,71),
        'ore_6': (118,132,143), 'ore_7': (163,177,184), 'ore_8': (201,213,217),
    }
    size, cell = 512, 64
    pixels = np.ones((size,size,4),dtype=np.float32)
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

        elif name=='copper': paint[(yy%27<2)&(xx%21<12)] += 13
        elif name=='rope': paint[(xx+yy)%7<2] -= 17
        x,y = tx*cell,ty*cell
        pixels[y:y+cell,x:x+cell,:3] = np.clip(paint/255,0,1)


    def image_file(suffix, values):
        image = bpy.data.images.new(STEM+suffix,size,size,alpha=False)
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
    source_folder=ROOT/'assets/generated/resources/iron/iron_outcrop_v1'
    source_texture=source_folder/'iron_outcrop_v1_albedo.png'
    source_blend=source_folder/'iron_outcrop_v1.blend'
    source_hash=hashlib.sha256(source_texture.read_bytes()).hexdigest()
    blend_hash=hashlib.sha256(source_blend.read_bytes()).hexdigest()
    original=bpy.data.images.load(str(source_texture),check_existing=True)
    assert tuple(original.size)==(256,256)
    original_pixels=np.empty(256*256*4,dtype=np.float32)
    original.pixels.foreach_get(original_pixels)
    original_pixels=original_pixels.reshape(256,256,4)
    for index in range(9):
        sx,sy=(index%4)*64,(index//4)*64
        dx,dy=Vector(slots['ore_'+str(index)])*cell
        dx,dy=int(dx),int(dy)
        pixels[dy:dy+64,dx:dx+64,:]=original_pixels[sy:sy+64,sx:sx+64,:]
        assert np.array_equal(pixels[dy:dy+64,dx:dx+64,:],original_pixels[sy:sy+64,sx:sx+64,:])
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
        'ore':['ore_0','ore_2','ore_1','ore_0','ore_1','ore_0'],
        'silver':['ore_6','ore_8','ore_7','ore_6','ore_7','ore_6'],
        'oxide':['ore_3','ore_5','ore_4','ore_3','ore_4','ore_3'],
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
                local=(coord-low)*(64 if paint.startswith('ore_') else 44)
                assert max(local)<56,(name,local)
                uvcoords.append(tuple((Vector(slots[paint])*cell+Vector((4,4))+local)/size))
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

    # A small cleared patch; height budget also respects iron's lower map badge.
    outline=[(-.57,-.43),(-.31,-.59),(.32,-.56),(.60,-.21),(.58,.36),(.26,.58),(-.30,.55),(-.60,.16)]
    verts=[(x,y,z) for z in (0,.035) for x,y in outline]
    polys=[tuple(reversed(range(8))),tuple(range(8,16))]
    polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    part('Quarry_worked_ground',verts,polys,['earth_side','earth_top']+['earth_side']*8)

    # New stepped workface in the original dark cubic host rock.
    for name,center,extent in [
        ('High_ore_face',(.29,.30,.30),(.28,.25,.53)),
        ('Right_ore_step',(.46,.17,.20),(.22,.24,.33)),
        ('Front_ore_step',(.25,.035,.13),(.31,.23,.18)),
        ('Rear_ore_step',(.12,.42,.18),(.23,.18,.27)),
        ('Left_ore_ledge',(.05,.25,.14),(.16,.23,.21)),
    ]: box(name,center,extent,'ore')
    # Exposed chips sit partly inside the rock, exactly as on the raw resource.
    for name,center,extent,paint in [
        ('High_silver_cap',(.255,.30,.57),(.095,.09,.027),'silver'),
        ('High_silver_chip',(.35,.32,.568),(.05,.06,.018),'silver'),
        ('High_front_iron',(.27,.164,.40),(.09,.027,.10),'silver'),
        ('High_front_oxide',(.365,.165,.31),(.055,.024,.09),'oxide'),
        ('High_left_iron',(.144,.32,.32),(.023,.07,.09),'silver'),
        ('Right_silver_cap',(.46,.17,.372),(.10,.08,.026),'silver'),
        ('Right_oxide_cap',(.525,.21,.368),(.055,.06,.018),'oxide'),
        ('Right_front_iron',(.46,.044,.25),(.075,.024,.07),'silver'),
        ('Front_silver_cap',(.24,.03,.228),(.08,.08,.025),'silver'),
        ('Front_oxide_cap',(.32,-.02,.226),(.05,.07,.021),'oxide'),
        ('Rear_silver_cap',(.11,.43,.323),(.07,.08,.028),'silver'),
        ('Ledge_silver_cap',(.055,.25,.251),(.06,.08,.023),'silver'),
    ]: box(name,center,extent,paint)

    # Compact timber gantry, with actual clear space for a hanging bucket.
    for y in (-.13,.34):
        box('Gantry_foot_'+str(y),(-.40,y,.065),(.15,.15,.06),'rock')
        box('Gantry_post_'+str(y),(-.40,y,.32),(.085,.09,.46),'wood')
        box('Gantry_iron_band_'+str(y),(-.40,y,.20),(.091,.096,.028),'iron')
    box('Gantry_long_beam',(-.40,.105,.59),(.12,.69,.08),'wood')
    box('Gantry_reaching_arm',(-.13,.02,.645),(.66,.09,.07),'wood')
    beam('Gantry_side_brace',(-.40,-.13,.30),(-.40,.10,.55),.04,.047)
    beam('Gantry_arm_brace',(-.40,.02,.34),(-.16,.02,.61),.038,.044)
    box('Pulley_block',(-.015,.02,.595),(.075,.045,.04),'iron')
    box('Hoist_rope',(-.015,.02,.46),(.012,.012,.27),'rope')
    box('Winch_axle',(-.46,-.13,.31),(.15,.03,.03),'iron')
    box('Winch_hand_crank',(-.54,-.13,.27),(.025,.025,.105),'iron')
    box('Winch_grip',(-.57,-.13,.22),(.09,.03,.03),'wood')
    beam('Hoist_rope_return',(-.015,.02,.595),(-.40,.02,.59),.010,.010,'rope')
    beam('Hoist_rope_corner',(-.40,.02,.59),(-.455,-.13,.56),.010,.010,'rope')
    beam('Hoist_rope_to_winch',(-.455,-.13,.56),(-.455,-.13,.31),.010,.010,'rope')

    bucket=(-.015,.02)
    box('Bucket_bottom',(*bucket,.18),(.16,.15,.026),'wood')
    for side in (-1,1):
        box('Bucket_side_'+str(side),(bucket[0]+side*.073,bucket[1],.223),(.018,.15,.095),'wood')
        box('Bucket_end_'+str(side),(bucket[0],bucket[1]+side*.066,.223),(.128,.018,.095),'wood')
        box('Bucket_iron_band_'+str(side),(bucket[0]+side*.084,bucket[1],.225),(.008,.15,.018),'iron')
        box('Bucket_handle_'+str(side),(bucket[0]+side*.061,bucket[1],.294),(.009,.012,.07),'iron')
    box('Bucket_handle_crossbar',(*bucket,.329),(.13,.012,.01),'iron')
    box('Bucket_ore_a',(-.042,.008,.228),(.062,.06,.075),'ore',.15)
    box('Bucket_ore_b',(.02,.04,.234),(.055,.05,.065),'ore',-.12)
    box('Bucket_iron_chip',(-.042,.008,.267),(.04,.033,.014),'silver')

    # A low timber sled holds broken ore; there is no furnace or molten metal.
    for x in (.20,.45):
        box('Sorting_sled_runner_'+str(x),(x,-.36,.058),(.032,.36,.045),'wood')
    for i,y in enumerate((-.47,-.39,-.31,-.23)):
        box('Sorting_sled_plank_'+str(i),(.325,y,.091),(.34,.071,.024),'wood')
    for x in (.17,.48):
        box('Sorting_sled_rim_'+str(x),(x,-.35,.13),(.026,.34,.07),'wood')
    for i,(center,extent,angle) in enumerate([
        ((.245,-.39,.15),(.11,.11,.10),-.1),
        ((.37,-.39,.17),(.12,.12,.14),.1),
        ((.31,-.27,.14),(.10,.09,.08),-.12),
    ]): box('Harvested_ore_'+str(i),center,extent,'ore',angle)
    box('Sorted_iron_cap_a',(.37,-.39,.245),(.06,.065,.022),'silver')
    box('Sorted_iron_cap_b',(.245,-.39,.204),(.055,.05,.018),'silver')

    # Visible hand tools and debris make the cut face read as worked terrain.
    beam('Quarry_pick_handle',(-.28,-.36,.05),(-.24,-.09,.34),.024,.027)
    beam('Quarry_pick_left',(-.34,-.095,.33),(-.24,-.09,.34),.026,.032,'iron')
    beam('Quarry_pick_right',(-.24,-.09,.34),(-.13,-.12,.31),.026,.032,'iron')
    box('Loose_ore_front',(-.08,-.48,.07),(.11,.09,.07),'ore',.14)
    box('Loose_ore_chip',(-.08,-.48,.11),(.05,.04,.018),'silver')

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
    height=max(v.co.z for v in data.vertices)
    assert radius<.83,(radius,height)
    assert height<.70,(radius,height)
    assert min(v.co.z for v in data.vertices)>-.000001
    assert len(data.loop_triangles)<1200,len(data.loop_triangles)
    root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
    root['improvement_id']='v2_improvement_iron_mine'
    root['resource_id']='iron'; root['shared_civilizations']='human,elf,orc,dwarf'
    obj=bpy.data.objects.new(STEM+'_Stepped_Quarry',data)
    scene.collection.objects.link(obj); obj.parent=root; data.materials.append(material)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    assert hashlib.sha256(source_texture.read_bytes()).hexdigest()==source_hash
    assert hashlib.sha256(source_blend.read_bytes()).hexdigest()==blend_hash
    report=dict(asset=STEM,improvement='v2_improvement_iron_mine',resource='iron',
        method='live Blender MCP localhost:9876',reuses_full_raw_resource_model=False,
        source_texture=str(source_texture.relative_to(ROOT)),source_texture_sha256=source_hash,
        source_blend_sha256=blend_hash,source_ore_texels_preserved=True,host_rock='cuboid blocks',
        concept='Stepped iron quarry, timber extraction hoist, loaded bucket and ore sorting sled',
        materials=1,meshes=1,vertices=len(data.vertices),triangles=len(data.loop_triangles),
        footprint_radius=radius,height=height,ground_origin=True,closed_components=True,
        texture_size=[size,size],texture_filter='nearest',animations=0,lights=0,
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
