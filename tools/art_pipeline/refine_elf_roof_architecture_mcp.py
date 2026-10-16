"""Remove inherited tribal roof straps from the first three elven revisions."""
import bpy
import json
import math
import time
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
PIPELINE=ROOT/'tools/art_pipeline'
ARCH_FOLDER=TOUCHUP_FOLDER
files=list((ROOT/'assets/generated/elves/buildings'/ARCH_FOLDER).glob(ARCH_FOLDER+'_report.json'))
assert len(files)==1
OUT=files[0].parent
old_report=json.loads(files[0].read_text(encoding='utf-8'))
ASSET_NAME,ASSET_FOLDER=old_report['name'],ARCH_FOLDER
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene,NAME,parts,groups,root=st['scene'],st['name'],st['parts'],st['groups'],st['root']
assert scene.get('architecture_revision')==1
bpy.context.window.scene=scene
CIV='elf'
notes={CIV:scene['architecture_design']}
changes=list(old_report['architecture_revision']['geometry_changes'])
connections=list(old_report['architecture_revision']['roof_braces'])
candidates=[o for o in groups['03_ROOFS'].objects if o.get('part') and 'Iron' in o['part'] and any(t in o['part'] for t in ('Binding','Edge'))]
assert candidates, 'Already refined'
changes.extend('remove_inherited_roof_lashing:'+o['part'] for o in candidates)
parts=[o for o in parts if o not in candidates]
private_meshes={o.data for o in candidates if o.data.users==1}
bpy.data.batch_remove(ids={*candidates,*private_meshes})
st['parts']=parts
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60)) for o in parts for v in o.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.03
phase_start=time.monotonic()
def checkpoint(phase):
    (ROOT/'art_source/building_architecture_review/current_stage.json').write_text(json.dumps({'asset':ARCH_FOLDER,'stage':phase,'elapsed':round(time.monotonic()-phase_start,1)}),encoding='utf-8')
code=(PIPELINE/'rebuild_building_architecture_mcp.py').read_text(encoding='utf-8')
exec(code[code.index('# Preserve all report metadata'):])
progress=ROOT/'art_source/building_architecture_review/completed.json'
completed=json.loads(progress.read_text(encoding='utf-8'))
for item in completed:
    if item['asset']==ARCH_FOLDER:
        item.update({'changed_parts':len(changes),'triangles':st['report']['triangles'],'roof_lashings_removed':len(candidates)})
progress.write_text(json.dumps(completed,ensure_ascii=False,indent=2),encoding='utf-8')
