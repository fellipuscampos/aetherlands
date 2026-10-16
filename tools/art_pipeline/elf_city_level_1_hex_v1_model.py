"""Elven city I: blocky woodland council pavilion. Live Blender MCP, asset only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'Elf_City_Level_1_Hex_V1'
RELATIVE_OUT = 'assets/generated/elves/buildings/elf_city_level_1_hex_v1'
OUT = ROOT / RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Elven City I source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_COUNCIL','03_ROOFS','04_TREE','05_COURTYARD',
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


def leaf(name,center,width,height,depth,region='gold',group='08_DETAILS'):
    # Squared leaf outline; flat surfaces, no smooth organic meshes.
    profile = [(0,-.5),(.16,-.34),(.16,-.20),(.30,-.20),(.30,.15),
               (.16,.15),(.16,.34),(0,.5),(-.16,.34),(-.16,.15),
               (-.30,.15),(-.30,-.20),(-.16,-.20),(-.16,-.34)]
    vertical_prism(name,[(x*width,z*height) for x,z in profile],center,depth,region,group)


polygon_prism('Hex_Pale_Foundation',hexagon(.84),0,.030,'foundation','01_FOUNDATION')
polygon_prism('Hex_Ivory_Rim',hexagon(.825),.030,.058,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Moss_Paving',hexagon(.775),.058,.076,'paving','01_FOUNDATION')

# One compact civic volume, with fine timber structure and light stone infill.
cx,cy = .045,.165
footprint = [(-.255,-.085),(.345,-.085),(.345,.302),(.045,.515),(-.255,.302)]
polygon_prism('Council_Stone_Foot',footprint,.076,.160,'cutstone','02_COUNCIL')
polygon_prism('Council_Ivory_Walls',footprint,.160,.661,'plaster','02_COUNCIL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Council_Base_Beam_%d'%i,a,b,.030,.156,.191,'timber','02_COUNCIL')
    wall('Council_Eave_Beam_%d'%i,a,b,.039,.627,.676,'timber','02_COUNCIL')
    box('Council_Slender_Post_%d'%i,(a[0],a[1],.417),(.040,.044,.473),'timber','06_ARCHITECTURE')
    box('Council_Post_Foot_%d'%i,(a[0],a[1],.186),(.063,.067,.062),'cutstone','06_ARCHITECTURE')
    box('Council_Post_Capital_%d'%i,(a[0],a[1],.628),(.063,.067,.032),'gold','06_ARCHITECTURE')

# Tall stepped roof with a narrow ridge and leafy gold finial; level I has one roof.
for j in range(7):
    sx,sy = .832-j*.106,.756-j*.092
    points = [(cx-sx/2,cy-sy/2),(cx+sx/2,cy-sy/2),
              (cx+sx/2,cy+sy/2),(cx-sx/2,cy+sy/2)]
    polygon_prism('Emerald_Roof_Course_%d'%j,clip_to_hex(points,.76),
                  .680+j*.058,.738+j*.058,'roof','03_ROOFS')
    if j in (0,3,6):
        box('Roof_Front_Gold_Edge_%d'%j,(cx,cy-sy/2-.005,.691+j*.058),
            (sx+.008,.014,.017),'gold','03_ROOFS')
box('Roof_Ridge',(cx,cy,1.102),(.125,.115,.034),'roof_dark','03_ROOFS')
box('Finial_Socket',(cx,cy,1.133),(.057,.056,.033),'gold','08_DETAILS')
leaf('Roof_Leaf_Finial',(cx,cy,1.226),.117,.173,.023)

# Branchlike exterior braces made from stair profiles, with open space underneath.
brace = [(0,0),(.035,0),(.035,.19),(.061,.19),(.061,.32),(.093,.32),
         (.093,.43),(.151,.43),(.151,.467),(.067,.467),(.067,.37),
         (.029,.37),(.029,.24),(0,.24)]
for sign in (-1,1):
    vertical_prism('Branch_Brace_'+str(sign),[(sign*x,z) for x,z in brace],
                   (cx+sign*.303,-.079,.201),.048,'timber','06_ARCHITECTURE')
    box('Brace_Stone_Pedestal_'+str(sign),(cx+sign*.320,-.079,.147),
        (.084,.096,.143),'cutstone','06_ARCHITECTURE')

# Narrow pointed portal with stepped ivory framing and a leaf clasp.
portal = [(-.119,0),(.119,0),(.119,.247),(.080,.247),(.080,.298),
          (.039,.298),(.039,.345),(0,.385),(-.039,.345),(-.039,.298),
          (-.080,.298),(-.080,.247),(-.119,.247)]
vertical_prism('Entry_Point_Shadow',portal,(cx,-.103,.169),.027,'shadow','06_ARCHITECTURE')
for sign in (-1,1):
    box('Entry_Wood_Leaf_'+str(sign),(cx+sign*.050,-.124,.293),
        (.094,.022,.243),'door','06_ARCHITECTURE')
    box('Entry_Slender_Jamb_'+str(sign),(cx+sign*.133,-.132,.317),
        (.029,.061,.303),'cutstone','06_ARCHITECTURE')
    for step,(x,z) in enumerate(((.112,.467),(.077,.506),(.042,.545))):
        box('Point_Arch_%s_%d'%(sign,step),(cx+sign*x,-.132,z),
            (.039,.062,.041),'cutstone','06_ARCHITECTURE')
    box('Door_Gold_Hinge_'+str(sign),(cx+sign*.085,-.140,.293),
        (.014,.013,.184),'gold','08_DETAILS')
    box('Door_Gold_Handle_'+str(sign),(cx+sign*.019,-.144,.300),
        (.012,.015,.025),'gold','08_DETAILS')
box('Entry_Arch_Cap',(cx,-.132,.572),(.049,.062,.029),'cutstone','06_ARCHITECTURE')
leaf('Entry_Leaf_Clasp',(cx,-.169,.565),.055,.063,.013)
box('Civic_Badge_Backing',(cx,-.127,.628),(.103,.035,.092),'timber','06_ARCHITECTURE')
box('Civic_Faction_Cloth',(cx,-.151,.628),(.083,.017,.074),'faction','07_FACTION')
leaf('Civic_Leaf_Crest',(cx,-.165,.630),.070,.061,.012)
for i,(y,width,top) in enumerate(((-.177,.302,.160),(-.261,.334,.128),(-.345,.365,.099))):
    box('Ivory_Entry_Step_%d'%i,(cx,y,(.076+top)/2),(width,.087,top-.076),'cutstone','05_COURTYARD')
for i,(x,y) in enumerate(((cx,-.450),(cx-.014,-.560),(0,-.674))):
    box('Court_Path_%d'%i,(x,y,.083),(.137,.081,.014),'cutstone','05_COURTYARD',(-1)**i*.07)

# One living tree at the council's side. Block canopy, branching square trunk.
tx,ty = -.470,.150
box('Tree_Root_Stone',(tx,ty,.101),(.213,.251,.050),'stone','04_TREE')
box('Tree_Main_Trunk',(tx,ty,.467),(.075,.087,.735),'timber','04_TREE')
for i,(x,y,z,sx,sy,sz) in enumerate((
    (tx-.034,ty-.025,.121,.136,.109,.066),
    (tx+.024,ty+.034,.145,.113,.113,.093),
    (tx-.054,ty,.535,.123,.063,.066),
    (tx-.087,ty,.587,.055,.063,.138),
    (tx+.049,ty+.013,.685,.133,.053,.052),
    (tx+.094,ty+.013,.746,.046,.053,.110),
)):
    box('Tree_Root_Branch_%d'%i,(x,y,z),(sx,sy,sz),'timber','04_TREE')
for i,(x,y,z,sx,sy,sz,reg) in enumerate((
    (tx-.068,ty-.011,.712,.242,.215,.124,'foliage'),
    (tx-.088,ty+.010,.793,.201,.194,.076,'foliage_light'),
    (tx+.022,ty+.025,.840,.234,.225,.148,'foliage'),
    (tx+.007,ty+.028,.941,.177,.180,.079,'foliage_light'),
    (tx+.018,ty+.028,.998,.094,.102,.046,'foliage_light'),
)):
    box('Tree_Block_Canopy_%d'%i,(x,y,z),(sx,sy,sz),reg,'04_TREE')

# Side windows: warm wood filigree over translucent-looking pale aqua paint.
box('Right_Window_Glass',(.361,.106,.427),(.022,.108,.191),'glass','06_ARCHITECTURE')
for y in (.044,.168):
    box('Right_Window_Jamb_'+str(y),(.378,y,.427),(.027,.021,.224),'timber','06_ARCHITECTURE')
for z in (.314,.540):
    box('Right_Window_Sill_'+str(z),(.378,.106,z),(.032,.150,.020),'cutstone','06_ARCHITECTURE')
box('Right_Window_Mullion',(.377,.106,.427),(.022,.014,.199),'gold','08_DETAILS')
box('Right_Window_Crossbar',(.377,.106,.427),(.022,.115,.014),'gold','08_DETAILS')
leaf('Right_Window_Cap_Leaf',(.377,.106,.572),.055,.049,.022)
box('Front_Small_Window',(.254,-.103,.410),(.075,.023,.160),'glass','06_ARCHITECTURE')
for z in (.323,.497):
    box('Front_Window_Edge_'+str(z),(.254,-.121,z),(.105,.034,.020),'timber','06_ARCHITECTURE')
box('Front_Window_Mullion',(.254,-.124,.410),(.014,.021,.159),'gold','08_DETAILS')

# Open civic court, moonwell and seating; no weapons or training props.
fx,fy = -.359,-.348
box('Moonwell_Foot',(fx,fy,.094),(.203,.196,.036),'cutstone','05_COURTYARD')
box('Moonwell_Water',(fx,fy,.157),(.140,.129,.017),'water','05_COURTYARD')
for dx,dy in ((-.089,0),(.089,0),(0,-.085),(0,.085)):
    box('Moonwell_Pale_Rim_%s_%s'%(dx,dy),(fx+dx,fy+dy,.146),
        (.025 if dx else .165,.025 if dy else .188,.076),'cutstone','05_COURTYARD')
box('Moonwell_Leaf_Stem',(fx,fy+.060,.205),(.016,.017,.103),'gold','08_DETAILS')
leaf('Moonwell_Leaf',(fx,fy+.060,.280),.075,.088,.015)
for x in (.323,.473):
    box('Council_Bench_Leg_'+str(x),(x,-.357,.112),(.025,.053,.071),'timber','08_DETAILS')
box('Council_Bench_Seat',(.398,-.357,.155),(.217,.073,.024),'door','08_DETAILS')
box('Council_Bench_Back',(.398,-.322,.197),(.217,.021,.068),'timber','08_DETAILS')
for i,(x,y) in enumerate(((.442,.325),(.354,-.522),(-.271,-.539))):
    box('Garden_Stone_%d'%i,(x,y,.095),(.104,.087,.038),'stone','05_COURTYARD')
    box('Garden_Block_Shrub_%d'%i,(x,y,.133),(.092,.076,.049),'foliage','08_DETAILS')
    box('Garden_Shrub_Top_%d'%i,(x+.011,y,.167),(.058,.052,.024),'foliage_light','08_DETAILS')
for i,(x,y) in enumerate(((.442,.325),(-.271,-.539))):
    box('Garden_Flower_%d'%i,(x+.019,y-.023,.168),(.029,.024,.021),'flower','08_DETAILS')

# A short civic pennant, separated for future owner tint.
px,py = .465,.119
box('Civic_Pennant_Stone',(px,py,.099),(.078,.078,.047),'cutstone','08_DETAILS')
box('Civic_Pennant_Pole',(px,py,.398),(.018,.020,.553),'timber','08_DETAILS')
box('Civic_Pennant_Faction',(px-.046,py,.573),(.100,.014,.151),'faction','07_FACTION')
leaf('Civic_Pennant_Leaf_Front',(px-.046,py-.013,.584),.077,.077,.008)
leaf('Civic_Pennant_Leaf_Back',(px-.046,py+.013,.584),.077,.077,.008)
box('Civic_Pennant_Cap',(px,py,.686),(.029,.031,.025),'gold','08_DETAILS')
for sign in (-1,1):
    x = cx+sign*.169
    box('Entry_Lantern_Frame_'+str(sign),(x,-.143,.439),(.034,.045,.056),'timber','08_DETAILS')
    box('Entry_Lantern_Glass_'+str(sign),(x,-.169,.439),(.022,.014,.035),'glow','08_DETAILS')
    box('Entry_Lantern_Cap_'+str(sign),(x,-.147,.476),(.047,.047,.020),'gold','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_1'
root['civilization'],root['city_level'],root['asset_only'] = 'elf',1,True
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025, (maximum,wall_inner_apothem)

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.49]
scene['door_clearance'] = [.194,.243]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Centro da Cidade Élfica — Nível I'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'],scene['civilization'],scene['asset_only'] = 1,'elf',True
scene['palette_overrides'] = {
    'foundation':[110,128,116],'stone':[137,158,131],'cutstone':[209,215,183],
    'paving':[127,146,109],'plaster':[222,222,192],'timber':[113,91,55],
    'door':[158,127,76],'roof':[48,122,88],'roof_dark':[30,81,66],
    'gold':[206,181,112],'faction':[91,167,143],'glass':[112,179,161],
    'water':[89,165,168],'foliage':[63,119,66],'foliage_light':[99,151,74],
    'flower':[218,188,138]}
scene['scale_note'] = 'Native map units; pointy-top hex tile radius 1, foundation radius .84. Fits the independent wall ring. Asset only, no runtime integration.'
scene['design_note'] = 'Elven city I of four: one ivory-and-timber council pavilion, slender posts and stepped branch braces, tall emerald hipped roof with gold leaf finial, pointed portal and leaf civic emblem. One square-canopy living tree, moonwell, bench, garden and short pennant. No perimeter walls; larger halls, towers and additional roofs reserved for levels II–IV.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,
          'wall_inner_apothem':wall_inner_apothem,'asset_only':True}
