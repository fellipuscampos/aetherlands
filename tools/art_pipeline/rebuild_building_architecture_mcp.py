"""Repair ONE existing source in the live Blender editor, through MCP only.

The caller supplies ARCH_FOLDER. Preserve gameplay IDs, props and the tile.
Native meshes are reconstructed; this does not recolor exported GLBs.
"""
import ast
import bpy
import bmesh
import json
import math
import time
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE = ROOT/'tools/art_pipeline'
phase_start=time.monotonic()
def checkpoint(phase):
    (ROOT/'art_source/building_architecture_review/current_stage.json').write_text(json.dumps({'asset':ARCH_FOLDER,'stage':phase,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
checkpoint('resolve_source')
files = list((ROOT/'assets/generated').glob('*/buildings/'+ARCH_FOLDER+'/'+ARCH_FOLDER+'_report.json'))
assert len(files)==1
OUT = files[0].parent
old_report = json.loads(files[0].read_text(encoding='utf-8'))
ASSET_NAME, ASSET_FOLDER = old_report['name'], ARCH_FOLDER
if ASSET_NAME not in bpy.data.scenes:
    with bpy.data.libraries.load(str(OUT/(ARCH_FOLDER+'.blend')),link=False) as (src,dst):
        dst.scenes = [ASSET_NAME]
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene, NAME, parts, groups, root = st['scene'], st['name'], st['parts'], st['groups'], st['root']
assert not scene.get('architecture_revision'), 'Already rebuilt: '+ARCH_FOLDER
bpy.context.window.scene = scene
CIV = {'humans':'human','elves':'elf','dwarves':'dwarf','orcs':'orc'}[OUT.parent.parent.name]
TRIM = {'human':'gold','elf':'gold','dwarf':'bronze','orc':'iron'}[CIV]
CUBE = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename, names in (
    ('warrior_hall_hex_v1_model.py',('mesh','box','polygon_prism','hexagon')),
    ('magic_school_model.py',('beam','ring')),
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<architecture_primitives>','exec'))

def bb(obj):
    return Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3))), Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))

part_groups={o.as_pointer():label for label,col in groups.items() for o in col.objects}
pending_removals=[]

def group_of(obj):
    pointer=obj.as_pointer()
    if pointer not in part_groups:
        part_groups[pointer]=next(k for k,c in groups.items() if obj.name in c.objects)
    return part_groups[pointer]

def remove(obj):
    parts.remove(obj)
    label=group_of(obj)
    part_groups.pop(obj.as_pointer(),None)
    assert obj.users==1, 'Shared source part requires individual isolation'
    groups[label].objects.unlink(obj)
    pending_removals.append(obj)

def resize_xy(obj, factor, maximum=.18):
    lo,hi = bb(obj); c=(lo+hi)/2; dims=hi-lo
    for v in obj.data.vertices:
        for i in (0,1):
            f=min(factor,maximum/dims[i]) if dims[i] else 1
            v.co[i]=c[i]+(v.co[i]-c[i])*f
    obj.data.update()

def structure(obj):
    label=group_of(obj)
    if not label.startswith(('02_','04_','03_')): return False
    if any(x in label for x in ('CATAPULT','MOUNTS','EQUIPMENT','TARGET')): return False
    return not any(x in obj['part'] for x in ('Horse','Catapult','Crane','Saddle','Wheel','Axle','Weapon','Bow','Shield','Sword','Axe','Arrow','Emblem','Sign','Crest','Badge','Banner','Standard','Dummy','Target','Rack','Book','Skull','Bone','Relic','Brazier','Lantern','Flame','Crystal','Orb','Armillary','Armilar','Root','Trunk','Branch','Canopy','Crown_Top'))

changes=[]
checkpoint('rebuild_geometry')
if CIV=='elf':
    for obj in list(parts):
        if group_of(obj)=='03_ROOFS' and 'Iron' in obj['part'] and any(t in obj['part'] for t in ('Binding','Edge')):
            label=obj['part']
            remove(obj)
            changes.append('remove_inherited_roof_lashing:'+label)
