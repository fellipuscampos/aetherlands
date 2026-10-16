"""Civilization-specific adaptations of validated training layouts, live Blender MCP.

Wrappers set BATCH_CIV and BATCH_ROLE. New scenes only; source scenes/files intact.
Layouts retain common training functions while architecture and props specialize.
"""
import ast
import bpy
import math
from pathlib import Path
from mathutils import Vector

TASK_PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
TASK_RECIPES = {
    'tank':('guardian_hall','Salão dos Guardiões'),
    'warrior':('warrior_hall','Salão de Armas'),
    'ranged':('ranger_camp','Campo dos Patrulheiros'),
    'cavalry':('war_stable','Estábulo de Guerra'),
    'rogue':('rogue_guild','Guilda dos Ladinos'),
    'siege':('siege_arsenal','Arsenal de Guerra'),
}
TASK_STEM,TASK_DISPLAY = TASK_RECIPES[BATCH_ROLE]
TASK_OLD_FOLDER = 'orc_'+TASK_STEM+'_hex_v1'
TASK_OLD_NAME = 'Orc_'+TASK_STEM.title()+'_Hex_V1'
TASK_FOLDER = BATCH_CIV+'_'+TASK_STEM+'_hex_v1'
TASK_NAME = BATCH_CIV.title()+'_'+TASK_STEM.title()+'_Hex_V1'
TASK_PLURAL = 'dwarves' if BATCH_CIV=='dwarf' else 'elves'
TASK_RELATIVE = 'assets/generated/'+TASK_PLURAL+'/buildings/'+TASK_FOLDER

class LayoutNames(ast.NodeTransformer):
    def visit_Constant(self,node):
        if isinstance(node.value,str):
            mapping = {TASK_OLD_NAME:TASK_NAME,TASK_OLD_FOLDER:TASK_FOLDER,
                       'assets/generated/orcs/buildings/'+TASK_OLD_FOLDER:TASK_RELATIVE,
                       'orc':BATCH_CIV}
            if node.value in mapping:
                return ast.copy_location(ast.Constant(mapping[node.value]),node)
        return node

task_tree = ast.parse((TASK_PIPELINE/(TASK_OLD_FOLDER+'_model.py')).read_text(encoding='utf-8'))
task_tree = ast.fix_missing_locations(LayoutNames().visit(task_tree))
exec(compile(task_tree,'<adapted_training_layout>','exec'),globals())

