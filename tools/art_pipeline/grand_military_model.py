"""Create one original military landmark in the live Blender MCP editor.

MILITARY_CIV / MILITARY_ROLE select a separate architectural recipe, not a
recolored copy. The equivalent basic scene is only read for materials/props.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
exec((PIPELINE/'grand_military_assets.py').read_text(encoding='utf-8'))
CIV, ROLE = MILITARY_CIV, MILITARY_ROLE
STEM, DISPLAY, LEGENDARY, PREVIOUS = RECIPES[ROLE]
FOLDER = folder_name(CIV, ROLE)
NAME = FOLDER.title()
ASSET_NAME, ASSET_FOLDER = NAME, FOLDER
OUT = ROOT/'assets/generated'/CIVS[CIV][0]/'buildings'/FOLDER
assert NAME not in bpy.data.scenes and not (OUT/(FOLDER+'.blend')).exists(), 'Existing asset preserved: '+FOLDER
ref_folder = reference_folder(CIV, ROLE)
ref_out = ROOT/'assets/generated'/CIVS[CIV][0]/'buildings'/ref_folder
reference_name = ref_folder.title()
if reference_name not in bpy.data.scenes:
    with bpy.data.libraries.load(str(ref_out/(ref_folder+'.blend')), link=False) as (src, dst):
        dst.scenes = [reference_name]
reference_scene = bpy.data.scenes[reference_name]
# Read the established full painter palette, then the equivalent scene's overrides.
for node in ast.parse((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')).body:
    if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id=='PALETTE' for t in node.targets):
        palette = {k:list(v) for k,v in ast.literal_eval(node.value).items()}
        break
palette.update({'gold':[206,181,112], 'bronze':[191,133,71], 'bone':[225,215,174],
                'faction':[52,83,145], 'foliage':[57,112,64], 'foliage_light':[99,151,74],
                'grass':[108,139,82], 'water':[63,117,138], 'rope':[184,161,112],
                'leather':[100,62,40], 'paper':[220,207,161], 'ink':[56,62,66],
                'glass':[100,140,161], 'ammunition':[149,158,158]})
palette.update({k:list(v) for k,v in reference_scene.get('palette_overrides',{}).items()})
palette['roof'] = palette['roof_dark'] = ROOFS[CIV]
palette['canvas'] = ROOFS[CIV]
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION','02_HALL','03_ROOFS','04_FOCUS','05_COURTYARD','06_TRAINING','07_FACTION','08_DETAILS','09_STUDIO'):
    col = bpy.data.collections.new(NAME+'_'+label)
    scene.collection.children.link(col)
    groups[label] = col
parts = []
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
TRIM = {'human':'iron_light','orc':'iron','dwarf':'bronze','elf':'gold'}[CIV]
BODY = {'human':'plaster','orc':'door','dwarf':'stone','elf':'plaster'}[CIV]
POST = 'cutstone' if CIV=='dwarf' else 'timber'
PITCH = {'human':.052,'orc':.050,'dwarf':.043,'elf':.061}[CIV]
for filename, names in (
    ('warrior_hall_hex_v1_model.py', ('mesh','box','polygon_prism','hexagon','wall','sword')),
    ('war_stable_hex_v1_model.py', ('vertical_prism','clip_to_hex')),
    ('magic_school_model.py', ('beam','ring')),
    ('orc_city_level_1_hex_v1_model.py', ('tusk',)),
    ('elf_city_level_1_hex_v1_model.py', ('leaf',)),
    ('grand_magic_model.py', ('roof','wall_craft','hall','doorway','window')),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), '<military_primitives>', 'exec'))
exec((PIPELINE/'grand_military_primitives.py').read_text(encoding='utf-8'))
polygon_prism('Hex_Foundation', hexagon(.92), 0,.036,'foundation','01_FOUNDATION')
polygon_prism('Hex_Rim', hexagon(.90), .036,.062,'cutstone','01_FOUNDATION')
polygon_prism('Hex_Paving', hexagon(.85), .062,.077,'paving','01_FOUNDATION')
exec((PIPELINE/('grand_military_'+CIV+'.py')).read_text(encoding='utf-8'))
for obj in parts:
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
root = bpy.data.objects.new(NAME+'_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_'+STEM
root['civilization'],root['asset_only'] = CIV,True
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, (NAME,maximum)
studio = (PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio[studio.index('world = bpy.data.worlds.new'):studio.index("scene['preview_target']")])
scene.render.resolution_x = scene.render.resolution_y = 800
scene.cycles.samples = 16
scene['preview_target'] = [0,0,.79]
scene['door_clearance'] = [.26,.40]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = FOLDER,128,7
scene['asset_output_relative'] = OUT.relative_to(ROOT).as_posix()
scene['display_name'] = DISPLAY+' — '+CIVS[CIV][1]
scene['civilization'],scene['military_role'],scene['grand_military'],scene['asset_only'] = CIV,ROLE,True,True
scene['trains'],scene['excludes'] = ['v2_legendary_'+LEGENDARY],[]
scene['requires_building'] = 'v2_building_'+PREVIOUS
scene['palette_overrides'] = palette
scene['material_reference'] = ref_out.relative_to(ROOT).as_posix()
scene['architecture_key'] = CIV+'_'+ROLE
scene['scale_note'] = 'Native 4X map units, pointy-top hex radius 1, foundation .92; placement scale 1.'
scene['design_note'] = design
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':list(scene['door_clearance']),'scale_note':scene['scale_note'],'design_note':design}
audit = {'AUDIT_RUN':False}
exec((PIPELINE/'magic_school_attachment_audit.py').read_text(encoding='utf-8'), audit)
unattached = [o['part'] for o in audit['detached'](parts)]
scene['physical_attachment_remaining'] = unattached
assert not unattached, (NAME,unattached)
result = {'asset':FOLDER,'parts':len(parts),'max_half_plane':maximum,
          'material_reference':scene['material_reference'],'architecture':scene['architecture_key']}
