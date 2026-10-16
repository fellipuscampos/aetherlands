"""Repaint, export, render and save the verified native joint repairs through MCP."""
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
repairs=json.loads((REVIEW/'face_repairs.json').read_text(encoding='utf-8'))
repair=next(r for r in repairs if r['asset']==FACE_ASSET)
CIV,ROLE,FOLDER=repair['civilization'],repair['role'],repair['asset']
audit=json.loads((REVIEW/'after_face_repairs.json').read_text(encoding='utf-8'))
assert audit['exposed_overlap_faces']==0,'Finish only after every overlap is repaired.'
code=(PIPELINE/'infrastructure_building_model_mcp.py').read_text(encoding='utf-8')
for node in ast.parse(code).body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('PLURALS','DISPLAY','BRANCHES','DESIGNS') for t in node.targets):
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<metadata>','exec'))
OUT=ROOT/'assets/generated'/PLURALS[CIV]/'buildings'/FOLDER
old_report=json.loads((OUT/(FOLDER+'_report.json')).read_text(encoding='utf-8'))
ASSET_NAME,ASSET_FOLDER=old_report['name'],FOLDER
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene,NAME,parts,groups,root,camera=st['scene'],st['name'],st['parts'],st['groups'],st['root'],st['camera']
bpy.context.window.scene=scene
assert scene['infrastructure_coplanar_review']==1
old_roof_review=old_report.get('infrastructure_roof_review')
if old_roof_review:
    contacts=[]
    for first,second in old_roof_review['support_contacts']:
        if first.endswith('_Shaft') and second.endswith('_Cross_Lintel'):
            capital=first[:-6]+'_Capital'
            contacts.extend([(first,capital),(capital,second)])
        else: contacts.append((first,second))
    old_roof_review['support_contacts']=contacts
face_revision={'version':1,'mcp_only':True,'exposed_coplanar_overlap_faces':0,'repaired_parts':repair['parts'],'method':audit['method'],'before_overlap_faces':repair['exposed_overlap_faces_before']}
scene['design_note']=scene['design_note']+' Junções ajustadas para eliminar faces coplanares expostas.'
st['design_note']=scene['design_note']
phase_start=time.monotonic()
def checkpoint(stage):
    (REVIEW/'current_stage.json').write_text(json.dumps({'asset':FOLDER,'stage':'faces_'+stage,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
GAME_ID=old_report['gameplay_building_id']
finish=code[code.index("checkpoint('paint_atlases')"):]
metadata="st['report']['surface_overlap_review']=face_revision\nif old_roof_review: st['report']['infrastructure_roof_review']=old_roof_review\ncheckpoint('export_glb')"
exec(finish.replace("checkpoint('export_glb')",metadata))
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
entry=next(e for e in entries if e['asset']==FOLDER)
entry.update(result)
(ROOT/'art_source/infrastructure_buildings_review/completed.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
journal=REVIEW/'faces_completed.json'
completed=json.loads(journal.read_text(encoding='utf-8')) if journal.exists() else []
completed.append({'asset':FOLDER,'repaired_parts':len(repair['parts']),'seconds':round(time.monotonic()-phase_start,1)})
journal.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
result={'asset':FOLDER,'repaired_parts':len(repair['parts']),'triangles':st['report']['triangles'],'seconds':round(time.monotonic()-phase_start,1),'mcp_only':True}
