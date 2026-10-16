"""Orc cavalry stable, original blocky hex architecture. Live Blender MCP only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_War_Stable_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_war_stable_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc War Stable scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_STABLE','03_ROOFS','04_MOUNTS','05_COURTYARD',
              '06_EQUIPMENT','07_FACTION','08_DETAILS','09_STUDIO'):
    collection = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Hex_Moss_Paving',hexagon(.85),.062,.077,'paving','01_FOUNDATION')
polygon_prism('Paddock_Dirt',[(-.637,.116),(.637,.116),(.665,-.283),(.386,-.568),
    (0,-.817),(-.386,-.568),(-.665,-.283)],.077,.092,'sand','05_COURTYARD')
footprint = [(-.527,.113),(.527,.113),(.527,.350),(0,.638),(-.527,.350)]
polygon_prism('Stable_Basalt_Foot',footprint,.077,.114,'stone','02_STABLE')
polygon_prism('Stable_Straw_Floor',[(-.494,.136),(.494,.136),(.494,.330),(0,.593),(-.494,.330)],
              .114,.125,'straw','02_STABLE')
for i in range(1,5):
    a,b = footprint[i],footprint[(i+1)%5]
    wall('Barn_Plank_Wall_%d'%i,a,b,.041,.114,.657,'door','02_STABLE')
    wall('Barn_Base_Beam_%d'%i,a,b,.054,.128,.177,'timber','02_STABLE')
    wall('Barn_Iron_Band_%d'%i,a,b,.049,.360,.397,'iron','02_STABLE')
    wall('Barn_Eave_Beam_%d'%i,a,b,.061,.609,.677,'timber','02_STABLE')
for x in (-.514,0,.514):
    box('Barn_Front_Heavy_Post_'+str(x),(x,.113,.395),(.075,.078,.563),'timber','02_STABLE')
    for z in (.164,.596):
        box('Barn_Post_Iron_Collar_%s_%s'%(x,z),(x,.113,z),(.094,.098,.045),'iron','02_STABLE')
box('Barn_Front_Heavy_Header',(0,.104,.660),(1.128,.115,.080),'timber','02_STABLE')
box('Barn_Front_Iron_Header',(0,.042,.654),(1.146,.029,.032),'iron','02_STABLE')
box('Stall_Central_Partition',(0,.329,.337),(.035,.402,.424),'timber','02_STABLE')
for i,x in enumerate((-.259,.259)):
    for z in (.212,.281):
        box('Stall_Gate_Rail_%d_%s'%(i,z),(x,.085,z),(.426,.035,.030),'door','02_STABLE')
    for dx in (-.183,.183):
        box('Stall_Gate_End_%d_%s'%(i,dx),(x+dx,.085,.245),(.029,.042,.122),'timber','02_STABLE')
    box('Stall_Gate_Latch_%d'%i,(x+.181,.054,.281),(.039,.020,.034),'iron_light','08_DETAILS')

# Broad barn roof, native hex clipping on every course and heavy iron binding.
for j in range(6):
    sx,sy = 1.197-j*.044,.658-j*.098
    points = [(-sx/2,.338-sy/2),(sx/2,.338-sy/2),(sx/2,.338+sy/2),(-sx/2,.338+sy/2)]
    polygon_prism('Stable_Hide_Roof_%d'%j,clip_to_hex(points,.855),
                  .703+j*.054,.757+j*.054,'roof','03_ROOFS')
    box('Roof_Iron_Front_Binding_%d'%j,(0,.338-sy/2-.008,.724+j*.054),
        (sx,.034,.029),'iron','03_ROOFS')
box('Barn_Heavy_Ridge',(0,.338,1.047),(.990,.077,.041),'timber','03_ROOFS')
for sign in (-1,1):
    box('Ridge_Horn_Iron_Socket_'+str(sign),(sign*.493,.338,1.060),(.060,.106,.057),'iron','03_ROOFS')
    tusk('Ridge_Great_Horn_'+str(sign),(sign*.493,.338,1.091),.147,.072,.059,sign,'03_ROOFS')
box('Barn_Ventilator_Base',(0,.367,1.079),(.155,.138,.041),'timber','02_STABLE')
box('Barn_Ventilator_Block',(0,.367,1.133),(.112,.107,.070),'door','02_STABLE')
box('Barn_Ventilator_Slit',(0,.306,1.133),(.077,.017,.033),'shadow','02_STABLE')
box('Barn_Ventilator_Cap',(0,.367,1.187),(.173,.153,.032),'roof_dark','03_ROOFS')

# Front-facing horseshoe sign, safely forward of the barn's lowest roof course.
box('Horseshoe_Iron_Frame',(0,-.052,.820),(.354,.047,.340),'iron','02_STABLE')
box('Horseshoe_Clan_Cloth',(0,-.084,.820),(.320,.018,.305),'faction','07_FACTION')
shoe = [(-.5,.5),(-.5,-.13),(-.39,-.13),(-.39,-.32),(-.21,-.32),(-.21,-.46),
        (.21,-.46),(.21,-.32),(.39,-.32),(.39,-.13),(.5,-.13),(.5,.5),
        (.29,.5),(.29,-.02),(.23,-.02),(.23,-.15),(.12,-.15),(.12,-.23),
        (-.12,-.23),(-.12,-.15),(-.23,-.15),(-.23,-.02),(-.29,-.02),(-.29,.5)]
vertical_prism('Horseshoe_Emblem',[(x*.221,z*.245) for x,z in shoe],(0,-.108,.823),.024,'iron_light','08_DETAILS')
for sign in (-1,1):
    for z in (.807,.889):
        box('Horseshoe_Nail_%s_%s'%(sign,z),(sign*.085,-.125,z),(.013,.010,.017),'iron','08_DETAILS')
    tusk('Horseshoe_Clan_Tusk_'+str(sign),(sign*.137,-.112,.745),.159,.042,.028,sign)

# Generic miniature horse props, reused without any rider, skin, rig or animation.
# Repack the approved coat paint; faction saddle blankets become orc rust-red.
source_file = ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1.blend'
source_atlas = ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1_albedo.png'
before = set(bpy.data.objects)
with bpy.data.libraries.load(str(source_file),link=False) as (data,loaded):
    loaded.objects = [name for name in data.objects if name.startswith(('Cavalier_V1_Horse',
                      'Cavalier_V1_Saddle','Cavalier_V1_BlanketSide'))]
imported = set(bpy.data.objects)-before
sources = [o for o in loaded.objects if o is not None and o.type=='MESH']
assert sources, 'Horse prop source missing'
coords = [v.co for obj in sources for v in obj.data.vertices]
lo = Vector(tuple(min(v[i] for v in coords) for i in range(3)))
hi = Vector(tuple(max(v[i] for v in coords) for i in range(3)))
anchor = Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for label,offset,length in (('In_Stall',Vector((-.257,.247,.125)),.350),
                            ('In_Paddock',Vector((.276,-.270,.093)),.397)):
    scale = length/(hi.y-lo.y)
    for source in sources:
        cloth = 'Blanket' in source.name
        name = 'Horse_'+label+'_'+source.get('part',source.name.split('Cavalier_V1_')[-1])
        obj = mesh(name,[tuple((v.co-anchor)*scale+offset) for v in source.data.vertices],
                   [tuple(p.vertices) for p in source.data.polygons],
                   'faction' if cloth else 'horse_source','07_FACTION' if cloth else '04_MOUNTS')
        if not cloth:
            obj['source_paint_atlas'] = str(source_atlas)
            source_faces = {frozenset(p.vertices):p for p in source.data.polygons}
            flat_uvs = []
            for poly in obj.data.polygons:
                original = source_faces[frozenset(poly.vertices)]
                by_vertex = {v:list(source.data.uv_layers.active.data[li].uv)
                             for v,li in zip(original.vertices,original.loop_indices)}
                flat_uvs += [value for v in poly.vertices for value in by_vertex[v]]
            obj['source_paint_uvs'] = flat_uvs
        obj['prop_source'] = 'Approved generic Cavalier horse only; static miniature, no rider. Rust-red clan saddle cloth.'
for obj in imported:
    bpy.data.objects.remove(obj,do_unlink=True)

# Low rails trace the front oblique edges, with a broad entrance at the apex.
for sign in (-1,1):
    a,b = (sign*.679,-.294),(sign*.235,-.659)
    for i in range(3):
        t = i/2
        x,y = a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t
        box('Paddock_Post_%s_%d'%(sign,i),(x,y,.178),(.047,.050,.171),'timber','05_COURTYARD')
        box('Paddock_Iron_Cap_%s_%d'%(sign,i),(x,y,.271),(.064,.067,.024),'iron','05_COURTYARD')
    for z in (.158,.238):
        wall('Paddock_Rail_%s_%s'%(sign,z),a,b,.026,z-.013,z+.013,'door','05_COURTYARD')
box('Hitching_Post',(.517,-.076,.221),(.047,.047,.257),'timber','06_EQUIPMENT')
box('Hitching_Rail',(.468,-.076,.358),(.268,.039,.036),'iron','06_EQUIPMENT')

# Hay, lance rack and spare saddle distinguish preparation of mounted units.
for i,(x,y,z,size) in enumerate(((-.389,-.249,.167,(.159,.145,.150)),
                                (-.475,-.426,.151,(.144,.137,.117)),
                                (-.389,-.249,.282,(.136,.127,.080)))):
    box('Hay_Bale_%d'%i,(x,y,z),size,'straw','06_EQUIPMENT')
    for dx in (-size[0]*.28,size[0]*.28):
        box('Hay_Rope_%d_%s'%(i,dx),(x+dx,y-size[1]/2-.006,z),(.012,.012,size[2]),'timber','06_EQUIPMENT')
for x in (-.678,-.541):
    box('Lance_Rack_Post_'+str(x),(x,.007,.231),(.024,.034,.284),'timber','06_EQUIPMENT')
box('Lance_Rack_Rail',(-.609,.007,.376),(.199,.038,.027),'iron','06_EQUIPMENT')
for i in range(3):
    x = -.666+i*.057
    box('Lance_Shaft_%d'%i,(x,-.022,.354),(.012,.014,.501),'door','06_EQUIPMENT')
    vertical_prism('Lance_Head_%d'%i,[(-.017,0),(.017,0),(.017,.036),(0,.069),(-.017,.036)],
                   (x,-.022,.609),.019,'iron_light','06_EQUIPMENT')
box('Saddle_Stand_Post',(-.087,-.205,.215),(.034,.041,.244),'timber','06_EQUIPMENT')
box('Saddle_Stand_Top',(-.087,-.205,.348),(.145,.091,.031),'timber','06_EQUIPMENT')
box('Spare_Leather_Saddle',(-.087,-.205,.380),(.113,.086,.042),'leather','06_EQUIPMENT')
for sign in (-1,1):
    box('Spare_Saddle_Flap_'+str(sign),(-.087+sign*.067,-.205,.334),(.023,.082,.104),'leather','06_EQUIPMENT')
    box('Saddle_Iron_Stud_'+str(sign),(-.087+sign*.067,-.253,.338),(.018,.012,.025),'iron_light','08_DETAILS')

# Open drinking trough, with water visibly below four solid walls.
wx,wy = -.014,-.448
box('Trough_Stone_Foot',(wx,wy,.112),(.254,.118,.041),'stone','08_DETAILS')
for a,b in ((-.116,0),(.116,0),(0,-.052),(0,.052)):
    box('Trough_Rim_%s_%s'%(a,b),(wx+a,wy+b,.164),
        (.023 if a else .222,.023 if b else .119,.079),'cutstone','08_DETAILS')
box('Trough_Water',(wx,wy,.173),(.207,.078,.014),'water','08_DETAILS')
for x in (-.232,.232):
    box('Barn_Lamp_Frame_'+str(x),(x,.021,.529),(.039,.048,.060),'iron','08_DETAILS')
    box('Barn_Lamp_Glow_'+str(x),(x,-.008,.529),(.026,.014,.041),'glow','08_DETAILS')

# Exposed clan standard at the barn's forward right corner.
px,py = .557,.057
box('Clan_Standard_Pole',(px,py,.843),(.019,.021,.385),'timber','08_DETAILS')
box('Clan_Standard_Cap',(px,py,1.049),(.035,.038,.028),'iron_light','08_DETAILS')
box('Cavalry_Clan_Faction_Banner',(px-.056,py,.938),(.125,.019,.144),'faction','07_FACTION')
vertical_prism('Banner_Horseshoe',[(x*.073,z*.079) for x,z in shoe],(px-.056,py-.020,.938),
               .012,'iron_light','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_war_stable','orc',True
root['unit_class'] = 'cavalry'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.43]
scene['door_clearance'] = [.426,.492]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Estábulo de Guerra dos Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_cavalier','v2_unit_shock_cavalier','v2_unit_armored_cavalier']
scene['excludes'] = ['v2_legendary_griffon_rider']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[107,113,88],'timber':[78,53,35],'door':[123,89,54],
    'roof':[130,58,39],'roof_dark':[96,47,34],'iron':[53,65,65],
    'iron_light':[152,161,151],'bone':[225,215,174],'faction':[170,60,39],
    'sand':[145,126,84],'leather':[104,64,39],'water':[76,139,147]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Orc cavalry stable: two genuinely open timber stalls on basalt, broad iron-bound rust-red hide roof with tusked ridge and low ventilator, prominent tusked horseshoe crest. Low oblique paddock rails, two generic static horse miniatures with repacked approved coat paint and clan-red saddle blankets, hay, lance rack, spare leather saddle and trough. Shared regular cavalier line; legendary griffon rider belongs to separate mastery building. No rider or full perimeter wall ring.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True,
          'horse_source_meshes':len(sources)}
