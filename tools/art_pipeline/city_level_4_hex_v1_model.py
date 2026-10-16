"""City IV royal palace: three stepped tower roofs, taller donjon and gold trim.
Build from independent City III mesh copies through the live Blender MCP.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'City_Level_4_Hex_V1'
OUT = ROOT/'assets/generated/humans/buildings/city_level_4_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('City IV scene exists; preserve its edits.')
source_name = 'City_Level_3_Hex_V1'
source_scene = bpy.data.scenes.get(source_name)
if source_scene is None:
    source_path = ROOT/'assets/generated/humans/buildings/city_level_3_hex_v1/city_level_3_hex_v1.blend'
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

cx,cy = .060,.235
for collection in source_scene.collection.children:
    label = collection.name[len(source_name)+1:]
    if label not in groups or label=='09_STUDIO':
        continue
    for original in collection.objects:
        if original.type!='MESH' or not original.get('part'):
            continue
        part = original['part']
        if part.startswith('Donjon_Roof_') or part in ('Donjon_Ridge','Donjon_GoldCap'):
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
            if part.startswith('Donjon_'):
                p.x = cx+(p.x-cx)*1.18
                p.y = cy+(p.y-cy)*1.18
                if part=='Donjon_Body' or part.startswith('Donjon_Corner_'):
                    if p.z>1.40:
                        p.z += .10
                elif part=='Donjon_EaveBand':
                    p.z += .10
                elif 'Window' in part:
                    p.z += .045
            elif part.startswith('RightTurret_') and 'Banner' not in part:
                p.z += min(.13,max(0,(p.z-.20)*.13/.73))
            elif part.startswith('RightTurret_Banner'):
                p.z += .075
            elif part in ('Flag_Pole','Flag_Cap','City_FactionFlag','Flag_Crown_Front','Flag_Crown_Back'):
                # The main banner moves from the left turret to the highest roof.
                p += Vector((.426,.415,.710))
        obj.data.update()

# Steeper, taller blue caps over both tower battlements; no enclosing wall ring.
for prefix,tx,ty,width,depth,bottom,layers,step in (
    ('Left',-.366,-.195,.402,.411,1.274,6,.057),
    ('Right',.446,-.122,.384,.392,1.231,5,.057),
):
    for j in range(layers):
        box(prefix+'Tower_Roof_%d'%j,(tx,ty,bottom+(j+.5)*step),
            (width-j*(width-.064)/(layers-1),depth-j*(depth-.066)/(layers-1),step),
            'roof','03_ROOFS')
    top = bottom+layers*step
    box(prefix+'Tower_Ridge',(tx,ty,top+.009),(.103,.107,.019),'roof_dark','03_ROOFS')
    box(prefix+'Tower_GoldTip',(tx,ty,top+.029),(.044,.044,.024),'gold','08_DETAILS')

# The widened royal donjon dominates the final skyline, with a five-tier cap.
for j in range(5):
    box('Donjon_Roof_%d'%j,(cx,cy,1.638+j*.048),
        (.535-j*.101,.499-j*.094,.049),'roof','03_ROOFS')
box('Donjon_Ridge',(cx,cy,1.864),(.153,.142,.025),'roof_dark','03_ROOFS')

# Gold fillets and crowns identify the completed royal capital at map distance.
box('Donjon_FrontGoldFillet',(cx,.024,1.597),(.447,.022,.019),'gold','08_DETAILS')
box('Donjon_RightGoldFillet',(.294,cy,1.597),(.022,.406,.019),'gold','08_DETAILS')
box('Donjon_BackGoldFillet',(cx,.446,1.597),(.447,.022,.019),'gold','08_DETAILS')
box('Donjon_LeftGoldFillet',(-.174,cy,1.597),(.022,.406,.019),'gold','08_DETAILS')
box('Donjon_CrestPlate',(cx,.034,1.544),(.103,.017,.070),'faction','07_FACTION')
crown('Donjon_RoyalCrown',(cx,.020,1.547),.075,.054,.010)
for prefix,tx,ty,width,depth,z in (
    ('Left',-.366,-.195,.307,.316,1.010),
    ('Right',.446,-.122,.273,.281,.992),
):
    box(prefix+'Tower_GoldBandFront',(tx,ty-depth/2-.009,z),(width,.018,.018),'gold','08_DETAILS')
    box(prefix+'Tower_GoldBandOuter',(tx+(-1 if prefix=='Left' else 1)*width/2,ty,z),
        (.018,depth,.018),'gold','08_DETAILS')

# A modest formal entrance carpet adds civilian ceremony without filling the court.
box('Court_FactionCarpet',(.076,-.447,.091),(.149,.195,.012),'faction','07_FACTION')
for x in (-.009,.161):
    box('Court_CarpetGoldEdge_'+str(x),(x,-.447,.092),(.014,.198,.012),'gold','08_DETAILS')
box('Court_CarpetGoldEnd',(.076,-.551,.092),(.183,.017,.012),'gold','08_DETAILS')
crown('Court_CarpetCrown',(.076,-.471,.099),.070,.052,.006)
# The shared crown helper is vertical; rotate the carpet ornament flat in its mesh.
carpet_crown = parts[-1]
for vertex in carpet_crown.data.vertices:
    p = vertex.co.copy()-Vector((.076,-.471,.099))
    vertex.co = Vector((.076,-.471,.099))+Vector((p.x,p.z,-p.y))
carpet_crown['paint_up'] = [0,0,1]
carpet_crown.data.update()

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_4'
root['city_level'] = 4
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025,(maximum,wall_inner_apothem)
studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.85]
scene['door_clearance'] = [.188,.296]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Centro da Cidade — Nível IV'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'] = 4
scene['palette_overrides'] = dict(source_scene['palette_overrides'])
scene['scale_note'] = 'Native map units, pointy-top tile radius 1; scales by City.tile_radius. Same .84 foundation and reserved fortification border as all previous city levels.'
scene['design_note'] = 'Final City IV royal palace: wider and taller central donjon, highest owner flag, three stepped blue tower roofs with gold caps, royal crowns and gold stonework fillets. Recognizable balcony, twin front turrets, original entrance and civic court. Small faction-colored entrance carpet. Same hex foundation; no perimeter walls or fortification geometry.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.188,.296],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'includes_perimeter_walls':False}
