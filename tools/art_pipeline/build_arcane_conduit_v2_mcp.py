"""A solid mana-crystal work site, built through live Blender MCP.

Reuse the original crystal primitive without importing the complete resource.
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
STEM = 'arcane_conduit_v2'
OUT = ROOT / 'assets/generated/improvements' / STEM
assert not (OUT / (STEM + '.glb')).exists() or bool(globals().get('REBUILD_ARCANE_CONDUIT_V2', False)), 'Do not overwrite an existing export without an explicit rebuild.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = set(bpy.data.scenes)
scene = bpy.data.scenes.new('Arcane_Conduit_V2_Solid_Crystal_Worksite')
bpy.context.window.scene = scene

try:
    palette = {
        'earth_side': (66,55,43), 'earth_top': (99,79,53),
        'rock_dark': (43,53,63), 'rock_side': (66,80,94), 'rock_top': (90,106,118),
        'wood_dark': (67,46,32), 'wood': (112,78,47), 'wood_top': (151,111,67),
        'wood_end': (133,94,56), 'iron_dark': (39,46,52), 'iron': (87,99,105),
        'copper': (137,101,64), 'rope': (152,131,88),
        'crystal_0': (24,92,119), 'crystal_1': (32,137,161),
        'crystal_2': (49,176,188), 'crystal_3': (96,210,216),
        'crystal_4': (159,234,235), 'crystal_5': (219,252,248),
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
        'rope':['rope']*6,
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

    # An uneven worked patch, not a square altar or a complete hex-tile plinth.
    outline=[(-.53,-.43),(-.29,-.62),(.33,-.55),(.60,-.17),(.56,.35),(.25,.57),(-.25,.52),(-.57,.16)]
    verts=[(x,y,z) for z in (0,.035) for x,y in outline]
    polys=[tuple(reversed(range(8))),tuple(range(8,16))]
    polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    part('Worked_ground_patch',verts,polys,['earth_side','earth_top']+['earth_side']*8)

    # A jagged seam behind the work area; the original crystals float above it.
    rock_blocks=[((.18,.20,.12),(.47,.42,.17),-.07),
                 ((.38,.28,.15),(.29,.35,.23),.14),
                 ((-.02,.28,.12),(.27,.26,.17),-.13),
                 ((.25,.42,.13),(.33,.22,.19),.06),
                 ((.40,.04,.08),(.25,.21,.09),.18),
                 ((.09,.02,.07),(.23,.19,.07),-.10)]
    for i,(center,extent,angle) in enumerate(rock_blocks): box('Seam_rock_'+str(i),center,extent,'rock',angle)

    # Execute ONLY the approved resource's shard primitive, not its full model.
    # This preserves its exact four-sided section, .32/.72 shoulders and two tips.
    profile_source=ROOT/'tools/art_pipeline/build_arcane_node_resource_mcp.py'
    source_tree=ast.parse(profile_source.read_text(encoding='utf-8'))
    shard_def=next(n for n in source_tree.body if isinstance(n,ast.FunctionDef) and n.name=='floating_shard')
    captured=[]
    profile_namespace={'add_part':lambda *args:captured.append(args)}
    exec(compile(ast.Module(body=[shard_def],type_ignores=[]),str(profile_source),'exec'),profile_namespace)

    def crystal(name,base,height,width,lean=(0,0),angle=0):
        captured.clear()
        profile_namespace['floating_shard'](name,0,0,0,height,width,*lean)
        _,local,polys,colors=captured[0]
        assert len(local)==10 and len(polys)==12
        bx,by,bz=base
        verts=[(bx+x*math.cos(angle)-y*math.sin(angle),
                by+x*math.sin(angle)+y*math.cos(angle),bz+z) for x,y,z in local]
        part(name,verts,polys,['crystal_'+str(c) for c in colors])

    # Identical dimensions to the original core and three satellite shards.
    crystal('Original_profile_core',(.14,.20,.24),.59,.135)
    crystal('Original_profile_right',(.40,.24,.285),.28,.060,(.028,.012))
    crystal('Original_profile_back',(-.035,.30,.23),.25,.060,(-.035,.012))
    crystal('Original_profile_front',(.30,.025,.15),.17,.048,(.015,-.025))

    # A single timber hoist and its diagonal braces establish the working site.
    for y in (-.17,.34):
        box('Hoist_foot_'+str(y),(-.37,y,.065),(.17,.17,.06),'rock')
        box('Hoist_post_'+str(y),(-.37,y,.355),(.085,.095,.54),'wood')
        box('Hoist_post_band_'+str(y),(-.37,y,.19),(.091,.101,.031),'iron')
    box('Hoist_long_beam',(-.37,.075,.645),(.12,.78,.10),'wood')
    box('Hoist_reaching_arm',(-.10,-.01,.715),(.69,.10,.09),'wood')
    beam('Hoist_front_brace',(-.37,-.17,.33),(-.37,.045,.59),.046,.052)
    beam('Hoist_arm_brace',(-.37,-.01,.40),(-.115,-.01,.675),.043,.05)
    box('Pulley_axle',(.075,-.01,.672),(.105,.055,.055),'iron')
    box('Hanging_rope',(.075,-.01,.535),(.014,.014,.24),'rope')
    box('Extraction_hook_stem',(.075,-.01,.402),(.02,.02,.055),'iron')
    box('Extraction_hook_tip',(.105,-.01,.38),(.075,.024,.018),'iron')
    crystal('Harvested_fragment_in_sling',(.105,-.01,.32),.10,.10*.135/.59,angle=.2)
    box('Hand_crank_axle',(-.44,-.17,.345),(.13,.03,.03),'iron')
    box('Hand_crank',(-.505,-.17,.302),(.025,.025,.11),'iron')
    box('Hand_crank_grip',(-.54,-.17,.25),(.10,.034,.034),'wood')

    # A dry workbench holds solid samples in wooden cradles. No liquid or sluice.
    for x in (-.26,.02):
        for y in (-.49,-.30):
            box('Workbench_leg_'+str((x,y)),(x,y,.12),(.042,.042,.17),'wood')
    box('Workbench_top',(-.12,-.395,.225),(.39,.29,.045),'wood')
    box('Workbench_lower_brace',(-.12,-.49,.11),(.31,.03,.04),'wood')
    for i,(x,height) in enumerate([(-.21,.16),(-.04,.12)]):
        box('Sample_cradle_'+str(i),(x,-.39,.262),(.105,.11,.026),'wood')
        for side in (-1,1):
            box('Sample_clamp_'+str((i,side)),(x+side*.045,-.39,.30),(.018,.09,.07),'iron')
        crystal('Solid_sample_'+str(i),(x,-.39,.275),height,height*.135/.59)

    # A small output crate and fragments make the raw material legible.
    box('Crate_bottom',(.44,-.34,.056),(.24,.24,.035),'wood')
    for side in (-1,1):
        box('Crate_side_'+str(side),(.44+side*.106,-.34,.14),(.028,.24,.15),'wood')
        box('Crate_end_'+str(side),(.44,-.34+side*.106,.14),(.184,.028,.15),'wood')
    crystal('Harvested_fragment_a',(.40,-.35,.10),.17,.17*.135/.59,angle=.3)
    crystal('Harvested_fragment_b',(.49,-.32,.09),.13,.13*.135/.59,angle=-.2)
    # Two foot planks provide a clear entrance beside the workbench.
    for i in range(2): box('Front_walk_plank_'+str(i),(.23,-.47+i*.105,.065),(.15,.086,.035),'wood',-.08)
    box('Loose_stone_a',(.44,-.08,.065),(.10,.085,.055),'rock',.2)
    box('Loose_stone_b',(-.25,.46,.055),(.13,.085,.035),'rock',-.2)

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
    root['improvement_id']='v2_improvement_arcane_conduit'
    root['resource_id']='mana_node'; root['shared_civilizations']='human,elf,orc,dwarf'
    obj=bpy.data.objects.new(STEM+'_Worked_Mana_Seam',data)
    scene.collection.objects.link(obj); obj.parent=root; data.materials.append(material)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    report=dict(asset=STEM,improvement='v2_improvement_arcane_conduit',resource='mana_node',
        method='live Blender MCP localhost:9876',reuses_full_raw_resource_model=False,
        reuses_original_crystal_primitive=True,
        concept='Solid mana crystals, timber hoist, dry workbench and harvested fragments',
        crystal_profile_source=str(profile_source.relative_to(ROOT)),
        crystal_cross_section='square, no bevel',crystal_ring_fractions=[.32,.72],
        crystal_vertices_per_piece=10,crystal_faces_per_piece=12,liquid_elements=0,
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