original_parts=list(parts)
roof_slabs=[o for o in original_parts if group_of(o)=='03_ROOFS' and o['region'] in ('roof','roof_dark','canvas') and bb(o)[1].z-bb(o)[0].z<.13]
for obj in original_parts:
    p,reg=obj['part'],obj['region']
    if not structure(obj): continue
    if CIV=='human' and reg in ('timber','plaster','door') and not any(t in p for t in ('Door','Gate','Shutter','Louver','Hatch','Rail')):
        obj['region']='stone' if any(t in p for t in ('Body','Wall','Chamber','Tower')) else 'cutstone'
        changes.append('masonry:'+p)
    elif CIV=='dwarf' and reg in ('timber','plaster','door') and not any(t in p for t in ('Door','Gate','Shutter','Hatch','Rail')):
        obj['region']='stone' if any(t in p for t in ('Body','Wall','Chamber','Tower')) else 'cutstone'
        changes.append('granite:'+p)
    elif CIV=='elf' and reg in ('stone','plaster','tombstone') and any(t in p for t in ('Body','Wall','Chamber','Tower')):
        obj['region']='cutstone'
        changes.append('ivory:'+p)
    elif CIV=='orc' and reg in ('plaster','stone','cutstone','tombstone'):
        if any(t in p for t in ('Body','Wall','Chamber','Tower','Post','Shaft','Pier','Pillar','Jamb','Lintel','Header')) and not any(t in p for t in ('Foot','Foundation','Crypt','Mausoleum','Altar')):
            obj['region']='door' if any(t in p for t in ('Body','Wall','Chamber','Tower')) else 'timber'
            changes.append('timber:'+p)

# Actual roof silhouettes: clipped leaflike eaves for elves, thick bevelled
# stone slabs for dwarves. Original height/crest contacts are retained.
if CIV in ('elf','dwarf'):
    for obj in roof_slabs:
        lo,hi=bb(obj); w,d,h=hi-lo; c=(lo+hi)/2
        if min(w,d)<.095 or max(w,d)/min(w,d)>9: continue
        xy=sorted(set((round(v.co.x,6),round(v.co.y,6)) for v in obj.data.vertices))
        if len(xy)==4:
            # Work on the real edge vectors, including diagonal hex-side roofs.
            # A world-aligned bounding rectangle would escape the tile.
            ordered=sorted(xy,key=lambda p:math.atan2(p[1]-c.y,p[0]-c.x))
            fraction=.19 if CIV=='elf' else .10
            points=[]
            for i,p in enumerate(ordered):
                for neighbor in (ordered[i-1],ordered[(i+1)%4]):
                    points.append((p[0]+(neighbor[0]-p[0])*fraction,p[1]+(neighbor[1]-p[1])*fraction))
        else:
            points=sorted(xy,key=lambda p:math.atan2(p[1]-c.y,p[0]-c.x))
        if CIV=='elf':
            lifts=[.012 if i%2==0 else 0 for i in range(len(points))]
        else:
            lifts=[0]*len(points)
        n=len(points)
        verts=[(x,y,z+lifts[i]) for z in (lo.z,hi.z) for i,(x,y) in enumerate(points)]
        faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        new=mesh(obj['part'],verts,faces,'roof',group_of(obj))
        remove(obj)
        changes.append('roof_geometry:'+new['part'])

# Elven stables and halls use an airy pavilion frame in place of the copied
# plank enclosure. Keep a stone sill for weather protection and stall walls.
if CIV=='elf':
    for obj in list(parts):
        if not structure(obj) or not any(t in obj['part'] for t in ('Plank_Wall','Backwall')): continue
        lo,hi=bb(obj)
        if hi.z-lo.z<.28: continue
        old_height=hi.z-lo.z
        for v in obj.data.vertices:
            v.co.z=lo.z+(v.co.z-lo.z)*.40
        obj['region']='cutstone'; obj.data.update()
        # Outer ends are the actual wall vertices, not its bounding-box corners.
        xy=sorted(set((round(v.co.x,6),round(v.co.y,6)) for v in obj.data.vertices))
        for j,(x,y) in enumerate((xy[0],xy[-1])):
            box('Architecture_Pavilion_'+obj['part']+'_'+str(j),(x,y,(lo.z+hi.z)/2),(.029,.029,old_height),'timber',group_of(obj))
        changes.append('open_pavilion:'+obj['part'])

