"""Original orc civic hall, level I. Live Blender MCP; asset only, no game registration."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'Orc_City_Level_1_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_city_level_1_hex_v1'
OUT = ROOT / RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc City I source scene already exists; preserve its edits.')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION', '02_KEEP', '03_ROOFS', '04_TOTEM', '05_COURTYARD',
              '06_ARCHITECTURE', '07_FACTION', '08_DETAILS', '09_STUDIO'):
    collection = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename, names in (
    ('guardian_hall_hex_v2_model.py', ('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py', ('clip_to_hex','vertical_prism')),
):
    tree = ast.parse((PIPELINE / filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), '<shared_primitives>', 'exec'))


def tusk(name, center, height, width, depth, sign=1, group='08_DETAILS'):
    # Six-sided silhouette: blunt rectangular base, two bends, tapered square tip.
    profile = [(-.5,0),(.5,0),(.40,.36),(.03,.68),(-.36,1),(-.10,.55)]
    vertical_prism(name, [(sign*x*width,z*height) for x,z in profile],
                   center, depth, 'bone', group)


def clan_crest(name, center, size, group='08_DETAILS'):
    x,y,z = center
    # Abstract tusked jaw, readable without introducing a character model.
    box(name+'_Jaw',(x,y,z-size*.10),(size*.68,size*.13,size*.26),'bone',group)
    box(name+'_Brow',(x,y,z+size*.16),(size*.78,size*.13,size*.19),'iron_light',group)
    for sign in (-1,1):
        tusk(name+'_Fang_'+str(sign),(x+sign*size*.32,y-size*.03,z-size*.23),
             size*.65,size*.22,size*.16,sign,group)
        box(name+'_Eye_'+str(sign),(x+sign*size*.18,y-size*.09,z+size*.06),
            (size*.13,size*.06,size*.09),'shadow',group)


# Compact town center. Leave the hex rim free for independently upgraded walls.
polygon_prism('Hex_Basalt_Platform',hexagon(.84),0,.033,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Lip',hexagon(.825),.033,.060,'stone','01_FOUNDATION')
polygon_prism('Hex_Earth_Paving',hexagon(.775),.060,.078,'paving','01_FOUNDATION')
footprint = [(-.34,-.075),(.34,-.075),(.34,.34),(0,.55),(-.34,.34)]
polygon_prism('Chief_Hall_Stone_Platform',footprint,.078,.183,'stone','02_KEEP')
polygon_prism('Chief_Hall_Wood_Body',footprint,.183,.680,'door','02_KEEP')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Sill_%d'%i,a,b,.044,.173,.214,'timber','02_KEEP')
    wall('Hall_Upper_Beam_%d'%i,a,b,.052,.640,.698,'timber','02_KEEP')
    box('Hall_Corner_Post_%d'%i,(a[0],a[1],.421),(.074,.074,.482),'timber','06_ARCHITECTURE')
    for z in (.228,.606):
        box('Post_Iron_Collar_%d_%s'%(i,z),(a[0],a[1],z),(.088,.088,.044),'iron','06_ARCHITECTURE')

# Broad gabled roof, coarse stepped hide shingles and a heavy exposed ridge.
# Its long ridge differs from the blue pyramidal roofs of the human cities.
for j in range(6):
    width = .89-j*.127
    depth = .78-j*.021
    points = [(-width/2,.235-depth/2),(width/2,.235-depth/2),
              (width/2,.235+depth/2),(-width/2,.235+depth/2)]
    polygon_prism('Hide_Roof_Course_%d'%j,clip_to_hex(points,.77),
                  .693+j*.056,.749+j*.056,'roof','03_ROOFS')
    # The front black iron binding exaggerates the gable's stepped outline.
    box('Roof_Front_Binding_%d'%j,(0,.235-depth/2-.007,.721+j*.056),
        (width+.012,.032,.025),'iron','03_ROOFS')
box('Heavy_Ridge_Beam',(0,.237,1.046),(.088,.709,.043),'timber','03_ROOFS')
for y in (-.116,.579):
    box('Ridge_End_Collar_'+str(y),(0,y,1.047),(.107,.045,.064),'iron','03_ROOFS')
    tusk('Ridge_End_Horn_'+str(y),(0,y,1.073),.119,.067,.055,1,'03_ROOFS')

# Reinforcing strips and large square rivets read at strategic zoom.
for sign in (-1,1):
    box('Front_Heavy_Post_'+str(sign),(sign*.263,-.108,.434),(.061,.075,.447),'timber','06_ARCHITECTURE')
    for z in (.238,.600):
        box('Front_Post_Strap_%s_%s'%(sign,z),(sign*.263,-.151,z),(.079,.025,.048),'iron','06_ARCHITECTURE')
        box('Front_Post_Rivet_%s_%s'%(sign,z),(sign*.263,-.168,z),(.024,.014,.024),'iron_light','08_DETAILS')
    # Tusks belong to the doorway, never to a ring around the tile.
    box('Entry_Tusk_Socket_'+str(sign),(sign*.194,-.202,.196),(.090,.095,.125),'iron','06_ARCHITECTURE')
    tusk('Entry_Great_Tusk_'+str(sign),(sign*.194,-.219,.238),.403,.091,.073,sign)
box('Entry_Shadow',(0,-.093,.408),(.268,.036,.396),'shadow','06_ARCHITECTURE')
for sign in (-1,1):
    box('Entry_Leaf_'+str(sign),(sign*.061,-.116,.400),(.116,.024,.359),'door','06_ARCHITECTURE')
    for z in (.280,.503):
        box('Entry_Iron_Band_%s_%s'%(sign,z),(sign*.061,-.135,z),(.112,.024,.031),'iron','06_ARCHITECTURE')
    box('Entry_Square_Handle_'+str(sign),(sign*.026,-.154,.394),(.020,.024,.032),'iron_light','08_DETAILS')
box('Entry_Timber_Lintel',(0,-.138,.608),(.326,.090,.065),'timber','06_ARCHITECTURE')
box('Chief_Clan_Plate',(0,-.181,.756),(.220,.032,.185),'iron','06_ARCHITECTURE')
box('Chief_Clan_Cloth',(0,-.202,.756),(.186,.016,.152),'faction','07_FACTION')
clan_crest('Chief_Jaw_Crest',(0,-.219,.752),.143)
for i,(y,width,top) in enumerate(((-.183,.310,.182),(-.275,.350,.143),(-.367,.386,.108))):
    box('Entry_Stone_Step_%d'%i,(0,y,(.078+top)/2),(width,.095,top-.078),'stone','05_COURTYARD')
for i,(x,y) in enumerate(((0,-.478),(-.026,-.590),(0,-.700))):
    box('Court_Path_Stone_%d'%i,(x,y,.088),(.139,.080,.020),'cutstone','05_COURTYARD',.06*(-1)**i)

# One low carved clan totem: civic assembly marker, not a military watchtower.
tx,ty = -.483,-.098
box('Totem_Stone_Foot',(tx,ty,.122),(.216,.228,.088),'stone','04_TOTEM')
box('Totem_Step',(tx,ty,.180),(.174,.186,.045),'cutstone','04_TOTEM')
box('Totem_Timber_Core',(tx,ty,.406),(.100,.110,.436),'timber','04_TOTEM')
for z in (.238,.453,.610):
    box('Totem_Binding_'+str(z),(tx,ty,z),(.134,.142,.041),'iron','04_TOTEM')
box('Totem_Head',(tx,ty,.652),(.183,.145,.160),'timber','04_TOTEM')
box('Totem_Brow',(tx,ty-.080,.683),(.193,.027,.047),'iron','04_TOTEM')
for sign in (-1,1):
    box('Totem_Eye_'+str(sign),(tx+sign*.043,ty-.089,.648),(.033,.021,.024),'shadow','04_TOTEM')
    tusk('Totem_Tusk_'+str(sign),(tx+sign*.081,ty-.093,.591),.135,.045,.030,sign,'04_TOTEM')
box('Totem_Banner_Pole',(tx,ty,.790),(.024,.025,.173),'timber','04_TOTEM')
box('Totem_Short_Clan_Banner',(tx+.062,ty,.799),(.128,.017,.106),'faction','07_FACTION')
box('Totem_Banner_Cap',(tx,ty,.884),(.035,.038,.034),'iron_light','04_TOTEM')

# Slatted window and single short smoke chimney keep the level-I silhouette modest.
box('Hall_Right_Window',(.351,.107,.448),(.025,.141,.145),'shadow','06_ARCHITECTURE')
for z in (.374,.522):
    box('Window_Sill_'+str(z),(.368,.107,z),(.040,.184,.029),'timber','06_ARCHITECTURE')
for y in (.058,.107,.156):
    box('Window_Iron_Slat_'+str(y),(.376,y,.448),(.017,.012,.139),'iron','06_ARCHITECTURE')
box('Chimney_Basalt_Block',(.274,.336,.774),(.125,.140,.213),'stone','08_DETAILS')
box('Chimney_Iron_Cap',(.274,.336,.887),(.158,.173,.036),'iron','08_DETAILS')
box('Chimney_Dark_Mouth',(.274,.336,.908),(.090,.106,.011),'shadow','08_DETAILS')

# Small civic forecourt: communal brazier and supplies, no training equipment.
fx,fy = .365,-.367
box('Brazier_Stone_Foot',(fx,fy,.109),(.177,.177,.062),'stone','05_COURTYARD')
box('Brazier_Coal',(fx,fy,.151),(.116,.116,.028),'shadow','08_DETAILS')
for dx,dy in ((-.070,0),(.070,0),(0,-.070),(0,.070)):
    box('Brazier_Iron_Rim_%s_%s'%(dx,dy),(fx+dx,fy+dy,.163),
        (.025 if dx else .126,.025 if dy else .126,.064),'iron','08_DETAILS')
for i,(dx,dy,width,height) in enumerate(((-.028,0,.040,.090),(.022,.011,.036,.126),(0,-.031,.026,.066))):
    box('Brazier_Fire_%d'%i,(fx+dx,fy+dy,.152+height/2),(width,width,height),'glow','08_DETAILS')
for i,(x,y,z) in enumerate(((-.371,-.353,.140),(-.354,-.480,.136),(-.397,-.370,.235))):
    box('Supply_Crate_%d'%i,(x,y,z),(.111,.105,.108),'crate','08_DETAILS')
    box('Crate_Band_%d'%i,(x,y-.055,z),(.027,.012,.106),'iron','08_DETAILS')
for i,(x,y) in enumerate(((.47,.128),(-.210,.494))):
    box('Ground_Moss_Base_%d'%i,(x,y,.097),(.102,.085,.035),'moss','08_DETAILS')
    box('Ground_Moss_Top_%d'%i,(x-.013,y+.013,.118),(.060,.057,.019),'moss','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_1'
root['civilization'],root['city_level'],root['asset_only'] = 'orc',1,True
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025, (maximum,wall_inner_apothem)

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.47]
scene['door_clearance'] = [.238,.359]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Centro da Cidade Orc — Nível I'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'],scene['civilization'],scene['asset_only'] = 1,'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98], 'cutstone':[145,141,121], 'foundation':[68,77,77],
    'paving':[107,113,88], 'timber':[78,53,35], 'door':[123,89,54],
    'roof':[130,58,39], 'roof_dark':[83,40,30], 'iron':[53,65,65],
    'iron_light':[126,137,130], 'bone':[225,215,174], 'faction':[170,60,39],
    'crate':[123,97,58], 'moss':[87,108,55]}
scene['scale_note'] = 'Native map units; pointy-top hex tile radius 1, foundation radius .84. Fits independent fortification ring; no runtime integration.'
scene['design_note'] = 'Orc level I of four: heavy timber chief hall on basalt, long stepped rust-red hide roof with black iron binding, paired ivory doorway tusks and abstract jaw clan crest. One low carved assembly totem, short flag, communal brazier and supplies. No perimeter walls. Taller chief keeps, additional roof volumes and towers reserved for levels II–IV.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,
          'wall_inner_apothem':wall_inner_apothem,'asset_only':True}
