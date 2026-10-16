"""Orc tank training hall, original blocky hex asset; live Blender MCP only."""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'Orc_Guardian_Hall_Hex_V1'
RELATIVE_OUT = 'assets/generated/orcs/buildings/orc_guardian_hall_hex_v1'
OUT = ROOT/RELATIVE_OUT
if NAME in bpy.data.scenes:
    raise RuntimeError('Orc Guardian Hall source scene exists; preserve its edits.')
OUT.mkdir(parents=True,exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_WATCHTOWER','05_COURTYARD',
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


def orc_shield(name,center,width,height,group='08_DETAILS'):
    # Broad square shoulders, a stepped pointed foot, heavy iron rim and tusks.
    cx,cy,cz = center
    outline = [(-.5,.5),(.5,.5),(.5,-.18),(.34,-.18),(.34,-.32),
               (.18,-.32),(.18,-.43),(0,-.53),(-.18,-.43),
               (-.18,-.32),(-.34,-.32),(-.34,-.18),(-.5,-.18)]
    for suffix,scale,y,reg,depth in (
        ('Iron_Rim',1,cy,'iron',.025),('Timber_Face',.81,cy-.020,'door',.017)):
        vertical_prism(name+'_'+suffix,[(x*width*scale,z*height*scale) for x,z in outline],
                       (cx,y,cz),depth,reg,group)
    box(name+'_Clan_Stripe',(cx,cy-.034,cz+.014),(width*.20,.014,height*.69),'faction','07_FACTION')
    box(name+'_Square_Boss',(cx,cy-.047,cz),(width*.24,.031,height*.23),'iron_light',group)
    for sign in (-1,1):
        tusk(name+'_Bone_Fang_'+str(sign),(cx+sign*width*.30,cy-.044,cz-height*.23),
             height*.33,width*.14,.018,sign,group)
        box(name+'_Rivet_'+str(sign),(cx+sign*width*.35,cy-.039,cz+height*.33),
            (width*.075,.017,height*.070),'iron_light',group)


# The same .92-radius foundation as the human military buildings; one whole hex.
polygon_prism('Hex_Basalt_Foundation',hexagon(.92),0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Stone_Rim',hexagon(.90),.036,.062,'stone','01_FOUNDATION')
polygon_prism('Hex_Training_Paving',hexagon(.85),.062,.077,'paving','01_FOUNDATION')
footprint = [(-.280,.012),(.425,.012),(.425,.360),(.075,.610),(-.280,.360)]
polygon_prism('Hall_Stone_Foot',footprint,.077,.168,'cutstone','02_HALL')
polygon_prism('Hall_Basalt_Lower',footprint,.168,.450,'stone','02_HALL')
polygon_prism('Hall_Timber_Upper',footprint,.450,.730,'door','02_HALL')
for i,a in enumerate(footprint):
    b = footprint[(i+1)%len(footprint)]
    wall('Hall_Sill_%d'%i,a,b,.045,.160,.199,'timber','02_HALL')
    wall('Hall_Iron_Mid_Band_%d'%i,a,b,.048,.426,.470,'iron','02_HALL')
    wall('Hall_Eave_%d'%i,a,b,.059,.690,.752,'timber','02_HALL')
    box('Hall_Heavy_Post_%d'%i,(a[0],a[1],.448),(.084,.084,.552),'timber','02_HALL')
    for z in (.230,.663):
        box('Hall_Post_Strap_%d_%s'%(i,z),(a[0],a[1],z),(.100,.100,.040),'iron','02_HALL')

# Rust-red hide roof, black bands and a pair of horned ridge ends.
for j in range(6):
    sx,sy = .950-j*.145,.710-j*.021
    points = [(.075-sx/2,.310-sy/2),(.075+sx/2,.310-sy/2),
              (.075+sx/2,.310+sy/2),(.075-sx/2,.310+sy/2)]
    polygon_prism('Hide_Roof_Course_%d'%j,clip_to_hex(points,.855),
                  .757+j*.058,.815+j*.058,'roof','03_ROOFS')
    box('Roof_Iron_Front_Binding_%d'%j,(.075,.310-sy/2-.007,.780+j*.058),
        (sx+.012,.034,.029),'iron','03_ROOFS')
box('Roof_Heavy_Ridge',(.075,.310,1.127),(.105,.627,.043),'timber','03_ROOFS')
for y in (.004,.616):
    box('Ridge_Iron_Socket_'+str(y),(.075,y,1.135),(.127,.061,.063),'iron','03_ROOFS')
    tusk('Ridge_Great_Horn_'+str(y),(.075,y,1.165),.161,.078,.066,1,'03_ROOFS')

# Entrance and large shield positioned forward of every roof binding.
box('Door_Shadow',(.075,-.007,.409),(.264,.032,.415),'shadow','02_HALL')
for sign in (-1,1):
    box('Door_Leaf_'+str(sign),(.075+sign*.058,-.030,.404),(.109,.025,.367),'door','02_HALL')
    box('Door_Timber_Jamb_'+str(sign),(.075+sign*.159,-.022,.411),(.048,.081,.435),'timber','02_HALL')
    for z in (.302,.536):
        box('Door_Iron_Band_%s_%s'%(sign,z),(.075+sign*.058,-.050,z),(.105,.023,.029),'iron','02_HALL')
    box('Door_Square_Handle_'+str(sign),(.075+sign*.026,-.069,.408),(.019,.023,.027),'iron_light','08_DETAILS')
    box('Entry_Tusk_Socket_'+str(sign),(.075+sign*.209,-.080,.193),(.091,.103,.128),'iron','02_HALL')
    tusk('Entry_Tusk_'+str(sign),(.075+sign*.209,-.090,.248),.395,.087,.068,sign)
box('Entry_Heavy_Lintel',(.075,-.042,.643),(.413,.110,.072),'timber','02_HALL')
box('Shield_Emblem_Mount',(.075,-.111,.854),(.326,.050,.333),'timber','02_HALL')
orc_shield('Portal_Tank_Shield',(.075,-.147,.854),.307,.312)
for i,(y,width,top) in enumerate(((-.096,.335,.166),(-.185,.371,.127),(-.274,.413,.098))):
    box('Entry_Step_%d'%i,(.075,y,(.077+top)/2),(width,.094,top-.077),'cutstone','05_COURTYARD')

# One square timber watchtower, bound in iron; compact open upper deck.
tx,ty = -.519,.090
box('Tower_Basalt_Foot',(tx,ty,.132),(.320,.331,.110),'stone','04_WATCHTOWER')
box('Tower_Lower_Stone',(tx,ty,.258),(.268,.275,.162),'stone','04_WATCHTOWER')
box('Tower_Timber_Core',(tx,ty,.564),(.238,.247,.472),'door','04_WATCHTOWER')
for dx in (-.118,.118):
    for dy in (-.124,.124):
        box('Tower_Corner_%s_%s'%(dx,dy),(tx+dx,ty+dy,.551),(.048,.051,.521),'timber','04_WATCHTOWER')
for z in (.342,.694):
    box('Tower_Iron_Belt_'+str(z),(tx,ty,z),(.287,.296,.042),'iron','04_WATCHTOWER')
box('Tower_Front_Slit',(tx,ty-.134,.562),(.058,.021,.149),'shadow','04_WATCHTOWER')
box('Tower_Left_Slit',(tx-.136,ty,.562),(.021,.055,.149),'shadow','04_WATCHTOWER')
box('Tower_Deck_Corbel',(tx,ty,.807),(.320,.331,.055),'timber','04_WATCHTOWER')
box('Tower_Iron_Deck_Lip',(tx,ty,.843),(.352,.354,.022),'iron','04_WATCHTOWER')
box('Tower_Deck',(tx,ty,.861),(.290,.292,.018),'door','04_WATCHTOWER')
for dx,dy in ((-.150,0),(.150,0),(0,-.151),(0,.151)):
    box('Tower_Deck_Rail_%s_%s'%(dx,dy),(tx+dx,ty+dy,.913),
        (.025 if dx else .293,.025 if dy else .302,.096),'iron','04_WATCHTOWER')
for i,(dx,dy) in enumerate(((-.147,-.149),(.147,-.149),(.147,.149),(-.147,.149))):
    box('Tower_Horn_Socket_%d'%i,(tx+dx,ty+dy,.968),(.062,.066,.047),'iron','04_WATCHTOWER')
    tusk('Tower_Corner_Horn_%d'%i,(tx+dx,ty+dy,.989),.148,.052,.041,1 if dx>0 else -1,'04_WATCHTOWER')

# Wedge-shaped drill yard and clear approach from the tile's forward apex.
polygon_prism('Training_Sand_Wedge',[(-.58,-.216),(.530,-.216),(.596,-.320),
    (.389,-.580),(0,-.817),(-.386,-.580),(-.612,-.335)],.077,.091,'sand','05_COURTYARD')
polygon_prism('Paved_Entrance_Wedge',[(-.072,-.218),(.216,-.218),(.167,-.610),
    (0,-.830),(-.103,-.610)],.091,.105,'paving','05_COURTYARD')
for i,(x,y) in enumerate(((-.301,-.411),(.383,-.385))):
    box('Dummy_Base_%d'%i,(x,y,.121),(.163,.132,.060),'timber','06_TRAINING')
    box('Dummy_Post_%d'%i,(x,y,.286),(.038,.043,.298),'timber','06_TRAINING')
    box('Dummy_Crossbar_%d'%i,(x,y,.365),(.191,.041,.042),'timber','06_TRAINING')
    box('Dummy_Straw_Head_%d'%i,(x,y,.467),(.072,.064,.081),'straw','06_TRAINING')
    orc_shield('Dummy_Tank_Shield_%d'%i,(x,y-.046,.305),.191,.236,'06_TRAINING')
    box('Drill_Position_%d'%i,(x*.81,y-.162,.099),(.128,.078,.016),'formation','06_TRAINING')

# Heavy shield rack on the exposed right flank, not a third unrelated emblem.
rx,ry = .597,.025
for dx in (-.042,.042):
    box('Shield_Rack_Post_'+str(dx),(rx+dx,ry,.224),(.023,.033,.293),'timber','06_TRAINING')
box('Shield_Rack_Rail',(rx,ry,.326),(.159,.038,.029),'iron','06_TRAINING')
orc_shield('Reserve_Tank_Shield',(rx,ry-.048,.229),.136,.177,'06_TRAINING')
for i,(x,y) in enumerate(((.457,.399),(.341,.514))):
    box('Supply_Crate_%d'%i,(x,y,.134),(.106,.099,.112),'crate','08_DETAILS')
    box('Supply_Crate_Band_%d'%i,(x,y-.053,.134),(.023,.012,.108),'iron','08_DETAILS')
box('Right_Hall_Window',(.442,.231,.557),(.025,.103,.143),'shadow','02_HALL')
for y in (.197,.231,.265):
    box('Hall_Window_Grille_'+str(y),(.459,y,.557),(.016,.014,.137),'iron','02_HALL')
for z in (.475,.639):
    box('Hall_Window_Beam_'+str(z),(.455,.231,z),(.041,.143,.025),'timber','02_HALL')

# Clan standard is forward of the tower so the roof cannot conceal it.
px,py = -.535,-.133
box('Clan_Standard_Pole',(px,py,.923),(.020,.023,.345),'timber','08_DETAILS')
box('Clan_Standard_Cap',(px,py,1.108),(.036,.039,.029),'iron_light','08_DETAILS')
box('Clan_Faction_Standard',(px+.064,py,.994),(.141,.020,.174),'faction','07_FACTION')
box('Standard_Shield_Boss',(px+.064,py-.018,.995),(.049,.022,.055),'iron_light','08_DETAILS')
for sign in (-1,1):
    tusk('Standard_Bone_Fang_'+str(sign),(px+.064+sign*.047,py-.019,.956),.066,.019,.013,sign)
    box('Entry_Lamp_Frame_'+str(sign),(.075+sign*.139,-.092,.483),(.035,.044,.057),'iron','08_DETAILS')
    box('Entry_Lamp_Glow_'+str(sign),(.075+sign*.139,-.118,.483),(.023,.014,.038),'glow','08_DETAILS')

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'],root['civilization'],root['asset_only'] = 'v2_building_guardian_hall','orc',True
root['unit_class'] = 'tank'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, maximum

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.49]
scene['door_clearance'] = [.222,.367]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['asset_output_relative'] = RELATIVE_OUT
scene['display_name'] = 'Salão dos Guardiões Orcs'
scene['integration_source'] = 'scripts/data/BuildingDatabase.gd'
scene['trains'] = ['v2_unit_shieldbearer','v2_unit_guardian','v2_unit_sentinel']
scene['excludes'] = ['v2_legendary_guardian_champion']
scene['civilization'],scene['asset_only'] = 'orc',True
scene['palette_overrides'] = {
    'stone':[91,101,98],'cutstone':[145,141,121],'foundation':[68,77,77],
    'paving':[107,113,88],'timber':[78,53,35],'door':[123,89,54],
    'roof':[130,58,39],'roof_dark':[83,40,30],'iron':[53,65,65],
    'iron_light':[126,137,130],'bone':[225,215,174],'faction':[170,60,39],
    'crate':[123,97,58],'sand':[145,126,84],'formation':[180,164,125]}
scene['scale_note'] = 'Native 4X map units; pointy-top tile radius 1, military foundation radius .92, placement scale tile_radius. Asset only, no integration.'
scene['design_note'] = 'Orc tank training hall: basalt-and-heavy-timber rear barracks, stepped rust-red hide roof bound in iron, tusked shield prominently forward of roof, horned square side watchtower and exposed clan standard. Open wedge sand court, two shield practice dummies, drill marks and spare shield rack. Trains the shared regular tank line; supreme guardian hero belongs to its own building. No outer wall ring; no character references required.'
bpy.app.driver_namespace['guardian_hall'] = {
    'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),
    'density':128,'paint_world_scale':7,'door_clearance':list(scene['door_clearance']),
    'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
