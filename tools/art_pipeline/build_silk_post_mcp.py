"""A shared mulberry and silk weaving worksite, built through live Blender MCP.

Reuse the approved mulberry and stepped cocoon primitives in a new worksite.
Create an isolated scene and restore the active Blender scene after export.
"""
import bpy
import bmesh
import math
import json
import ast
import hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = 'silk_post_v1'
OUT = ROOT / 'assets/generated/improvements' / STEM
assert not (OUT / (STEM + '.glb')).exists() or bool(globals().get('REBUILD_SILK_POST_V1', False)), 'Do not overwrite an existing export without an explicit rebuild.'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
previous_scene = bpy.context.window.scene
previous_scenes = set(bpy.data.scenes)
scene = bpy.data.scenes.new('Silk_Post_V1_Shared')
bpy.context.window.scene = scene

try:
    palette = {
        'earth_side': (66,55,43), 'earth_top': (99,79,53),
        'rock_dark': (67,65,76), 'rock_side': (91,85,102), 'rock_top': (121,111,129), 'tunnel': (35,32,41),
        'wood_dark': (67,46,32), 'wood': (112,78,47), 'wood_top': (151,111,67),
        'wood_end': (133,94,56), 'iron_dark': (39,46,52), 'iron': (87,99,105),
        'copper': (137,101,64), 'rope': (152,131,88),
        'bark_dark': (83,56,34), 'bark': (130,91,48),
        'leaf_dark': (44,83,39), 'leaf': (65,111,44), 'leaf_light': (92,138,57),
        'fiber_dark': (177,158,111), 'fiber': (224,213,172), 'fiber_light': (246,240,212),
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
        elif name.startswith('fiber'):
            paint[(yy%4==0)&(xx%7<5)] -= 9
            paint[(yy%4==1)&(xx%5<3)] += 5
            paint[(xx%6==0)&(yy%9<6)] -= 4
        elif name.startswith('leaf'):
            paint[((xx//4*13+yy//4*23)%37)<5] += 12
            paint[((xx//3*11+yy//3*17)%41)<4] -= 11
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
        'silk':['fiber','fiber_light','fiber','fiber_dark','fiber','fiber_light'],
        'thread':['fiber_light']*6,
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

    # One small worked patch, contained in the tile's inscribed circle.
    outline=[(-.57,-.43),(-.29,-.60),(.35,-.55),(.60,-.19),(.58,.34),(.28,.57),(-.32,.53),(-.60,.16)]
    verts=[(x,y,z) for z in (0,.035) for x,y in outline]
    polys=[tuple(reversed(range(8))),tuple(range(8,16))]
    polys.extend((i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8))
    part('Silk_worksite_ground',verts,polys,['earth_side','earth_top']+['earth_side']*8)

    # Preserve the game's squared foliage and exact stepped cocoon construction.
    profile_source=ROOT/'tools/art_pipeline/build_silk_resource_mcp.py'
    source_hash=hashlib.sha256(profile_source.read_bytes()).hexdigest()
    tree=ast.parse(profile_source.read_text(encoding='utf-8'))
    definitions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ('block','cocoon')]
    assert len(definitions)==2
    captured=[]
    namespace={'add_part':lambda *args:captured.append(args),'Vector':Vector,'Matrix':Matrix,'math':math}
    exec(compile(ast.Module(body=definitions,type_ignores=[]),str(profile_source),'exec'),namespace)
    source_colors=['bark_dark','bark','leaf_dark','leaf','leaf_light','fiber_dark','fiber','fiber_light','leaf_light']

    def approved(primitive,args,base=(0,0,0),scale=1):
        captured.clear()
        namespace[primitive](*args)
        name,local,polys,colors=captured[0]
        verts=[tuple(Vector(base)+Vector(v)*scale) for v in local]
        if primitive=='cocoon': assert len(verts)==24
        part(name,verts,polys,[source_colors[index] for index in colors])

    # A pruned mulberry at the back-right, not the entire original resource model.
    base=(.30,.28,.035); scale=.70
    for args in [
        ('Mulberry_trunk',-.04,.04,-.035,.035,0,.36),
        ('Mulberry_branch_left',-.22,-.035,-.025,.025,.19,.245),
        ('Mulberry_branch_right',.035,.23,-.025,.025,.235,.285),
        ('Mulberry_front_branch',-.025,.025,-.23,-.015,.18,.23),
        ('Mulberry_main_leaves',-.18,.18,-.15,.15,.27,.49,True),
        ('Mulberry_crown_leaves',-.12,.12,-.10,.11,.49,.61,True),
        ('Mulberry_left_leaves',-.33,-.10,-.13,.11,.21,.39,True),
        ('Mulberry_right_leaves',.11,.30,-.10,.14,.27,.45,True),
        ('Mulberry_front_leaves',-.12,.16,-.28,-.08,.21,.37,True),
    ]: approved('block',args,base,scale)
    for args in [
        ('Mulberry_cocoon_front_left',-.065,-.294,.29,.037,.029,.14),
        ('Mulberry_cocoon_front_right',.125,-.292,.32,.034,.029,.13),
        ('Mulberry_cocoon_upper',-.015,-.16,.46,.034,.029,.14),
        ('Mulberry_cocoon_left',-.34,-.045,.30,.028,.034,.14),
        ('Mulberry_cocoon_right',.308,.075,.37,.029,.034,.14),
    ]: approved('cocoon',args,base,scale)

    # An exposed handloom: upright warp, lower woven fabric and a cloth apron.
    # No roof conceals the actual textile work from the map camera.
    for x in (-.50,-.055):
        box('Loom_foot_'+str(x),(x,.20,.06),(.085,.43,.05),'wood')
        box('Loom_upright_'+str(x),(x,.20,.355),(.045,.055,.60),'wood')
        box('Loom_rear_leg_'+str(x),(x,.38,.16),(.042,.045,.22),'wood')
        beam('Loom_side_brace_'+str(x),(x,.38,.16),(x,.20,.40),.026,.03)
    box('Loom_top_beam',(-.2775,.20,.665),(.54,.07,.07),'wood')
    box('Loom_bottom_beam',(-.2775,.20,.185),(.49,.065,.055),'wood')
    box('Loom_upper_roller',(-.2775,.17,.605),(.41,.04,.045),'wood')
    box('Loom_lower_roller',(-.2775,.16,.20),(.41,.05,.045),'wood')
    for i in range(10):
        x=-.444+i*.037
        box('Loom_warp_'+str(i),(x,.153,.445),(.006,.006,.31),'thread')
    box('Loom_woven_silk',(-.2775,.137,.272),(.355,.014,.17),'silk')
    beam('Loom_cloth_apron',(-.2775,.14,.19),(-.2775,-.06,.13),.355,.013,'silk')
    box('Loom_beater_crossbar',(-.2775,.119,.39),(.39,.027,.022),'wood')
    # A small flat shuttle rests on the actual weave rather than floating.
    box('Weaving_shuttle',(-.36,-.005,.153),(.095,.027,.018),'wood',.10)

    # Winding bench and a square reel/spool with a hand crank.
    bench=(-.13,-.36)
    for x in (-.27,.01):
        for y in (-.46,-.26):
            box('Winding_bench_leg_'+str((x,y)),(x,y,.12),(.035,.035,.17),'wood')
    box('Winding_bench_top',(*bench,.222),(.36,.28,.04),'wood')
    for x in (-.23,-.03):
        box('Reel_support_'+str(x),(x,-.36,.28),(.027,.04,.10),'wood')
    box('Reel_axle',(-.13,-.36,.33),(.27,.018,.018),'wood')
    box('Wound_silk',(-.13,-.36,.33),(.15,.075,.09),'silk')
    for x in (-.22,-.04):
        box('Reel_flange_'+str(x),(x,-.36,.33),(.018,.11,.12),'wood')
    box('Reel_crank',(-.28,-.36,.295),(.018,.018,.085),'iron')
    box('Reel_crank_handle',(-.30,-.36,.255),(.06,.022,.022),'wood')

    # The harvested material remains recognizable: original capsule profile.
    box('Cocoon_tray_base',(.35,-.31,.058),(.31,.27,.035),'wood')
    for side in (-1,1):
        box('Cocoon_tray_side_'+str(side),(.35+side*.145,-.31,.087),(.02,.27,.065),'wood')
        box('Cocoon_tray_end_'+str(side),(.35,-.31+side*.125,.087),(.27,.02,.065),'wood')
    approved('cocoon',('Harvested_cocoon_a',.275,-.35,.107,.030,.025,.12,True))
    approved('cocoon',('Harvested_cocoon_b',.415,-.35,.107,.030,.025,.12,True))
    approved('cocoon',('Harvested_cocoon_c',.35,-.25,.107,.030,.025,.13,True))

    # A restrained stack of finished cloth gives the exchange its output.
    box('Cloth_pallet',(.455,-.055,.058),(.22,.19,.035),'wood')
    for i in range(3):
        box('Folded_silk_'+str(i),(.455,-.055,.089+i*.027),(.19-i*.012,.16,.025),'silk')
    box('Bundle_binding',(.455,-.055,.158),(.018,.16,.009),'rope')

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
    assert height<.85,(radius,height)
    assert min(v.co.z for v in data.vertices)>-.000001
    assert len(data.loop_triangles)<1600,len(data.loop_triangles)
    root=bpy.data.objects.new(STEM,None); scene.collection.objects.link(root)
    root['improvement_id']='v2_improvement_silk_post'
    root['resource_id']='silk'; root['shared_civilizations']='human,elf,orc,dwarf'
    obj=bpy.data.objects.new(STEM+'_Mulberry_and_Weaving',data)
    scene.collection.objects.link(obj); obj.parent=root; data.materials.append(material)
    for item in scene.objects: item.select_set(False)
    root.select_set(True); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(STEM+'.glb')),export_format='GLB',
        use_selection=True,use_active_scene=True,export_animations=False,export_skins=False,
        export_yup=True,export_cameras=False,export_lights=False,export_extras=True,export_materials='EXPORT')
    assert hashlib.sha256(profile_source.read_bytes()).hexdigest()==source_hash
    report=dict(asset=STEM,improvement='v2_improvement_silk_post',resource='silk',
        method='live Blender MCP localhost:9876',reuses_full_raw_resource_model=False,
        reuses_original_cocoon_and_foliage_primitives=True,source_sha256=source_hash,
        primitive_source=str(profile_source.relative_to(ROOT)),
        concept='Cultivated mulberry, stepped cocoons, open handloom, winding reel and folded silk',
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
