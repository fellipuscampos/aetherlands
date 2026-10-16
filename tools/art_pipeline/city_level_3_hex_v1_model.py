"""City III: raised twin turrets, royal balcony and roof-top donjon; no walls.
Clone City II editable geometry through the active Blender MCP connection.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'City_Level_3_Hex_V1'
OUT = ROOT/'assets/generated/humans/buildings/city_level_3_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('City III scene exists; preserve its edits.')
source_name = 'City_Level_2_Hex_V1'
source_scene = bpy.data.scenes.get(source_name)
if source_scene is None:
    source_path = ROOT/'assets/generated/humans/buildings/city_level_2_hex_v1/city_level_2_hex_v1.blend'
    with bpy.data.libraries.load(str(source_path),link=False) as (available,loaded):
        assert source_name in available.scenes
        loaded.scenes = [source_name]
    source_scene = loaded.scenes[0]
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
    ('city_level_1_hex_v1_model.py',('crown',)),
):
    tree = ast.parse((PIPELINE/filename).read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<shared_primitives>','exec'))

# All meshes are independent copies. The approved City II source remains intact.
for collection in source_scene.collection.children:
    label = collection.name[len(source_name)+1:]
    if label not in groups or label=='09_STUDIO':
        continue
    for original in collection.objects:
        if original.type!='MESH' or not original.get('part'):
            continue
        part = original['part']
        # Three lower roof terraces remain; a new central donjon replaces the ridge.
        if part in ('Keep_Roof_3','Keep_Roof_4','Keep_Roof_5','Keep_Ridge',
                    'Front_Banner_0','Front_Banner_0_Rod','Front_Banner_0_Crown',
                    'Front_Banner_1','Front_Banner_1_Rod','Front_Banner_1_Crown',
                    'RightTurret_Merlon_5','RightTurret_Merlon_6'):
            continue
        obj = original.copy()
        obj.data = original.data.copy()
        obj.parent = None
        obj.name = NAME+'_'+part
        obj.data.name = obj.name+'_Mesh'
        obj.data.materials.clear()
        groups[label].objects.link(obj)
        parts.append(obj)
        for vertex in obj.data.vertices:
            p = vertex.co
            if part=='Keep_Body' and p.z>.85:
                p.z += .13
            elif part.startswith('Keep_EaveBand') or part.startswith('Keep_Roof'):
                p.z += .13
            elif part.startswith('Keep_ButtressTop'):
                p.z += .12
            elif part.startswith('Keep_Buttress') and p.z>.65:
                p.z += .12
            elif part.startswith('Upper_'):
                p.z += .07
            elif part.startswith('Turret_'):
                p.z += min(.16,max(0,(p.z-.20)*.16/.64))
            elif part.startswith('RightTurret_'):
                p.z += min(.30,max(0,(p.z-.20)*.30/.43))
            elif part in ('Flag_Pole','Flag_Cap','City_FactionFlag','Flag_Crown_Front','Flag_Crown_Back'):
                p.z += .16
        obj.data.update()

# Upper facade is taller and bears a civic balcony over the original entry.
box('Balcony_CorbelLeft',(-.038,-.136,.770),(.061,.125,.089),'cutstone','06_ARCHITECTURE')
box('Balcony_CorbelRight',(.190,-.136,.770),(.061,.125,.089),'cutstone','06_ARCHITECTURE')
box('Balcony_Slab',(.076,-.168,.830),(.355,.201,.046),'cutstone','06_ARCHITECTURE')
box('Balcony_DoorShadow',(.076,-.090,.941),(.115,.020,.167),'shadow','06_ARCHITECTURE')
box('Balcony_Door',(.076,-.107,.936),(.097,.015,.154),'door','06_ARCHITECTURE')
for x in (.005,.147):
    box('Balcony_DoorJamb_'+str(x),(x,-.108,.941),(.021,.029,.181),'cutstone','06_ARCHITECTURE')
box('Balcony_DoorLintel',(.076,-.108,1.025),(.163,.031,.025),'cutstone','06_ARCHITECTURE')
for x in (-.075,.227):
    box('Balcony_Post_'+str(x),(x,-.250,.918),(.035,.037,.131),'cutstone','06_ARCHITECTURE')
for x in (-.011,.047,.105,.163):
    box('Balcony_Baluster_'+str(x),(x,-.250,.913),(.017,.018,.111),'iron','06_ARCHITECTURE')
box('Balcony_Handrail',(.076,-.250,.984),(.335,.036,.027),'gold','08_DETAILS')
for x in (-.075,.227):
    box('Balcony_SideRail_'+str(x),(x,-.172,.980),(.027,.155,.021),'gold','08_DETAILS')
box('Balcony_FactionHanging',(.076,-.266,.887),(.115,.015,.141),'faction','07_FACTION')
crown('Balcony_Crown',(.076,-.279,.905),.074,.054,.008)

# A compact central royal donjon grows out of the keep, changing the skyline.
cx,cy = .060,.235
box('Donjon_Body',(cx,cy,1.323),(.338,.308,.350),'stone','02_KEEP')
box('Donjon_LowerBand',(cx,cy,1.226),(.360,.330,.031),'cutstone','02_KEEP')
box('Donjon_EaveBand',(cx,cy,1.483),(.374,.344,.043),'cutstone','02_KEEP')
for dx in (-.167,.167):
    for dy in (-.152,.152):
        box('Donjon_Corner_%s_%s'%(dx,dy),(cx+dx,cy+dy,1.352),(.042,.043,.244),'cutstone','06_ARCHITECTURE')
box('Donjon_FrontWindow',(cx,cy-.164,1.347),(.107,.021,.149),'shadow','06_ARCHITECTURE')
for dx in (-.067,.067):
    box('Donjon_FrontWindowJamb_'+str(dx),(cx+dx,cy-.175,1.347),(.021,.029,.180),'cutstone','06_ARCHITECTURE')
for z in (1.253,1.441):
    box('Donjon_FrontWindowBand_'+str(z),(cx,cy-.179,z),(.163,.040,.026),'cutstone','06_ARCHITECTURE')
box('Donjon_FrontWindowMullion',(cx,cy-.178,1.347),(.015,.015,.147),'iron','06_ARCHITECTURE')
box('Donjon_RightWindow',(cx+.178,cy,1.347),(.021,.097,.149),'shadow','06_ARCHITECTURE')
for dy in (-.063,.063):
    box('Donjon_RightWindowJamb_'+str(dy),(cx+.188,cy+dy,1.347),(.029,.021,.181),'cutstone','06_ARCHITECTURE')
for z in (1.253,1.441):
    box('Donjon_RightWindowBand_'+str(z),(cx+.191,cy,z),(.038,.153,.026),'cutstone','06_ARCHITECTURE')
box('Donjon_BackWindow',(cx,cy+.164,1.347),(.090,.020,.147),'shadow','06_ARCHITECTURE')
box('Donjon_BackWindowSill',(cx,cy+.180,1.253),(.137,.039,.026),'cutstone','06_ARCHITECTURE')
for j in range(4):
    box('Donjon_Roof_%d'%j,(cx,cy,1.531+j*.046),(.436-j*.097,.405-j*.091,.048),'roof','03_ROOFS')
box('Donjon_Ridge',(cx,cy,1.707),(.150,.124,.028),'roof_dark','03_ROOFS')
box('Donjon_GoldCap',(cx,cy,1.730),(.061,.052,.025),'gold','08_DETAILS')

# Tall narrow owner cloth on the enlarged right tower, separate from gold rods.
box('RightTurret_Banner',(.446,-.258,.770),(.079,.016,.214),'faction','07_FACTION')
box('RightTurret_BannerRod',(.446,-.266,.887),(.102,.029,.022),'gold','08_DETAILS')
crown('RightTurret_BannerCrown',(.446,-.272,.809),.051,.037,.008)

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_3'
root['city_level'] = 3
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025,(maximum,wall_inner_apothem)
studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.69]
scene['door_clearance'] = [.188,.296]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Centro da Cidade — Nível III'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'] = 3
scene['palette_overrides'] = dict(source_scene['palette_overrides'])
scene['scale_note'] = 'Native map units, pointy-top tile radius 1; scales by City.tile_radius. Same .84 foundation and reserved fortification border as levels I/II.'
scene['design_note'] = 'Level III of four: City II evolves into a taller royal castle with raised twin crenellated turrets, a stone balcony above the entry and a central roof-top donjon with stepped blue hipped roof and small gold cap. Same original door, courtyard and hex footprint. Neutral owner flag, balcony hanging and right tower banner. No perimeter walls; fortifications stay independent. Grandest expansion reserved for level IV.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.188,.296],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'includes_perimeter_walls':False}
