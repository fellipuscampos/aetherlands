"""Paint, render, validate and save one magic school before the next is built."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st = bpy.app.driver_namespace['guardian_hall']
scene, NAME = st['scene'], st['name']
ASSET_NAME, ASSET_FOLDER = NAME, Path(st['out']).name
# Reuse the exact metric masonry/wood/roof painter; add school emission.
paint_code = (PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')
if scene.get('finish_pass_revision'):
    finish_paint = """elif reg == 'faction':
        edge = np.minimum(np.minimum(xx, w-1-xx), np.minimum(yy, h-1-yy))
        shift(edge < 2, -24)
        shift((edge == 2) & ((xx+yy) % 3 == 0), 32)
        shift((xx % 4 == 0) & (yy % 4 == 0), -6)
    elif reg == 'bone':
        edge = np.minimum(np.minimum(xx, w-1-xx), np.minimum(yy, h-1-yy))
        shift(edge < 1, -18)
        shift((xx >= w*.25) & (xx < w*.45) & (edge > 0), 14)
        shift(((xx*7+yy*13+index) % 47 == 0), -20)
    elif reg == 'glow':"""
    paint_code = paint_code.replace("elif reg == 'glow':",finish_paint)
paint_code = paint_code.replace("elif reg == 'glow':", "elif reg in ('magic', 'fire', 'air', 'water', 'earth'):\n        e[:] = np.asarray(PALETTE[reg]) * (.75 if reg == 'earth' else 1.0)\n    elif reg == 'glow':")
exec(paint_code)
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene = st['scene']
bpy.context.window.scene = scene
camera = scene.camera
out = Path(st['out'])
previews = out/'previews'
previews.mkdir(exist_ok=True)
views = {'three_quarter':((2.6,-4,3.3),2.8), 'game_top':((1.8,-2.9,4.9),2.65),
         'top':((0,0,6),2.25), 'back':((-2.6,4,3.4),2.8)}
cycles_preferences=bpy.context.preferences.addons['cycles'].preferences
previous_compute,previous_device=cycles_preferences.compute_device_type,scene.cycles.device
try:
    # Use available hardware only for these previews; restore user settings before saving.
    try:
        cycles_preferences.compute_device_type='OPTIX'
        cycles_preferences.get_devices()
        if any(d.type=='OPTIX' and d.use for d in cycles_preferences.devices):
            scene.cycles.device='GPU'
    except (TypeError,RuntimeError):
        cycles_preferences.compute_device_type=previous_compute
    for view,(location,scale) in views.items():
        camera.location,camera.data.ortho_scale = location,scale
        target = Vector((0,0,0)) if view=='top' else Vector(scene['preview_target'])
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath = str(previews/(view+'.png'))
        try:
            bpy.ops.render.render(write_still=True)
        except RuntimeError:
            if scene.cycles.device!='GPU':
                raise
            scene.cycles.device='CPU'
            cycles_preferences.compute_device_type=previous_compute
            bpy.ops.render.render(write_still=True)
finally:
    scene.cycles.device=previous_device
    cycles_preferences.compute_device_type=previous_compute
camera.location,camera.data.ortho_scale = views['three_quarter']
camera.rotation_euler = (Vector(scene['preview_target'])-camera.location).to_track_quat('-Z','Y').to_euler()
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in st['parts'] for v in obj.data.vertices for i in range(6))
st['report'].update({'civilization':scene['civilization'],'magic_school':scene['magic_school'],
    'asset_only':True,'integrated_in_game':False,'includes_perimeter_walls':False,
    'hex_tile':{'tile_circumradius':1,'foundation_circumradius':.92,'orientation':'pointy-top',
                'max_half_plane_blender':maximum,'tile_apothem':math.sqrt(3)/2},
    'ritual_building_separate':True,
    'excluded_buildings':list(scene['excludes'])})
if scene.get('finish_pass_revision'):
    st['report']['finish_pass'] = {
        'revision':int(scene['finish_pass_revision']),
        'original_structure_preserved':bool(scene['finish_pass_preserves_structure']),
        'race_details':scene['finish_pass_note'],
        'roof_rgb':list(scene['palette_overrides']['roof']),
        'physical_attachment_remaining':list(scene['finish_pass_attachment_remaining']),
        'relic_source':'skeleton_warrior_v1' if scene['magic_school']=='necromancy' else None}
# Existing exporter re-resolves state from this report.
(out/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
r = st['report']
readme = '# '+scene['display_name']+'\n\n'+scene['design_note']+'\n\n'
readme += 'Escola: `'+scene['magic_school']+'`. Treina `'+r['trains'][0]+'`. Estrutura ritual é um prédio separado.\n\n'
readme += '- `.blend`: cena isolada, peças editáveis e texturas empacotadas.\n- `.glb`: grupos consolidados, atlas embutidos, sem câmera/luz/rig/animação.\n'
readme += '- Atlas albedo e emissão PNG, UVs métricas e filtro nearest.\n- Quatro prévias: três quartos, mapa, topo e traseira.\n- Relatório JSON com validação e medidas.\n\n'
readme += f"{r['editable_parts']} peças, {r['triangles']} triângulos, atlas {r['texture']['size'][0]}².\n\n"
readme += 'Origem central no solo; frente −Y no Blender / +Z no Godot. Base pointy-top raio 0,92 para tile raio 1. Todos os vértices dentro das seis bordas.\n\n'
readme += 'Criado e salvo pelo Blender MCP aberto, usando `magic_school_model.py` e `magic_school_finish.py`. Asset preparado; ainda sem integração no catálogo do jogo.\n'
if scene.get('finish_pass_revision'):
    readme += '\nAcabamento ajustado sobre o modelo existente, com volumes principais preservados. '
    readme += scene['finish_pass_note']+' Telhados uniformes por civilização e adereços físicos com apoios revisados.\n'
    if scene['magic_school']=='necromancy':
        readme += '\nRelíquias usam caveira, mandíbula e costelas do `skeleton_warrior_v1`, com sua pintura original preservada.\n'
(out/'README.md').write_text(readme,encoding='utf-8')
result.update({'asset':ASSET_FOLDER,'civilization':scene['civilization'],'magic_school':scene['magic_school']})
