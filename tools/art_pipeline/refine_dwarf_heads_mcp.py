"""Repaint earlier MCP assets after the rear-head hair correction. Geometry is frozen."""
import json
from blender_mcp_client import execute
from dwarf_troop_assets import ASSETS,ROOT,OUT

source=str(ROOT/'tools/art_pipeline/build_dwarf_troops.py')
for row in ASSETS:
    if row['family']=='siege': continue
    report=OUT/row['stem']/(row['stem']+'_report.json')
    revision=json.loads(report.read_text(encoding='utf-8'))['atlas'].get('paint_revision',0)
    needs_armor=row['family']=='rogue' and row['tier']>=2 and revision<4
    if revision>=3 and not needs_armor: continue
    code=f'''import bpy, importlib, sys, json
from pathlib import Path
from mathutils import Vector
source=Path({source!r})
sys.path.insert(0,str(source.parent))
import dwarf_troop_paint
importlib.reload(dwarf_troop_paint)
ns={{'__file__':str(source),'__name__':'dwarf_live_factory'}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
row={row!r}
scene=bpy.data.scenes[row['stem']+'_MCP_Static_V2']
folder=ns['OUT']/row['stem']
report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
parts=[o for o in scene.objects if o.type=='MESH' and o.get('surface') and not o.get('part','').startswith('STUDIO')]
ns.update(SCENE=scene,PARTS=parts,BODY={{o['shared_anatomy']:o for o in parts if o.get('shared_anatomy')}},ROW=row,
          ROOT_OBJ=next(o for o in scene.objects if o.get('asset_stage')=='static_model_review'))
assert ns['anatomy_hashes']()==report['anatomy']
bpy.context.window.scene=scene
with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
    for obj in parts:
        obj.data.materials.clear()
        for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    atlas=ns['pack_and_paint'](folder,row['stem'])
    report['atlas']=atlas
    report['export']=ns['export'](folder,row['stem'],atlas)
    center=(Vector(report['geometry']['bounds_min'])+Vector(report['geometry']['bounds_max']))/2
    views={{'back':(-6,12,5)}}
    if {needs_armor!r}: views.update(three_quarter=(6,-12,5.6),front=(0,-12,1.2),game_top=(5,-7,11))
    for view,offset in views.items():
        scene.camera.location=center+Vector(offset)
        scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(folder/'previews'/(view+'.png'))
        bpy.ops.render.render(write_still=True,scene=scene.name)
    scene.camera.location=center+Vector((6,-12,5.6))
    scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.data.libraries.write(str(folder/(row['stem']+'.blend')),{{scene}},path_remap='RELATIVE',fake_user=True,compress=True)
    (folder/(row['stem']+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
result={{'repainted':row['stem'],'anatomy_unchanged':True,'back_hair':'corrected','mcp':'live'}}
'''
    execute(code)
    print('DWARF_HEAD_REFINED '+row['stem'],flush=True)
