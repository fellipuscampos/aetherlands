"""Sequential family asset render/export; wrappers set ASSET_NAME/ASSET_FOLDER."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
scene=bpy.data.scenes[ASSET_NAME]
parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
if not parts[0].data.materials:
    # Allows finalizing a saved unpainted source in a fresh live session.
    root=scene.objects[ASSET_NAME+'_ROOT']
    groups={c.name[len(ASSET_NAME)+1:]:c for c in scene.collection.children}
    out=PIPELINE.parent.parent/scene['asset_output_relative']
    bpy.app.driver_namespace['guardian_hall']={'scene':scene,'name':ASSET_NAME,'parts':parts,
        'groups':groups,'root':root,'out':str(out),'density':128,'paint_world_scale':7,
        'camera':scene.camera,'target':Vector(scene['preview_target']),
        'door_clearance':list(scene['door_clearance']),
        'scale_note':scene['scale_note'],'design_note':scene['design_note']}
    exec((PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8'))
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
bpy.context.window.scene=scene
camera,target=st['camera'],st['target']
views={'three_quarter':((2.6,-4,3.3),2.80),'game_top':((1.8,-2.9,4.9),2.65),
       'top':((0,0,6),2.25),'back':((-2.6,4,3.4),2.80)}
out=Path(st['out'])/'previews'; out.mkdir(exist_ok=True)
for name in globals().get('VIEWS',['three_quarter','game_top','top','back']):
    camera.location,camera.data.ortho_scale=views[name]
    aim=Vector((0,0,0)) if name=='top' else target
    camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
camera.location,camera.data.ortho_scale=views['three_quarter']
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
            for obj in st['parts'] for v in obj.data.vertices for i in range(6))
assert maximum<=math.sqrt(3)/2-.030,maximum
source=(PIPELINE.parent.parent/'scripts/data/BuildingDatabase.gd').read_text(encoding='utf-8')
assert ASSET_FOLDER not in source
st['report'].update({'civilization':scene['civilization'],'unit_class':scene['unit_class'],
    'asset_only':True,'integrated_in_game':False,'includes_perimeter_walls':False,
    'layout_source':scene['layout_source'],
    'hex_tile':{'tile_circumradius':1.0,'foundation_circumradius':.92,
        'orientation':'pointy-top','placement_scale':'tile_radius',
        'max_half_plane_blender':maximum,'tile_apothem':math.sqrt(3)/2},
    'faction_tint':'Clan cloth and shield/horse blanket accents isolated in Faction mesh; architecture keeps its civilization palette. No runtime integration.'})
if scene['unit_class']=='cavalry':
    st['report']['horse_props']={'count':2,'static':True,'riders':False,
        'source':'humans/cavalier_v1: horse/saddle only, repacked original coat paint, recolored clan blankets'}
(Path(st['out'])/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
