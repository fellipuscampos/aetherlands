"""Focused native roof correction, preserving the approved layout and details."""
import ast
import bpy
import bmesh
import json
import math
import time
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE=ROOT/'tools/art_pipeline'
REVIEW=ROOT/'art_source/infrastructure_roof_review'
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
entry=next(e for e in entries if e['asset']==ROOF_ASSET)
CIV,ROLE,FOLDER=entry['civilization'],entry['role'],entry['asset']
model_code=(PIPELINE/'infrastructure_building_model_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(model_code).body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('PLURALS','DISPLAY','BRANCHES','DESIGNS') for t in node.targets):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<metadata>','exec'))
OUT=ROOT/'assets/generated'/PLURALS[CIV]/'buildings'/FOLDER
report=json.loads((OUT/(FOLDER+'_report.json')).read_text(encoding='utf-8'))
ASSET_NAME,ASSET_FOLDER=report['name'],FOLDER
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene,NAME,parts,groups,root,camera=st['scene'],st['name'],st['parts'],st['groups'],st['root'],st['camera']
assert not scene.get('infrastructure_roof_review'),FOLDER+' already revised'
bpy.context.window.scene=scene
phase_start=time.monotonic()
def checkpoint(stage):
    (REVIEW/'current_stage.json').write_text(json.dumps({'asset':FOLDER,'stage':stage,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
checkpoint('review_roof_geometry')
CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
for filename,names in (
    ('guardian_hall_hex_v2_model.py',('mesh','box','polygon_prism','hexagon')),
    ('war_stable_hex_v1_model.py',('clip_to_hex','vertical_prism')),
    ('ranger_camp_hex_v1_model.py',('beam',)),
    ('elf_city_level_1_hex_v1_model.py',('leaf',)),
    ('orc_city_level_1_hex_v1_model.py',('tusk',)),
):
    for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in names:
            if node.name=='tusk': node.name='_native_tusk'
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<roof_primitives>','exec'))
def tusk(name,center,height,width,group='08_DETAILS'):
    return _native_tusk(name,center,height,width,width*.68,1,group)
POST={'human':'cutstone','elf':'timber','dwarf':'cutstone','orc':'timber'}[CIV]
TRIM={'human':'gold','elf':'gold','dwarf':'bronze','orc':'iron'}[CIV]
exec((PIPELINE/'infrastructure_primitives.py').read_text(encoding='utf-8'))

# Evaluate only recipe call arguments. Every construction function is a no-op;
# approved halls, walls, mechanisms and furniture are never built again.
specs=[]
def capture_roof(name,x,y,w,d,z,courses=6,hip=False):
    specs.append({'name':name,'x':x,'y':y,'w':w,'d':d,'z':z,'courses':courses,'hip':hip})
def capture_hall(name,x,y,w,d,h,open_front=False,hip=False):
    capture_roof(name,x,y,w+.12,d+.11,.076+h+.02,6,hip)
def noop(*args,**kwargs): return None
mock={'CIV':CIV,'ROLE':ROLE,'Vector':Vector,'hexagon':hexagon,'roof':capture_roof,'hall':capture_hall}
for function_name in ('box','polygon_prism','beam','support','portal','window','barrel','crate','table','bench','book','shelf','crystal','basin','anvil','forge','gear','tree','leaf','tusk','crop_bed','trade_goods'):
    mock[function_name]=noop
exec((PIPELINE/'infrastructure_building_recipes.py').read_text(encoding='utf-8'),mock)
assert specs,'The six-sided Orc university already follows its reference.'
source_before=json.loads((REVIEW/'source_before.json').read_text(encoding='utf-8'))
original=next(r for r in source_before if r['asset']==FOLDER)
assert set(original['roofs'])=={s['name'] for s in specs}
changed=[]
for spec in specs:
    prefix=spec['name']
    selected=[o for o in parts if o['part'].startswith(prefix+'_Tile_Course_') or o['part']==prefix+'_Ridge' or o['part']==prefix+'_Leaf_Finial' or o['part'].startswith(prefix+'_Tusk_')]
    assert len([o for o in selected if '_Tile_Course_' in o['part']])==spec['courses']
    actual_base=min(v.co.z for o in selected if '_Tile_Course_' in o['part'] for v in o.data.vertices)
    assert abs(actual_base-spec['z'])<1e-5,(FOLDER,prefix,actual_base,spec['z'])
    parts=[o for o in parts if o not in selected]
    private_meshes={o.data for o in selected if o.data.users==1}
    bpy.data.batch_remove(ids={*selected,*private_meshes})
    roof(**spec)
    changed.append({'roof':prefix,'shape':'straight_hip' if spec['hip'] else 'straight_gable','courses':spec['courses'],'base_height':spec['z']})
contacts=[]
if CIV=='human' and ROLE=='market':
    beam('Blue_Side_Stall_Cross_Lintel',(.34,-.22,.437),(.65,-.22,.437),.034,'cutstone','06_STRUCTURE')
    contacts=[('Side_Stall_0.36_Shaft','Blue_Side_Stall_Cross_Lintel'),('Side_Stall_0.63_Shaft','Blue_Side_Stall_Cross_Lintel'),('Blue_Side_Stall_Cross_Lintel','Blue_Side_Stall_Tile_Course_0')]
elif CIV=='elf' and ROLE=='market':
    for i,(x,y) in enumerate(((-.36,-.32),(.35,-.35))):
        name='Leaf_Kiosk_'+str(i)+'_Cross_Lintel'
        beam(name,(x-.14,y,.347),(x+.14,y,.347),.030,'timber','06_STRUCTURE')
        contacts.extend([(f'Leaf_Kiosk_{i}_{side}_Shaft',name) for side in (-1,1)])
        contacts.append((name,f'Leaf_Kiosk_{i}_Tile_Course_0'))
elif CIV=='dwarf' and ROLE=='arcane_shrine':
    box('Regulator_Bearing',(.37,-.095,.265),(.070,.070,.13),'iron','04_FOCUS')
    beam('Mana_Regulator_Axle',(.37,-.20,.31),(.37,-.06,.31),.022,'iron','04_FOCUS')
    contacts=[('Mana_Regulator_Wheel','Mana_Regulator_Axle'),('Mana_Regulator_Hub','Mana_Regulator_Axle'),('Mana_Regulator_Axle','Regulator_Bearing'),('Regulator_Bearing','Regulator_Base')]
for obj in parts: obj.parent=root
st['parts']=parts
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.03
scene['infrastructure_roof_review']=1
review_note='Telhados retangulares com beirais retos; coberturas hexagonais preservadas. Apoios revisados por contato. Oficina e universidade élficas com duas águas, conforme os salões anteriores.'
if CIV=='dwarf' and ROLE=='arcane_shrine': review_note+=' Eixo e mancal do regulador presos à base de pedra.'
scene['design_note']=scene['design_note']+' Revisão: '+review_note
st['design_note']=scene['design_note']
GAME_ID=report['gameplay_building_id']
revision={'version':1,'mcp_only':True,'roofs':changed,'support_contacts':contacts,'note':review_note,'before_backup':'art_source/infrastructure_before_roof_review'}
finish=model_code[model_code.index("checkpoint('paint_atlases')"):]
finish=finish.replace("checkpoint('export_glb')","st['report']['infrastructure_roof_review']=revision\ncheckpoint('export_glb')")
exec(finish)
entry.update(result)
(ROOT/'art_source/infrastructure_buildings_review/completed.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
journal=REVIEW/'completed.json'
completed=json.loads(journal.read_text(encoding='utf-8')) if journal.exists() else []
completed.append({'asset':FOLDER,'civilization':CIV,'role':ROLE,'roofs':changed,'added_supports':len(contacts),'seconds':round(time.monotonic()-phase_start,1)})
journal.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
result={'asset':FOLDER,'revised_roofs':len(changed),'triangles':st['report']['triangles'],'seconds':round(time.monotonic()-phase_start,1),'mcp_only':True}
