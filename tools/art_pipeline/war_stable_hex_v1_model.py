"""War Stable, a hex-first 4X map building. Run in the live Blender MCP.
Three open stalls, clipped barn roof, miniature horses from the approved Cavalier.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'War_Stable_Hex_V1'
OUT = ROOT / 'assets/generated/humans/buildings/war_stable_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('War Stable scene exists; preserve its edits.')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_HORSES','05_COURTYARD',
              '06_EQUIPMENT','07_HERALDRY','08_DETAILS','09_STUDIO'):
    collection = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
tree = ast.parse((PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8'))
for node in tree.body:
    if isinstance(node,ast.FunctionDef) and node.name in ('mesh','box','polygon_prism','hexagon','wall'):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<hall_primitives>','exec'))


def clip_to_hex(points, radius):
    # Clip a roof course against the six actual tile edges; no rectangular overhang.
    for i in range(6):
        nx,ny = math.cos(math.radians(i*60)),math.sin(math.radians(i*60))
        limit = radius*math.sqrt(3)/2
        output = []
        for j,current in enumerate(points):
            previous = points[j-1]
            dc,dp = current[0]*nx+current[1]*ny-limit, previous[0]*nx+previous[1]*ny-limit
            if (dc<=0)!=(dp<=0):
                t = dp/(dp-dc)
                output.append((previous[0]+t*(current[0]-previous[0]),previous[1]+t*(current[1]-previous[1])))
            if dc<=0:
                output.append(current)
        points = output
    return points


def vertical_prism(name, profile, center, depth, region, group):
    cx,cy,cz = center
    n = len(profile)
    verts = [(cx+x,cy+d,cz+z) for d in (-depth/2,depth/2) for x,z in profile]
    faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,region,group)


# Shared family rim. A wedge-shaped paddock occupies the front of the hex.
polygon_prism('Hex_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim',hexagon(.90),.035,.060,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Paving',hexagon(.85),.060,.075,'paving','01_FOUNDATION')
polygon_prism('Paddock_Dirt',[(-.66,.08),(.66,.08),(.66,-.32),(.31,-.59),
    (0,-.76),(-.31,-.59),(-.66,-.32)],.075,.088,'sand','05_COURTYARD')

# Five-sided barn footprint leaves the front open; three stalls are real spaces.
footprint = [(-.615,.105),(.615,.105),(.615,.32),(0,.675),(-.615,.32)]
polygon_prism('Barn_StoneFoot',footprint,.075,.121,'cutstone','02_HALL')
polygon_prism('Barn_StrawFloor',[(-.577,.137),(.577,.137),(.577,.298),(0,.631),(-.577,.298)],
              .121,.129,'straw','02_HALL')
for i in range(1,5):
    wall('Barn_BackWall_%d'%i,footprint[i],footprint[(i+1)%5],.041,.121,.578,'door','02_HALL')
    wall('Barn_BackBeam_%d'%i,footprint[i],footprint[(i+1)%5],.062,.542,.590,'timber','02_HALL')
for x in (-.60,-.20,.20,.60):
    box('Stall_Post_'+str(x),(x,.105,.353),(.055,.058,.467),'timber')
    box('Stall_PostFoot_'+str(x),(x,.105,.15),(.080,.082,.064),'iron')
box('Barn_FrontBeam',(0,.105,.580),(1.285,.082,.066),'timber')
for x in (-.20,.20):
    box('Stall_Divider_'+str(x),(x,.343,.302),(.027,.435,.343),'timber')
for i,x in enumerate((-.40,0,.40)):
    for z in (.212,.275):
        box('Stall_%d_HalfGate_%s'%(i,z),(x,.075,z),(.315,.030,.032),'door')
    for dx in (-.12,.12):
        box('Stall_%d_GateEnd_%s'%(i,dx),(x+dx,.075,.239),(.026,.037,.144),'timber')
    box('Stall_%d_Latch'%i,(x+.12,.052,.281),(.029,.012,.028),'iron_light')

# Stepped blue gable, recut at every course to the hex. Shared faces are internal.
for j in range(6):
    half_width = (.63-j*.104)/2
    points = [(-.656,.40-half_width),(.656,.40-half_width),(.656,.40+half_width),(-.656,.40+half_width)]
    polygon_prism('Barn_Roof_%d'%j,clip_to_hex(points,.835),.613+j*.047,.660+j*.047,'roof','03_ROOFS')
box('Barn_Ridge',(0,.40,.914),(1.327,.058,.030),'roof_dark','03_ROOFS')
# Small ventilator at the ridge, with broad dark slits and a blocky roof cap.
box('Ventilator_Base',(0,.36,.949),(.185,.183,.045),'timber','02_HALL')
box('Ventilator_Body',(0,.36,1.023),(.141,.140,.103),'plaster','02_HALL')
box('Ventilator_FrontSlit',(0,.282,1.026),(.102,.017,.053),'shadow','02_HALL')
for x in (-.031,.031):
    box('Ventilator_Louver_'+str(x),(x,.269,1.027),(.014,.015,.060),'timber','02_HALL')
for j in range(3):
    box('Ventilator_Roof_%d'%j,(0,.36,1.093+j*.039),(.213-j*.064,.211-j*.063,.039),'roof','03_ROOFS')

# Miniature props retain the exact horse geometry and paint of the existing model.
# Append source objects into memory only, copy raw static meshes, omit all riders/rigs.
source_file = ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1.blend'
source_atlas = ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1_albedo.png'
before = set(bpy.data.objects)
with bpy.data.libraries.load(str(source_file),link=False) as (data,loaded):
    loaded.objects = [name for name in data.objects if name.startswith('Cavalier_V1_Horse')
        or name.startswith('Cavalier_V1_Saddle') or name.startswith('Cavalier_V1_BlanketSide')]
imported = set(bpy.data.objects)-before
for label,offset,scale in (('In_Stall',Vector((-.40,.325,.131)),.175),
                           ('In_Paddock',Vector((.365,-.22,.088)),.175)):
    for source in loaded.objects:
        if source is None or source.type!='MESH':
            continue
        vertices = [tuple(vertex.co*scale+offset) for vertex in source.data.vertices]
        faces = [tuple(poly.vertices) for poly in source.data.polygons]
        name = 'Horse_'+label+'_'+source.get('part',source.name.split('Cavalier_V1_')[-1])
        obj = mesh(name,vertices,faces,'horse_source','04_HORSES')
        obj['source_paint_atlas'] = str(source_atlas)
        # Normal correction can reverse a face; map source UVs by vertex IDs.
        source_faces = {frozenset(p.vertices):p for p in source.data.polygons}
        flat_uvs = []
        for poly in obj.data.polygons:
            original = source_faces[frozenset(poly.vertices)]
            by_vertex = {v:list(source.data.uv_layers.active.data[li].uv) for v,li in zip(original.vertices,original.loop_indices)}
            flat_uvs += [value for vertex in poly.vertices for value in by_vertex[vertex]]
        obj['source_paint_uvs'] = flat_uvs
        obj['paint_up'] = list(source.get('paint_up',[0,0,1]))
        obj['prop_source'] = 'Approved Cavalier horse, static miniature, no rider'
for obj in imported:
    bpy.data.objects.remove(obj,do_unlink=True)

# Oblique paddock rails trace the front hex edges and leave a central opening.
for sign in (-1,1):
    start,end = (sign*.681,-.31),(sign*.235,-.65)
    for j in range(4):
        t = j/3
        x,y = start[0]*(1-t)+end[0]*t,start[1]*(1-t)+end[1]*t
        box('Paddock_Post_%d_%d'%(sign,j),(x,y,.230),(.045,.045,.284),'timber','05_COURTYARD')
        box('Paddock_PostCap_%d_%d'%(sign,j),(x,y,.382),(.059,.059,.020),'iron','05_COURTYARD')
    for z in (.189,.305):
        wall('Paddock_Rail_%d_%s'%(sign,z),start,end,.027,z-.018,z+.018,'door','05_COURTYARD')
box('Hitching_Post',(.585,-.125,.258),(.047,.047,.34),'timber','06_EQUIPMENT')
box('Hitching_Beam',(.480,-.125,.397),(.27,.036,.041),'door','06_EQUIPMENT')

# Hay and tack stay large enough to read at map zoom.
for i,(x,y,z,size) in enumerate(((-.475,-.205,.165,(.18,.18,.15)),(-.57,-.385,.153,(.15,.15,.13)),
                              (-.475,-.205,.280,(.153,.158,.08)))):
    box('Hay_Bale_%d'%i,(x,y,z),size,'straw','06_EQUIPMENT')
    for dx in (-size[0]*.28,size[0]*.28):
        box('Hay_Binding_%d_%s'%(i,dx),(x+dx,y-size[1]/2-.004,z),(.012,.010,size[2]),'timber','06_EQUIPMENT')
box('Saddle_Stand_Post',(-.24,-.21,.222),(.036,.046,.27),'timber','06_EQUIPMENT')
box('Saddle_Stand_Top',(-.24,-.21,.34),(.17,.10,.041),'door','06_EQUIPMENT')
box('Spare_Saddle',(-.24,-.21,.377),(.132,.090,.038),'leather','06_EQUIPMENT')
for x in (-.31,-.17):
    box('Spare_Saddle_Flap_'+str(x),(x,-.21,.319),(.023,.086,.116),'leather','06_EQUIPMENT')
for x in (-.67,-.47):
    box('Lance_Rack_Post_'+str(x),(x,.02,.27),(.024,.030,.361),'timber','06_EQUIPMENT')
box('Lance_Rack_Rail',(-.57,.02,.387),(.244,.030,.029),'door','06_EQUIPMENT')
for i in range(3):
    x = -.646+i*.074
    box('Lance_%d_Shaft'%i,(x,-.003,.38),(.011,.011,.56),'door','06_EQUIPMENT')
    box('Lance_%d_Head'%i,(x,-.003,.69),(.021,.015,.052),'iron_light','06_EQUIPMENT')

# Open water trough, using four walls; the water is below its rim.
box('Trough_Foot',(.025,-.385,.11),(.255,.112,.047),'stone','08_DETAILS')
for x in (-.124,.124):
    box('Trough_End_'+str(x),(x,-.385,.17),(.026,.130,.103),'cutstone','08_DETAILS')
for y in (-.442,-.328):
    box('Trough_Side_'+str(y),(0,y,.17),(.23,.026,.103),'cutstone','08_DETAILS')
box('Trough_Water',(0,-.385,.182),(.222,.092,.018),'water','08_DETAILS')

# A continuous blocky U-shaped horseshoe, free of coplanar overlapping blocks.
box('Crest_Wood_Backboard',(0,-.016,.817),(.382,.033,.378),'timber','07_HERALDRY')
box('Crest_Blue_Plate',(0,-.040,.817),(.342,.015,.343),'team_plain','07_HERALDRY')
profile = [(-.14,.17),(-.14,-.055),(-.11,-.055),(-.11,-.115),(-.06,-.115),(-.06,-.15),
    (.06,-.15),(.06,-.115),(.11,-.115),(.11,-.055),(.14,-.055),(.14,.17),(.083,.17),
    (.083,-.018),(.065,-.018),(.065,-.055),(.035,-.055),(.035,-.078),(-.035,-.078),
    (-.035,-.055),(-.065,-.055),(-.065,-.018),(-.083,-.018),(-.083,.17)]
vertical_prism('Horseshoe_Crest',profile,(0,-.061,.817),.020,'iron_light','07_HERALDRY')
for sign in (-1,1):
    for z in (.782,.887):
        box('Horseshoe_Nail_%d_%s'%(sign,z),(sign*.110,-.076,z),(.014,.008,.018),'iron','07_HERALDRY')
box('Flag_Pole',(.535,.30,1.04),(.016,.016,.38),'timber','07_HERALDRY')
box('Flag_Cap',(.535,.30,1.247),(.028,.028,.029),'iron_light','07_HERALDRY')
flag = box('Cavalry_Flag',(.416,.30,1.143),(.222,.012,.15),'banner','07_HERALDRY')
flag['banner_center'],flag['banner_size'],flag['heraldry'] = [.416,.30,1.143],[.222,.15],'horseshoe'
for x in (-.225,.225):
    box('Stable_Lantern_'+str(x),(x,.052,.487),(.032,.035,.055),'glow','08_DETAILS')
    box('Stable_LanternCap_'+str(x),(x,.052,.530),(.049,.049,.024),'iron','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_war_stable'
root['design'] = 'Hex-first 4X war stable, 3 open stalls and front paddock; tile radius 1, native scale 1.'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2+1e-6,maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'],scene['door_clearance'] = [0,0,.47],[.345,.415]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Estábulo de Guerra'
scene['trains'] = ['v2_unit_cavalier','v2_unit_shock_cavalier','v2_unit_armored_cavalier']
scene['excludes'] = ['v2_legendary_griffon_rider']
scene['palette_overrides'] = {'water':[63,117,138],'leather':[100,62,40],'team_plain':[49,79,127]}
scene['scale_note'] = 'Native 4X map units, pointy-top hex tile radius 1, placement multiplier 1.0. Symbolic architecture and miniature props.'
scene['design_note'] = 'Five-sided open timber barn with three stalls, hex-clipped blue gable and ventilator. Front wedge paddock, two miniature approved Cavalier horses, hay, tack, lance rack, water trough, and a large horseshoe crest.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':list(scene['door_clearance']),'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'allowed':math.sqrt(3)/2}
