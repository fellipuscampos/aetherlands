"""Dwarven city I, original blocky civic stone hall. Live Blender MCP, asset only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Dwarf_City_Level_1_Hex_V1'
RELATIVE_OUT = 'assets/generated/dwarves/buildings/dwarf_city_level_1_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Dwarf City I scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_COUNCIL','03_ROOFS','04_MASONRY','05_COURTYARD',
              '06_ARCHITECTURE','07_FACTION','08_DETAILS','09_STUDIO'):
    collection = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def hammer(name,center,width,height,depth,group='08_DETAILS'):
    x,y,z = center
    box(name+'_Handle',(x,y,z-height*.14),(width*.15,depth,height*.66),'bronze',group)
    profile = [(-.50,-.15),(.50,-.15),(.50,.12),(.39,.12),(.39,.21),
               (-.39,.21),(-.39,.12),(-.50,.12)]
    vertical_prism(name+'_Head',[(px*width,pz*height) for px,pz in profile],
                   (x,y,z+height*.23),depth*1.12,'bronze',group)


polygon_prism('Hex_Granite_Foundation',hexagon(.84),0,.033,'foundation','01_FOUNDATION')
polygon_prism('Hex_Carved_Rim',hexagon(.825),.033,.060,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Stone_Court',hexagon(.775),.060,.078,'paving','01_FOUNDATION')
footprint = [(-.385,-.080),(.385,-.080),(.385,.276),(.160,.465),(-.160,.465),(-.385,.276)]
polygon_prism('Council_Granite_Platform',footprint,.078,.184,'cutstone','02_COUNCIL')
polygon_prism('Council_Heavy_Stone_Body',footprint,.184,.648,'stone','02_COUNCIL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Base_Course_%d'%i,a,b,.039,.182,.222,'cutstone','02_COUNCIL')
    wall('Hall_Eave_Band_%d'%i,a,b,.056,.604,.665,'cutstone','02_COUNCIL')
    box('Corner_Buttress_%d'%i,(a[0],a[1],.395),(.086,.091,.407),'cutstone','04_MASONRY')
    box('Corner_Buttress_Foot_%d'%i,(a[0],a[1],.203),(.111,.115,.102),'stone','04_MASONRY')
    box('Corner_Copper_Collar_%d'%i,(a[0],a[1],.531),(.099,.102,.040),'bronze','04_MASONRY')

# Long squat vault silhouette, dark slate courses and thick copper gable binding.
for j in range(5):
    width,depth = .924-j*.143,.734-j*.032
    points = [(-width/2,.177-depth/2),(width/2,.177-depth/2),
              (width/2,.177+depth/2),(-width/2,.177+depth/2)]
    polygon_prism('Slate_Vault_Course_%d'%j,clip_to_hex(points,.765),
                  .669+j*.059,.728+j*.059,'roof','03_ROOFS')
    box('Copper_Gable_Binding_%d'%j,(0,.177-depth/2-.007,.687+j*.059),
        (width+.012,.036,.031),'bronze','03_ROOFS')
box('Vault_Broad_Ridge',(0,.177,.984),(.252,.596,.040),'roof_dark','03_ROOFS')
for y in (-.107,.461):
    box('Ridge_Copper_Collar_'+str(y),(0,y,.986),(.271,.039,.060),'bronze','03_ROOFS')

# One low square roof lantern rather than a tall level-II tower.
box('Roof_Lantern_Stone_Base',(0,.229,1.027),(.188,.187,.047),'cutstone','02_COUNCIL')
box('Roof_Lantern_Block',(0,.229,1.087),(.137,.140,.077),'stone','02_COUNCIL')
box('Roof_Lantern_Front_Glass',(0,.151,1.089),(.094,.018,.042),'glow','08_DETAILS')
for x in (-.028,.028):
    box('Roof_Lantern_Grille_'+str(x),(x,.138,1.089),(.011,.012,.046),'iron','08_DETAILS')
box('Roof_Lantern_Copper_Cap',(0,.229,1.139),(.212,.207,.032),'bronze','03_ROOFS')
box('Roof_Lantern_Top',(0,.229,1.171),(.140,.140,.032),'roof_dark','03_ROOFS')

# Monumental square pilasters; ornament is deliberately large at 4X camera scale.
for sign in (-1,1):
    x = sign*.291
    box('Front_Pillar_Foot_'+str(sign),(x,-.123,.183),(.158,.156,.174),'stone','04_MASONRY')
    box('Front_Pillar_Shaft_'+str(sign),(x,-.126,.402),(.110,.121,.308),'cutstone','04_MASONRY')
    box('Front_Pillar_Capital_'+str(sign),(x,-.124,.584),(.156,.155,.063),'stone','04_MASONRY')
    box('Front_Copper_Capital_'+str(sign),(x,-.151,.589),(.163,.109,.027),'bronze','04_MASONRY')
    box('Front_Pillar_Carved_Inset_'+str(sign),(x,-.191,.402),(.043,.014,.158),'shadow','06_ARCHITECTURE')
    for dz in (-.052,.052):
        box('Pillar_Copper_Rune_%s_%s'%(sign,dz),(x,-.203,.402+dz),(.036,.010,.014),'bronze','08_DETAILS')
    box('Pillar_Rune_Stem_'+str(sign),(x,-.204,.402),(.014,.010,.113),'bronze','08_DETAILS')

box('Entry_Recess',(0,-.098,.367),(.293,.035,.325),'shadow','06_ARCHITECTURE')
for sign in (-1,1):
    box('Entry_Copper_Door_'+str(sign),(sign*.064,-.128,.359),(.122,.023,.280),'door','06_ARCHITECTURE')
    box('Entry_Stone_Jamb_'+str(sign),(sign*.163,-.126,.355),(.042,.080,.343),'cutstone','06_ARCHITECTURE')
    for z in (.262,.453):
        box('Door_Copper_Band_%s_%s'%(sign,z),(sign*.064,-.150,z),(.118,.022,.031),'bronze','06_ARCHITECTURE')
        box('Door_Square_Rivet_%s_%s'%(sign,z),(sign*.104,-.167,z),(.019,.013,.019),'iron_light','08_DETAILS')
    box('Door_Square_Handle_'+str(sign),(sign*.026,-.171,.359),(.019,.023,.029),'bronze','08_DETAILS')
box('Portal_Massive_Lintel',(0,-.125,.551),(.423,.111,.075),'cutstone','06_ARCHITECTURE')
box('Portal_Lintel_Copper_Inlay',(0,-.186,.551),(.365,.017,.026),'bronze','08_DETAILS')
box('Portal_Keystone',(0,-.196,.559),(.075,.035,.083),'stone','06_ARCHITECTURE')
box('Civic_Crest_Iron_Frame',(0,-.235,.690),(.192,.039,.164),'iron','06_ARCHITECTURE')
box('Civic_Crest_Faction_Plate',(0,-.260,.690),(.164,.017,.137),'faction','07_FACTION')
hammer('Civic_Hammer',(0,-.276,.690),.120,.119,.017)
for i,(y,width,top) in enumerate(((-.209,.337,.183),(-.305,.389,.146),(-.401,.430,.109))):
    box('Entry_Granite_Step_%d'%i,(0,y,(.078+top)/2),(width,.100,top-.078),'cutstone','05_COURTYARD')
for i,(x,y) in enumerate(((0,-.501),(.010,-.612),(0,-.708))):
    box('Court_Path_%d'%i,(x,y,.086),(.164,.074,.016),'paving','05_COURTYARD')

# Deep framed, narrow amber windows behind heavy black grilles.
box('Right_Window_Recess',(.400,.098,.420),(.028,.115,.175),'shadow','06_ARCHITECTURE')
box('Right_Window_Amber',(.418,.098,.420),(.018,.080,.136),'glow','08_DETAILS')
for z in (.323,.517):
    box('Window_Granite_Frame_'+str(z),(.426,.098,z),(.054,.158,.034),'cutstone','06_ARCHITECTURE')
for y in (.050,.098,.146):
    box('Window_Iron_Grille_'+str(y),(.431,y,.420),(.019,.013,.152),'iron','08_DETAILS')
box('Window_Grille_Rail',(.431,.098,.420),(.019,.111,.013),'iron','08_DETAILS')
box('Rear_Vent_Dark',(0,.480,.441),(.166,.022,.111),'shadow','06_ARCHITECTURE')
for x in (-.058,0,.058):
    box('Rear_Vent_Grille_'+str(x),(x,.493,.441),(.018,.016,.095),'iron','06_ARCHITECTURE')
box('Rear_Vent_Lintel',(0,.485,.510),(.207,.048,.033),'cutstone','06_ARCHITECTURE')

# Founder's anvil monument marks a civic center, not a production workshop.
ax,ay = -.366,-.365
box('Founder_Monument_Foot',(ax,ay,.107),(.192,.179,.058),'stone','05_COURTYARD')
box('Founder_Monument_Plinth',(ax,ay,.164),(.134,.132,.063),'cutstone','05_COURTYARD')
box('Founder_Monument_Plaque',(ax,ay-.074,.164),(.072,.015,.030),'bronze','08_DETAILS')
anvil = [(-.090,0),(.090,0),(.090,.020),(.051,.020),(.051,.048),
         (.094,.065),(.133,.084),(.133,.106),(-.104,.106),(-.104,.078),
         (-.049,.061),(-.049,.025),(-.090,.025)]
vertical_prism('Founder_Bronze_Anvil',anvil,(ax,ay,.197),.084,'bronze','08_DETAILS')

# One stone bench and drinking cistern; no enclosing defensive ring.
for x in (.323,.463):
    box('Stone_Bench_Leg_'+str(x),(x,-.327,.125),(.040,.060,.094),'stone','08_DETAILS')
box('Stone_Bench_Seat',(.393,-.327,.181),(.211,.087,.029),'cutstone','08_DETAILS')
wx,wy = .379,-.498
box('Cistern_Stone_Base',(wx,wy,.097),(.151,.141,.038),'stone','05_COURTYARD')
box('Cistern_Water',(wx,wy,.146),(.103,.092,.016),'water','05_COURTYARD')
for dx,dy in ((-.066,0),(.066,0),(0,-.061),(0,.061)):
    box('Cistern_Rim_%s_%s'%(dx,dy),(wx+dx,wy+dy,.137),
        (.022 if dx else .128,.022 if dy else .144,.061),'cutstone','05_COURTYARD')
for i,(x,y,z,size) in enumerate(((-.461,.068,.120,.083),(-.497,.161,.129,.101),
                                (-.450,.125,.208,.068))):
    box('Stacked_Cut_Block_%d'%i,(x,y,z),(size,size,size),'cutstone','08_DETAILS')

# Compact sapphire-colored civic standard; tint group prepared for future use.
px,py = -.493,-.219
box('Standard_Stone_Foot',(px,py,.119),(.095,.093,.083),'stone','08_DETAILS')
box('Standard_Metal_Pole',(px,py,.424),(.018,.022,.540),'iron','08_DETAILS')
box('Standard_Faction_Cloth',(px+.062,py,.574),(.131,.018,.150),'faction','07_FACTION')
box('Standard_Copper_Crossbar',(px+.057,py,.658),(.164,.027,.025),'bronze','08_DETAILS')
box('Standard_Copper_Cap',(px,py,.707),(.034,.037,.031),'bronze','08_DETAILS')
hammer('Standard_Hammer_Front',(px+.062,py-.016,.584),.079,.094,.009)
hammer('Standard_Hammer_Back',(px+.062,py+.016,.584),.079,.094,.009)
for sign in (-1,1):
    box('Entry_Lamp_Iron_'+str(sign),(sign*.192,-.194,.416),(.039,.055,.052),'iron','08_DETAILS')
    box('Entry_Lamp_Amber_'+str(sign),(sign*.192,-.227,.416),(.025,.014,.035),'glow','08_DETAILS')
    box('Entry_Lamp_Copper_Cap_'+str(sign),(sign*.192,-.198,.452),(.052,.060,.019),'bronze','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_1'
root['civilization'],root['city_level'],root['asset_only'] = 'dwarf',1,True
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025, (maximum,wall_inner_apothem)

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.45]
scene['door_clearance'] = [.250,.280]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Centro da Cidade Anã — Nível I'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'],scene['civilization'],scene['asset_only'] = 1,'dwarf',True
scene['palette_overrides'] = {
    'foundation':[78,87,91],'stone':[117,124,123],'cutstone':[175,172,152],
    'paving':[122,130,126],'timber':[101,75,43],'door':[130,96,54],
    'roof':[67,82,89],'roof_dark':[43,59,64],'iron':[48,62,67],
    'iron_light':[151,162,160],'bronze':[191,133,71],
    'faction':[69,109,153],'water':[76,139,153]}
scene['scale_note'] = 'Native map units; pointy-top hex tile radius 1, foundation radius .84. Fits independent fortification ring; asset only, no game integration.'
scene['design_note'] = 'Dwarf city I of four: squat broad granite council hall, huge square pilasters with copper rune inlays, long stepped dark slate vault bound in copper, one low roof lantern and large hammer civic badge. Founders bronze anvil monument, stone bench and water cistern in open forecourt. No perimeter walls. Tall towers, extra halls and grand roof volumes reserved for levels II–IV.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,
          'wall_inner_apothem':wall_inner_apothem,'asset_only':True}
