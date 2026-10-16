"""Original dwarven tank training hall, blocky hex asset. Live Blender MCP only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Dwarf_Guardian_Hall_Hex_V1'
RELATIVE_OUT = 'assets/generated/dwarves/buildings/dwarf_guardian_hall_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Dwarf Guardian Hall source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_BASTION','05_COURTYARD',
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
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def dwarf_shield(name,center,width,height,group='08_DETAILS'):
    # Angular eight-sided shield, massive copper rim, steel body and clan-blue inset.
    x,y,z = center
    shape = [(-.34,.50),(.34,.50),(.50,.34),(.50,-.29),(.29,-.50),
             (-.29,-.50),(-.50,-.29),(-.50,.34)]
    for suffix,scale,depth,offset,region,label in (
        ('Copper_Rim',1,.030,0,'bronze',group),
        ('Steel_Face',.82,.021,-.022,'iron_light',group),
        ('Clan_Inset',.59,.013,-.039,'faction','07_FACTION')):
        vertical_prism(name+'_'+suffix,[(u*width*scale,v*height*scale) for u,v in shape],
                       (x,y+offset,z),depth,region,label)
    box(name+'_Iron_Boss_Base',(x,y-.052,z),(.27*width,.023,.25*height),'iron',group)
    box(name+'_Copper_Boss',(x,y-.069,z),(.16*width,.027,.15*height),'bronze',group)
    for sign in (-1,1):
        box(name+'_Upper_Rivet_'+str(sign),(x+sign*.31*width,y-.035,z+.33*height),
            (.060*width,.014,.055*height),'bronze',group)


def pillar_rune(name,x,y,z,width=.037,height=.137):
    box(name+'_Dark_Inset',(x,y,z),(width*1.56,.015,height*1.28),'shadow','08_DETAILS')
    box(name+'_Copper_Stem',(x,y-.012,z),(width*.34,.010,height),'bronze','08_DETAILS')
    for sign in (-1,1):
        box(name+'_Copper_Bar_'+str(sign),(x,y-.012,z+sign*height*.43),
            (width,.010,height*.13),'bronze','08_DETAILS')


# Military .92-radius base, larger than the .84 city-center foundation.
polygon_prism('Hex_Granite_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Carved_Stone_Rim',hexagon(.90),.035,.063,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Stone_Paving',hexagon(.85),.063,.079,'paving','01_FOUNDATION')
footprint = [(-.300,.035),(.450,.035),(.450,.332),(.150,.603),(-.060,.603),(-.300,.367)]
polygon_prism('Hall_Granite_Platform',footprint,.079,.177,'stone','02_HALL')
polygon_prism('Hall_Heavy_Granite_Body',footprint,.177,.644,'stone','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Base_Course_%d'%i,a,b,.039,.173,.220,'cutstone','02_HALL')
    wall('Hall_Eave_Stone_Band_%d'%i,a,b,.062,.601,.674,'cutstone','02_HALL')
    box('Corner_Stone_Buttress_%d'%i,(a[0],a[1],.411),(.084,.091,.447),'cutstone','02_HALL')
    box('Buttress_Granite_Foot_%d'%i,(a[0],a[1],.222),(.111,.117,.114),'stone','02_HALL')
    box('Buttress_Copper_Collar_%d'%i,(a[0],a[1],.535),(.100,.108,.043),'bronze','02_HALL')

# Slate vault and copper courses repeat the approved dwarf city palette.
for j in range(5):
    width,depth = .970-j*.145,.738-j*.029
    points = [(.075-width/2,.305-depth/2),(.075+width/2,.305-depth/2),
              (.075+width/2,.305+depth/2),(.075-width/2,.305+depth/2)]
    polygon_prism('Dark_Slate_Vault_%d'%j,clip_to_hex(points,.852),
                  .679+j*.060,.739+j*.060,'roof','03_ROOFS')
    box('Copper_Front_Vault_Binding_%d'%j,(.075,.305-depth/2-.010,.698+j*.060),
        (width+.012,.036,.030),'bronze','03_ROOFS')
box('Vault_Broad_Ridge',(.075,.305,1.000),(.263,.588,.042),'roof_dark','03_ROOFS')
for y in (.027,.583):
    box('Ridge_Copper_Collar_'+str(y),(.075,y,1.009),(.284,.036,.060),'bronze','03_ROOFS')

# Monumental entrance: thick stone pilasters with copper rune panels.
dx = .075
for sign in (-1,1):
    x = dx+sign*.260
    box('Portal_Pillar_Granite_Foot_'+str(sign),(x,-.040,.211),(.135,.148,.176),'stone','02_HALL')
    box('Portal_Pillar_Shaft_'+str(sign),(x,-.044,.403),(.098,.109,.275),'cutstone','02_HALL')
    box('Portal_Pillar_Capital_'+str(sign),(x,-.044,.571),(.140,.143,.066),'stone','02_HALL')
    box('Portal_Pillar_Copper_Cap_'+str(sign),(x,-.090,.587),(.145,.060,.024),'bronze','08_DETAILS')
    pillar_rune('Portal_Pillar_Rune_'+str(sign),x,-.108,.403)
box('Portal_Dark_Recess',(dx,.012,.358),(.298,.038,.327),'shadow','02_HALL')
for sign in (-1,1):
    box('Portal_Door_Leaf_'+str(sign),(dx+sign*.068,-.015,.351),(.127,.025,.280),'door','02_HALL')
    box('Portal_Stone_Jamb_'+str(sign),(dx+sign*.168,-.006,.360),(.046,.086,.350),'cutstone','02_HALL')
    for z in (.257,.449):
        box('Door_Copper_Strap_%s_%s'%(sign,z),(dx+sign*.068,-.038,z),(.124,.023,.029),'bronze','02_HALL')
    box('Door_Copper_Handle_'+str(sign),(dx+sign*.028,-.056,.350),(.020,.025,.030),'bronze','08_DETAILS')
box('Portal_Massive_Lintel',(dx,-.020,.564),(.433,.128,.077),'cutstone','02_HALL')
box('Portal_Lintel_Copper_Inlay',(dx,-.091,.565),(.375,.019,.024),'bronze','08_DETAILS')
box('Shield_Emblem_Iron_Mount',(dx,-.137,.782),(.384,.047,.414),'iron','08_DETAILS')
dwarf_shield('Portal_Tank_Shield',(dx,-.175,.782),.353,.383)
hammer('Shield_Hammer_Rune',(dx,-.230,.867),.088,.080,.010)
for i,(y,width,top) in enumerate(((-.103,.339,.176),(-.193,.377,.133),(-.285,.413,.101))):
    box('Portal_Granite_Step_%d'%i,(dx,y,(.079+top)/2),(width,.096,top-.079),'cutstone','05_COURTYARD')

# Low square bastion attached on the left; no surrounding fortification ring.
tx,ty = -.515,.100
box('Bastion_Basalt_Foot',(tx,ty,.136),(.330,.337,.114),'stone','04_BASTION')
box('Bastion_Granite_Core',(tx,ty,.454),(.274,.282,.555),'stone','04_BASTION')
for dx in (-.127,.127):
    for dy in (-.131,.131):
        box('Bastion_Corner_Pilaster_%s_%s'%(dx,dy),(tx+dx,ty+dy,.452),
            (.058,.061,.547),'cutstone','04_BASTION')
for z in (.216,.653):
    box('Bastion_Carved_Course_'+str(z),(tx,ty,z),(.321,.327,.053),'cutstone','04_BASTION')
box('Bastion_Copper_Belt',(tx,ty,.681),(.335,.343,.030),'bronze','04_BASTION')
box('Bastion_Front_Slit',(tx,ty-.150,.468),(.063,.021,.166),'shadow','04_BASTION')
box('Bastion_Slit_Iron_Grille',(tx,ty-.166,.468),(.014,.016,.151),'iron','04_BASTION')
box('Bastion_Slit_Lintel',(tx,ty-.163,.567),(.111,.042,.034),'cutstone','04_BASTION')
box('Bastion_Left_Slit',(tx-.151,ty,.459),(.021,.061,.153),'shadow','04_BASTION')
box('Bastion_Deck_Corbel',(tx,ty,.741),(.345,.351,.064),'cutstone','04_BASTION')
box('Bastion_Copper_Deck_Lip',(tx,ty,.783),(.361,.368,.024),'bronze','04_BASTION')
box('Bastion_Deck',(tx,ty,.801),(.293,.302,.016),'paving','04_BASTION')
for i,(dx,dy) in enumerate(((-.133,-.136),(.133,-.136),(.133,.136),(-.133,.136))):
    box('Bastion_Square_Merlon_%d'%i,(tx+dx,ty+dy,.865),(.093,.096,.133),'stone','04_BASTION')
    box('Bastion_Iron_Merlon_Cap_%d'%i,(tx+dx,ty+dy,.940),(.104,.107,.023),'iron','04_BASTION')
pillar_rune('Bastion_Copper_Rune',tx,ty-.173,.314,.039,.091)

# Clan standard rises just above the low bastion, copper shield motif both sides.
px,py = -.574,.118
box('Clan_Standard_Iron_Pole',(px,py,.979),(.018,.023,.359),'iron','08_DETAILS')
box('Clan_Standard_Copper_Cap',(px,py,1.171),(.033,.038,.026),'bronze','08_DETAILS')
box('Clan_Standard_Copper_Crossbar',(px+.071,py,1.128),(.182,.028,.025),'bronze','08_DETAILS')
box('Clan_Standard_Blue_Cloth',(px+.073,py,1.037),(.149,.018,.157),'faction','07_FACTION')
small_outline = [(-.030,.037),(.030,.037),(.038,.029),(.038,-.022),(0,-.044),(-.038,-.022),(-.038,.029)]
for side in (-1,1):
    vertical_prism('Standard_Copper_Shield_'+str(side),small_outline,(px+.073,py+side*.016,1.037),
                   .010,'bronze','08_DETAILS')

# Open shield-drill yard follows the hexagonal tile edges, leaving central access.
polygon_prism('Shield_Drill_Sand_Wedge',[(-.612,-.226),(.580,-.226),(.643,-.310),
    (.363,-.583),(0,-.821),(-.357,-.583),(-.644,-.309)],.079,.091,'sand','05_COURTYARD')
polygon_prism('Central_Granite_Approach',[(-.092,-.232),(.245,-.232),(.162,-.611),
    (0,-.829),(-.119,-.611)],.091,.104,'paving','05_COURTYARD')
for i,(x,y) in enumerate(((-.284,-.402),(.388,-.375))):
    box('Shield_Dummy_Base_%d'%i,(x,y,.122),(.166,.140,.056),'stone','06_TRAINING')
    box('Shield_Dummy_Wood_Stake_%d'%i,(x,y,.268),(.041,.042,.255),'timber','06_TRAINING')
    box('Shield_Dummy_Straw_Torso_%d'%i,(x,y,.286),(.105,.077,.127),'straw','06_TRAINING')
    box('Shield_Dummy_Wood_Arms_%d'%i,(x,y,.339),(.173,.041,.037),'timber','06_TRAINING')
    box('Shield_Dummy_Straw_Head_%d'%i,(x,y,.395),(.076,.070,.071),'straw','06_TRAINING')
    box('Shield_Dummy_Steel_Helmet_%d'%i,(x,y,.438),(.091,.078,.031),'iron_light','06_TRAINING')
    box('Dummy_Helmet_Copper_Band_%d'%i,(x,y-.045,.426),(.091,.014,.018),'bronze','06_TRAINING')
    dwarf_shield('Practice_Shield_%d'%i,(x,y-.055,.279),.183,.207,'06_TRAINING')
    box('Shield_Drill_Stance_%d'%i,(x*.87,y-.169,.101),(.144,.082,.019),'formation','05_COURTYARD')

# Two spare angular shields on a low rack beside the hall's exposed right side.
rx,ry = .625,.045
for y in (ry-.114,ry+.114):
    box('Reserve_Rack_Iron_Post_'+str(y),(rx,y,.241),(.025,.031,.315),'iron','06_TRAINING')
box('Reserve_Shield_Rack_Rail',(rx,ry,.358),(.038,.287,.031),'timber','06_TRAINING')
for i,y in enumerate((ry-.064,ry+.081)):
    # Facing forward is deliberate so rack contents read in the isometric view.
    dwarf_shield('Reserve_Shield_%d'%i,(rx,y,.253),.141,.175,'06_TRAINING')
box('Right_Hall_Window_Shadow',(.468,.229,.427),(.026,.105,.148),'shadow','02_HALL')
box('Right_Hall_Amber_Window',(.487,.229,.427),(.016,.073,.105),'glow','08_DETAILS')
for y in (.199,.229,.259):
    box('Right_Window_Grille_'+str(y),(.500,y,.427),(.018,.012,.122),'iron','08_DETAILS')
for z in (.341,.513):
    box('Right_Window_Stone_Frame_'+str(z),(.488,.229,z),(.043,.143,.027),'cutstone','02_HALL')
box('Rear_Vent_Shadow',(.049,.620,.434),(.119,.022,.095),'shadow','02_HALL')
for x in (.010,.049,.088):
    box('Rear_Vent_Iron_Grille_'+str(x),(x,.637,.434),(.012,.016,.089),'iron','08_DETAILS')
for i,(x,y) in enumerate(((.365,.453),(.237,.549))):
    box('Training_Supply_Crate_%d'%i,(x,y,.137),(.098,.096,.116),'crate','08_DETAILS')
    box('Supply_Crate_Iron_Band_%d'%i,(x,y-.053,.137),(.023,.013,.112),'iron','08_DETAILS')
for sign in (-1,1):
    x = .075+sign*.189
    box('Portal_Lamp_Iron_Frame_'+str(sign),(x,-.104,.416),(.040,.049,.054),'iron','08_DETAILS')
    box('Portal_Lamp_Amber_'+str(sign),(x,-.134,.416),(.026,.014,.036),'glow','08_DETAILS')
    box('Portal_Lamp_Copper_Cap_'+str(sign),(x,-.112,.453),(.055,.061,.021),'bronze','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_guardian_hall','dwarf',True
root['unit_class'],root['includes_perimeter_walls'] = 'tank',False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.425]
scene['door_clearance'] = [.260,.280]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Salão dos Guardiões dos Anões'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_shieldbearer','v2_unit_guardian','v2_unit_sentinel']
scene['excludes'] = ['v2_legendary_guardian_champion']
scene['civilization'],scene['asset_only'] = 'dwarf',True
scene['palette_overrides'] = {
    'foundation':[78,87,91],'stone':[117,124,123],'cutstone':[175,172,152],
    'paving':[122,130,126],'timber':[101,75,43],'door':[130,96,54],
    'roof':[67,82,89],'roof_dark':[43,59,64],'iron':[48,62,67],
    'iron_light':[151,162,160],'bronze':[191,133,71],'faction':[69,109,153],
    'crate':[123,97,58],'sand':[145,136,108],'formation':[189,175,134]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92; placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Original dwarf tank hall: squat heavy granite barracks, monumental rune-inlaid stone portal, dark slate stepped vault with thick copper bindings and large angular copper-rimmed steel shield with clan-blue inset. Compact attached stone bastion with square merlons, copper belts and blue shield standard. Open wedge drill yard with two short shield-practice straw dummies in steel helmet caps, stance markers and two reserve shields on a rack. Palette matches dwarf city I. Same shared shieldbearer/guardian/sentinel training line; supreme guardian belongs to separate mastery building. No surrounding wall ring or character-model dependency.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
