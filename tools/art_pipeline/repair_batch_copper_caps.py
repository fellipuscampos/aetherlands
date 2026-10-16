"""Seat dwarven copper finials on sockets and finish the crane cap, live MCP only."""
import contextlib
import io
from pathlib import Path
from blender_mcp_client import execute
from run_civilization_training_batch import write_readme

PIPELINE=Path(__file__).resolve().parent
for stem in ('ranger_camp','war_stable','rogue_guild','siege_arsenal'):
    folder='dwarf_'+stem+'_hex_v1'
    name='Dwarf_'+stem.title()+'_Hex_V1'
    source_name='Orc_'+stem.title()+'_Hex_V1'
    code=f'''
import bpy
import bmesh
import ast
import math
from mathutils import Vector
from pathlib import Path
ASSET_NAME,ASSET_FOLDER={name!r},{folder!r}
PIPELINE=Path({str(PIPELINE)!r})
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
source=bpy.data.scenes.get({source_name!r})
if source is None:
    source_file=PIPELINE.parent.parent/'assets/generated/orcs/buildings'/('orc_{stem}_hex_v1')/('orc_{stem}_hex_v1.blend')
    with bpy.data.libraries.load(str(source_file),link=False) as (available,loaded):
        loaded.scenes=[{source_name!r}]
    source=loaded.scenes[0]
original={{o.get('part'):o for o in source.objects if o.type=='MESH'}}
if {stem!r}=='siege_arsenal':
    NAME=ASSET_NAME
    groups,parts=st['groups'],st['parts']
    CUBE=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
    for node in ast.parse((PIPELINE/'guardian_hall_hex_v2_model.py').read_text(encoding='utf-8')).body:
        if isinstance(node,ast.FunctionDef) and node.name in ('mesh','box'):
            exec(compile(ast.Module(body=[node],type_ignores=[]),'<cap_primitives>','exec'))
    for obj in list(parts):
        if obj['part']!='Crane_Clan_Horn' or obj.get('region')!='bone': continue
        lo=Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
        hi=Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
        center,size=(lo+hi)/2,hi-lo
        height=min(.090,max(.030,size.z*.60)); center.z=lo.z+height/2
        group=next(label for label,col in groups.items() if col in obj.users_collection)
        old_data=obj.data; parts.remove(obj); bpy.data.objects.remove(obj,do_unlink=True)
        if old_data.users==0: bpy.data.meshes.remove(old_data)
        box('Copper_Runestone_Crane_Clan_Horn',tuple(center),
            (max(.020,min(.061,size.x)),max(.018,min(.055,size.y)),height),'bronze',group)
        box('Runestone_Inset_Crane_Clan_Horn',(center.x,center.y-.031,center.z),
            (.013,.010,height*.61),'iron',group)
    for obj in parts: obj.parent=st['root']
changed=0
for obj in st['parts']:
    label=obj['part']
    if not label.startswith('Copper_Runestone_'): continue
    source_label=label[len('Copper_Runestone_'):]
    previous=original[source_label]
    desired=min(v.co.z for v in previous.data.vertices)
    delta=desired-min(v.co.z for v in obj.data.vertices)
    if abs(delta)<.00001: continue
    for target in st['parts']:
        if target['part'] in (label,'Runestone_Inset_'+source_label):
            for vertex in target.data.vertices: vertex.co.z+=delta
            target.data.update()
    changed+=1
scene=st['scene']
scene['copper_caps_seated']=True
exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'civilization_training_batch_finish.py').read_text(encoding='utf-8'))
'''
    print('SEAT_CAPS '+folder,flush=True)
    with contextlib.redirect_stdout(io.StringIO()):
        reply=execute(code)
    write_readme(folder,'dwarf')
    print({'DONE':folder,'export':reply.get('result')},flush=True)
