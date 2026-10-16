"""City II evolves the approved City I source: higher keep, second turret, no walls.
Clone editable parts into an isolated scene through live Blender MCP.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
NAME = 'City_Level_2_Hex_V1'
OUT = ROOT/'assets/generated/humans/buildings/city_level_2_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('City II scene exists; preserve its edits.')
source_name = 'City_Level_1_Hex_V1'
source_scene = bpy.data.scenes.get(source_name)
if source_scene is None:
    source_path = ROOT/'assets/generated/humans/buildings/city_level_1_hex_v1/city_level_1_hex_v1.blend'
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


# Reuse the approved silhouette, source objects and hand-authored proportions.
# Every mesh is copied; the user's City I scene, geometry and paint remain intact.
for collection in source_scene.collection.children:
    label = collection.name[len(source_name)+1:]
    if label not in groups or label=='09_STUDIO':
        continue
    for original in collection.objects:
        if original.type!='MESH' or not original.get('part'):
            continue
        part = original['part']
        # Front slit is replaced by the new turret. The joining corner's merlon
        # is removed so it cannot emerge through the taller keep's roof.
        if part.startswith('Front_Window') or part=='Turret_Merlon_4':
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
            if part=='Keep_Body' and p.z>.65:
                p.z += .24
            elif part.startswith('Keep_EaveBand') or part.startswith('Keep_Roof') or part=='Keep_Ridge':
                p.z += .24
            elif part.startswith('Keep_ButtressTop'):
                p.z += .20
            elif part.startswith('Keep_Buttress') and p.z>.48:
                p.z += .20
            elif part.startswith('Turret_'):
                p.y -= .09
                p.z += min(.26,max(0,(p.z-.20)*.26/.43))
            elif part.startswith('Basin_'):
                p.y -= .106
            elif part.startswith('Bench_'):
                p.x -= .128
                p.y -= .083
            elif part in ('Flag_Pole','Flag_Cap','City_FactionFlag','Flag_Crown_Front','Flag_Crown_Back'):
                p += Vector((-.445,-.438,.100))
            elif part.startswith('Royal_'):
                p.z += .020
        obj.data.update()

# The added floor has an unmistakable horizontal band and two framed windows.
footprint = [(-.28,-.075),(.40,-.075),(.40,.32),(.08,.53),(-.28,.32)]
for i,a in enumerate(footprint):
    b = footprint[(i+1)%5]
    wall('Keep_UpperFloorBand_%d'%i,a,b,.037,.647,.676,'cutstone','02_KEEP')
for i,x in enumerate((-.147,.290)):
    box('Upper_FrontWindow_%d'%i,(x,-.092,.796),(.083,.023,.132),'shadow','06_ARCHITECTURE')
    for dx in (-.055,.055):
        box('Upper_FrontWindow_%d_Jamb_%s'%(i,dx),(x+dx,-.105,.796),(.022,.030,.163),'cutstone','06_ARCHITECTURE')
    box('Upper_FrontWindow_%d_Lintel'%i,(x,-.105,.879),(.132,.032,.024),'cutstone','06_ARCHITECTURE')
    box('Upper_FrontWindow_%d_Sill'%i,(x,-.111,.711),(.140,.042,.030),'cutstone','06_ARCHITECTURE')
    box('Upper_FrontWindow_%d_Mullion'%i,(x,-.112,.797),(.012,.014,.131),'iron','06_ARCHITECTURE')
box('Upper_RightWindow',(.416,.144,.795),(.020,.095,.135),'shadow','06_ARCHITECTURE')
for y in (.083,.205):
    box('Upper_RightWindow_Jamb_'+str(y),(.432,y,.795),(.025,.022,.165),'cutstone','06_ARCHITECTURE')
box('Upper_RightWindow_Sill',(.432,.144,.711),(.043,.151,.030),'cutstone','06_ARCHITECTURE')
box('Upper_RightWindow_Lintel',(.427,.144,.879),(.031,.147,.024),'cutstone','06_ARCHITECTURE')

# New shorter square turret flanks the opposite side. It belongs to the keep,
# not to an enclosing perimeter; independent fortification assets stay outside.
tx,ty = .446,-.122
box('RightTurret_Foot',(tx,ty,.138),(.279,.290,.124),'cutstone','04_TURRET')
box('RightTurret_Body',(tx,ty,.411),(.240,.248,.486),'stone','04_TURRET')
for z in (.233,.532):
    box('RightTurret_Stringcourse_'+str(z),(tx,ty,z),(.260,.268,.027),'cutstone','04_TURRET')
box('RightTurret_CorbelLip',(tx,ty,.643),(.287,.293,.046),'cutstone','04_TURRET')
box('RightTurret_Deck',(tx,ty,.683),(.245,.251,.015),'paving','04_TURRET')
for dx in (-.133,.133):
    box('RightTurret_ParapetSide_'+str(dx),(tx+dx,ty,.709),(.033,.297,.067),'stone','04_TURRET')
for dy in (-.138,.138):
    box('RightTurret_ParapetEnd_'+str(dy),(tx,ty+dy,.709),(.239,.033,.067),'stone','04_TURRET')
for i,(dx,dy) in enumerate(((-.123,-.124),(0,-.124),(.123,-.124),(.123,0),
                           (.123,.124),(0,.124),(-.123,.124),(-.123,0))):
    box('RightTurret_Merlon_%d'%i,(tx+dx,ty+dy,.761),(.065,.067,.070),'cutstone','04_TURRET')
box('RightTurret_FrontSlit',(tx,ty-.133,.429),(.044,.020,.153),'shadow','06_ARCHITECTURE')
box('RightTurret_FrontSlitSill',(tx,ty-.145,.345),(.079,.033,.026),'cutstone','06_ARCHITECTURE')
box('RightTurret_OuterSlit',(tx+.128,ty,.429),(.019,.044,.153),'shadow','06_ARCHITECTURE')
box('RightTurret_OuterSlitSill',(tx+.142,ty,.345),(.032,.079,.026),'cutstone','06_ARCHITECTURE')

# Two heraldic hangings reinforce the civilian royal identity, with owner tint.
for i,x in enumerate((-.160,.273)):
    box('Front_Banner_%d'%i,(x,-.117,.565),(.067,.015,.137),'faction','07_FACTION')
    box('Front_Banner_%d_Rod'%i,(x,-.121,.647),(.083,.027,.020),'gold','08_DETAILS')
    crown('Front_Banner_%d_Crown'%i,(x,-.131,.575),.044,.033,.008)

root = bpy.data.objects.new(NAME+'_ROOT',None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'city_center_level_2'
root['city_level'] = 2
root['includes_perimeter_walls'] = False
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
wall_inner_apothem = .94*(math.sqrt(3)/2-.10/2)
assert maximum < wall_inner_apothem-.025,(maximum,wall_inner_apothem)

studio_code = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.51]
scene['door_clearance'] = [.188,.296]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Centro da Cidade — Nível II'
scene['integration_source'] = 'scripts/city/City.gd'
scene['trains'],scene['excludes'] = [],[]
scene['city_level'] = 2
scene['palette_overrides'] = dict(source_scene['palette_overrides'])
scene['scale_note'] = 'Native map units, pointy-top tile radius 1; scales by City.tile_radius. Same .84 foundation as level I; clear border for independent future wall models.'
scene['design_note'] = 'Level II of four: approved City I stone castle evolved into a taller two-floor keep, raised left crenellated turret and new shorter right turret. Same blue roof, door, steps, crowns and civic courtyard; basin and bench repositioned for the added turret. Neutral faction flags and heraldic hangings. No enclosing or perimeter walls; three fortification levels are independent assets.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.188,.296],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'includes_perimeter_walls':False}
