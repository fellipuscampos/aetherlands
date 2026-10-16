"""Finish early pennants and mechanical supports, via Blender MCP."""
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
REVIEW=ROOT/'art_source/infrastructure_buildings_review'
progress=REVIEW/'completed.json'
entries=json.loads(progress.read_text(encoding='utf-8'))
code=(PIPELINE/'infrastructure_building_model_mcp.py').read_text(encoding='utf-8')
# Load only the metadata dictionaries from the builder; never run its geometry setup.
namespace={}
for node in ast.parse(code).body:
    if isinstance(node,ast.Assign) and any(isinstance(target,ast.Name) and target.id in ('PLURALS','DISPLAY','BRANCHES','DESIGNS') for target in node.targets):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<metadata>','exec'),namespace)
globals().update(namespace)
refined=[]
for entry in entries:
    if entry['role'] not in ('market','farm','workshop','university','arcane_shrine'): continue
    CIV,ROLE=entry['civilization'],entry['role']
    FOLDER=entry['asset']; OUT=ROOT/'assets/generated'/PLURALS[CIV]/'buildings'/FOLDER
    report=json.loads((OUT/(FOLDER+'_report.json')).read_text(encoding='utf-8'))
    NAME=report['name']; scene=bpy.data.scenes[NAME]
    current_parts={o.get('part') for o in scene.objects if o.type=='MESH'}
    markers={('human','workshop'):'Finished_Wheel_Rack_Foot',('dwarf','farm'):'Pump_Axle',('dwarf','workshop'):'Press_Gear_Axle'}
    needs_support=(CIV,ROLE) in markers and markers[(CIV,ROLE)] not in current_parts
    lodge=next((o for o in scene.objects if o.get('part')=='Teaching_Lodge_Walls'),None)
    rotate_lodge=lodge is not None and min(v.co.y for v in lodge.data.vertices)<-.06
    teaching_gear=next((o for o in scene.objects if o.get('part')=='Teaching_Gear_Wheel'),None)
    lower_teaching_gear=teaching_gear is not None and min(v.co.z for v in teaching_gear.data.vertices)>.32
    crystal_parts=[o for o in scene.objects if o.get('region')=='mana']
    roofs=[o for o in scene.objects if o.get('region')=='roof']
    needs_clearance=ROLE=='arcane_shrine' and max(v.co.z for o in crystal_parts for v in o.data.vertices)>min(v.co.z for o in roofs for v in o.data.vertices)-.020
    foot=next(o for o in scene.objects if o.get('part')=='Owner_Pole_Foot')
    center=sum((v.co for v in foot.data.vertices),Vector())/len(foot.data.vertices)
    move_flag=ROLE=='market' and abs(center.y+.45)>1e-6
    if not move_flag and not needs_support and not rotate_lodge and not lower_teaching_gear and not needs_clearance: continue
    phase_start=time.monotonic()
    def checkpoint(stage):
        (REVIEW/'current_stage.json').write_text(json.dumps({'asset':FOLDER,'stage':stage,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
    ASSET_NAME,ASSET_FOLDER=NAME,FOLDER
    exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
    scene,parts,groups,root,camera=st['scene'],st['parts'],st['groups'],st['root'],st['camera']
    CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
    POST={'human':'cutstone','elf':'timber','dwarf':'cutstone','orc':'timber'}[CIV]
    TRIM={'human':'gold','elf':'gold','dwarf':'bronze','orc':'iron'}[CIV]
    for filename,names in (('guardian_hall_hex_v2_model.py',('mesh','box')),('ranger_camp_hex_v1_model.py',('beam',))):
        for node in ast.parse((PIPELINE/filename).read_text(encoding='utf-8')).body:
            if isinstance(node,ast.FunctionDef) and node.name in names:
                exec(compile(ast.Module(body=[node],type_ignores=[]),'<support_primitives>','exec'))
    exec((PIPELINE/'infrastructure_primitives.py').read_text(encoding='utf-8'))
    offset=Vector((.55-center.x,-.45-center.y,0))
    for obj in parts:
        if move_flag and obj['part'].startswith('Owner_'):
            for vertex in obj.data.vertices: vertex.co+=offset
            obj.data.update()
        if rotate_lodge and obj['part'].startswith(('Teaching_Lodge_','Lodge_Post_','Lodge_Rust_Roof_')):
            for vertex in obj.data.vertices:
                x,y=vertex.co.x,vertex.co.y-.27
                vertex.co.x=x*math.cos(math.pi/6)-y*math.sin(math.pi/6)
                vertex.co.y=.27+x*math.sin(math.pi/6)+y*math.cos(math.pi/6)
            obj.data.update()
        if rotate_lodge and obj['part'].startswith('Lodge_Tusk_'):
            for vertex in obj.data.vertices: vertex.co.y+=.10
            obj.data.update()
        if lower_teaching_gear and obj['part'].startswith('Teaching_Gear_'):
            for vertex in obj.data.vertices: vertex.co.z-=.010
            obj.data.update()
        if needs_clearance:
            part=obj['part']
            if CIV=='human' and part=='Mana_Pedestal':
                for vertex in obj.data.vertices: vertex.co.z=.08+(vertex.co.z-.08)*(.30/.38)
                obj.data.update()
            if CIV=='human' and part=='Chapel_Crystal':
                for vertex in obj.data.vertices: vertex.co.z=.39+(vertex.co.z-.48)*(.20/.35)
                obj.data.update()
            if CIV=='dwarf' and part.startswith('Granite_Mana_Engine_'):
                if any(token in part for token in ('Tile_Course','Ridge','Lintel','Capital')):
                    for vertex in obj.data.vertices: vertex.co.z+=.13
                elif any(token in part for token in ('Rear_Wall','Shaft','Collar')):
                    for vertex in obj.data.vertices: vertex.co.z=.076+(vertex.co.z-.076)*(.56/.43)
                obj.data.update()
            if CIV=='orc' and part=='Shamans_Crystal':
                for vertex in obj.data.vertices: vertex.co.z=.31+(vertex.co.z-.31)*(.26/.29)
                obj.data.update()
    if needs_support:
        if (CIV,ROLE)==('human','workshop'):
            box('Finished_Wheel_Rack_Foot',(.47,.235,.091),(.17,.12,.030),'timber','08_DETAILS')
            box('Finished_Wheel_Rack_Post',(.47,.235,.173),(.043,.065,.194),'timber','08_DETAILS')
            beam('Finished_Wheel_Axle',(.47,.18,.28),(.47,.28,.28),.026,'iron','08_DETAILS')
        elif (CIV,ROLE)==('dwarf','farm'):
            beam('Pump_Axle',(.48,-.082,.31),(.48,.046,.31),.023,'iron','04_FOCUS')
        elif (CIV,ROLE)==('dwarf','workshop'):
            support('Press_Gear_Bearing',.53,-.185,.076,.46,.055)
            beam('Press_Gear_Axle',(.53,-.29,.42),(.53,-.16,.42),.030,'iron','04_FOCUS')
        for obj in parts: obj.parent=root
    maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
    GAME_ID=report['gameplay_building_id']
    exec(code[code.index("checkpoint('paint_atlases')"):])
    entry.update(result)
    progress.write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
    refined.append(FOLDER)
result={'refined_assets':refined,'mcp_only':True}