# Natural shrines also need their own engineering vocabulary. Keep the living
# tree, but replace the shared stone-marker arrangement with clan construction.
for obj in list(parts):
    p=obj['part']
    if not (p.startswith('Standing_Stone_') or p.startswith('Ancestral_Marker_') and 'Foot' not in p): continue
    lo,hi=bb(obj); c=(lo+hi)/2; dims=hi-lo
    if dims.z<.18: continue
    if CIV=='elf':
        obj['region']='timber'
        for vertex in obj.data.vertices:
            t=(vertex.co.z-lo.z)/dims.z
            vertex.co.x=c.x+(vertex.co.x-c.x)*(1-.32*t)
            vertex.co.y=c.y+(vertex.co.y-c.y)*(1-.32*t)
        obj.data.update()
        for sign in (-1,1):
            beam('Architecture_Grove_Branch_'+p+'_'+str(sign),(c.x,c.y,lo.z+dims.z*.52),(c.x+sign*dims.x*.40,c.y,lo.z+dims.z*.86),.021,'timber',group_of(obj))
        changes.append('living_grove_marker:'+p)
    elif CIV=='orc':
        obj['region']='timber'
        for j,z in enumerate((lo.z+.07,hi.z-.05)):
            box('Architecture_Totem_Iron_'+p+'_'+str(j),(c.x,c.y,z),(dims.x+.012,dims.y+.012,.035),'iron',group_of(obj))
        changes.append('tribal_totem:'+p)
    elif CIV=='dwarf':
        obj['region']='stone'; resize_xy(obj,1.4,.23)
        lo,hi=bb(obj); dims=hi-lo
        box('Architecture_Grove_Granite_Shoe_'+p,(c.x,c.y,lo.z+.039),(dims.x+.025,dims.y+.025,.078),'cutstone',group_of(obj))
        box('Architecture_Grove_Copper_Cap_'+p,(c.x,c.y,hi.z-.018),(dims.x+.017,dims.y+.017,.036),'bronze',group_of(obj))
        changes.append('granite_runestone:'+p)

posts=[]
for obj in list(parts):
    p=obj['part']; lo,hi=bb(obj); dims=hi-lo
    if structure(obj) and any(t in p for t in ('Post','Pier','Pillar','Column','Shaft','Architecture_Pavilion')) and dims.z>.19 and max(dims.x,dims.y)<.26 and obj['region'] in ('timber','cutstone','stone','plaster','door'):
        posts.append(obj)

connections=[]
for idx,obj in enumerate(posts):
    lo,hi=bb(obj); c=(lo+hi)/2; dims=hi-lo; group=group_of(obj)
    if CIV=='human':
        obj['region']='cutstone'; resize_xy(obj,1.4,.13)
        lo,hi=bb(obj); dims=hi-lo
        if lo.z<.23:
            bottom=max(.077,lo.z-.035); height=min(.16,(hi.z-bottom)*.30)
            box('Architecture_Stone_Plinth_'+str(idx),(c.x,c.y,bottom+height/2),(dims.x+.026,dims.y+.026,height),'cutstone',group)
        box('Architecture_Stone_Capital_'+str(idx),(c.x,c.y,hi.z-.025),(dims.x+.023,dims.y+.023,.05),'cutstone',group)
        changes.append('stone_pier:'+obj['part'])
    elif CIV=='dwarf':
        obj['region']='cutstone'; resize_xy(obj,1.7,.19)
        lo,hi=bb(obj); dims=hi-lo
        for j,z in enumerate((lo.z+.06,hi.z-.06)):
            box('Architecture_Copper_Collar_%s_%s'%(idx,j),(c.x,c.y,z),(dims.x+.018,dims.y+.018,.037),'bronze',group)
        # A stepped, load-bearing granite shoe seated on the original floor.
        bottom=max(.077,lo.z-.04)
        if bottom<hi.z-.15:
            box('Architecture_Granite_Shoe_'+str(idx),(c.x,c.y,bottom+.042),(dims.x+.028,dims.y+.028,.084),'stone',group)
        changes.append('granite_pier:'+obj['part'])
    else:
        # Determine the real roof supported by this post before adding braces.
        roofs=[]
        for roof_obj in parts:
            if group_of(roof_obj)!='03_ROOFS' or roof_obj['region'] not in ('roof','roof_dark'): continue
            rlo,rhi=bb(roof_obj)
            if abs(rlo.z-hi.z)<.10 and rlo.x-.012<=c.x<=rhi.x+.012 and rlo.y-.012<=c.y<=rhi.y+.012:
                roofs.append((abs(rlo.z-hi.z),roof_obj,rlo,rhi))
        if CIV=='orc':
            obj['region']='timber'; resize_xy(obj,1.25,.16)
            lo,hi=bb(obj); dims=hi-lo
            for j,z in enumerate((lo.z+.07,hi.z-.055)):
                box('Architecture_Iron_Lashing_%s_%s'%(idx,j),(c.x,c.y,z),(dims.x+.014,dims.y+.014,.037),'iron',group)
            changes.append('bound_log:'+obj['part'])
        else:
            # Timber joints and branches, rather than human masonry buttresses.
            obj['region']='timber'
            resize_xy(obj,.83,.12)
            changes.append('branch_pier:'+obj['part'])
        if roofs:
            _,roof_obj,rlo,rhi=min(roofs,key=lambda t:t[0]); rc=(rlo+rhi)/2
            for axis in (0,1):
                distance=rc[axis]-c[axis]
                if abs(distance)<.045: continue
                start=Vector((c.x,c.y,hi.z-min(.18,dims.z*.35)))
                end=Vector((c.x,c.y,min(hi.z+.01,rlo.z+.008)))
                end[axis]+=math.copysign(min(.13,abs(distance)*.65),distance)
                beam('Architecture_%s_Brace_%s_%s'%('Branch' if CIV=='elf' else 'Log',idx,axis),start,end,.023 if CIV=='elf' else .038,'timber',group)
                connections.append({'post':obj['part'],'roof':roof_obj['part'],'end':list(end)})

