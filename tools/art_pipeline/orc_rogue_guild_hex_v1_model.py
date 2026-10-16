"""Original blocky orc assassination guild. Execute in the live Blender MCP."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_Rogue_Guild_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_rogue_guild_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc Rogue Guild source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_ANNEX','05_COURTYARD',
              '06_TRAINING','07_FACTION','08_DETAILS','09_STUDIO'):
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
    ('rogue_guild_hex_v1_model.py',('dagger',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))

polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Guild_Moss_Paving',hexagon(.85),.062,.079,'paving','01_FOUNDATION')

# Narrow rear hall and attached low wing, both follow the rear tile diagonals.
footprint = [(-.550,.040),(.150,.040),(.150,.430),(-.180,.660),(-.550,.430)]
polygon_prism('Guild_Basalt_Foot',footprint,.079,.186,'stone','02_HALL')
polygon_prism('Guild_Dark_Timber_Body',footprint,.186,.620,'door','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Lower_Beam_%d'%i,a,b,.041,.175,.211,'timber','02_HALL')
    wall('Hall_Eave_Beam_%d'%i,a,b,.054,.593,.650,'timber','02_HALL')
    box('Hall_Corner_Post_%d'%i,(a[0],a[1],.397),(.062,.064,.438),'timber','02_HALL')
    for z in (.236,.556):
        box('Hall_Post_Iron_Collar_%d_%s'%(i,z),(a[0],a[1],z),(.079,.081,.033),'iron','02_HALL')
for x in (-.426,.025):
    box('Hall_Front_Stud_'+str(x),(x,.021,.398),(.030,.035,.388),'timber','02_HALL')
for j in range(6):
    width,depth = .878-j*.117,.774-j*.057
    points = [(-.200-width/2,.305-depth/2),(-.200+width/2,.305-depth/2),
              (-.200+width/2,.305+depth/2),(-.200-width/2,.305+depth/2)]
    polygon_prism('Dark_Hide_Hood_Roof_%d'%j,clip_to_hex(points,.852),
                  .648+j*.054,.702+j*.054,'roof','03_ROOFS')
    box('Roof_Front_Iron_Edge_%d'%j,(-.200,.305-depth/2-.008,.670+j*.054),
        (width,.025,.023),'iron','03_ROOFS')
box('Heavy_Dark_Ridge',(-.200,.305,.994),(.083,.481,.041),'timber','03_ROOFS')
for i,y in enumerate((.082,.526)):
    box('Ridge_Rust_Red_Binding_%d'%i,(-.200,y,1.010),(.109,.051,.042),'roof_red','03_ROOFS')
    tusk('Ridge_Short_Tusk_%d'%i,(-.200,y,1.032),.103,.058,.046,1,'03_ROOFS')

# Discreet, offset single entrance under a heavy lintel.
dx = -.205
box('Entry_Dark_Recess',(dx,.014,.366),(.241,.033,.316),'shadow','02_HALL')
box('Entry_Door',(dx,-.007,.361),(.204,.024,.283),'door','02_HALL')
for z in (.260,.462):
    box('Entry_Iron_Strap_'+str(z),(dx,-.023,z),(.203,.020,.026),'iron','02_HALL')
for sign in (-1,1):
    box('Entry_Heavy_Jamb_'+str(sign),(dx+sign*.139,-.003,.368),(.043,.066,.354),'timber','02_HALL')
box('Entry_Lintel',(dx,-.016,.558),(.343,.099,.054),'timber','02_HALL')
box('Entry_Lock',(dx+.060,-.040,.348),(.021,.021,.030),'iron_light','08_DETAILS')
for i,(y,top) in enumerate(((-.048,.180),(-.129,.130),(-.212,.101))):
    box('Entry_Stone_Step_%d'%i,(dx,y,(.079+top)/2),(.283+i*.022,.086,top-.079),'cutstone','05_COURTYARD')
box('Hall_Left_Window_Shadow',(-.579,.226,.405),(.023,.130,.106),'shadow','02_HALL')
for y in (.182,.226,.270):
    box('Hall_Left_Window_Grille_'+str(y),(-.594,y,.405),(.017,.013,.100),'iron','02_HALL')
box('Rear_Window_Shadow',(-.348,.560,.439),(.122,.028,.126),'shadow','02_HALL',-.61)
box('Rear_Window_Shutter',(-.359,.578,.437),(.103,.023,.109),'door','02_HALL',-.61)

# Silver hood and crossed short daggers project forward of the roof, readable from above.
box('Guild_Sign_Iron_Frame',(dx,-.130,.760),(.356,.039,.356),'iron','08_DETAILS')
box('Guild_Sign_Clan_Cloth',(dx,-.157,.760),(.318,.018,.318),'faction','07_FACTION')
hood = [(-.114,-.032),(.114,-.032),(.114,.045),(.077,.045),
        (.077,.104),(.030,.160),(-.030,.160),(-.077,.104),(-.077,.045),(-.114,.045)]
vertical_prism('Crest_Hood',hood,(dx,-.182,.774),.023,'iron_light','08_DETAILS')
face = [(-.070,-.012),(.070,-.012),(.070,.039),(.028,.101),(-.028,.101),(-.070,.039)]
vertical_prism('Crest_Face_Shadow',face,(dx,-.200,.774),.017,'shadow','08_DETAILS')
box('Crest_Narrow_Eyes',(dx,-.214,.805),(.085,.011,.016),'bone','08_DETAILS')
for sign in (-1,1):
    tusk('Crest_Little_Tusk_'+str(sign),(dx+sign*.069,-.220,.739),.068,.027,.014,sign,'08_DETAILS')
dagger('Crest_Left_Dagger',(dx-.029,-.220,.657),.228,.71,'08_DETAILS')
dagger('Crest_Right_Dagger',(dx+.029,-.241,.657),.228,-.71,'08_DETAILS')
for x in (dx-.155,dx+.155):
    for z in (.606,.914):
        box('Sign_Rivet_%s_%s'%(x,z),(x,-.155,z),(.013,.017,.013),'iron_light','08_DETAILS')

# Low storehouse and dark red canvas awning form a sheltered equipment corner.
annex = [(.140,.153),(.610,.153),(.610,.328),(.286,.543),(.140,.443)]
polygon_prism('Annex_Basalt_Base',annex,.079,.150,'stone','04_ANNEX')
polygon_prism('Annex_Plank_Body',annex,.150,.480,'door','04_ANNEX')
for i,a in enumerate(annex):
    b = annex[(i+1)%len(annex)]
    wall('Annex_Eave_%d'%i,a,b,.043,.447,.495,'timber','04_ANNEX')
    box('Annex_Post_%d'%i,(a[0],a[1],.314),(.044,.045,.331),'timber','04_ANNEX')
for j in range(4):
    xa,xb = .120+j*.132,.120+(j+1)*.132+.008
    points = [(xa,.093),(xb,.093),(xb,.595),(xa,.595)]
    polygon_prism('Annex_Lean_Roof_%d'%j,clip_to_hex(points,.840),
                  .684-j*.057,.726-j*.057,'roof_dark','03_ROOFS')
    box('Annex_Red_Roof_Edge_%d'%j,((xa+xb)/2,.082,.699-j*.057),
        (xb-xa,.024,.024),'roof_red','03_ROOFS')
box('Annex_Door_Recess',(.431,.135,.302),(.148,.025,.233),'shadow','04_ANNEX')
box('Annex_Door_Leaf',(.431,.114,.298),(.122,.025,.212),'door','04_ANNEX')
for z in (.222,.374):
    box('Annex_Door_Strap_'+str(z),(.431,.093,z),(.119,.020,.023),'iron','04_ANNEX')
box('Annex_Small_Lock',(.470,.077,.301),(.015,.015,.021),'iron_light','04_ANNEX')
for x in (.181,.607):
    box('Awning_Post_'+str(x),(x,-.123,.273),(.029,.034,.385),'timber','04_ANNEX')
for j in range(3):
    box('Charcoal_Cloth_Awning_%d'%j,(.394,-.091+j*.069,.474+j*.025),
        (.487,.072,.026),'canvas','03_ROOFS')
box('Clan_Awning_Valance',(.394,-.135,.448),(.487,.023,.056),'faction','07_FACTION')
for i,x in enumerate((.191,.277,.363,.449,.535,.598)):
    box('Valance_Ragged_Hem_%d'%i,(x,-.135,.412),(.033,.023,.026+(i%2)*.012),'faction','07_FACTION')

# A small knife practice court and a separate closed cellar hatch.
polygon_prism('Training_Dirt_Wedge',[(-.638,-.191),(.654,-.212),(.570,-.405),
    (.295,-.642),(0,-.822),(-.350,-.586),(-.643,-.323)],.079,.091,'sand','05_COURTYARD')
for i,(x,y) in enumerate(((-.188,-.344),(-.109,-.486),(-.042,-.648))):
    box('Entry_Paver_%d'%i,(x,y,.102),(.159,.114,.022),'paving','05_COURTYARD',-.14)
for x in (.157,.335):
    box('Cellar_Hatch_Frame_'+str(x),(x,-.548,.112),(.025,.238,.036),'iron','05_COURTYARD')
for y in (-.650,-.446):
    box('Cellar_Hatch_Frame_'+str(y),(.246,y,.112),(.183,.028,.036),'iron','05_COURTYARD')
box('Closed_Cellar_Hatch',(.246,-.548,.110),(.151,.179,.028),'door','05_COURTYARD')
for y in (-.605,-.491):
    box('Cellar_Hatch_Iron_Strap_'+str(y),(.246,y,.131),(.145,.018,.014),'iron','05_COURTYARD')
box('Cellar_Hatch_Handle',(.278,-.550,.143),(.020,.040,.011),'iron_light','05_COURTYARD')

x,y = .485,-.315
box('Precision_Dummy_Foot',(x,y,.111),(.156,.127,.039),'timber','06_TRAINING')
box('Precision_Dummy_Stake',(x,y,.239),(.032,.034,.248),'timber','06_TRAINING')
box('Precision_Dummy_Torso',(x,y,.327),(.103,.074,.144),'straw','06_TRAINING')
box('Precision_Dummy_Shoulders',(x,y,.378),(.171,.066,.037),'straw','06_TRAINING')
box('Precision_Dummy_Head',(x,y,.431),(.079,.074,.069),'straw','06_TRAINING')
box('Precision_Dummy_Throat_Mark',(x,y-.045,.399),(.041,.013,.020),'target_red','06_TRAINING')
box('Precision_Dummy_Heart_Mark',(x+.021,y-.045,.337),(.028,.013,.031),'target_red','06_TRAINING')
dagger('Dummy_Planted_Dagger',(x+.021,y-.064,.305),.131,.18,'06_TRAINING')

x,y = -.445,-.335
box('Knife_Target_Base',(x,y,.111),(.153,.112,.036),'timber','06_TRAINING')
box('Knife_Target_Post',(x,y,.259),(.029,.034,.287),'timber','06_TRAINING')
box('Knife_Target_Board',(x,y,.405),(.212,.041,.217),'door','06_TRAINING')
box('Knife_Target_Ivory_Ring',(x,y-.030,.405),(.157,.018,.162),'bone','06_TRAINING')
box('Knife_Target_Red_Center',(x,y-.044,.405),(.060,.013,.064),'target_red','06_TRAINING')
dagger('Target_Embedded_Dagger',(x-.018,y-.064,.373),.147,-.27,'06_TRAINING')

# Blade bench and stoppered preparation bottles, not a magic tower.
box('Knife_Bench_Top',(.364,-.038,.234),(.278,.137,.027),'door','06_TRAINING')
for x in (.265,.463):
    box('Knife_Bench_Leg_'+str(x),(x,-.038,.153),(.028,.089,.155),'timber','06_TRAINING')
box('Knife_Bench_Blade_Rail',(.357,-.117,.268),(.229,.024,.027),'iron','06_TRAINING')
for i,x in enumerate((.280,.357,.434)):
    dagger('Stored_Dagger_%d'%i,(x,-.139,.273),.170,(-1)**i*.12,'06_TRAINING')
for i,(x,region) in enumerate(((.288,'bottle_green'),(.382,'bottle_amber'))):
    box('Preparation_Bottle_%d'%i,(x,-.015,.273),(.036,.035,.052),'bottle_green' if i==0 else region,'08_DETAILS')
    box('Bottle_Neck_%d'%i,(x,-.015,.307),(.020,.021,.019),region,'08_DETAILS')
    box('Bottle_Stopper_%d'%i,(x,-.015,.322),(.023,.023,.012),'leather','08_DETAILS')
box('Supply_Chest',(-.645,.094,.131),(.101,.143,.108),'crate','08_DETAILS')
box('Supply_Chest_Iron_Lid',(-.645,.094,.191),(.108,.148,.020),'iron','08_DETAILS')
box('Supply_Chest_Lock',(-.645,.015,.146),(.027,.016,.036),'iron_light','08_DETAILS')
for i,(x,y) in enumerate(((-.653,-.205),(.075,.747),(.652,.025))):
    box('Moss_Shrub_Base_%d'%i,(x,y,.116),(.103,.088,.058),'foliage','08_DETAILS')
    box('Moss_Shrub_Top_%d'%i,(x+.011,y,.160),(.070,.062,.036),'foliage_light','08_DETAILS')
for i,(x,y,z) in enumerate(((-.376,-.038,.431),(.621,.128,.335))):
    box('Shielded_Lamp_Frame_%d'%i,(x,y,z),(.039,.040,.059),'iron','08_DETAILS')
    box('Shielded_Lamp_Light_%d'%i,(x,y-.025,z-.007),(.024,.013,.029),'glow','08_DETAILS')
    box('Shielded_Lamp_Hood_%d'%i,(x,y-.006,z+.038),(.058,.058,.025),'iron','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_rogue_guild','orc',True
root['unit_class'] = 'rogue'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.410]
scene['door_clearance'] = [.204,.283]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Guilda dos Ladinos Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_rogue','v2_unit_saboteur','v2_unit_assassin']
scene['excludes'] = ['v2_legendary_shadow_master']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[101,110,90],'timber':[67,47,34],'door':[99,76,51],
    'roof':[130,58,39],'roof_dark':[96,47,34],'roof_red':[117,53,36],
    'iron':[45,57,57],'iron_light':[169,178,164],'bone':[225,215,174],
    'faction':[170,60,39],'canvas':[96,47,34],'brass':[137,131,108],
    'leather':[72,53,38],'target_red':[167,60,39],'sand':[132,118,85],
    'crate':[113,87,54],'foliage':[67,87,57],'foliage_light':[86,109,65],
    'bottle_green':[58,130,87],'bottle_amber':[153,101,48]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Original orc rogue guild: asymmetric dark timber and basalt rear hall with rust-red stepped hood roof matching the orc building family, short ivory ridge tusks and rust-red bindings; prominent silver hood, narrow eyes, little tusks and crossed short daggers on clan-red plaque. Low attached storehouse with dark red roof and canvas awning, ragged red awning valance, blade bench and stoppered preparation bottles. Open precision training yard with one straw marked-throat/heart dummy and one knife-throwing board, separate closed cellar hatch and moss shrubs. Same regular rogue/saboteur/assassin line; legendary shadow master belongs to separate mastery building. No character dependency, watchtower or perimeter wall ring.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
