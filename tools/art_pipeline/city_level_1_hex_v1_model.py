"""Level I city center: compact castle, one crenellated turret, room for III upgrades.
Build original geometry via live Blender MCP; preserve all other scenes.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'City_Level_1_Hex_V1'
OUT = ROOT/'assets/generated/humans/buildings/city_level_1_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('City I source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_KEEP','03_ROOFS','04_TURRET','05_COURTYARD',
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


def crown(name, center, width, height, depth, group='08_DETAILS'):
    profile = [(-.5,-.5),(.5,-.5),(.5,.25),(.30,.25),(.30,-.05),(.11,-.05),
               (.11,.5),(-.11,.5),(-.11,-.05),(-.30,-.05),(-.30,.25),(-.5,.25)]
    vertical_prism(name,[(x*width,z*height) for x,z in profile],center,depth,'gold',group)


# Smaller foundation leaves a gap to the separate fortification wall's inner face.
polygon_prism('Hex_Foundation',hexagon(.84),0,.030,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim',hexagon(.825),.030,.058,'cutstone','01_FOUNDATION')
polygon_prism('Castle_Paving',hexagon(.775),.058,.076,'paving','01_FOUNDATION')

# Modest stone keep, pentagonal rear, a single floor rather than a grand citadel.
footprint = [(-.28,-.075),(.40,-.075),(.40,.32),(.08,.53),(-.28,.32)]
polygon_prism('Keep_StoneFoot',footprint,.076,.167,'cutstone','02_KEEP')
polygon_prism('Keep_Body',footprint,.167,.669,'stone','02_KEEP')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Keep_EaveBand_%d'%i,a,b,.043,.636,.691,'cutstone','02_KEEP')
    wall('Keep_BaseBand_%d'%i,a,b,.032,.164,.198,'cutstone','02_KEEP')
    box('Keep_Buttress_%d'%i,(a[0],a[1],.334),(.069,.069,.335),'cutstone','06_ARCHITECTURE')
    box('Keep_ButtressTop_%d'%i,(a[0],a[1],.520),(.052,.052,.037),'cutstone','06_ARCHITECTURE')

# Hex-clipped stepped hipped roof; its center can become a taller keep in level II.
for j in range(6):
    sx,sy = .84-j*.137,.71-j*.117
    points = [(.06-sx/2,.235-sy/2),(.06+sx/2,.235-sy/2),
              (.06+sx/2,.235+sy/2),(.06-sx/2,.235+sy/2)]
    polygon_prism('Keep_Roof_%d'%j,clip_to_hex(points,.74),.704+j*.046,.750+j*.046,
                  'roof','03_ROOFS')
box('Keep_Ridge',(.06,.235,.996),(.173,.144,.031),'roof_dark','03_ROOFS')

# One square crenellated turret is the unmistakable castle silhouette at level I.
tx,ty = -.366,-.105
box('Turret_Foot',(tx,ty,.138),(.313,.316,.124),'cutstone','04_TURRET')
box('Turret_Body',(tx,ty,.433),(.273,.281,.536),'stone','04_TURRET')
for z in (.230,.571):
    box('Turret_Stringcourse_'+str(z),(tx,ty,z),(.295,.303,.028),'cutstone','04_TURRET')
box('Turret_CorbelLip',(tx,ty,.686),(.317,.326,.060),'cutstone','04_TURRET')
box('Turret_TopDeck',(tx,ty,.723),(.276,.280,.015),'paving','04_TURRET')
for dx in (-.15,.15):
    box('Turret_ParapetSide_'+str(dx),(tx+dx,ty,.750),(.034,.331,.073),'stone','04_TURRET')
for dy in (-.152,.152):
    box('Turret_ParapetEnd_'+str(dy),(tx,ty+dy,.750),(.271,.034,.073),'stone','04_TURRET')
for i,(dx,dy) in enumerate(((-.137,-.14),(0,-.14),(.137,-.14),(.137,0),
                           (.137,.14),(0,.14),(-.137,.14),(-.137,0))):
    box('Turret_Merlon_%d'%i,(tx+dx,ty+dy,.809),(.070,.072,.076),'cutstone','04_TURRET')
box('Turret_FrontSlit',(tx,ty-.149,.472),(.047,.019,.165),'shadow','06_ARCHITECTURE')
box('Turret_FrontSlitSill',(tx,ty-.163,.381),(.083,.036,.028),'cutstone','06_ARCHITECTURE')
box('Turret_LeftSlit',(tx-.145,ty,.472),(.018,.045,.165),'shadow','06_ARCHITECTURE')
box('Turret_LeftSlitSill',(tx-.163,ty,.381),(.036,.081,.028),'cutstone','06_ARCHITECTURE')

# Closed double door, stepped stone arch and three low entry steps.
box('Entry_DoorShadow',(.076,-.090,.328),(.228,.026,.332),'shadow','06_ARCHITECTURE')
for sign in (-1,1):
    box('Entry_DoorLeaf_'+str(sign),(.076+sign*.049,-.108,.316),(.092,.019,.296),'door','06_ARCHITECTURE')
    box('Entry_DoorJamb_'+str(sign),(.076+sign*.130,-.098,.304),(.036,.055,.348),'cutstone','06_ARCHITECTURE')
    box('Entry_ArchShoulder_'+str(sign),(.076+sign*.11,-.104,.482),(.074,.060,.042),'cutstone','06_ARCHITECTURE')
    for z in (.228,.392):
        box('Entry_DoorBand_%s_%s'%(sign,z),(.076+sign*.049,-.123,z),(.089,.014,.020),'iron','06_ARCHITECTURE')
    box('Entry_Handle_'+str(sign),(.076+sign*.021,-.135,.313),(.016,.018,.024),'gold','08_DETAILS')
box('Entry_ArchCap',(.076,-.104,.513),(.168,.060,.040),'cutstone','06_ARCHITECTURE')
box('Entry_ArchKeystone',(.076,-.114,.529),(.052,.067,.070),'cutstone','06_ARCHITECTURE')
for i,(y,width,top) in enumerate(((-.16,.303,.145),(-.233,.343,.122),(-.312,.38,.100))):
    box('Entry_Step_%d'%i,(.076,y,(.076+top)/2),(width,.079,top-.076),'cutstone','05_COURTYARD')

# Royal badge is compact, unlike the large military class emblems of the halls.
box('Royal_PlateBacking',(.076,-.105,.601),(.167,.036,.155),'iron','08_DETAILS')
box('Royal_FactionPlate',(.076,-.130,.601),(.139,.018,.128),'faction','07_FACTION')
crown('Royal_Crown',(.076,-.147,.604),.098,.074,.016)

# Narrow stone-framed windows, positioned outside the solid body on each facade.
box('Front_Window',(.297,-.092,.424),(.079,.021,.169),'shadow','06_ARCHITECTURE')
for x in (.244,.350):
    box('Front_WindowJamb_'+str(x),(x,-.108,.424),(.022,.024,.207),'cutstone','06_ARCHITECTURE')
box('Front_WindowLintel',(.297,-.106,.524),(.132,.031,.024),'cutstone','06_ARCHITECTURE')
box('Front_WindowSill',(.297,-.116,.324),(.137,.046,.031),'cutstone','06_ARCHITECTURE')
box('Right_Window',(.416,.128,.422),(.021,.086,.164),'shadow','06_ARCHITECTURE')
for y in (.072,.184):
    box('Right_WindowJamb_'+str(y),(.433,y,.422),(.025,.024,.205),'cutstone','06_ARCHITECTURE')
box('Right_WindowSill',(.432,.128,.324),(.040,.133,.030),'cutstone','06_ARCHITECTURE')

# Civic forecourt, with water basin, bench and clipped shrubs rather than training props.
for i,(x,y) in enumerate(((.068,-.425),(.021,-.549),(0,-.675))):
    box('Court_Path_%d'%i,(x,y,.083),(.147,.093,.014),'cutstone','05_COURTYARD',(-1)**i*.09)
fx,fy = .405,-.314
box('Basin_Foot',(fx,fy,.093),(.190,.188,.034),'cutstone','05_COURTYARD')
box('Basin_Water',(fx,fy,.160),(.115,.113,.015),'water','05_COURTYARD')
for dx in (-.079,.079):
    box('Basin_Side_'+str(dx),(fx+dx,fy,.145),(.032,.18,.09),'stone','05_COURTYARD')
for dy in (-.077,.077):
    box('Basin_End_'+str(dy),(fx,fy+dy,.145),(.126,.032,.09),'stone','05_COURTYARD')
for x in (.359,.476):
    box('Bench_Leg_'+str(x),(x,-.477,.114),(.027,.052,.076),'timber','08_DETAILS')
box('Bench_Seat',(.418,-.477,.160),(.19,.077,.025),'door','08_DETAILS')
for i,(x,y) in enumerate(((-.474,-.342),(.378,.388))):
    box('Planter_%d'%i,(x,y,.109),(.138,.116,.063),'stone','05_COURTYARD')
    box('Shrub_%d_Base'%i,(x,y,.162),(.121,.103,.080),'foliage','08_DETAILS')
    box('Shrub_%d_Top'%i,(x+.013,y,.215),(.076,.075,.036),'foliage_light','08_DETAILS')

# Neutral cloth is recolored by City.gd; gold crests and stone keep their atlas colors.
px,py = .079,.258
box('Flag_Pole',(px,py,1.033),(.014,.014,.312),'timber','08_DETAILS')
box('Flag_Cap',(px,py,1.201),(.028,.028,.028),'gold','08_DETAILS')
box('City_FactionFlag',(.169,py,1.132),(.163,.012,.108),'faction','07_FACTION')
crown('Flag_Crown_Front',(.169,py-.012,1.133),.069,.051,.008)
crown('Flag_Crown_Back',(.169,py+.012,1.133),.069,.051,.008)
for i,x in enumerate((-.077,.226)):
    box('Entry_Lantern_%d'%i,(x,-.145,.424),(.028,.032,.046),'glow','08_DETAILS')
    for dz in (-.031,.031):
        box('Entry_Lantern_%d_Cap_%s'%(i,dz),(x,-.145,.424+dz),(.041,.043,.017),'iron','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_1'
root['city_level'] = 1
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
# Fits not only the tile, but the inside of the independent fortification ring.
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-0.025, (maximum,wall_inner_apothem)

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.45]
scene['door_clearance'] = [.188,.296]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Centro da Cidade — Nível I'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'] = 1
scene['palette_overrides'] = {'stone':[145,153,159],'cutstone':[184,187,178],
    'faction':[232,232,232],'gold':[192,158,84],'water':[70,129,158],
    'foliage':[70,99,56],'foliage_light':[99,125,66]}
scene['scale_note'] = 'Native map units, pointy-top tile radius 1. City scales uniformly with tile_radius; foundation radius .84 fits the independent fortification ring.'
scene['design_note'] = 'Level I of four: compact pentagonal stone keep, single low square crenellated turret, stepped blue hipped roof, framed double door, gold crown and neutral faction cloth. Three entry steps, civic basin, bench and shrubs. Taller keeps and additional towers reserved for future city levels; full tile walls remain a separate fortification system.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.188,.296],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'wall_inner_apothem':wall_inner_apothem}
