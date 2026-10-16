"""Hex-first Ranger Camp, built through the running Blender MCP, native tile radius 1.
New isolated scene; preserves all earlier halls and the user's open scenes.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT / 'tools/art_pipeline'
NAME = 'Ranger_Camp_Hex_V1'
OUT = ROOT / 'assets/generated/humans/buildings/ranger_camp_hex_v1'
if NAME in bpy.data.scenes:
    raise RuntimeError('Ranger Camp scene exists; preserve its edits.')
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
groups = {}
for label in ('01_FOUNDATION', '02_HALL', '03_ROOFS', '04_TARGETS',
              '05_COURTYARD', '06_EQUIPMENT', '07_HERALDRY', '08_DETAILS', '09_STUDIO'):
    collection = bpy.data.collections.new(NAME + '_' + label)
    scene.collection.children.link(collection)
    groups[label] = collection
parts = []
CUBE = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
# Share tested geometric primitives without executing another scene's constructor.
tree = ast.parse((PIPELINE / 'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8'))
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('mesh', 'box', 'polygon_prism', 'hexagon', 'wall'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), '<hall_primitives>', 'exec'))


def beam(name, a, b, width, region='timber', group='08_DETAILS'):
    # A square beam between arbitrary endpoints, still flat block geometry.
    start, end = Vector(a), Vector(b)
    direction = (end - start).normalized()
    across = direction.cross(Vector((0, 1, 0)))
    if across.length < .001:
        across = direction.cross(Vector((1, 0, 0)))
    across.normalize()
    up = direction.cross(across).normalized()
    verts = [tuple(p + across * sx * width/2 + up * sy * width/2)
             for p in (start, end) for sy in (-1, 1) for sx in (-1, 1)]
    return mesh(name, verts, CUBE, region, group)


def target_disc(name, center, diameter, depth, facing_angle, region):
    # Stepped round face, matching the block silhouette of the troops' equipment.
    profile = [(-.28,.5),(.28,.5),(.28,.4),(.42,.4),(.42,.24),(.5,.24),
               (.5,-.24),(.42,-.24),(.42,-.4),(.28,-.4),(.28,-.5),
               (-.28,-.5),(-.28,-.4),(-.42,-.4),(-.42,-.24),(-.5,-.24),
               (-.5,.24),(-.42,.24),(-.42,.4),(-.28,.4)]
    c = Vector(center)
    a = Vector((math.cos(facing_angle), math.sin(facing_angle), 0))
    b = Vector((-math.sin(facing_angle), math.cos(facing_angle), 0))
    verts = [tuple(c + a * u * diameter + Vector((0,0,v*diameter)) + b * d)
             for d in (-depth/2, depth/2) for u, v in profile]
    n = len(profile)
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, verts, faces, region, '04_TARGETS')


def bow(name, center, height, group='06_EQUIPMENT'):
    # Seven axis-aligned wooden segments; a straight string joins the tips.
    x, y, z = center
    unit = height / .48
    for i, (dx, dz, length) in enumerate(((-.095,0,.13),(-.070,.10,.070),(-.070,-.10,.070),
                                       (-.035,.1675,.065),(-.035,-.1675,.065),
                                       (.015,.22,.04),(.015,-.22,.04))):
        box(name + '_Limb_%d' % i, (x+dx*unit,y,z+dz*unit),
            (.038*unit,.030*unit,length*unit), 'door', group)
    # Horizontal joins ensure each stepped limb is connected, not floating.
    for sign in (-1, 1):
        box(name + '_JoinA_' + str(sign), (x-.080*unit,y,z+sign*.065*unit),
            (.055*unit,.030*unit,.015*unit), 'door', group)
        box(name + '_JoinB_' + str(sign), (x-.052*unit,y,z+sign*.133*unit),
            (.070*unit,.030*unit,.016*unit), 'door', group)
        box(name + '_JoinC_' + str(sign), (x-.008*unit,y,z+sign*.202*unit),
            (.086*unit,.030*unit,.015*unit), 'door', group)
    box(name + '_Grip', (x-.095*unit,y-.004*unit,z), (.046*unit,.041*unit,.070*unit), 'timber', group)
    box(name + '_String', (x+.029*unit,y,z), (.009*unit,.009*unit,.458*unit), 'target_white', group)


# Family-consistent rim, with grass inside: this is an outdoor ranged training camp.
polygon_prism('Hex_Foundation', hexagon(.92), 0, .035, 'foundation', '01_FOUNDATION')
polygon_prism('Hex_Rim', hexagon(.90), .035, .060, 'cutstone', '01_FOUNDATION')
polygon_prism('Camp_Grass', hexagon(.85), .060, .075, 'grass', '01_FOUNDATION')

# Small timber lodge occupies the left side, keeping the range open.
box('Lodge_StoneFoot', (-.50,.16,.107), (.345,.515,.064), 'stone')
box('Lodge_TimberBody', (-.50,.16,.345), (.30,.46,.413), 'door')
for x in (-.65,-.35):
    for y in (-.065,.385):
        box('Lodge_Post_%s_%s' % (x,y), (x,y,.35), (.043,.046,.43), 'timber')
box('Lodge_EaveBeam', (-.50,.16,.563), (.345,.505,.036), 'timber')
for j in range(5):
    box('Lodge_Roof_%d' % j, (-.50,.16,.608+j*.044),
        (.39-j*.072,.55,.044), 'roof', '03_ROOFS')
box('Lodge_Ridge', (-.50,.16,.809), (.053,.57,.021), 'roof_dark', '03_ROOFS')
box('Lodge_DoorShadow', (-.50,-.081,.32), (.168,.024,.355), 'shadow')
box('Lodge_Door', (-.50,-.098,.31), (.142,.022,.333), 'timber')
for z in (.205,.402):
    box('Lodge_DoorBand_' + str(z), (-.50,-.114,z), (.138,.012,.023), 'iron')
box('Lodge_DoorHandle', (-.454,-.124,.304), (.018,.018,.028), 'iron_light')
box('Lodge_SideWindow', (-.337,.155,.37), (.015,.152,.157), 'shadow')
for y in (.075,.235):
    box('Lodge_WindowJamb_' + str(y), (-.329,y,.37), (.026,.025,.184), 'timber')
box('Lodge_WindowCrossbar', (-.329,.155,.37), (.026,.152,.023), 'timber')

# Porch with a short olive awning echoes the archers' green hoods.
box('Porch_Deck', (-.50,-.177,.104), (.36,.192,.058), 'timber', '02_HALL')
box('Porch_Step', (-.50,-.29,.083), (.295,.052,.016), 'door', '02_HALL')
for x in (-.657,-.343):
    box('Porch_Post_' + str(x), (x,-.255,.308), (.036,.036,.41), 'timber')
for j in range(3):
    box('Porch_Awning_%d' % j, (-.50,-.234+j*.061,.497+j*.023),
        (.387,.061,.024), 'canvas_olive', '03_ROOFS')
box('Porch_Fascia', (-.50,-.27,.482), (.39,.025,.068), 'canvas_olive', '03_ROOFS')

# The targets follow the rear-right edge. Their faces point down the three lanes.
angle = math.radians(-30)
a = Vector((math.cos(angle),math.sin(angle),0))
b = Vector((-math.sin(angle),math.cos(angle),0))
centers = [Vector((.12,.63,.415)),Vector((.34,.50,.415)),Vector((.56,.37,.415))]
screen = Vector((.34,.50,0)) + b*.058
box('Arrow_Backstop', (screen.x,screen.y,.36), (.835,.032,.45), 'timber', '04_TARGETS', angle)
box('Backstop_UpperRail', (screen.x,screen.y,.605), (.88,.067,.04), 'door', '04_TARGETS', angle)
for sign in (-1,1):
    p = screen+a*sign*.432
    box('Target_FramePost_' + str(sign), (p.x,p.y,.367), (.043,.043,.585), 'timber', '04_TARGETS')
    pfront = p-b*.128
    beam('Target_FrameBrace_' + str(sign), (pfront.x,pfront.y,.087), (p.x,p.y,.46), .035, group='04_TARGETS')
for j in range(3):
    p = screen - b*(.066-j*.054)
    box('Target_Shade_%d' % j, (p.x,p.y,.648+j*.021),
        (.895,.054,.025), 'canvas_olive', '03_ROOFS', angle)
for i, center in enumerate(centers):
    foot = center.copy()
    foot.z = .092
    box('Target_Foot_%d' % i, tuple(foot), (.145,.115,.035), 'door', '04_TARGETS', angle)
    box('Target_Stake_%d' % i, (center.x,center.y,.242), (.032,.032,.305), 'timber', '04_TARGETS')
    for j, (diameter, region) in enumerate(((.253,'straw'),(.217,'target_white'),(.156,'target_blue'),(.096,'target_white'),(.048,'target_red'))):
        position = center - b*(0 if j == 0 else .020+(j-1)*.009)
        target_disc('Target_%d_Ring_%d' % (i,j), position, diameter, .035 if j == 0 else .009, angle, region)
    # One planted arrow makes the training function visible without filling the model with props.
    impact = center-b*.050+Vector((.018,0,.012))
    tail = impact-b*.105
    beam('Target_Arrow_%d' % i, impact, tail, .008, 'door', '06_EQUIPMENT')
    beam('Target_ArrowFeather_%d' % i, tail, tail+b*.026, .017, 'target_white', '06_EQUIPMENT')
    # Parallel strips and firing bars form a coherent range rather than a dueling arena.
    lane = center-b*.40
    box('Range_Lane_%d' % i, (lane.x,lane.y,.084), (.147,.61,.018), 'sand', '05_COURTYARD', angle)
    firing = center-b*.745
    box('Firing_Line_%d' % i, (firing.x,firing.y,.091), (.18,.034,.026), 'formation', '05_COURTYARD', angle)
    for offset in (-.06,.06):
        marker = firing+a*offset-b*.043
        box('Firing_Foot_%d_%s' % (i,offset), (marker.x,marker.y,.083), (.040,.067,.016), 'paving', '05_COURTYARD', angle)

# A short front path fits the tapered entrance sector of the hex.
polygon_prism('Entry_Path', [(-.115,-.50),(.115,-.50),(.115,-.66),(0,-.80),(-.115,-.66)],
              .075,.085,'sand','05_COURTYARD')
for sign in (-1,1):
    wall('Low_Fence_' + str(sign), (sign*.68,-.31),(sign*.25,-.60), .026,.173,.203, 'timber')
    for j in range(3):
        t = j/2
        x,y = sign*(.68*(1-t)+.25*t), -.31*(1-t)-.60*t
        box('Fence_Post_%d_%d' % (sign,j), (x,y,.187), (.039,.039,.224), 'timber', '05_COURTYARD')

# Side rack stores bows and large quivers, away from the lanes.
for x in (-.73,-.55):
    box('BowRack_Post_' + str(x), (x,-.40,.237), (.025,.030,.32), 'timber', '06_EQUIPMENT')
box('BowRack_Rail', (-.64,-.40,.34), (.22,.029,.026), 'door', '06_EQUIPMENT')
bow('Stored_Bow_Left', (-.664,-.42,.267), .27)
bow('Stored_Bow_Right', (-.56,-.42,.267), .27)
for i in range(2):
    x,y = .43+i*.12,-.27+i*.045
    box('Quiver_%d' % i, (x,y,.163), (.063,.072,.171), 'door', '06_EQUIPMENT')
    box('Quiver_Rim_%d' % i, (x,y,.253), (.076,.086,.020), 'timber', '06_EQUIPMENT')
    for j in range(3):
        ax = x-.020+j*.020
        box('Quiver_Arrow_%d_%d' % (i,j), (ax,y,.27), (.007,.009,.120), 'door', '06_EQUIPMENT')
        box('Quiver_Feather_%d_%d' % (i,j), (ax,y,.327), (.016,.020,.038), 'target_white' if j%2 else 'target_red', '06_EQUIPMENT')

# Large bow-and-arrow sign at the entrance, a clear strategic-map class marker.
for sign in (-1,1):
    box('Entrance_Post_' + str(sign), (sign*.171,-.63,.316), (.043,.043,.482), 'timber', '07_HERALDRY')
box('Entrance_Lintel', (0,-.63,.554), (.41,.065,.053), 'door', '07_HERALDRY')
box('Bow_Crest_Backboard', (0,-.664,.69), (.363,.032,.39), 'canvas_olive', '07_HERALDRY')
bow('Entrance_Crest_Bow', (0,-.697,.693), .40, '07_HERALDRY')
box('Crest_Arrow_Shaft', (.034,-.722,.693), (.331,.010,.013), 'target_white', '07_HERALDRY')
for j in range(3):
    box('Crest_Arrow_Head_%d' % j, (.179+j*.020,-.722,.693),
        (.020,.019,.063-j*.019), 'iron_light', '07_HERALDRY')
for z in (.678,.708):
    box('Crest_Arrow_Feather_' + str(z), (-.114,-.722,z), (.063,.015,.018), 'target_white', '07_HERALDRY')

box('Flag_Pole', (-.50,.333,.925), (.016,.016,.49), 'timber', '07_HERALDRY')
box('Flag_Cap', (-.50,.333,1.185), (.029,.029,.029), 'iron_light', '07_HERALDRY')
flag = box('Ranger_Flag', (-.378,.333,1.079), (.225,.012,.146), 'banner', '07_HERALDRY')
flag['banner_center'],flag['banner_size'],flag['heraldry'] = [-.378,.333,1.079],[.225,.146],'arrow'
box('Porch_Lantern', (-.685,-.174,.346), (.030,.034,.051), 'glow', '08_DETAILS')
box('Porch_LanternCap', (-.685,-.174,.383), (.043,.046,.021), 'iron', '08_DETAILS')
box('Supply_Crate', (-.64,.44,.145), (.123,.132,.14), 'crate', '08_DETAILS')
for label,x,y in (('Rear',-.34,.61),('Front',.47,-.48)):
    box('Shrub_' + label + '_Base', (x,y,.125), (.16,.145,.10), 'foliage', '08_DETAILS')
    box('Shrub_' + label + '_Top', (x+.025,y,.194), (.102,.105,.044), 'foliage_light', '08_DETAILS')

root = bpy.data.objects.new(NAME + '_ROOT', None)
scene.collection.objects.link(root)
root['gameplay_building_id'] = 'v2_building_ranger_camp'
root['design'] = 'Hex-first outdoor ranged training camp. Map tile radius 1; native scale 1.'
for obj in parts:
    obj.parent = root
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in parts for v in obj.data.vertices for i in range(6))
assert maximum <= math.sqrt(3)/2+1e-6, maximum

studio_code = (PIPELINE / 'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')
exec(studio_code[studio_code.index('world = bpy.data.worlds.new'):studio_code.index("scene['preview_target']")])
scene['preview_target'] = [0,0,.44]
scene['door_clearance'] = [.142,.333]
scene['asset_basename'],scene['density'],scene['paint_world_scale'] = OUT.name,128,7
scene['display_name'] = 'Campo dos Patrulheiros'
scene['trains'] = ['v2_unit_archer','v2_unit_hunter','v2_unit_elite_marksman']
scene['excludes'] = ['v2_legendary_legend_hunter']
scene['palette_overrides'] = {'grass':[101,122,71], 'canvas_olive':[83,113,60], 'foliage':[72,101,49],
    'foliage_light':[102,129,65], 'target_white':[221,216,185], 'target_blue':[65,93,147], 'target_red':[165,57,44]}
scene['scale_note'] = 'Native map units, pointy-top tile radius 1, model_scale_multiplier 1.0. Symbolic 4X camp.'
scene['design_note'] = 'Asymmetric timber lodge and olive porch left, three diagonal stepped round bullseye targets and firing lanes right. Bow-and-arrow gate sign, bow rack, quivers and low fences; blue team roof and green ranger details.'
bpy.app.driver_namespace['guardian_hall'] = {'scene':scene,'name':NAME,'out':str(OUT),'parts':parts,'groups':groups,
    'root':root,'camera':camera,'target':Vector(scene['preview_target']),'density':128,'paint_world_scale':7,
    'door_clearance':[.142,.333],'scale_note':scene['scale_note'],'design_note':scene['design_note']}
result = {'scene':NAME,'parts':len(parts),'max_tile_half_plane':maximum,'allowed':math.sqrt(3)/2}