# Re-proportion the upper architecture as a continuous map, including its
# attached ornaments. Contacts remain coincident: steep elven crowns, low
# dwarven slate roofs, and squat orc roof frames are structurally different.
roof_bases=[bb(o)[0].z for o in parts if group_of(o)=='03_ROOFS' and o['region']=='roof' and bb(o)[1].x-bb(o)[0].x>.10 and bb(o)[1].y-bb(o)[0].y>.10]
if roof_bases and CIV!='human':
    eave=min(roof_bases)
    factor={'elf':1.22,'dwarf':.62,'orc':.86}[CIV]
    for obj in parts:
        for vertex in obj.data.vertices:
            if vertex.co.z>eave: vertex.co.z=eave+(vertex.co.z-eave)*factor
        obj.data.update()
    for connection in connections:
        if connection['end'][2]>eave: connection['end'][2]=eave+(connection['end'][2]-eave)*factor
    changes.append('upper_structure_proportion:'+str(factor))

# Roof color must belong to the civilization, including the ranger target shed.
palette={k:list(v) for k,v in scene.get('palette_overrides',{}).items()}
palettes={
 'human':{'stone':[131,141,145],'cutstone':[172,179,174],'roof':[49,79,127],'roof_dark':[37,59,95],'gold':[206,181,112]},
 'elf':{'cutstone':[209,215,183],'roof':[48,122,88],'roof_dark':[30,81,66],'gold':[206,181,112]},
 'dwarf':{'stone':[117,124,123],'cutstone':[175,172,152],'roof':[67,82,89],'roof_dark':[43,59,64],'bronze':[191,133,71]},
 'orc':{'stone':[88,100,97],'cutstone':[137,148,124],'roof':[130,58,39],'roof_dark':[83,40,30],'iron':[53,65,65]},
}
palette.update(palettes[CIV]); scene['palette_overrides']=palette
for obj in parts:
    if obj['region'].startswith('canvas') and group_of(obj)=='03_ROOFS':
        obj['region']='roof'; changes.append('civilization_roof:'+obj['part'])
    obj.parent=root

notes={
 'human':'Alvenaria de blocos de pedra, pilares com bases e capitéis de cantaria, telhados azuis; madeira reservada a portas, cercas, móveis e mecanismos.',
 'elf':'Cantaria clara com armação esbelta de madeira, mãos-francesas em forma de galhos e coberturas verdes com cantos facetados e beirais ascendentes.',
 'dwarf':'Engenharia de granito com pilares engrossados, sapatas escalonadas e cintas de cobre; coberturas de ardósia escura com cantos chanfrados.',
 'orc':'Estrutura de madeira grossa, postes cintados com ferro e contraventamentos diagonais; coberturas ferrugem, pedra escura na fundação e presas do clã.',
}
scene['architecture_revision']=1
scene['architecture_design']=notes[CIV]
scene['architecture_mcp_only']=True
scene['design_note']=notes[CIV]+' Função e adereços do edifício original preservados.'
scene['asset_output_relative']=OUT.relative_to(ROOT).as_posix()
st.update({'parts':parts,'design_note':scene['design_note']})
if pending_removals:
    private_data={o.data for o in pending_removals if o.data.users==1}
    bpy.data.batch_remove(ids={*pending_removals,*private_data})
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.030,(ARCH_FOLDER,maximum)
assert changes, 'No architecture changed'

