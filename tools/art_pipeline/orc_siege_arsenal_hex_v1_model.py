"""Orc siege assembly workshop, original blocky hex asset. Live Blender MCP."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_Siege_Arsenal_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_siege_arsenal_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc Siege Arsenal source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_WORKSHOP','03_ROOFS','04_CATAPULT','05_COURTYARD',
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
    ('ranger_camp_hex_v1_model.py',('beam',)),
    ('siege_arsenal_hex_v1_model.py',('wheel',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))

polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Hex_Workyard_Paving',hexagon(.85),.062,.078,'paving','01_FOUNDATION')
polygon_prism('Assembly_Yard_Wedge',[(-.657,.105),(.657,.105),(.649,-.244),
    (.341,-.586),(0,-.822),(-.341,-.586),(-.649,-.244)],.078,.090,'yard','05_COURTYARD')

# Low broad shed: solid rear wall, genuinely open left assembly bay.
footprint = [(-.590,.180),(.590,.180),(.590,.341),(.145,.642),(-.145,.642),(-.590,.341)]
polygon_prism('Workshop_Basalt_Platform',footprint,.078,.126,'stone','02_WORKSHOP')
for i in range(1,len(footprint)):
    a,b = footprint[i],footprint[(i+1)%len(footprint)]
    wall('Workshop_Back_Planks_%d'%i,a,b,.042,.126,.626,'door','02_WORKSHOP')
    wall('Workshop_Basalt_Sill_%d'%i,a,b,.061,.126,.220,'stone','02_WORKSHOP')
    wall('Workshop_Eave_Beam_%d'%i,a,b,.069,.593,.659,'timber','02_WORKSHOP')
for i,(x,y) in enumerate(footprint):
    box('Workshop_Heavy_Post_%d'%i,(x,y,.383),(.067,.070,.514),'timber','02_WORKSHOP')
    for z in (.183,.557):
        box('Workshop_Post_Iron_Collar_%d_%s'%(i,z),(x,y,z),(.088,.091,.041),'iron','02_WORKSHOP')
box('Assembly_Portal_Middle_Post',(.170,.168,.383),(.070,.078,.514),'timber','02_WORKSHOP')
box('Assembly_Portal_Header',(0,.166,.632),(1.268,.096,.079),'timber','02_WORKSHOP')
box('Assembly_Portal_Iron_Header',(0,.106,.632),(1.280,.026,.037),'iron','02_WORKSHOP')
for i,(x,sign) in enumerate(((-.545,1),(.120,-1))):
    profile = [(0,0),(sign*.110,0),(0,-.121)]
    vertical_prism('Portal_Triangle_Brace_%d'%i,profile,(x,.153,.594),.060,'timber','02_WORKSHOP')
box('Right_Stores_Basalt',(.394,.285,.194),(.360,.210,.136),'stone','02_WORKSHOP')
box('Right_Stores_Planks',(.394,.285,.422),(.360,.210,.320),'door','02_WORKSHOP')
box('Stores_Slit_Shadow',(.394,.169,.433),(.168,.025,.103),'shadow','02_WORKSHOP')
for x in (.344,.394,.444):
    box('Stores_Slit_Grille_'+str(x),(x,.150,.433),(.014,.020,.098),'iron','02_WORKSHOP')
box('Stores_Slit_Sill',(.394,.148,.365),(.213,.043,.028),'timber','02_WORKSHOP')

# Family rust-red roof. Every course is clipped to the six map boundaries.
for j in range(6):
    width,depth = 1.304-j*.043,.728-j*.113
    points = [(-width/2,.405-depth/2),(width/2,.405-depth/2),
              (width/2,.405+depth/2),(-width/2,.405+depth/2)]
    polygon_prism('Rust_Red_Workshop_Roof_%d'%j,clip_to_hex(points,.852),
                  .684+j*.049,.733+j*.049,'roof','03_ROOFS')
    box('Roof_Front_Iron_Binding_%d'%j,(0,.405-depth/2-.009,.701+j*.049),
        (width,.026,.025),'iron','03_ROOFS')
box('Heavy_Transverse_Ridge',(0,.405,.998),(1.096,.082,.039),'timber','03_ROOFS')
for i,x in enumerate((-.531,.531)):
    box('Ridge_Horn_Iron_Socket_%d'%i,(x,.405,1.018),(.062,.104,.060),'iron','03_ROOFS')
    tusk('Ridge_Horn_%d'%i,(x,.405,1.051),.144,.069,.051,-1 if i==0 else 1,'03_ROOFS')

# Visible workshop chimney and forge, not a full forge building.
box('Forge_Basalt_Block',(.384,.409,.300),(.210,.203,.348),'stone','06_EQUIPMENT')
box('Forge_Fire_Recess',(.384,.299,.303),(.128,.021,.127),'shadow','06_EQUIPMENT')
box('Forge_Embers',(.384,.282,.266),(.098,.015,.032),'glow','08_DETAILS')
box('Forge_Iron_Hood',(.384,.409,.533),(.244,.222,.070),'iron','06_EQUIPMENT')
box('Forge_Smoke_Flue',(.384,.409,.865),(.094,.106,.635),'stone','02_WORKSHOP')
for z in (.816,1.115):
    box('Flue_Iron_Collar_'+str(z),(.384,.409,z),(.121,.130,.037),'iron','02_WORKSHOP')
box('Flue_Dark_Opening',(.384,.409,1.191),(.091,.101,.028),'shadow','08_DETAILS')
for dx in (-.069,.069):
    box('Chimney_Cap_Support_'+str(dx),(.384+dx,.409,1.220),(.025,.124,.057),'iron','02_WORKSHOP')
box('Chimney_Rain_Cap',(.384,.409,1.259),(.192,.176,.026),'iron_light','03_ROOFS')

# Cog and tusks read clearly above the portal in strategic view.
cx,cy,cz = -.120,-.039,.821
box('Cog_Sign_Iron_Frame',(cx,cy,cz),(.374,.044,.345),'iron','08_DETAILS')
box('Cog_Sign_Clan_Cloth',(cx,cy-.032,cz),(.341,.018,.312),'faction','07_FACTION')
gear = [(-.032,.143),(.032,.143),(.032,.107),(.077,.107),(.099,.129),(.129,.099),
        (.107,.077),(.107,.032),(.143,.032),(.143,-.032),(.107,-.032),(.107,-.077),
        (.129,-.099),(.099,-.129),(.077,-.107),(.032,-.107),(.032,-.143),(-.032,-.143),
        (-.032,-.107),(-.077,-.107),(-.099,-.129),(-.129,-.099),(-.107,-.077),
        (-.107,-.032),(-.143,-.032),(-.143,.032),(-.107,.032),(-.107,.077),
        (-.129,.099),(-.099,.129),(-.077,.107),(-.032,.107)]
vertical_prism('Arsenal_Silver_Gear',gear,(cx,cy-.061,cz),.024,'iron_light','08_DETAILS')
box('Gear_Hub_Shadow',(cx,cy-.081,cz),(.095,.017,.095),'shadow','08_DETAILS')
box('Gear_Square_Axle',(cx,cy-.096,cz),(.038,.018,.038),'bone','08_DETAILS')
for sign in (-1,1):
    x = cx+sign*.217
    box('Sign_Tusk_Socket_'+str(sign),(x,cy-.026,.652),(.065,.053,.054),'iron','08_DETAILS')
    tusk('Sign_Clan_Tusk_'+str(sign),(x,cy-.040,.682),.154,.048,.039,sign,'08_DETAILS')

# Original heavy miniature catapult, aimed towards the open front of the hex.
cx,cy = -.264,-.354
for dx in (-.121,.121):
    box('Catapult_Heavy_Chassis_'+str(dx),(cx+dx,cy,.269),(.063,.414,.053),'timber','04_CATAPULT')
    for y in (cy-.151,cy+.151):
        box('Catapult_Rail_Iron_Boot_%s_%s'%(dx,y),(cx+dx,y,.269),(.078,.050,.067),'iron','04_CATAPULT')
for dy in (-.154,.154):
    box('Catapult_Crossmember_'+str(dy),(cx,cy+dy,.275),(.346,.061,.066),'door','04_CATAPULT')
    box('Catapult_Axle_'+str(dy),(cx,cy+dy,.197),(.430,.034,.036),'iron','04_CATAPULT')
    for dx in (-.193,.193):
        wheel('Catapult_Wheel_%s_%s'%(dx,dy),(cx+dx,cy+dy,.195),.205,.047,'04_CATAPULT')
for dx in (-.131,.131):
    box('Catapult_Frame_Post_'+str(dx),(cx+dx,cy,.375),(.051,.065,.208),'timber','04_CATAPULT')
    box('Catapult_Post_Iron_Cap_'+str(dx),(cx+dx,cy,.462),(.068,.080,.050),'iron','04_CATAPULT')
    beam('Catapult_Diagonal_Brace_'+str(dx),(cx+dx,cy+.162,.299),(cx+dx,cy,.445),.038,'door','04_CATAPULT')
box('Catapult_Frame_Crossbar',(cx,cy,.492),(.351,.078,.049),'timber','04_CATAPULT')
box('Catapult_Torsion_Rope_Bundle',(cx,cy-.006,.441),(.331,.075,.060),'rope','04_CATAPULT')
for x in (cx-.132,cx+.132):
    box('Catapult_Torsion_Iron_Collar_'+str(x),(x,cy-.006,.441),(.033,.088,.075),'iron','04_CATAPULT')
beam('Catapult_Raised_Throwing_Arm',(cx,cy-.181,.297),(cx,cy+.196,.736),.049,'door','04_CATAPULT')
box('Catapult_Arm_Iron_Binding',(cx,cy+.128,.657),(.063,.067,.065),'iron','04_CATAPULT')
bx,by = cx,cy+.196
box('Catapult_Spoon_Floor',(bx,by,.754),(.145,.142,.023),'timber','04_CATAPULT')
for dx in (-.072,.072):
    box('Catapult_Spoon_Side_'+str(dx),(bx+dx,by,.784),(.019,.151,.062),'door','04_CATAPULT')
for dy in (-.070,.070):
    box('Catapult_Spoon_End_'+str(dy),(bx,by+dy,.784),(.131,.019,.062),'door','04_CATAPULT')
box('Catapult_Loaded_Stone',(bx,by,.789),(.079,.077,.073),'ammunition','04_CATAPULT')
box('Catapult_Nose_Iron_Plate',(cx,cy-.218,.309),(.303,.032,.085),'iron','04_CATAPULT')
for sign in (-1,1):
    tusk('Catapult_Nose_Tusk_'+str(sign),(cx+sign*.131,cy-.227,.350),.103,.041,.031,sign,'04_CATAPULT')
box('Catapult_Winch_Spindle',(cx,cy-.179,.365),(.310,.030,.031),'iron','04_CATAPULT')
box('Catapult_Winch_Handle',(cx+.166,cy-.179,.391),(.021,.030,.079),'door','04_CATAPULT')
beam('Catapult_Tension_Rope',(cx,cy-.179,.381),(cx,cy-.026,.434),.011,'rope','04_CATAPULT')
box('Catapult_Red_Clan_Plate',(cx,cy-.239,.309),(.120,.015,.056),'faction','07_FACTION')

# Tall angled assembly crane stands outside the eaves and lifts a spare axle.
mx,my = .546,-.095
box('Crane_Basalt_Foot',(mx,my,.137),(.167,.170,.094),'stone','06_EQUIPMENT')
box('Crane_Heavy_Mast',(mx,my,.627),(.075,.079,.939),'timber','06_EQUIPMENT')
for z in (.214,.692,1.052):
    box('Crane_Mast_Iron_Band_'+str(z),(mx,my,z),(.096,.100,.039),'iron','06_EQUIPMENT')
end = Vector((.315,-.365,1.100))
beam('Crane_Diagonal_Jib',(mx,my,1.100),end,.079,'door','06_EQUIPMENT')
beam('Crane_Support_Brace',(mx,my,.801),(.353,-.321,1.059),.046,'timber','06_EQUIPMENT')
box('Crane_Mast_Cap',(mx,my,1.125),(.103,.107,.070),'iron','06_EQUIPMENT')
tusk('Crane_Clan_Horn',(mx,my,1.162),.119,.054,.043,1,'06_EQUIPMENT')
box('Crane_Pulley_Housing',(.315,-.365,1.052),(.098,.093,.069),'iron','06_EQUIPMENT')
box('Crane_Lifting_Chain',(.315,-.365,.853),(.013,.014,.343),'iron_light','06_EQUIPMENT')
for j in range(7):
    box('Crane_Chain_Link_%d'%j,(.315,-.365,.703+j*.047),(.026,.024,.016),'iron','06_EQUIPMENT')
hook = [(-.028,.032),(-.028,-.044),(.030,-.044),(.030,-.009),(.012,-.009),
        (.012,-.025),(-.009,-.025),(-.009,.032)]
vertical_prism('Crane_Open_Hook',hook,(.315,-.365,.657),.020,'iron_light','06_EQUIPMENT')
box('Crane_Suspended_Axle',(.315,-.365,.522),(.262,.052,.060),'door','06_EQUIPMENT')
for sign in (-1,1):
    beam('Crane_Axle_Rope_Sling_'+str(sign),(.315,-.365,.629),(.315+sign*.104,-.365,.552),.014,'rope','06_EQUIPMENT')
    box('Crane_Axle_Iron_Bracket_'+str(sign),(.315+sign*.100,-.365,.522),(.027,.064,.078),'iron','06_EQUIPMENT')
box('Crane_Winch_Body',(.598,-.095,.429),(.064,.110,.096),'iron','06_EQUIPMENT')
box('Crane_Winch_Crank',(.640,-.095,.443),(.044,.020,.020),'iron_light','06_EQUIPMENT')
box('Crane_Winch_Grip',(.659,-.095,.408),(.020,.023,.082),'door','06_EQUIPMENT')

# Bench, spare components, squared stone ammunition and no perimeter wall ring.
box('Workshop_Bench_Top',(-.280,.398,.298),(.421,.125,.034),'door','06_EQUIPMENT')
for x in (-.444,-.116):
    box('Workshop_Bench_Leg_'+str(x),(x,.398,.209),(.034,.085,.144),'timber','06_EQUIPMENT')
box('Bench_Anvil_Foot',(-.389,.393,.343),(.064,.066,.055),'iron','06_EQUIPMENT')
box('Bench_Anvil_Top',(-.389,.393,.385),(.122,.060,.033),'iron_light','06_EQUIPMENT')
box('Assembly_Plan_Parchment',(-.224,.390,.322),(.146,.096,.012),'bone','06_EQUIPMENT')
for y in (.371,.403):
    box('Plan_Ink_Line_'+str(y),(-.224,y,.332),(.109,.006,.005),'shadow','06_EQUIPMENT')
box('Bench_Hammer_Haft',(-.089,.394,.329),(.014,.097,.015),'door','06_EQUIPMENT')
box('Bench_Hammer_Head',(-.089,.425,.343),(.052,.032,.032),'iron_light','06_EQUIPMENT')
wheel('Spare_Wheel',(-.651,.100,.218),.250,.042,'06_EQUIPMENT')
for j in range(3):
    box('Spare_Timber_Stack_%d'%j,(-.625,-.195,.117+j*.040),(.103,.306,.035),'door','06_EQUIPMENT')
for y in (-.289,-.100):
    box('Timber_Stack_Iron_Tie_'+str(y),(-.625,y,.151),(.115,.020,.127),'iron','06_EQUIPMENT')
box('Ammunition_Tray_Floor',(.188,-.605,.111),(.235,.158,.036),'timber','06_EQUIPMENT')
for dx in (-.121,.121):
    box('Ammunition_Tray_Side_'+str(dx),(.188+dx,-.605,.161),(.020,.173,.102),'door','06_EQUIPMENT')
for dy in (-.080,.080):
    box('Ammunition_Tray_End_'+str(dy),(.188,-.605+dy,.161),(.235,.019,.102),'door','06_EQUIPMENT')
for i,(x,y,z) in enumerate(((.126,-.635,.179),(.208,-.635,.179),(.169,-.561,.179),(.166,-.601,.248))):
    box('Stacked_Stone_Ammo_%d'%i,(x,y,z),(.070,.068,.070),'ammunition','06_EQUIPMENT')
box('Stores_Supply_Chest',(.641,.082,.141),(.109,.127,.103),'crate','08_DETAILS')
box('Stores_Chest_Iron_Lid',(.641,.082,.199),(.119,.135,.019),'iron','08_DETAILS')
for i,(x,y) in enumerate(((-.075,.600),(.221,.546))):
    box('Workshop_Iron_Ingot_%d'%i,(x,y,.178),(.080,.104,.070),'iron_light','06_EQUIPMENT')
for i,x in enumerate((-.566,.170)):
    box('Portal_Lamp_Frame_%d'%i,(x,.100,.459),(.035,.043,.060),'iron','08_DETAILS')
    box('Portal_Lamp_Light_%d'%i,(x,.072,.450),(.022,.014,.031),'glow','08_DETAILS')
for i,y in enumerate((-.737,-.808)):
    box('Front_Entry_Paver_%d'%i,(-.066,y,.097),(.146,.066,.014),'cutstone','05_COURTYARD')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_siege_arsenal','orc',True
root['unit_class'] = 'siege'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.450]
scene['door_clearance'] = [.690,.427]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Arsenal de Guerra dos Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_catapult','v2_unit_trebuchet','v2_unit_bombard']
scene['excludes'] = ['v2_legendary_siege_colossus']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[107,113,88],'timber':[78,53,35],'door':[123,89,54],
    'roof':[130,58,39],'roof_dark':[96,47,34],'iron':[53,65,65],
    'iron_light':[152,161,151],'bone':[225,215,174],'faction':[170,60,39],
    'crate':[123,97,58],'yard':[132,125,103],'rope':[174,148,99],
    'ammunition':[128,136,128]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Original orc siege arsenal: low broad basalt-and-heavy-timber assembly shed with genuinely open front bay, hex-clipped rust-red stepped roof, transverse horned ridge, forge chimney and large silver cog with tusks on clan-red sign. Foreground static four-wheeled reinforced torsion catapult with loaded open spoon, iron nose and ivory tusks; angled timber crane with chain, open hook and suspended spare axle. Wheel and timber stocks, stone ammunition tray, anvil, hammer and parchment assembly plan. Same regular catapult/trebuchet/bombard line; legendary siege colossus belongs to separate mastery building. No unit dependencies, animation or perimeter wall ring.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
