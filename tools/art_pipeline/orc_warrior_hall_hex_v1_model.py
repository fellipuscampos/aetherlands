"""Original orc warrior training hall, blocky 4X hex asset. Live Blender MCP."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_Warrior_Hall_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_warrior_hall_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc Warrior Hall source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_ARMORY','05_COURTYARD',
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
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def axe(name,center,length,angle=0,blade_side=1,group='08_DETAILS'):
    # Bake orientation into vertices; all editable source transforms remain identity.
    c = Vector(center)
    up,right = Vector((math.sin(angle),0,math.cos(angle))),Vector((math.cos(angle),0,-math.sin(angle)))
    def component(suffix,profile,depth,region):
        n = len(profile)
        verts = [tuple(c+right*(x*length)+up*(z*length)+Vector((0,y,0)))
                 for y in (-depth/2,depth/2) for x,z in profile]
        faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return mesh(name+'_'+suffix,verts,faces,region,group)
    component('Haft',[(-.030,-.50),(.030,-.50),(.030,.49),(-.030,.49)],.025,'timber')
    component('Grip',[(-.041,-.43),(.041,-.43),(.041,-.23),(-.041,-.23)],.029,'iron')
    head = [(-.048,.23),(.056,.23),(.056,.15),(.244,.15),(.244,.25),
            (.294,.25),(.294,.44),(.235,.44),(.235,.52),(.056,.52),
            (.056,.44),(-.048,.44)]
    component('Heavy_Blade',[(blade_side*x,z) for x,z in head],.031,'iron_light')
    component('Head_Collar',[(-.073,.22),(.082,.22),(.082,.44),(-.073,.44)],.037,'iron')


polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Hex_Paving',hexagon(.85),.062,.077,'paving','01_FOUNDATION')
footprint = [(-.545,.090),(.395,.090),(.395,.340),(.120,.571),(-.324,.571),(-.545,.340)]
polygon_prism('Warrior_Hall_Stone_Foot',footprint,.077,.167,'cutstone','02_HALL')
polygon_prism('Warrior_Hall_Lower_Basalt',footprint,.167,.316,'stone','02_HALL')
polygon_prism('Warrior_Hall_Heavy_Timber',footprint,.316,.625,'door','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Base_Beam_%d'%i,a,b,.040,.159,.193,'timber','02_HALL')
    wall('Hall_Iron_Band_%d'%i,a,b,.045,.306,.339,'iron','02_HALL')
    wall('Hall_Eave_Beam_%d'%i,a,b,.061,.586,.651,'timber','02_HALL')
    box('Hall_Corner_Post_%d'%i,(a[0],a[1],.387),(.073,.077,.458),'timber','02_HALL')
    for z in (.213,.550):
        box('Post_Iron_Collar_%d_%s'%(i,z),(a[0],a[1],z),(.090,.094,.042),'iron','02_HALL')

# Broad transverse ridge: different silhouette from the taller tank hall.
for j in range(6):
    width,depth = 1.167-j*.045,.692-j*.103
    points = [(-.075-width/2,.306-depth/2),(-.075+width/2,.306-depth/2),
              (-.075+width/2,.306+depth/2),(-.075-width/2,.306+depth/2)]
    polygon_prism('Transverse_Hide_Roof_%d'%j,clip_to_hex(points,.852),
                  .653+j*.055,.708+j*.055,'roof','03_ROOFS')
    box('Roof_Front_Iron_Binding_%d'%j,(-.075,.306-depth/2-.007,.674+j*.055),
        (width,.032,.026),'iron','03_ROOFS')
box('Roof_Transverse_Ridge',(-.075,.306,1.004),(.981,.079,.040),'timber','03_ROOFS')
for i,x in enumerate((-.563,.413)):
    box('Ridge_Iron_Horn_Socket_%d'%i,(x,.306,1.018),(.057,.103,.059),'iron','03_ROOFS')
    tusk('Roof_Horn_%d'%i,(x,.306,1.048),.149,.072,.058,1 if i else -1,'03_ROOFS')

# Framed door and crossed axes mounted clearly forward of all roof courses.
dx = -.119
box('Portal_Shadow',(dx,.074,.366),(.273,.035,.343),'shadow','02_HALL')
for sign in (-1,1):
    box('Portal_Door_Leaf_'+str(sign),(dx+sign*.060,.048,.362),(.112,.026,.300),'door','02_HALL')
    box('Portal_Heavy_Jamb_'+str(sign),(dx+sign*.166,.051,.363),(.050,.092,.370),'timber','02_HALL')
    for z in (.262,.465):
        box('Portal_Door_Strap_%s_%s'%(sign,z),(dx+sign*.060,.026,z),(.108,.024,.027),'iron','02_HALL')
    box('Portal_Handle_'+str(sign),(dx+sign*.025,.007,.363),(.019,.023,.027),'iron_light','08_DETAILS')
box('Portal_Heavy_Lintel',(dx,.043,.566),(.426,.116,.061),'timber','02_HALL')
box('Axe_Emblem_Iron_Frame',(dx,-.090,.733),(.363,.044,.341),'iron','02_HALL')
box('Axe_Emblem_Clan_Cloth',(dx,-.120,.733),(.330,.018,.307),'faction','07_FACTION')
axe('Emblem_Left_Axe',(dx,-.150,.730),.317,-.55,-1)
axe('Emblem_Right_Axe',(dx,-.188,.730),.317,.55,1)
for sign in (-1,1):
    x = dx+sign*.228
    box('Entry_Horn_Socket_'+str(sign),(x,-.018,.179),(.085,.088,.099),'iron','02_HALL')
    tusk('Entry_Short_Tusk_'+str(sign),(x,-.034,.229),.219,.067,.057,sign)
for i,(y,width,top) in enumerate(((.010,.317,.165),(-.077,.351,.129),(-.164,.386,.099))):
    box('Entry_Step_%d'%i,(dx,y,(.077+top)/2),(width,.090,top-.077),'cutstone','05_COURTYARD')

# Attached open weapon shelter, roof falling towards the outside of the hex.
for x in (.416,.670):
    for y in (-.033,.314):
        height = .449 if x>.6 else .579
        box('Armory_Post_%s_%s'%(x,y),(x,y,.077+height/2),(.040,.045,height),'timber','04_ARMORY')
        box('Armory_Post_Socket_%s_%s'%(x,y),(x,y,.119),(.058,.063,.075),'iron','04_ARMORY')
for j in range(3):
    box('Armory_Lean_Roof_%d'%j,(.439+j*.097,.142,.653-j*.058),(.112,.439,.047),'roof_dark','03_ROOFS')
    box('Armory_Roof_Iron_Edge_%d'%j,(.439+j*.097,-.084,.653-j*.058),(.116,.022,.028),'iron','03_ROOFS')
box('Armory_Front_Header',(.548,-.033,.481),(.297,.048,.040),'timber','04_ARMORY')
for x in (.476,.632):
    box('Axe_Rack_Post_'+str(x),(x,-.073,.236),(.024,.037,.291),'timber','04_ARMORY')
box('Axe_Rack_Rail',(.554,-.073,.376),(.219,.046,.026),'iron','04_ARMORY')
axe('Rack_Left_Axe',(.486,-.106,.283),.347,-.12,-1,'04_ARMORY')
axe('Rack_Right_Axe',(.610,-.134,.283),.347,.13,1,'04_ARMORY')
box('Armory_Supply_Chest',(.553,.217,.136),(.166,.108,.118),'crate','04_ARMORY')
box('Armory_Chest_Latch',(.553,.156,.151),(.033,.017,.042),'iron','04_ARMORY')

# Open sparring court, shaped around the actual pointy-top tile boundaries.
polygon_prism('Sparring_Sand_Wedge',[(-.605,-.147),(.442,-.147),(.590,-.286),
    (.394,-.571),(0,-.820),(-.402,-.577),(-.644,-.288)],.077,.091,'sand','05_COURTYARD')
polygon_prism('Entry_Paving_Wedge',[(-.279,-.112),(.040,-.112),(.018,-.551),
    (0,-.828),(-.201,-.568)],.091,.105,'paving','05_COURTYARD')
for i,(x,y) in enumerate(((-.367,-.364),(.183,-.434))):
    box('Melee_Dummy_Base_%d'%i,(x,y,.119),(.158,.131,.056),'timber','06_TRAINING')
    box('Melee_Dummy_Post_%d'%i,(x,y,.278),(.039,.043,.284),'timber','06_TRAINING')
    box('Melee_Dummy_Arms_%d'%i,(x,y,.338),(.196,.045,.040),'timber','06_TRAINING')
    box('Melee_Dummy_Straw_Torso_%d'%i,(x,y-.025,.312),(.106,.075,.164),'straw','06_TRAINING')
    box('Melee_Dummy_Straw_Head_%d'%i,(x,y,.445),(.076,.071,.079),'straw','06_TRAINING')
    for j in range(3):
        scratch = [(-.004,-.043),(.004,-.043),(.020,.043),(.012,.043)]
        vertical_prism('Dummy_Slash_%d_%d'%(i,j),scratch,(x-.029+j*.023,y-.068,.321),
                       .008,'shadow','06_TRAINING')
    box('Sparring_Position_%d'%i,(x*.89,y-.181,.100),(.135,.075,.018),'formation','06_TRAINING')

# Small charcoal brazier, supply crates and barred slit in the front wall.
fx,fy = -.568,-.083
box('Brazier_Stone_Foot',(fx,fy,.105),(.154,.153,.056),'stone','08_DETAILS')
box('Brazier_Coal',(fx,fy,.145),(.110,.108,.026),'shadow','08_DETAILS')
for a,b in ((-.062,0),(.062,0),(0,-.061),(0,.061)):
    box('Brazier_Iron_Rim_%s_%s'%(a,b),(fx+a,fy+b,.161),
        (.023 if a else .124,.023 if b else .129,.067),'iron','08_DETAILS')
for i,(a,b,h) in enumerate(((-.022,0,.076),(.019,.007,.108))):
    box('Brazier_Fire_%d'%i,(fx+a,fy+b,.145+h/2),(.033,.031,h),'glow','08_DETAILS')
for i,(x,y) in enumerate(((-.648,.092),(-.600,.208))):
    box('Supply_Crate_%d'%i,(x,y,.131),(.094,.093,.108),'crate','08_DETAILS')
box('Front_Window',(.233,.071,.453),(.095,.028,.119),'shadow','02_HALL')
for x in (.203,.233,.263):
    box('Front_Window_Grille_'+str(x),(x,.050,.453),(.014,.021,.113),'iron','02_HALL')
for z in (.383,.523):
    box('Front_Window_Beam_'+str(z),(.233,.046,z),(.131,.046,.025),'timber','02_HALL')

# Short clan banner at the exposed forward edge of the armory.
px,py = .645,-.246
box('Clan_Banner_Stone',(px,py,.111),(.094,.099,.067),'stone','08_DETAILS')
box('Clan_Banner_Pole',(px,py,.521),(.019,.022,.803),'timber','08_DETAILS')
box('Clan_Banner_Cap',(px,py,.941),(.035,.038,.032),'iron_light','08_DETAILS')
box('Warrior_Clan_Faction_Banner',(px-.066,py,.801),(.142,.018,.187),'faction','07_FACTION')
axe('Banner_Axe',(px-.066,py-.024,.800),.137,.20,1)
for sign in (-1,1):
    x = dx+sign*.122
    box('Door_Lamp_Frame_'+str(sign),(x,-.027,.440),(.033,.043,.055),'iron','08_DETAILS')
    box('Door_Lamp_Glow_'+str(sign),(x,-.053,.440),(.020,.013,.035),'glow','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_warrior_hall','orc',True
root['unit_class'] = 'warrior'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.43]
scene['door_clearance'] = [.226,.300]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Salão de Armas dos Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_warrior','v2_unit_swordsman','v2_unit_weapon_master']
scene['excludes'] = ['v2_legendary_blade_hero']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[107,113,88],'timber':[78,53,35],'door':[123,89,54],
    'roof':[130,58,39],'roof_dark':[96,47,34],'iron':[53,65,65],
    'iron_light':[152,161,151],'bone':[225,215,174],'faction':[170,60,39],
    'crate':[123,97,58],'sand':[145,126,84],'formation':[180,164,125]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Orc warrior hall: broad low basalt-and-timber barracks, transverse stepped rust-red hide roof and horned ridge, prominent crossed heavy axes forward of roof. Open right lean-to armory with two axes and supply chest, two straw melee targets with slash marks in the wedge sparring yard, charcoal brazier and clan pennant. Shared warrior line and evolutions; supreme blade hero remains in the separate mastery building. No watchtower or shield training equipment.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
