"""A worked amethyst mine, built through live Blender MCP.

Reuse the approved amethyst primitive without importing the full resource.
Create an isolated scene and restore the active Blender scene after export.
"""
import bpy
import bmesh
import math
import json
import ast
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = 'gem_mine_v1'
OUT = ROOT / 'assets/generated/improvements' / STEM
assert not (OUT / (STEM + '.glb')).exists() or bool(globals().get('REBUILD_GEM_MINE_V1', False)), 'Do not overwrite an existing export without an explicit rebuild.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = set(bpy.data.scenes)
scene = bpy.data.scenes.new('Gem_Mine_V1_Shared')
bpy.context.window.scene = scene

try:
    palette = {
        'earth_side': (66,55,43), 'earth_top': (99,79,53),
        'rock_dark': (67,65,76), 'rock_side': (91,85,102), 'rock_top': (121,111,129), 'tunnel': (35,32,41),
        'wood_dark': (67,46,32), 'wood': (112,78,47), 'wood_top': (151,111,67),
        'wood_end': (133,94,56), 'iron_dark': (39,46,52), 'iron': (87,99,105),
        'copper': (137,101,64), 'rope': (152,131,88),
        'crystal_0': (81,39,117), 'crystal_1': (112,55,155),
        'crystal_2': (145,75,185), 'crystal_3': (175,106,212),
        'crystal_4': (206,150,232), 'crystal_5': (236,198,247),
    }
    size, cell = 512, 64
    pixels = np.ones((size,size,4),dtype=np.float32)
    pixels[:,:,:3] = (.08,.10,.12)
    emission = np.ones_like(pixels); emission[:,:,:3] = 0
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
        elif name.startswith('crystal'):
            paint[((xx//3*7+yy//5*11)%37)<2] += 13
        elif name=='copper': paint[(yy%27<2)&(xx%21<12)] += 13
        elif name=='rope': paint[(xx+yy)%7<2] -= 17
        x,y = tx*cell,ty*cell
        pixels[y:y+cell,x:x+cell,:3] = np.clip(paint/255,0,1)
        if name.startswith('crystal'):
            emission[y:y+cell,x:x+cell,:3] = pixels[y:y+cell,x:x+cell,:3] * .45

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
    for image,socket in [(image_file('_albedo',pixels),'Base Color'),(image_file('_emission',emission),'Emission Color')]:
        tex=material.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=image; tex.interpolation='Closest'
        material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])
    bsdf.inputs['Emission Strength'].default_value=.5

    vertices,faces,face_uvs,parts=[],[],[],[]
    BOX_FACES=[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    PAINTS={
        'earth':['earth_side','earth_top','earth_side','earth_side','earth_side','earth_side'],
        'rock':['rock_dark','rock_top','rock_side','rock_dark','rock_side','rock_side'],
        'wood':['wood_dark','wood_top','wood','wood_end','wood','wood_end'],
        'iron':['iron_dark','iron','iron','iron_dark','iron','iron'],
        'copper':['iron_dark','copper','copper','copper','copper','copper'],
        'rope':['rope']*6,'tunnel':['tunnel']*6,
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

    # The ground patch stays inside the hex inscribed circle at any rotation.
    outline=[(-.57,-.43),(-.38,-.60),(.33,-.55),(.60,-.17),(.56,.35),(.25,.57),(-.45,.52),(-.60,.16)]
    verts=[(x,y,z) for z in (0,.035) for x,y in outline]
    polys=[tuple(reversed(range(8))),tuple(range(8,16))]
    polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    part('Worked_quarry_ground',verts,polys,['earth_side','earth_top']+['earth_side']*8)

    # Read the exact approved four-sided crystal primitive, not a round proxy.
    profile_source=ROOT/'tools/art_pipeline/build_crystal_resource_mcp.py'
    tree=ast.parse(profile_source.read_text(encoding='utf-8'))
    definition=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='crystal')
    captured=[]
    namespace={'add_part':lambda *args:captured.append(args),'math':math}
    exec(compile(ast.Module(body=[definition],type_ignores=[]),str(profile_source),'exec'),namespace)

    def gem(name,base,height,radius,lean_x=0,lean_y=0,scale=1):
        captured.clear()
        namespace['crystal'](name,0,0,height,radius,lean_x,lean_y,0)
        _,local,polys,colors=captured[0]
        assert len(local)==13 and len(polys)==13
        verts=[tuple(Vector(base)+Vector(v)*scale) for v in local]
        part(name,verts,polys,['crystal_'+str(c) for c in colors])

    # Open, stepped rock face. Purple spires keep their existing growth shape.
    blocks=[((.28,.20,.11),(.48,.43,.15),-.04),
            ((.43,.30,.15),(.30,.30,.23),.07),
            ((.23,.43,.18),(.32,.18,.24),-.04),
            ((.38,.015,.075),(.35,.22,.08),.03),
            ((.065,.29,.12),(.19,.29,.17),-.08)]
    for i,(center,extent,angle) in enumerate(blocks):
        box('Ore_face_rock_'+str(i),center,extent,'rock',angle)
    gem('Crown_profile',(.28,.20,.12),.76,.135,-.035,.02,.84)
    gem('Left_spire_profile',(.075,.30,.145),.47,.10,-.095,-.035,.80)
    gem('Right_spire_profile',(.46,.28,.16),.55,.108,.085,.055,.78)
    gem('Front_spire_profile',(.33,.015,.10),.40,.105,.035,-.065,.72)
    gem('Rear_spire_profile',(.27,.44,.16),.34,.08,-.035,.05,.65)
    gem('Emerging_shard_profile',(.49,-.015,.09),.21,.06,.055,-.02,.65)

    # Actual recessed entrance: floor, side walls, lintel and a shaded back wall.
    # Its open front reads in the strategy camera without a full roof hiding it.
    box('Tunnel_floor',(-.30,.33,.06),(.44,.35,.05),'rock')
    box('Tunnel_left_wall',(-.565,.32,.26),(.09,.38,.45),'rock')
    box('Tunnel_right_wall',(-.035,.34,.25),(.10,.33,.43),'rock')
    box('Tunnel_rock_lintel',(-.30,.37,.515),(.60,.30,.105),'rock')
    box('Tunnel_recess',(-.30,.49,.27),(.44,.035,.39),'tunnel')
    for x in (-.535,-.065):
        box('Entrance_post_'+str(x),(x,.16,.285),(.075,.10,.44),'wood')
        box('Entrance_iron_band_'+str(x),(x,.16,.20),(.081,.106,.032),'iron')
    box('Entrance_crossbeam',(-.30,.16,.52),(.59,.13,.09),'wood')
    beam('Entrance_left_brace',(-.535,.16,.34),(-.405,.16,.475),.037,.045)
    beam('Entrance_right_brace',(-.065,.16,.34),(-.195,.16,.475),.037,.045)

    # A short rail spur and a loaded wagon communicate extraction at map scale.
    for i,y in enumerate((-.45,-.29,-.13,.03,.19)):
        box('Rail_sleeper_'+str(i),(-.30,y,.052),(.38,.065,.034),'wood')
    for x in (-.45,-.15):
        box('Iron_rail_'+str(x),(x,-.105,.077),(.022,.77,.026),'iron')

    def wheel(name,center):
        cx,cy,cz=center
        ring=[(math.cos(i*math.tau/8)*.048,math.sin(i*math.tau/8)*.048) for i in range(8)]
        verts=[(cx+x,cy+y,cz+z) for x in (-.014,.014) for y,z in ring]
        polys=[tuple(reversed(range(8))),tuple(range(8,16))]
        polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
        part(name,verts,polys,['iron_dark','iron_dark']+['iron']*8)

    for y in (-.375,-.195):
        box('Cart_axle_'+str(y),(-.30,y,.138),(.33,.026,.026),'iron')
        for x in (-.45,-.15):
            wheel('Cart_wheel_'+str((x,y)),(x,y,.138))
    box('Cart_bottom',(-.30,-.285,.185),(.265,.28,.035),'wood')
    for side in (-1,1):
        box('Cart_side_'+str(side),(-.30+side*.121,-.285,.26),(.024,.28,.15),'wood')
        box('Cart_end_'+str(side),(-.30,-.285+side*.128,.26),(.22,.024,.15),'wood')
        box('Cart_side_band_'+str(side),(-.30+side*.135,-.285,.265),(.009,.15,.018),'iron')
    gem('Cart_load_tall',(-.33,-.26,.205),.47,.10,-.095,-.035,.36)
    gem('Cart_load_small',(-.25,-.33,.205),.40,.105,.035,-.065,.30)
    gem('Cart_load_rear',(-.25,-.22,.205),.34,.08,-.035,.05,.36)

    # Sorting tray and a pick at the foot of the exposed seam, all solid material.
    box('Sorting_tray_base',(.30,-.37,.06),(.29,.24,.035),'wood')
    for side in (-1,1):
        box('Sorting_tray_side_'+str(side),(.30+side*.135,-.37,.09),(.02,.24,.07),'wood')
        box('Sorting_tray_end_'+str(side),(.30,-.37+side*.11,.09),(.25,.02,.07),'wood')
    gem('Sorted_shard_a',(.245,-.39,.07),.40,.105,.035,-.065,.28)
    gem('Sorted_shard_b',(.35,-.35,.07),.34,.08,-.035,.05,.29)
    beam('Pick_handle',(.04,-.21,.06),(.065,.02,.40),.024,.027,'wood')
    beam('Pick_head_left',(-.035,-.01,.385),(.065,.02,.40),.028,.034,'iron')
    beam('Pick_head_right',(.065,.02,.40),(.17,.0,.36),.028,.034,'iron')
    box('Loose_rock_front',(.03,-.49,.065),(.09,.08,.06),'rock',.2)
    box('Loose_rock_right',(.55,-.23,.07),(.10,.08,.07),'rock',-.2)

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
    assert radius<.80,(radius,height)
    assert height<.85,(radius,height)
    assert min(v.co.z for v in data.vertices)>-.000001
    assert len(data.loop_triangles)<1100,len(data.loop_triangles)
    root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
    root['improvement_id']='v2_improvement_gem_mine'
    root['resource_id']='gems'; root['shared_civilizations']='human,elf,orc,dwarf'
    obj=bpy.data.objects.new(STEM+'_Amethyst_Worksite',data)
    scene.collection.objects.link(obj); obj.parent=root; data.materials.append(material)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    report=dict(asset=STEM,improvement='v2_improvement_gem_mine',resource='gems',
        method='live Blender MCP localhost:9876',reuses_full_raw_resource_model=False,
        reuses_original_crystal_primitive=True,
        concept='Amethyst seam, timber-shored mine entrance, rails and loaded mining cart',
        crystal_profile_source=str(profile_source.relative_to(ROOT)),
        crystal_cross_section='square, no bevel',crystal_ring_fractions=[.20,.73],
        crystal_vertices_per_piece=13,crystal_faces_per_piece=13,liquid_elements=0,
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
