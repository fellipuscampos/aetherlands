"""Paint, preview, export and save one military landmark through live MCP."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE = Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st = bpy.app.driver_namespace['guardian_hall']
scene, NAME = st['scene'], st['name']
ASSET_NAME, ASSET_FOLDER = NAME, Path(st['out']).name
assert scene.get('grand_military')
paint = (PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')
paint = paint.replace("elif reg == 'glow':", """elif reg == 'faction':
        edge = np.minimum(np.minimum(xx, w-1-xx), np.minimum(yy, h-1-yy))
        shift(edge < 2, -24)
        shift((edge == 2) & ((xx+yy) % 3 == 0), 32)
    elif reg == 'glow':""")
exec(paint)
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene = st['scene']
bpy.context.window.scene = scene
reference = (PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8')
render = reference[reference.index('camera = scene.camera'):reference.index('maximum = max(')]
render = render.replace('((2.6,-4,3.3),2.8)', '((3.2,-4.8,4.1),3.45)')
render = render.replace('((1.8,-2.9,4.9),2.65)', '((2.1,-3.5,6.0),3.20)')
render = render.replace('((-2.6,4,3.4),2.8)', '((-3.2,4.8,4.1),3.45)')
exec(render)
maximum = max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
              for obj in st['parts'] for v in obj.data.vertices for i in range(6))
st['report'].update({'civilization':scene['civilization'], 'military_role':scene['military_role'],
    'grand_military':True, 'asset_only':True, 'integrated_in_game':False,
    'requires_building':scene['requires_building'], 'includes_perimeter_walls':False,
    'hex_tile':{'tile_circumradius':1, 'foundation_circumradius':.92, 'orientation':'pointy-top',
                'max_half_plane_blender':maximum, 'tile_apothem':math.sqrt(3)/2},
    'architecture_key':scene['architecture_key'], 'material_reference':scene['material_reference'],
    'roof_rgb':list(scene['palette_overrides']['roof']),
    'physical_attachment_remaining':list(scene['physical_attachment_remaining'])})
out = Path(st['out'])
if scene.get('military_finish_revision'):
    st['report']['finish_review'] = {
        'revision':int(scene['military_finish_revision']),
        'method':'live Blender MCP; localized closed-mesh repairs',
        'changes':json.loads(scene['military_finish_changes_json']),
        'geometry_checks':json.loads(scene['military_finish_audit_json']),
        'backup':'art_source/grand_military_before_finish_pass'}
(out/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
r = st['report']
readme = '# '+scene['display_name']+'\n\n'+scene['design_note']+'\n\n'
readme += 'Doutrina: `'+scene['military_role']+'`. Grande construção associada a `'+r['trains'][0]+'`; requisito no cadastro: `'+scene['requires_building']+'`.\n\n'
readme += 'Referência militar básica da própria civilização: `'+scene['material_reference']+'`. Planta e volumes avançados próprios, sem copiar a arquitetura entre raças.\n\n'
readme += '- `.blend`: cena isolada, peças editáveis e texturas empacotadas.\n- `.glb`: grupos consolidados, atlas embutidos e nearest, sem rig/animação/câmera/luz.\n- Dois atlas PNG, relatório JSON e quatro prévias.\n\n'
readme += f"{r['editable_parts']} peças, {r['triangles']} triângulos, atlas {r['texture']['size'][0]}².\n\n"
readme += 'Origem central no solo; frente −Y no Blender / +Z no Godot. Base pointy-top raio 0,92 para tile raio 1, escala 1; todas as peças dentro das seis bordas.\n\n'
readme += 'Criado, finalizado e salvo pelo Blender MCP. Integração ao cadastro do jogo permanece pendente.\n'
if scene.get('military_finish_revision'):
    readme += '\nRevisão de acabamento: acessos desobstruídos, mastros fora das coberturas e faces coincidentes corrigidas. Arquitetura e paleta da civilização preservadas. [Revisão](../../../../../docs/GRAND_MILITARY_FINISH_REVIEW.md).\n'
(out/'README.md').write_text(readme,encoding='utf-8')
result.update({'asset':ASSET_FOLDER, 'civilization':scene['civilization'], 'grand_military':True})
