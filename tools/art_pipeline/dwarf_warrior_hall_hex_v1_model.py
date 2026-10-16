"""Original dwarven warrior hall, blocky hex-map asset. Live Blender MCP only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Dwarf_Warrior_Hall_Hex_V1'
RELATIVE_OUT = 'assets/generated/dwarves/buildings/dwarf_warrior_hall_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Dwarf Warrior Hall source scene exists; preserve its edits.')
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
    ('dwarf_city_level_1_hex_v1_model.py',('hammer',)),
    ('dwarf_guardian_hall_hex_v1_model.py',('pillar_rune',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def dwarf_weapon(name,center,length,kind='axe',angle=0,group='08_DETAILS'):
    # Bake a rotated XZ profile into closed meshes, preserving identity transforms.
    c = Vector(center)
    up = Vector((math.sin(angle),0,math.cos(angle)))
    across = Vector((math.cos(angle),0,-math.sin(angle)))
    def component(suffix,profile,depth,region):
        n = len(profile)
        verts = [tuple(c+across*(x*length)+up*(z*length)+Vector((0,y,0)))
                 for y in (-depth/2,depth/2) for x,z in profile]
        faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return mesh(name+'_'+suffix,verts,faces,region,group)
    component('Timber_Haft',[(-.028,-.50),(.028,-.50),(.028,.43),(-.028,.43)],.023,'timber')
    component('Copper_Grip',[(-.041,-.43),(.041,-.43),(.041,-.22),(-.041,-.22)],.029,'bronze')
    component('Steel_Pommel',[(-.047,-.53),(.047,-.53),(.047,-.46),(-.047,-.46)],.031,'iron_light')
    if kind=='axe':
        profile = [(-.065,.213),(-.195,.159),(-.257,.159),(-.257,.447),
                   (-.195,.447),(-.065,.400),(.065,.400),(.195,.447),
                   (.257,.447),(.257,.159),(.195,.159),(.065,.213)]
        component('Double_Stepped_Blade',profile,.034,'iron_light')
        for side in (-1,1):
            component('Blade_Inlay_'+str(side),[(side*.164,.212),(side*.194,.212),
                      (side*.194,.396),(side*.164,.396)],.039,'bronze')
    else:
        profile = [(-.248,.208),(.248,.208),(.248,.429),(.179,.429),
                   (.179,.474),(-.179,.474),(-.179,.429),(-.248,.429)]
        component('Heavy_Steel_Hammer_Head',profile,.054,'iron_light')
        for side in (-1,1):
            component('Hammer_Copper_Face_'+str(side),[(side*.203,.204),(side*.270,.204),
                      (side*.270,.438),(side*.203,.438)],.063,'bronze')
    component('Head_Copper_Collar',[(-.071,.198),(.071,.198),(.071,.438),(-.071,.438)],.067,'bronze')


polygon_prism('Hex_Granite_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Carved_Stone_Rim',hexagon(.90),.035,.063,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Stone_Paving',hexagon(.85),.063,.079,'paving','01_FOUNDATION')

# Broad rear granite hall; short transverse roof differs from the tank hall vault.
footprint = [(-.550,.055),(.340,.055),(.340,.338),(.118,.571),(-.327,.571),(-.550,.338)]
polygon_prism('Hall_Granite_Platform',footprint,.079,.172,'stone','02_HALL')
polygon_prism('Hall_Heavy_Stone_Body',footprint,.172,.584,'stone','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Base_Course_%d'%i,a,b,.042,.169,.211,'cutstone','02_HALL')
    wall('Hall_Eave_Course_%d'%i,a,b,.060,.554,.620,'cutstone','02_HALL')
    box('Hall_Stone_Buttress_%d'%i,(a[0],a[1],.370),(.074,.079,.387),'cutstone','02_HALL')
    box('Buttress_Granite_Foot_%d'%i,(a[0],a[1],.201),(.106,.111,.110),'stone','02_HALL')
    box('Buttress_Copper_Collar_%d'%i,(a[0],a[1],.494),(.090,.096,.038),'bronze','02_HALL')
for j in range(6):
    width,depth = 1.126-j*.044,.720-j*.111
    points = [(-.105-width/2,.306-depth/2),(-.105+width/2,.306-depth/2),
              (-.105+width/2,.306+depth/2),(-.105-width/2,.306+depth/2)]
    polygon_prism('Transverse_Slate_Roof_%d'%j,clip_to_hex(points,.852),
                  .625+j*.052,.677+j*.052,'roof','03_ROOFS')
    box('Copper_Roof_Front_Binding_%d'%j,(-.105,.306-depth/2-.008,.642+j*.052),
        (width+.010,.032,.027),'bronze','03_ROOFS')
box('Transverse_Broad_Ridge',(-.105,.306,.959),(.916,.102,.043),'roof_dark','03_ROOFS')
for x in (-.535,.325):
    box('Ridge_Copper_Collar_'+str(x),(x,.306,.973),(.038,.128,.062),'bronze','03_ROOFS')

# A squat carved portal and a large crossed axe/hammer plaque.
dx = -.105
box('Portal_Recess',(dx,.031,.343),(.275,.035,.296),'shadow','02_HALL')
for sign in (-1,1):
    box('Door_Leaf_'+str(sign),(dx+sign*.060,.009,.336),(.112,.026,.260),'door','02_HALL')
    box('Portal_Stone_Jamb_'+str(sign),(dx+sign*.153,.010,.349),(.047,.088,.339),'cutstone','02_HALL')
    for z in (.248,.425):
        box('Door_Copper_Strap_%s_%s'%(sign,z),(dx+sign*.060,-.014,z),(.109,.024,.027),'bronze','02_HALL')
    box('Door_Copper_Handle_'+str(sign),(dx+sign*.026,-.033,.336),(.019,.023,.028),'bronze','08_DETAILS')
box('Portal_Stone_Lintel',(dx,-.002,.543),(.403,.121,.068),'cutstone','02_HALL')
box('Portal_Copper_Inlay',(dx,-.069,.544),(.349,.018,.022),'bronze','08_DETAILS')
for sign in (-1,1):
    x = dx+sign*.257
    box('Portal_Pilaster_Foot_'+str(sign),(x,.010,.202),(.113,.127,.153),'stone','02_HALL')
    box('Portal_Pilaster_Shaft_'+str(sign),(x,.009,.376),(.081,.093,.240),'cutstone','02_HALL')
    box('Portal_Pilaster_Capital_'+str(sign),(x,.006,.518),(.118,.129,.051),'stone','02_HALL')
    box('Pilaster_Copper_Cap_'+str(sign),(x,-.031,.541),(.121,.070,.023),'bronze','08_DETAILS')
    pillar_rune('Warrior_Portal_Rune_'+str(sign),x,-.047,.373,.033,.111)
box('Weapons_Sign_Iron_Frame',(dx,-.128,.738),(.402,.042,.358),'iron','08_DETAILS')
box('Weapons_Sign_Blue_Cloth',(dx,-.158,.738),(.365,.018,.322),'faction','07_FACTION')
dwarf_weapon('Emblem_Battle_Axe',(dx-.020,-.191,.734),.332,'axe',-.59)
dwarf_weapon('Emblem_War_Hammer',(dx+.020,-.233,.734),.332,'hammer',.59)
for x in (dx-.179,dx+.179):
    for z in (.587,.889):
        box('Weapons_Sign_Copper_Rivet_%s_%s'%(x,z),(x,-.156,z),(.015,.019,.015),'bronze','08_DETAILS')
for i,(y,width,top) in enumerate(((-.056,.308,.170),(-.141,.350,.130),(-.228,.393,.101))):
    box('Entry_Granite_Step_%d'%i,(dx,y,(.079+top)/2),(width,.092,top-.079),'cutstone','05_COURTYARD')

# Open right weapon shelter with a low copper-bound slate lean-to roof.
for x in (.390,.648):
    for y in (-.061,.302):
        height = .424 if x>.6 else .560
        box('Armory_Stone_Post_%s_%s'%(x,y),(x,y,.079+height/2),(.046,.049,height),'cutstone','04_ARMORY')
        box('Armory_Post_Copper_Foot_%s_%s'%(x,y),(x,y,.137),(.064,.067,.061),'bronze','04_ARMORY')
for j in range(3):
    box('Armory_Slate_Lean_Roof_%d'%j,(.410+j*.099,.123,.663-j*.060),
        (.119,.444,.044),'roof_dark','03_ROOFS')
    box('Armory_Copper_Roof_Edge_%d'%j,(.410+j*.099,-.108,.662-j*.060),
        (.126,.027,.026),'bronze','03_ROOFS')
box('Armory_Front_Header',(.519,-.061,.477),(.305,.048,.042),'timber','04_ARMORY')
for x in (.448,.602):
    box('Weapons_Rack_Iron_Post_'+str(x),(x,-.100,.243),(.023,.030,.305),'iron','04_ARMORY')
box('Weapons_Rack_Timber_Rail',(.525,-.100,.391),(.234,.043,.027),'timber','04_ARMORY')
dwarf_weapon('Reserve_Battle_Axe',(.447,-.137,.285),.341,'axe',-.09,'04_ARMORY')
dwarf_weapon('Reserve_War_Hammer',(.600,-.165,.285),.341,'hammer',.09,'04_ARMORY')
box('Armory_Supply_Chest',(.518,.217,.136),(.173,.109,.110),'crate','04_ARMORY')
box('Armory_Chest_Iron_Lid',(.518,.217,.199),(.182,.116,.020),'iron','04_ARMORY')
box('Armory_Chest_Copper_Latch',(.518,.153,.153),(.030,.017,.035),'bronze','04_ARMORY')

# Two squat torso targets and a broad sparring court shaped to the hex.
polygon_prism('Sparring_Sand_Wedge',[(-.623,-.179),(.446,-.179),(.594,-.304),
    (.358,-.595),(0,-.821),(-.376,-.588),(-.652,-.298)],.079,.091,'sand','05_COURTYARD')
polygon_prism('Central_Paved_Approach',[(-.255,-.158),(.030,-.158),(.032,-.592),
    (0,-.829),(-.203,-.592)],.091,.104,'paving','05_COURTYARD')
for i,(x,y) in enumerate(((-.374,-.365),(.193,-.401))):
    box('Combat_Dummy_Stone_Base_%d'%i,(x,y,.122),(.160,.136,.056),'stone','06_TRAINING')
    box('Combat_Dummy_Wood_Stake_%d'%i,(x,y,.268),(.040,.042,.255),'timber','06_TRAINING')
    box('Combat_Dummy_Torso_%d'%i,(x,y-.018,.285),(.109,.074,.154),'straw','06_TRAINING')
    box('Combat_Dummy_Shoulders_%d'%i,(x,y,.346),(.186,.041,.038),'timber','06_TRAINING')
    box('Combat_Dummy_Straw_Head_%d'%i,(x,y,.412),(.074,.070,.075),'straw','06_TRAINING')
    box('Combat_Dummy_Wood_Helmet_%d'%i,(x,y,.454),(.092,.079,.025),'timber','06_TRAINING')
    box('Dummy_Copper_Chest_Strap_%d'%i,(x,y-.061,.284),(.018,.014,.146),'bronze','06_TRAINING')
    for j in range(2):
        scar = [(-.005,-.040),(.005,-.040),(.021,.040),(.011,.040)]
        vertical_prism('Dummy_Slash_Mark_%d_%d'%(i,j),scar,(x-.036+j*.051,y-.066,.297),
                       .009,'shadow','06_TRAINING')
    box('Sparring_Stance_%d'%i,(x*.86,y-.178,.101),(.148,.085,.020),'formation','05_COURTYARD')

# Small bench and repair anvil, no industrial forge competing with melee identity.
bx,by = -.631,-.036
box('Repair_Anvil_Stone_Foot',(bx,by,.128),(.131,.122,.098),'stone','08_DETAILS')
box('Repair_Anvil_Iron_Waist',(bx,by,.201),(.068,.060,.055),'iron','08_DETAILS')
box('Repair_Anvil_Steel_Top',(bx,by,.245),(.166,.080,.038),'iron_light','08_DETAILS')
for x in (-.499,-.359):
    box('Warrior_Bench_Leg_'+str(x),(x,-.138,.135),(.030,.050,.112),'stone','08_DETAILS')
box('Warrior_Bench_Seat',(-.429,-.138,.204),(.207,.077,.028),'timber','08_DETAILS')
box('Hall_Right_Window_Shadow',(.357,.236,.399),(.026,.090,.136),'shadow','02_HALL')
box('Hall_Right_Window_Amber',(.376,.236,.399),(.015,.063,.097),'glow','08_DETAILS')
for y in (.210,.236,.262):
    box('Hall_Right_Window_Grille_'+str(y),(.390,y,.399),(.017,.012,.117),'iron','08_DETAILS')
box('Rear_Hall_Vent_Shadow',(-.105,.590,.397),(.136,.024,.099),'shadow','02_HALL')
for x in (-.149,-.105,-.061):
    box('Rear_Hall_Vent_Grille_'+str(x),(x,.608,.397),(.014,.016,.091),'iron','08_DETAILS')
for i,(x,y) in enumerate(((-.619,.151),(-.577,.289))):
    box('Warrior_Supply_Crate_%d'%i,(x,y,.134),(.096,.099,.110),'crate','08_DETAILS')
    box('Supply_Crate_Iron_Tie_%d'%i,(x,y-.054,.134),(.022,.013,.106),'iron','08_DETAILS')

# Short blue military standard in the exposed left corner.
px,py = -.640,-.198
box('Standard_Stone_Foot',(px,py,.112),(.080,.084,.066),'stone','08_DETAILS')
box('Standard_Iron_Pole',(px,py,.496),(.017,.021,.720),'iron','08_DETAILS')
box('Standard_Copper_Cap',(px,py,.871),(.032,.036,.025),'bronze','08_DETAILS')
box('Standard_Copper_Crossbar',(px+.062,py,.819),(.156,.025,.024),'bronze','08_DETAILS')
box('Standard_Blue_Cloth',(px+.065,py,.733),(.129,.018,.148),'faction','07_FACTION')
hammer('Standard_Hammer_Front',(px+.065,py-.017,.744),.079,.092,.009)
hammer('Standard_Hammer_Back',(px+.065,py+.017,.744),.079,.092,.009)
for sign in (-1,1):
    x = -.105+sign*.177
    box('Portal_Lamp_Iron_Frame_'+str(sign),(x,-.065,.396),(.037,.044,.050),'iron','08_DETAILS')
    box('Portal_Lamp_Amber_'+str(sign),(x,-.092,.396),(.025,.014,.033),'glow','08_DETAILS')
    box('Portal_Lamp_Copper_Cap_'+str(sign),(x,-.071,.429),(.049,.055,.018),'bronze','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_warrior_hall','dwarf',True
root['unit_class'],root['includes_perimeter_walls'] = 'warrior',False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.385]
scene['door_clearance'] = [.228,.260]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Salão de Armas dos Anões'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_warrior','v2_unit_swordsman','v2_unit_weapon_master']
scene['excludes'] = ['v2_legendary_blade_hero']
scene['civilization'],scene['asset_only'] = 'dwarf',True
scene['palette_overrides'] = {
    'foundation':[78,87,91],'stone':[117,124,123],'cutstone':[175,172,152],
    'paving':[122,130,126],'timber':[101,75,43],'door':[130,96,54],
    'roof':[67,82,89],'roof_dark':[43,59,64],'iron':[48,62,67],
    'iron_light':[151,162,160],'bronze':[191,133,71],'faction':[69,109,153],
    'crate':[123,97,58],'sand':[145,136,108],'formation':[189,175,134]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Original dwarf warrior hall: low broad granite barracks, transverse dark slate stepped roof and copper bindings, squat carved rune portal and prominent crossed double-headed axe/war hammer on blue clan cloth. Open right stone-post armory with slate lean-to and reserve axe/hammer; open wedge sparring court with two short slash-marked straw melee targets, stance markers, small repair anvil, bench and blue military standard. Palette matches dwarf city I and tank hall. Same shared warrior/swordsman/weapon-master line; supreme blade hero belongs to separate mastery building. No watchtower, shield-training equipment, surrounding wall ring or character-model dependency.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