# Preserve all report metadata while repacking new metric face UVs and emission.
paint_code=(PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')
checkpoint('paint_atlases')
paint_code=paint_code.replace("elif reg == 'glow':", "elif reg in ('magic','fire','air','water','earth'):\n        e[:] = np.asarray(PALETTE[reg]) * (.75 if reg == 'earth' else 1.0)\n    elif reg == 'glow':")
exec(paint_code)
new_report=st['report']
merged=dict(old_report); merged.update(new_report)
if 'hex_tile' in merged:
    merged['hex_tile']['max_half_plane_blender']=maximum
catalog=(ROOT/'scripts/data/BuildingArtCatalog.gd').read_text(encoding='utf-8')
merged['integrated_in_game']=('"'+ARCH_FOLDER+'"' in catalog)
merged['integration_source']='scripts/data/BuildingArtCatalog.gd'
merged['architecture_revision']={'revision':1,'civilization':CIV,'design':notes[CIV],'geometry_changes':changes,'roof_braces':connections,'max_tile_half_plane':maximum,'blender_mcp_only':True}
st['report']=merged
files[0].write_text(json.dumps(merged,ensure_ascii=False,indent=2),encoding='utf-8')
checkpoint('export_glb')
exec((PIPELINE/'export_architecture_revision_mcp.py').read_text(encoding='utf-8'))

# Re-render all four established views, restoring the scene's rendering setup.
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
camera=scene.camera; target=Vector(scene.get('preview_target',(0,0,.6)))
old_camera=(camera.location.copy(),camera.rotation_euler.copy(),camera.data.ortho_scale)
render_settings=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)
old_device=scene.cycles.device
prefs=bpy.context.preferences.addons['cycles'].preferences
old_compute=prefs.compute_device_type
try:
    try:
        prefs.compute_device_type='OPTIX'; prefs.get_devices()
        if any(d.type=='OPTIX' and d.use for d in prefs.devices): scene.cycles.device='GPU'
    except (TypeError,RuntimeError): pass
    views={'three_quarter':((2.6,-4,3.3),2.8),'game_top':((1.8,-2.9,4.9),2.65),'top':((0,0,6),2.25),'back':((-2.6,4,3.4),2.8)}
    for view,(location,scale) in views.items():
        checkpoint('render_'+view)
        camera.location=location; camera.data.ortho_scale=scale
        aim=Vector((0,0,0)) if view=='top' else target
        camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/'previews'/(view+'.png'))
        bpy.ops.render.render(write_still=True)
finally:
    camera.location,camera.rotation_euler,camera.data.ortho_scale=old_camera
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=render_settings
    scene.cycles.device=old_device; prefs.compute_device_type=old_compute
bpy.data.libraries.write(str(OUT/(ARCH_FOLDER+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
readme=OUT/'README.md'
body='# '+st['report']['display_name']+'\n\n'+notes[CIV]+'\n\n'
body+='Revisão de arquitetura de 2026-10-09 pelo **Blender MCP**. Mantém a função de treino, os equipamentos, o ID e o caminho usados pelo catálogo do jogo.\n\n'
body+='- Fonte `.blend` com peças editáveis e atlas empacotados.\n- Exportação `.glb` com grupos arquitetônicos e dois atlas embutidos.\n- Sem câmera, luz, rig ou animação na exportação.\n- Origem no centro do tile, solo Z=0; frente −Y no Blender / +Z no Godot.\n'
body+=f"- {st['report']['editable_parts']} peças, {st['report']['triangles']} triângulos, atlas {st['report']['texture']['size'][0]}² e filtro nearest.\n\n"
body+='Prévias: [três quartos](previews/three_quarter.png), [mapa](previews/game_top.png), [topo](previews/top.png), [traseira](previews/back.png).\n\n'
body+='O relatório JSON lista alterações de geometria, conexões dos contraventamentos e limites do tile. Os arquivos anteriores estão preservados em `art_source/buildings_before_architecture_revision`.\n'
readme.write_text(body,encoding='utf-8')
checkpoint('complete')
result={'asset':ARCH_FOLDER,'civilization':CIV,'changed_parts':len(changes),'braces':len(connections),'triangles':st['report']['triangles'],'max_half_plane':maximum,'mcp_only':True}
