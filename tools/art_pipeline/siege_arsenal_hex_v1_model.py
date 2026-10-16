"""Original blocky siege workshop, native hex radius 1, built via live Blender MCP.
Open assembly shed, display catapult, timber crane and spare siege components.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'Siege_Arsenal_Hex_V1'
OUT = ROOT / 'assets/generated/humans/buildings/siege_arsenal_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('Siege Arsenal scene exists; preserve its edits.')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_WORKSHOP','03_ROOFS','04_CATAPULT',
              '05_COURTYARD','06_EQUIPMENT','07_HERALDRY','08_DETAILS','09_STUDIO'):
    collection = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon','wall')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
    ('ranger_camp_hex_v1_model.py',('beam',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))


def wheel(name, center, diameter, depth, group='06_EQUIPMENT'):
    # Closed stepped wheel, axle along X. Metal tire, wooden disk and four spokes.
    profile = [(-.28,.5),(.28,.5),(.28,.4),(.42,.4),(.42,.24),(.5,.24),
               (.5,-.24),(.42,-.24),(.42,-.4),(.28,-.4),(.28,-.5),
               (-.28,-.5),(-.28,-.4),(-.42,-.4),(-.42,-.24),(-.5,-.24),
               (-.5,.24),(-.42,.24),(-.42,.4),(-.28,.4)]
    cx,cy,cz = center
    n = len(profile)
    for label,scale,thickness,region in (('Tire',1,depth,'iron'),('Wood',.78,depth+.004,'door')):
        verts = [(cx+dx,cy+y*diameter*scale,cz+z*diameter*scale)
                 for dx in (-thickness/2,thickness/2) for y,z in profile]
        faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh(name+'_'+label,verts,faces,region,group)
    for side in (-1,1):
        x = cx+side*(depth/2+.006)
        box(name+'_SpokeV_'+str(side),(x,cy,cz),(.009,diameter*.10,diameter*.69),'timber',group)
        box(name+'_SpokeH_'+str(side),(x,cy,cz),(.009,diameter*.69,diameter*.10),'timber',group)
        box(name+'_Hub_'+str(side),(x+side*.006,cy,cz),(.018,diameter*.23,diameter*.23),'iron_light',group)


# The family foundation follows the map's six exact edges, with an 8% margin.
polygon_prism('Hex_Foundation',hexagon(.92),0,.035,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim',hexagon(.90),.035,.065,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Paving',hexagon(.85),.065,.078,'paving','01_FOUNDATION')
polygon_prism('Workyard_Pavers',[(-.63,.10),(.63,.10),(.63,-.31),(.28,-.59),
    (0,-.75),(-.28,-.59),(-.63,-.31)],.078,.086,'yard','05_COURTYARD')

# Rear pentagonal workshop: a genuinely open wide left bay, closed right store.
footprint = [(-.61,.16),(.61,.16),(.61,.32),(0,.675),(-.61,.32)]
polygon_prism('Workshop_Platform',footprint,.078,.124,'stone','02_WORKSHOP')
for i in range(1,5):
    a,b = footprint[i],footprint[(i+1)%5]
    wall('Workshop_Wall_%d'%i,a,b,.044,.124,.607,'door','02_WORKSHOP')
    wall('Workshop_Sill_%d'%i,a,b,.058,.124,.204,'stone','02_WORKSHOP')
    wall('Workshop_Eave_%d'%i,a,b,.062,.578,.636,'timber','02_WORKSHOP')
for x in (-.60,.20,.60):
    box('Portal_Post_'+str(x),(x,.153,.367),(.060,.061,.487),'timber','02_WORKSHOP')
    box('Portal_PostBoot_'+str(x),(x,.153,.171),(.081,.080,.090),'iron','02_WORKSHOP')
box('Portal_Lintel',(0,.153,.615),(1.286,.082,.067),'timber','02_WORKSHOP')
for x,sign in ((-.563,1),(.163,-1)):
    profile = [(0,0),(sign*.114,0),(0,-.118)]
    vertical_prism('Portal_Gusset_'+str(sign),profile,(x,.143,.582),.054,'timber','02_WORKSHOP')
box('Store_StoneFoot',(.407,.284,.176),(.355,.220,.104),'stone','02_WORKSHOP')
box('Store_Body',(.407,.284,.393),(.355,.220,.33),'plaster','02_WORKSHOP')
box('Store_WindowShadow',(.407,.164,.403),(.203,.026,.172),'shadow','02_WORKSHOP')
for x in (.331,.407,.483):
    box('Store_WindowBar_'+str(x),(x,.147,.403),(.014,.016,.173),'iron','02_WORKSHOP')
box('Store_WindowSill',(.407,.145,.306),(.24,.040,.032),'timber','02_WORKSHOP')

# Blue stepped gable, individually recut to the hex; rear tip is fully covered.
for j in range(6):
    half_width = (.64-j*.105)/2
    points = [(-.654,.405-half_width),(.654,.405-half_width),
              (.654,.405+half_width),(-.654,.405+half_width)]
    polygon_prism('Workshop_Roof_%d'%j,clip_to_hex(points,.835),.664+j*.049,.713+j*.049,
                  'roof','03_ROOFS')
box('Workshop_Ridge',(0,.405,.975),(1.321,.058,.034),'roof_dark','03_ROOFS')
# Low roof vent echoes a workshop smoke hood without an oversized forge tower.
box('Roof_VentBody',(-.29,.408,1.008),(.202,.160,.080),'iron','02_WORKSHOP')
box('Roof_VentSlit',(-.29,.32,1.014),(.145,.019,.034),'shadow','02_WORKSHOP')
box('Roof_VentCap',(-.29,.408,1.057),(.242,.196,.026),'iron_light','03_ROOFS')

# Tool bench and stocks inside the open bay, visible beneath the portal.
box('Interior_BenchTop',(-.22,.427,.303),(.49,.135,.037),'door','06_EQUIPMENT')
for x in (-.407,-.033):
    box('Interior_BenchLeg_'+str(x),(x,.427,.204),(.040,.093,.163),'timber','06_EQUIPMENT')
box('Interior_AnvilFoot',(-.38,.415,.348),(.072,.075,.057),'iron','06_EQUIPMENT')
box('Interior_AnvilTop',(-.38,.415,.390),(.13,.067,.035),'iron_light','06_EQUIPMENT')
box('Interior_Blueprint',(-.16,.417,.326),(.161,.099,.011),'blueprint','06_EQUIPMENT')
for y in (.401,.432):
    box('Blueprint_Line_'+str(y),(-.16,y,.335),(.119,.006,.004),'chalk','06_EQUIPMENT')
for i in range(3):
    box('Back_TimberStock_%d'%i,(-.49,.34,.152+i*.053),(.09,.202,.047),'door','06_EQUIPMENT')

# Complete display catapult in the foreground, aimed towards the open front.
cx,cy = -.25,-.245
for dx in (-.11,.11):
    box('Catapult_ChassisRail_'+str(dx),(cx+dx,cy,.267),(.049,.383,.043),'timber','04_CATAPULT')
for dy in (-.143,.143):
    box('Catapult_Crossmember_'+str(dy),(cx,cy+dy,.262),(.321,.045,.049),'door','04_CATAPULT')
    box('Catapult_Axle_'+str(dy),(cx,cy+dy,.186),(.382,.028,.031),'iron','04_CATAPULT')
    for dx in (-.174,.174):
        wheel('Catapult_Wheel_%s_%s'%(dx,dy),(cx+dx,cy+dy,.181),.19,.039,'04_CATAPULT')
for dx in (-.12,.12):
    box('Catapult_FramePost_'+str(dx),(cx+dx,cy,.358),(.042,.052,.20),'timber','04_CATAPULT')
    beam('Catapult_FrameBrace_'+str(dx),(cx+dx,cy+.139,.278),(cx+dx,cy,.426),.032,'door','04_CATAPULT')
box('Catapult_FrameCrossbar',(cx,cy,.447),(.30,.066,.047),'timber','04_CATAPULT')
box('Catapult_TorsionBundle',(cx,cy-.01,.408),(.29,.062,.049),'rope','04_CATAPULT')
for x in (cx-.113,cx+.113):
    box('Catapult_TorsionCollar_'+str(x),(x,cy-.01,.408),(.029,.074,.062),'iron','04_CATAPULT')
beam('Catapult_ThrowingArm',(cx,cy-.159,.284),(cx,cy+.191,.688),.035,'door','04_CATAPULT')
# Open square spoon with its stone; actual interior, not a solid crate.
bx,by = cx,cy+.191
box('Catapult_SpoonFloor',(bx,by,.704),(.121,.126,.021),'timber','04_CATAPULT')
for dx in (-.061,.061):
    box('Catapult_SpoonSide_'+str(dx),(bx+dx,by,.727),(.017,.133,.052),'door','04_CATAPULT')
for dy in (-.061,.061):
    box('Catapult_SpoonEnd_'+str(dy),(bx,by+dy,.727),(.106,.017,.052),'door','04_CATAPULT')
box('Catapult_LoadedStone',(bx,by,.742),(.064,.065,.056),'ammunition','04_CATAPULT')
box('Catapult_Winch',(cx,cy-.157,.316),(.263,.026,.028),'iron','04_CATAPULT')
box('Catapult_WinchHandle',(cx+.146,cy-.157,.340),(.019,.027,.07),'door','04_CATAPULT')
beam('Catapult_TensionRope',(cx,cy-.157,.330),(cx,cy-.038,.402),.009,'rope','04_CATAPULT')

# Timber assembly crane stands to the right, clear of the shed roof.
mx,my = .51,-.085
box('Crane_StoneFoot',(mx,my,.124),(.154,.158,.076),'stone','06_EQUIPMENT')
box('Crane_Mast',(mx,my,.622),(.066,.072,.924),'timber','06_EQUIPMENT')
for z in (.226,.710,1.015):
    box('Crane_MastBand_'+str(z),(mx,my,z),(.083,.087,.032),'iron','06_EQUIPMENT')
box('Crane_Jib',(mx,-.212,1.066),(.071,.453,.060),'door','06_EQUIPMENT')
box('Crane_EndCap',(mx,-.43,1.066),(.085,.031,.082),'iron','06_EQUIPMENT')
beam('Crane_DiagonalBrace',(mx,my,.784),(mx,-.357,1.027),.039,'timber','06_EQUIPMENT')
box('Crane_PulleyHousing',(mx,-.368,1.010),(.094,.084,.057),'iron','06_EQUIPMENT')
box('Crane_LiftingChain',(mx,-.368,.821),(.012,.013,.34),'iron_light','06_EQUIPMENT')
for j in range(7):
    box('Crane_ChainLink_%d'%j,(mx,-.368,.687+j*.044),(.023,.022,.015),'iron','06_EQUIPMENT')
hook = [(-.027,.030),(-.027,-.041),(.028,-.041),(.028,-.010),(.013,-.010),
        (.013,-.023),(-.010,-.023),(-.010,.030)]
vertical_prism('Crane_Hook',hook,(mx,-.368,.635),.018,'iron_light','06_EQUIPMENT')
box('Crane_SuspendedAxle',(mx,-.368,.508),(.241,.043,.055),'door','06_EQUIPMENT')
for sign in (-1,1):
    beam('Crane_LoadSling_'+str(sign),(mx,-.368,.613),(mx+sign*.091,-.368,.542),.014,'rope','06_EQUIPMENT')
    box('Crane_LoadBracket_'+str(sign),(mx+sign*.087,-.368,.509),(.027,.057,.068),'iron','06_EQUIPMENT')
box('Crane_WinchBody',(.565,-.085,.378),(.062,.101,.092),'iron','06_EQUIPMENT')
box('Crane_WinchCrank',(.610,-.085,.392),(.048,.018,.019),'iron_light','06_EQUIPMENT')
box('Crane_WinchGrip',(.629,-.085,.359),(.018,.019,.078),'door','06_EQUIPMENT')

# Ammunition tray and spare wheels flank a broad unobstructed front entrance.
box('StoneBin_Floor',(.105,-.518,.102),(.193,.139,.030),'timber','06_EQUIPMENT')
for dx in (-.101,.101):
    box('StoneBin_Side_'+str(dx),(.105+dx,-.518,.148),(.018,.151,.095),'door','06_EQUIPMENT')
for dy in (-.071,.071):
    box('StoneBin_End_'+str(dy),(.105,-.518+dy,.148),(.193,.016,.095),'door','06_EQUIPMENT')
for i,(dx,dy,z) in enumerate(((-.053,-.027,.164),(.026,-.027,.164),(-.016,.034,.164),(-.022,-.003,.224))):
    box('StoneBin_Ammo_%d'%i,(.105+dx,-.518+dy,z),(.061,.059,.062),'ammunition','06_EQUIPMENT')
wheel('Spare_Wheel_Left',(-.638,.002,.202),.237,.041)
wheel('Spare_Wheel_Right',(.64,.292,.197),.229,.034)
box('Spare_Axles',(-.576,-.287,.128),(.106,.235,.066),'door','06_EQUIPMENT')
for i in range(2):
    box('Stacked_Timber_%d'%i,(-.568,-.251,.184+i*.038),(.101,.272,.032),'timber','06_EQUIPMENT')
box('Supply_Crate',(.236,-.108,.153),(.131,.136,.135),'crate','08_DETAILS')
for i,(x,y) in enumerate(((.284,.284),(-.42,.42))):
    box('Supply_IronIngot_%d'%i,(x,y,.18),(.085,.113,.055),'iron_light','08_DETAILS')

# Large cog sign: machinery class marker, separate from the stable and warrior crests.
box('Cog_Crest_Backing',(.377,.083,.787),(.385,.044,.390),'timber','07_HERALDRY')
box('Cog_Crest_BluePlate',(.377,.051,.787),(.349,.022,.354),'banner_plain','07_HERALDRY')
gear = [(-.035,.16),(.035,.16),(.035,.12),(.085,.12),(.11,.145),(.145,.11),
        (.12,.085),(.12,.035),(.16,.035),(.16,-.035),(.12,-.035),(.12,-.085),
        (.145,-.11),(.11,-.145),(.085,-.12),(.035,-.12),(.035,-.16),(-.035,-.16),
        (-.035,-.12),(-.085,-.12),(-.11,-.145),(-.145,-.11),(-.12,-.085),
        (-.12,-.035),(-.16,-.035),(-.16,.035),(-.12,.035),(-.12,.085),
        (-.145,.11),(-.11,.145),(-.085,.12),(-.035,.12)]
vertical_prism('Cog_Crest_Gear',gear,(.377,.023,.787),.028,'iron_light','07_HERALDRY')
box('Cog_Crest_HubShadow',(.377,.001,.787),(.106,.018,.106),'roof_dark','07_HERALDRY')
box('Cog_Crest_Axle',(.377,-.014,.787),(.042,.018,.042),'brass','07_HERALDRY')
for x in (.218,.536):
    for z in (.626,.948):
        box('Cog_Crest_Rivet_%s_%s'%(x,z),(x,.031,z),(.014,.019,.014),'brass','07_HERALDRY')
# Center the whole sign above the wide portal so the crane cannot hide its badge.
for obj in parts:
    if obj['part'].startswith('Cog_Crest_'):
        for vertex in obj.data.vertices:
            vertex.co += Vector((-.377,0,.070))
        obj.data.update()
box('Flag_Pole',(-.43,.306,.998),(.017,.017,.543),'timber','07_HERALDRY')
box('Flag_Cap',(-.43,.306,1.286),(.029,.029,.029),'iron_light','07_HERALDRY')
flag = box('Arsenal_Flag',(-.316,.306,1.202),(.208,.013,.137),'banner','07_HERALDRY')
flag['banner_center'],flag['banner_size'],flag['heraldry'] = [-.316,.306,1.202],[.208,.137],'gear'

for i,x in enumerate((-.59,.205)):
    box('Portal_Lantern_%d'%i,(x,.103,.471),(.033,.041,.054),'glow','08_DETAILS')
    for dz in (-.037,.037):
        box('Portal_Lantern_%d_Cap_%s'%(i,dz),(x,.103,.471+dz),(.047,.053,.020),'iron','08_DETAILS')
for sign in (-1,1):
    a,b = (sign*.675,-.316),(sign*.27,-.581)
    wall('Yard_Curb_'+str(sign),a,b,.050,.086,.122,'cutstone','05_COURTYARD')
for i,y in enumerate((-.667,-.77)):
    box('Entry_Stone_%d'%i,(0,y,.091),(.178,.079,.010),'cutstone','05_COURTYARD')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_siege_arsenal'
root['design'] = 'Hex-first siege assembly workshop; original static siege props, native map scale.'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2+1e-6, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.48]
scene['door_clearance'] = [.74,.454]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Arsenal de Cerco'
scene['trains'] = ['v2_unit_catapult','v2_unit_trebuchet','v2_unit_bombard']
scene['excludes'] = ['v2_legendary_siege_colossus']
scene['palette_overrides'] = {
    'yard':[136,135,128], 'rope':[174,148,99], 'ammunition':[113,121,130],
    'brass':[178,146,83], 'blueprint':[61,94,135], 'chalk':[199,213,214],
    'banner_plain':[52,83,145], 'plaster':[175,169,147],
}
scene['scale_note'] = 'Native 4X map units, pointy-top tile radius 1, placement multiplier 1.0. Symbolic architecture and static miniature siege equipment.'
scene['design_note'] = 'Open pentagonal assembly shed with hex-clipped blue gable, right stores and roof vent. Original wheeled torsion catapult with raised throwing arm, open loaded spoon, timber crane with suspended axle, spare wheels, stone ammunition tray, stocks, anvil and blueprint. Large cog sign and blue gear flag identify the siege workshop.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.74,.454],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'allowed':math.sqrt(3)/2}