# Shared AST primitives, without executing any existing model builder.
for task_file,task_names in (
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
    ('ranger_camp_hex_v1_model.py',('beam',)),
    ('warrior_hall_hex_v1_model.py',('sword',)),
):
    for node in ast.parse((TASK_PIPELINE/task_file).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in task_names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<family_primitives>','exec'),globals())


def part_collection(obj):
    return next(label for label,col in groups.items() if col in obj.users_collection)


def remove_part(obj):
    parts.remove(obj)
    data = obj.data
    bpy.data.objects.remove(obj,do_unlink=True)
    if data.users==0:
        bpy.data.meshes.remove(data)


def bounds(obj):
    lo=Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    hi=Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    return lo,hi


def crossbow(name,center,height,group):
    x,y,z=center
    box(name+'_Stock',(x,y,z),(.047,.039,height),'door',group)
    box(name+'_Steel_Rail',(x,y-.027,z+height*.13),(.026,.016,height*.65),'iron_light',group)
    for sign in (-1,1):
        beam(name+'_Limb_'+str(sign),(x+sign*.02,y,z+height*.20),
             (x+sign*height*.44,y,z+height*.14),height*.065,'iron',group)
        box(name+'_Copper_Tip_'+str(sign),(x+sign*height*.43,y,z+height*.14),
            (.027,.036,.030),'bronze',group)
    beam(name+'_String',(x-height*.43,y-.018,z+height*.14),
         (x+height*.43,y-.018,z+height*.14),.006,'bone',group)
    box(name+'_Trigger',(x+.031,y,z-height*.19),(.033,.033,.029),'bronze',group)
    box(name+'_Bolt',(x,y-.043,z+height*.27),(.009,.010,height*.64),'bone',group)
    vertical_prism(name+'_Bolt_Point',[(-.014,0),(.014,0),(0,.035)],
                   (x,y-.043,z+height*.59),.010,'iron_light',group)


def sapling(name,center,height=.88,width=.18,group='08_DETAILS'):
    x,y,z=center
    box(name+'_Root',(x,y,z+.027),(width*.67,width*.66,.055),'cutstone',group)
    box(name+'_Trunk',(x,y,z+height*.38),(.037,.043,height*.74),'timber',group)
    for sign in (-1,1):
        beam(name+'_Branch_'+str(sign),(x,y,z+height*.48),
             (x+sign*width*.27,y,z+height*.68),.025,'timber',group)
    for i,(factor,w,d) in enumerate(((.65,1,.89),(.80,.85,.77),(.91,.53,.51))):
        box(name+'_Block_Crown_%d'%i,(x,y,z+height*factor),
            (width*w,width*d,height*.14),'foliage_light' if i else 'foliage',group)


def pointed_frame(name,cx,front,bottom,width,height):
    for sign in (-1,1):
        box(name+'_Ivory_Jamb_'+str(sign),(cx+sign*width*.58,front,bottom+height*.38),
            (.025,.053,height*.76),'cutstone','08_DETAILS')
        for j in range(3):
            box(name+'_Point_Step_%s_%s'%(sign,j),
                (cx+sign*width*(.47-j*.17),front,bottom+height*(.79+j*.10)),
                (width*.19,.054,height*.115),'cutstone','08_DETAILS')
    leaf(name+'_Gold_Leaf',(cx,front-.034,bottom+height*1.04),.059,.075,.013)


# Remove all orc horn/tusk shapes. New geometric copper ornaments or gold leaves.
task_ornaments = []
for obj in list(parts):
    part=obj['part']
    if any(token in part for token in ('Tusk','Horn','Bone_Fang')) and obj.get('region')=='bone':
        lo,hi=bounds(obj)
        task_ornaments.append((part,(lo+hi)/2,hi-lo,part_collection(obj)))
        remove_part(obj)
for label,center,size,group in task_ornaments:
    if BATCH_CIV=='dwarf':
        # Squared caps and runestones replace the tusked clan vocabulary.
        height=min(.090,max(.030,size.z*.60))
        center.z=center.z-size.z/2+height/2
        box('Copper_Runestone_'+label,tuple(center),
            (max(.020,min(.061,size.x)),max(.018,min(.055,size.y)),height),'bronze',group)
        box('Runestone_Inset_'+label,(center.x,center.y-.031,center.z),
            (.013,.010,height*.61),'iron',group)
    else:
        leaf('Leaf_Ornament_'+label,tuple(center),min(.10,max(.045,size.x*1.3)),
             min(.19,max(.07,size.z)),max(.013,min(.027,size.y)),'gold',group)

# Convert the architectural vocabulary, retaining actual open training spaces.
for obj in list(parts):
    part,reg=obj['part'],obj['region']
    label=part_collection(obj)
    architectural=label.startswith(('02_','04_')) and not label.startswith(('04_TARGET','04_CATAPULT','04_MOUNTS'))
    if BATCH_CIV=='dwarf':
        if architectural and reg in ('door','timber') and any(t in part for t in ('Body','Wall','Post','Core','Header','Jamb','Eave','Beam','Foot')):
            obj['region']='stone' if any(t in part for t in ('Body','Wall','Core')) else 'cutstone'
        if reg=='iron' and any(t in part for t in ('Roof','Ridge','Collar','Binding','Band','Sign','Frame','Socket','Cap')):
            obj['region']='bronze'
        if BATCH_ROLE=='ranged' and reg=='grass':
            obj['region']='paving'
    else:
        if architectural and reg in ('stone','door') and any(t in part for t in ('Body','Wall','Core','Lower','Foot')):
            obj['region']='plaster' if any(t in part for t in ('Body','Wall','Core','Lower')) else 'cutstone'
        if reg=='iron' and any(t in part for t in ('Roof','Ridge','Collar','Binding','Band','Frame','Socket','Cap','Header')):
            obj['region']='gold'
        if reg=='iron_light' and any(t in part for t in ('Boss','Emblem','Hood','Rivet')):
            obj['region']='gold'
        if 'Window' in part and reg=='shadow':
            obj['region']='glass'
        if architectural and 'Post' in part and reg=='timber':
            lo,hi=bounds(obj); midpoint=(lo+hi)/2
            for vertex in obj.data.vertices:
                vertex.co.x=midpoint.x+(vertex.co.x-midpoint.x)*.66
                vertex.co.y=midpoint.y+(vertex.co.y-midpoint.y)*.66
        if label=='03_ROOFS' and obj.get('region')=='roof' and BATCH_ROLE in ('tank','ranged','rogue'):
            # Taller layered crowns while preserving the clipped footprint.
            try: step=int(part.rsplit('_',1)[1])
            except ValueError: step=0
            for vertex in obj.data.vertices:
                vertex.co.z+=step*.011
        obj.data.update()

if BATCH_CIV=='dwarf' and BATCH_ROLE=='ranged':
    for obj in list(parts):
        if obj['part'].startswith(('Emblem_Heavy_Bow','Emblem_Arrow','Rack_Bow_Left','Rack_Bow_Right')):
            remove_part(obj)
    crossbow('Clan_Crossbow_Emblem',(-.468,-.240,.651),.246,'08_DETAILS')
    crossbow('Rack_Crossbow_Left',(-.230,-.128,.277),.277,'06_EQUIPMENT')
    crossbow('Rack_Crossbow_Right',(-.096,-.143,.277),.277,'06_EQUIPMENT')

if BATCH_CIV=='elf' and BATCH_ROLE=='tank':
    for obj in list(parts):
        if part_collection(obj)=='04_WATCHTOWER' or obj['part'].startswith(('Clan_Standard','Clan_Faction_Standard','Standard_Shield_Boss','Standard_Bone','Leaf_Ornament_Standard_Bone')):
            remove_part(obj)
    # A living lookout tree replaces the closed square military tower.
    sapling('Living_Guardian_Tree',(-.535,.095,.079),1.11,.292,'04_WATCHTOWER')
    box('Tree_Lookout_Deck',(-.535,.095,.679),(.284,.288,.031),'door','04_WATCHTOWER')
    for sign in (-1,1):
        box('Tree_Deck_Rail_'+str(sign),(-.535+sign*.134,.095,.760),(.019,.276,.099),'timber','04_WATCHTOWER')
    leaf('Tank_Shield_Leaf',(.075,-.213,.916),.098,.108,.014)
    pointed_frame('Guardian_Point_Portal',.075,-.078,.215,.222,.371)

if BATCH_CIV=='elf' and BATCH_ROLE=='warrior':
    for obj in list(parts):
        if obj['part'].startswith(('Emblem_Left_Axe','Emblem_Right_Axe','Banner_Axe','Rack_Left_Axe','Rack_Right_Axe')):
            remove_part(obj)
    sword('Clan_Left_Sword',(-.119,-.162,.734),.330,-.56,'08_DETAILS')
    sword('Clan_Right_Sword',(-.119,-.197,.734),.330,.56,'08_DETAILS')
    sword('Reserve_Left_Sword',(.486,-.106,.303),.335,-.08,'04_ARMORY')
    sword('Reserve_Right_Sword',(.610,-.134,.303),.335,.08,'04_ARMORY')
    pointed_frame('Warrior_Point_Portal',-.119,-.042,.207,.226,.318)
    leaf('Warrior_Banner_Leaf',(.579,-.271,.802),.065,.100,.012)

if BATCH_CIV=='elf' and BATCH_ROLE=='rogue':
    pointed_frame('Rogue_Point_Portal',-.205,-.041,.220,.204,.300)
    leaf('Rogue_Hood_Leaf',(-.205,-.222,.894),.076,.099,.015)
if BATCH_CIV=='elf' and BATCH_ROLE=='ranged':
    pointed_frame('Ranger_Point_Portal',-.468,-.151,.199,.149,.270)

if BATCH_CIV=='elf':
    # Individual roof finials and gardens connect every building to the civic style.
    if BATCH_ROLE!='tank':
        tree_location={'warrior':(-.640,.105,.079),'ranged':(-.668,-.205,.079),
                       'cavalry':(-.686,.278,.079),'rogue':(-.680,.153,.079),
                       'siege':(-.686,.181,.079)}[BATCH_ROLE]
        for obj in list(parts):
            lo,hi=bounds(obj); midpoint=(lo+hi)/2
            if ('Crate' in obj['part'] or 'Chest' in obj['part']) and (midpoint-Vector(tree_location)).xy.length<.13:
                remove_part(obj)
        sapling('Woodland_Sapling',tree_location,.89,.175)
    roof_parts=[obj for obj in parts if part_collection(obj)=='03_ROOFS' and obj.get('region') in ('roof','roof_dark')]
    tallest=max(roof_parts,key=lambda o:bounds(o)[1].z)
    lo,hi=bounds(tallest); point=(lo+hi)/2
    leaf('Roof_Gold_Leaf_Finial',(point.x,point.y,hi.z+.088),.111,.166,.021)
    for i,(x,y) in enumerate(((.048,.740),(.593,-.242))):
        box('Woodland_Garden_Base_%d'%i,(x,y,.111),(.089,.071,.059),'foliage','08_DETAILS')
        box('Woodland_Garden_Flower_%d'%i,(x+.009,y,.154),(.031,.027,.028),'flower','08_DETAILS')

task_palette = {
    'bone':[225,215,174],'leather':[104,64,39],'rope':[174,148,99],
    'crate':[123,97,58],'ammunition':[128,136,128],'brass':[191,133,71],
    'target_red':[160,69,48],'bottle_green':[58,130,87],'bottle_amber':[153,101,48],
}
if BATCH_CIV=='dwarf':
    task_palette.update({'foundation':[78,87,91],'stone':[117,124,123],'cutstone':[175,172,152],
        'paving':[122,130,126],'timber':[101,75,43],'door':[130,96,54],'plaster':[155,163,153],
        'roof':[67,82,89],'roof_dark':[43,59,64],'roof_red':[191,133,71],
        'iron':[48,62,67],'iron_light':[151,162,160],'bronze':[191,133,71],
        'faction':[69,109,153],'water':[76,139,153],'grass':[122,130,126],
        'sand':[145,136,108],'formation':[189,175,134],'foliage':[72,94,69],
        'foliage_light':[99,117,84],'canvas':[43,59,64],'yard':[132,137,127]})
else:
    task_palette.update({'foundation':[110,128,116],'stone':[137,158,131],'cutstone':[209,215,183],
        'paving':[127,146,109],'plaster':[222,222,192],'timber':[113,91,55],
        'door':[158,127,76],'roof':[48,122,88],'roof_dark':[30,81,66],
        'roof_red':[206,181,112],'gold':[206,181,112],'bronze':[206,181,112],
        'brass':[206,181,112],'faction':[91,167,143],'glass':[112,179,161],
        'water':[89,165,168],'foliage':[63,119,66],'foliage_light':[99,151,74],
        'flower':[218,188,138],'grass':[102,137,82],'sand':[163,150,109],
        'formation':[204,191,142],'canvas':[30,81,66],'iron':[60,84,73],
        'iron_light':[192,206,180],'yard':[153,161,120]})

task_class_notes = {
 'tank':'Guardian pavilion, leaf-marked pointed shields, living lookout tree, two shield dummies and reserve shield.',
 'warrior':'Broad combat hall, crossed slender swords, open sword rack and two melee practice targets.',
 'ranged':'Small side lodge, three targets following the rear-right hex, marked lanes and ammunition. '+('Copper reinforced crossbows and ivory bolts.' if BATCH_CIV=='dwarf' else 'Wooden bows, arrows, pointed portal and woodland sapling.'),
 'cavalry':'Two genuinely open stalls, horseshoe sign, two generic static horse props without riders/rigs, clan-colored saddle blankets, low paddock rails, hay, lances, saddle and water trough.',
 'rogue':'Asymmetric guild, hood and crossed daggers, low wing, sheltered blade bench, preparation bottles, precision dummy, knife target and closed cellar hatch.',
 'siege':'Open assembly shed, cog sign, static loaded catapult, crane with suspended axle, spare wheels, wood and stone ammunition. No unit model defined.',
}
scene['display_name']=TASK_DISPLAY+(' dos Anões' if BATCH_CIV=='dwarf' else ' dos Elfos')
scene['civilization'],scene['asset_only']=BATCH_CIV,True
scene['includes_perimeter_walls']=False
scene['layout_source']=TASK_OLD_FOLDER
scene['palette_overrides']=task_palette
scene['design_note']=('Dwarven granite architecture, dark slate roofs, squared copper runestones and bands, blue clan accents; palette matches dwarf city I. ' if BATCH_CIV=='dwarf' else 'Elven ivory-and-timber architecture, emerald layered roofs, gold leaf finials and foliage; palette matches elf city I. ')+task_class_notes[BATCH_ROLE]+' Shared regular training line; supreme unit remains in its separate mastery building. Asset only.'
root['civilization'],root['unit_class'],root['asset_only']=BATCH_CIV,BATCH_ROLE,True
root['includes_perimeter_walls']=False
for obj in parts:
    obj.parent=root
    if 'prop_source' in obj:
        obj['prop_source']='Generic static horse miniature only; no rider or rig; clan saddle cloth.'

# All six tile constraints, including new leaves, trees and crossbow tips.
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
            for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2-.030, (TASK_FOLDER,maximum)
scene['unit_class']=BATCH_ROLE
bpy.app.driver_namespace['guardian_hall'].update({
    'parts':parts,'root':root,'design_note':scene['design_note'],
    'scale_note':scene['scale_note']})
result={'asset':TASK_FOLDER,'civilization':BATCH_CIV,'unit_class':BATCH_ROLE,
        'parts':len(parts),'max_tile_half_plane':maximum,'asset_only':True}
