"""Hex-first Rogue Guild, built from original block geometry via live Blender MCP.
No character reference required. Preserve the user's existing scenes.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'Rogue_Guild_Hex_V1'
OUT = ROOT / 'assets/generated/humans/buildings/rogue_guild_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('Rogue Guild scene exists; preserve its edits.')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION', '02_HALL', '03_ROOFS', '04_LOOKOUT',
              '05_COURTYARD', '06_TRAINING', '07_HERALDRY', '08_DETAILS', '09_STUDIO'):
    collection = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename, names in (
    ('guardian_hall_hex_v2_model.py', ('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py', ('clip_to_hex','vertical_prism')),
    ('ranger_camp_hex_v1_model.py', ('beam',)),
):
    tree = ast.parse((PIPELINE / filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), '<shared_primitives>', 'exec'))


def dagger(name, center, length, angle=0, group='06_TRAINING'):
    # Short double-edged blade, broad tip steps, compact guard and leather grip.
    c = Vector(center)
    direction = Vector((math.sin(angle), 0, math.cos(angle)))
    across = Vector((math.cos(angle), 0, -math.sin(angle)))
    profile = [(-.09,.03),(.09,.03),(.09,.37),(.055,.37),(.055,.48),
               (.023,.48),(.023,.56),(-.023,.56),(-.023,.48),(-.055,.48),
               (-.055,.37),(-.09,.37)]
    n = len(profile)
    verts = [tuple(c + across*u*length + direction*v*length + Vector((0,d,0)))
             for d in (-length*.025,length*.025) for u,v in profile]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh(name+'_Blade', verts, faces, 'iron_light', group)
    beam(name+'_Guard', tuple(c-across*length*.18), tuple(c+across*length*.18),
         length*.06, 'brass', group)
    beam(name+'_Grip', tuple(c-direction*length*.30), tuple(c-direction*length*.035),
         length*.075, 'leather', group)
    p = c-direction*length*.33
    box(name+'_Pommel', tuple(p), (length*.10,length*.08,length*.09), 'brass', group)


# Shared six-sided map foundation; cool paving makes the silhouette readable.
polygon_prism('Hex_Foundation', hexagon(.92), 0,.035, 'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim', hexagon(.90), .035,.065, 'cutstone','01_FOUNDATION')
polygon_prism('Guild_Paving', hexagon(.85), .065,.078, 'paving','01_FOUNDATION')

# Rear pentagonal headquarters follows the rear tile diagonals.
footprint = [(-.48,.055),(.48,.055),(.48,.395),(0,.675),(-.48,.395)]
polygon_prism('Hall_StoneFoot', footprint, .078,.185,'stone','02_HALL')
polygon_prism('Hall_Plaster', footprint, .185,.775,'plaster','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_LowerBeam_%d'%i,a,b,.038,.192,.228,'timber','02_HALL')
    wall('Hall_UpperBeam_%d'%i,a,b,.051,.736,.793,'timber','02_HALL')
    box('Hall_CornerPost_%d'%i,(a[0],a[1],.487),(.044,.044,.563),'timber')
for x in (-.255,.195):
    box('Hall_FrontStud_'+str(x),(x,.033,.48),(.030,.035,.52),'timber')
wall('Rear_Diagonal_Brace',(.46,.395),(.245,.521),.031,.455,.49,'timber','02_HALL')
# Hipped roof courses are individually clipped; no overhang into neighbor tiles.
for j in range(6):
    sx,sy = 1.12-j*.167, .80-j*.116
    points = [(-sx/2,.39-sy/2),(sx/2,.39-sy/2),(sx/2,.39+sy/2),(-sx/2,.39+sy/2)]
    polygon_prism('Hall_Roof_%d'%j,clip_to_hex(points,.835),.805+j*.053,.858+j*.053,
                  'roof','03_ROOFS')
box('Hall_RidgeCap',(0,.39,1.135),(.23,.23,.035),'roof_dark','03_ROOFS')

# Discreet entrance, barred side window and projecting purple hood over the door.
box('Door_Recess',(-.07,.035,.382),(.253,.026,.428),'shadow')
box('Door_Leaf',(-.07,.015,.374),(.216,.018,.405),'door')
for z in (.25,.485):
    box('Door_Band_'+str(z),(-.07,-.002,z),(.215,.016,.023),'iron')
box('Door_Lock',(.005,-.018,.358),(.025,.023,.036),'brass')
box('Entry_Step',(-.07,-.08,.104),(.303,.17,.052),'stone','05_COURTYARD')
box('Front_WindowShadow',(.323,.026,.463),(.186,.025,.211),'shadow')
for x in (.223,.423):
    box('Front_WindowJamb_'+str(x),(x,.011,.463),(.026,.032,.254),'timber')
for x in (.278,.323,.368):
    box('Front_WindowBar_'+str(x),(x,.002,.463),(.014,.014,.205),'iron')
box('Front_WindowSill',(.323,-.001,.343),(.235,.058,.035),'timber')
for j in range(3):
    box('Door_Canopy_%d'%j,(-.07,-.101+j*.060,.621+j*.025),(.315,.062,.025),'canvas_violet','03_ROOFS')
box('Canopy_Fascia',(-.07,-.13,.603),(.318,.023,.057),'canvas_violet','03_ROOFS')

# Hexagonal urban lookout, timber upper floor rather than a military battlement.
tc = (-.48,.02)
polygon_prism('Lookout_Stone',hexagon(.19,tc),.078,.52,'stone','04_LOOKOUT')
polygon_prism('Lookout_UpperFloor',hexagon(.205,tc),.52,1.036,'plaster','04_LOOKOUT')
for z in (.52,.77,1.036):
    polygon_prism('Lookout_Band_'+str(z),hexagon(.222,tc),z-.024,z+.024,'timber','04_LOOKOUT')
for i,p in enumerate(hexagon(.211,tc)):
    box('Lookout_Post_%d'%i,(p[0],p[1],.788),(.031,.031,.51),'timber','04_LOOKOUT')
box('Lookout_FrontWindow',(-.48,-.164,.893),(.195,.017,.164),'shadow','04_LOOKOUT')
for x in (-.541,-.48,-.419):
    box('Lookout_FrontBar_'+str(x),(x,-.177,.893),(.014,.016,.16),'timber','04_LOOKOUT')
box('Lookout_Sill',(-.48,-.18,.807),(.225,.033,.025),'timber','04_LOOKOUT')
# Dark shutters on the exposed outer side.
box('Lookout_LeftShutter',(-.666,.021,.896),(.019,.153,.167),'door','04_LOOKOUT')
for z in (.843,.945):
    box('Lookout_ShutterBand_'+str(z),(-.68,.021,z),(.014,.156,.014),'iron','04_LOOKOUT')
for j in range(5):
    polygon_prism('Lookout_Roof_%d'%j,hexagon(.27-j*.047,tc),1.061+j*.052,1.113+j*.052,
                  'roof','03_ROOFS')
box('Lookout_Finial',(-.48,.02,1.341),(.058,.058,.048),'iron','03_ROOFS')

# Lower front enclosure traces two tile edges, leaving the front tip open.
for sign in (-1,1):
    a,b = (sign*.665,-.31),(sign*.23,-.595)
    wall('Court_Wall_'+str(sign),a,b,.041,.078,.235,'stone','05_COURTYARD')
    wall('Court_WallCap_'+str(sign),a,b,.059,.235,.259,'cutstone','05_COURTYARD')
    for i,p in enumerate((a,b)):
        box('Court_Pier_%d_%d'%(sign,i),(p[0],p[1],.211),(.073,.073,.266),'stone','05_COURTYARD')
        box('Court_PierCap_%d_%d'%(sign,i),(p[0],p[1],.355),(.090,.090,.026),'cutstone','05_COURTYARD')
for i,(x,y) in enumerate(((-.01,-.695),(-.055,-.535),(-.03,-.38))):
    box('Entry_Paver_%d'%i,(x,y,.085),(.158,.123,.014),'cutstone','05_COURTYARD',(-1)**i*.10)

# Two wooden torso targets teach precise close-range attacks; no troop model used.
for i,(x,y,angle) in enumerate(((.37,-.19,-.16),(.49,.01,.13))):
    box('Dummy_%d_Foot'%i,(x,y,.097),(.18,.135,.039),'timber','06_TRAINING',angle)
    box('Dummy_%d_Stake'%i,(x,y,.235),(.031,.032,.27),'timber','06_TRAINING')
    box('Dummy_%d_Torso'%i,(x,y,.359),(.116,.082,.145),'straw','06_TRAINING',angle)
    box('Dummy_%d_Shoulder'%i,(x,y,.417),(.204,.074,.043),'straw','06_TRAINING',angle)
    box('Dummy_%d_Head'%i,(x,y,.476),(.082,.078,.075),'straw','06_TRAINING',angle)
    box('Dummy_%d_ThroatMark'%i,(x,y-.045,.442),(.047,.012,.024),'target_red','06_TRAINING')
    box('Dummy_%d_HeartMark'%i,(x+.025,y-.047,.373),(.032,.012,.032),'target_red','06_TRAINING')
    dagger('Dummy_%d_PlantedDagger'%i,(x+.025,y-.066,.332),.14,.10)

# Throwing board on the left and a low vault rail provide a second training area.
box('ThrowingTarget_Post',(-.46,-.40,.249),(.035,.035,.34),'timber','06_TRAINING')
box('ThrowingTarget_Foot',(-.46,-.40,.096),(.18,.13,.036),'timber','06_TRAINING')
box('ThrowingTarget_Board',(-.46,-.40,.401),(.224,.043,.246),'door','06_TRAINING')
box('ThrowingTarget_Inset',(-.46,-.428,.401),(.164,.017,.184),'straw','06_TRAINING')
box('ThrowingTarget_Bullseye',(-.46,-.442,.401),(.054,.014,.060),'target_red','06_TRAINING')
dagger('ThrowingTarget_Embedded',(-.47,-.46,.368),.15,-.36)
for x in (.13,.29):
    box('Vault_Post_'+str(x),(x,-.44,.17),(.028,.030,.184),'timber','06_TRAINING')
box('Vault_Rail',(.21,-.44,.246),(.228,.033,.037),'timber','06_TRAINING')

# A compact supply bench with dagger rack and small colored alchemy bottles.
box('Equipment_Bench',(-.34,-.213,.218),(.19,.104,.025),'door','06_TRAINING')
for x in (-.405,-.275):
    box('Equipment_Leg_'+str(x),(x,-.213,.149),(.029,.072,.124),'timber','06_TRAINING')
for i,x in enumerate((-.394,-.344,-.294)):
    dagger('Stored_Dagger_%d'%i,(x,-.272,.295),.13,0)
box('Bench_BladeRail',(-.344,-.263,.273),(.185,.022,.024),'timber','06_TRAINING')
for i,x in enumerate((-.382,-.308)):
    box('Bottle_%d'%i,(x,-.206,.262),(.032,.031,.063),'bottle_green' if i==0 else 'bottle_violet','08_DETAILS')
    box('Bottle_Stopper_%d'%i,(x,-.206,.302),(.019,.019,.017),'leather','08_DETAILS')
box('Supply_Chest',(.55,.26,.164),(.167,.19,.171),'crate','08_DETAILS')
box('Supply_Chest_Lid',(.55,.26,.258),(.181,.202,.025),'timber','08_DETAILS')
box('Supply_Chest_Lock',(.55,.151,.216),(.032,.018,.044),'brass','08_DETAILS')

# Large map-readable hood badge with crossed SHORT blades beneath the face.
box('Guild_Crest_Backing',(.02,-.019,.924),(.415,.047,.425),'timber','07_HERALDRY')
box('Guild_Crest_Plate',(.02,-.050,.924),(.377,.019,.389),'canvas_violet','07_HERALDRY')
hood = [(-.152,-.083),(.152,-.083),(.152,.043),(.112,.043),(.112,.118),(.050,.186),
        (-.050,.186),(-.112,.118),(-.112,.043),(-.152,.043)]
vertical_prism('Crest_Hood',hood,(.02,-.072,.946),.022,'hood','07_HERALDRY')
face = [(-.091,-.052),(.091,-.052),(.091,.039),(.048,.107),(-.048,.107),(-.091,.039)]
vertical_prism('Crest_FaceShadow',face,(.02,-.089,.946),.017,'shadow','07_HERALDRY')
box('Crest_EyeSlit',(.02,-.102,.971),(.105,.010,.018),'iron_light','07_HERALDRY')
dagger('Crest_Dagger_Left',(-.005,-.115,.820),.22,math.radians(52),'07_HERALDRY')
dagger('Crest_Dagger_Right',(.045,-.134,.820),.22,math.radians(-52),'07_HERALDRY')
for x in (-.167,.207):
    for z in (.732,1.116):
        box('Crest_Rivet_%s_%s'%(x,z),(x,-.049,z),(.016,.017,.016),'brass','07_HERALDRY')

# Small faction banner and shielded lanterns; no skulls or exaggerated dungeon props.
box('Flag_Pole',(.282,.387,1.18),(.015,.015,.435),'timber','07_HERALDRY')
box('Flag_Cap',(.282,.387,1.408),(.027,.027,.027),'iron_light','07_HERALDRY')
flag = box('Guild_Flag',(.379,.387,1.325),(.18,.013,.13),'banner','07_HERALDRY')
flag['banner_center'],flag['banner_size'],flag['heraldry'] = [.379,.387,1.325],[.18,.13],'dagger'
for i,(x,y,z) in enumerate(((-.242,-.024,.51),(.606,.116,.372))):
    box('Lantern_%d'%i,(x,y,z),(.033,.040,.052),'glow','08_DETAILS')
    for dz in (-.037,.037):
        box('Lantern_%d_Cap_%s'%(i,dz),(x,y,z+dz),(.047,.053,.020),'iron','08_DETAILS')
    box('Lantern_%d_FrontBar'%i,(x,y-.026,z),(.010,.009,.053),'iron','08_DETAILS')
for name,x,y in (('Rear',-.20,.70),('Right',.65,-.12)):
    box('Shrub_'+name+'_Base',(x,y,.116),(.128,.101,.077),'foliage','08_DETAILS')
    box('Shrub_'+name+'_Top',(x+.016,y,.172),(.078,.077,.036),'foliage_light','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_rogue_guild'
root['design'] = 'Original hex-first assassination training guild; native 4X map scale.'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2+1e-6, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.55]
scene['door_clearance'] = [.216,.405]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Guilda dos Ladinos'
scene['trains'] = ['v2_unit_rogue','v2_unit_saboteur','v2_unit_assassin']
scene['excludes'] = ['v2_legendary_shadow_master']
scene['palette_overrides'] = {
    'stone':[111,122,134], 'plaster':[145,146,156], 'paving':[119,126,137],
    'timber':[76,57,48], 'door':[106,78,61], 'roof':[40,52,83], 'roof_dark':[29,38,62],
    'canvas_violet':[91,62,111], 'hood':[119,85,139], 'brass':[178,146,83],
    'leather':[69,55,59], 'target_red':[149,62,73], 'bottle_green':[72,137,103],
    'bottle_violet':[131,94,159], 'foliage':[61,81,66], 'foliage_light':[80,103,74],
}
scene['scale_note'] = 'Native 4X map units, pointy-top tile radius 1, multiplier 1.0. Symbolic guild architecture.'
scene['design_note'] = 'Asymmetric pentagonal headquarters, hexagonal timber lookout, dark slate hipped roofs and violet canopy. Hood and crossed short daggers mark the entrance. Precise-strike wooden dummies, throwing board, vault rail, blade bench and small bottles identify assassination training; original geometry with no character dependencies.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.216,.405],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'allowed':math.sqrt(3)/2}
