"""Paint, inspect, render and save one grand landmark before starting the next."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

PIPELINE=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline')
st=bpy.app.driver_namespace['guardian_hall']
scene,NAME=st['scene'],st['name']
ASSET_NAME,ASSET_FOLDER=NAME,Path(st['out']).name
assert scene.get('grand_magic')
paint_code=(PIPELINE/'guardian_hall_paint_save.py').read_text(encoding='utf-8')
paint_code=paint_code.replace("('stone', 'cutstone', 'foundation', 'paving')", "('stone', 'cutstone', 'foundation', 'paving', 'tombstone')")
paint_code=paint_code.replace("elif reg == 'glow':", """elif reg == 'faction':
        edge = np.minimum(np.minimum(xx, w-1-xx), np.minimum(yy, h-1-yy))
        shift(edge < 2, -24)
        shift((edge == 2) & ((xx+yy) % 3 == 0), 32)
        shift((xx % 4 == 0) & (yy % 4 == 0), -6)
    elif reg in ('magic', 'school', 'fire', 'air', 'water', 'earth'):
        e[:] = np.asarray(PALETTE[reg]) * (.60 if reg in ('earth','school') else 1.0)
    elif reg == 'glow':""")
exec(paint_code)
exec((PIPELINE/'guardian_hall_state.py').read_text(encoding='utf-8'))
scene=st['scene']
bpy.context.window.scene=scene
# Share the established preview lighting and safe temporary GPU rendering.
finish_reference=(PIPELINE/'magic_school_finish.py').read_text(encoding='utf-8')
render_code=finish_reference[finish_reference.index('camera = scene.camera'):finish_reference.index('maximum = max(')]
render_code=render_code.replace("((2.6,-4,3.3),2.8)","((3.2,-4.8,4.1),3.50)")
render_code=render_code.replace("((1.8,-2.9,4.9),2.65)","((2.1,-3.5,6.0),3.25)")
render_code=render_code.replace("((-2.6,4,3.4),2.8)","((-3.2,4.8,4.1),3.50)")
exec(render_code)
maximum=max(v.co.x*math.cos(math.radians(i*60))+v.co.y*math.sin(math.radians(i*60))
            for obj in st['parts'] for v in obj.data.vertices for i in range(6))
st['report'].update({'civilization':scene['civilization'],'magic_school':scene['magic_school'],
    'grand_magic':True,'asset_only':True,'integrated_in_game':False,'requires_building':scene['requires_building'],
    'includes_perimeter_walls':False,'school_building_separate':True,
    'hex_tile':{'tile_circumradius':1,'foundation_circumradius':.92,'orientation':'pointy-top',
        'max_half_plane_blender':maximum,'tile_apothem':math.sqrt(3)/2},
    'craft':{'race_details':scene['race_details'],'material_reference':scene['material_reference'],
        'roof_rgb':list(scene['palette_overrides']['roof']),
        'physical_attachment_remaining':list(scene['physical_attachment_remaining']),
        'intentional_levitation':list(scene['intentional_levitation']),
        'relic_source':'skeleton_warrior_v1' if scene['magic_school']=='necromancy' else None}})
out=Path(st['out'])
(out/(ASSET_FOLDER+'_report.json')).write_text(json.dumps(st['report'],ensure_ascii=False,indent=2),encoding='utf-8')
exec((PIPELINE/'guardian_hall_export.py').read_text(encoding='utf-8'))
r=st['report']
readme='# '+scene['display_name']+'\n\n'+scene['design_note']+'\n\n'
readme+='Grande construção ritual da escola `'+scene['magic_school']+'`; manifestação associada: `'+r['trains'][0]+'`. Requisito no cadastro: `'+scene['requires_building']+'`.\n\n'
readme+='Materiais e cores copiados da escola revisada da mesma civilização: `'+scene['material_reference']+'`.\n\n'
readme+='- `.blend`: cena isolada, peças editáveis e texturas empacotadas.\n- `.glb`: grupos consolidados, atlas embutidos e filtro nearest; sem rig, animação, câmera ou luz.\n- Atlas albedo/emissão PNG, relatório JSON e quatro prévias.\n\n'
readme+=f"{r['editable_parts']} peças, {r['triangles']} triângulos, atlas {r['texture']['size'][0]}².\n\n"
readme+='Origem central no solo. Frente −Y no Blender / +Z no Godot. Base hexagonal pointy-top raio 0,92 para tile raio 1, sem escala adicional; todos os vértices dentro das seis bordas.\n\n'
readme+='Criado, finalizado e salvo pelo Blender MCP, usando `grand_magic_model.py` e `grand_magic_finish.py`. Modelo preparado; integração no cadastro do jogo permanece pendente.\n'
(out/'README.md').write_text(readme,encoding='utf-8')
result.update({'asset':ASSET_FOLDER,'civilization':scene['civilization'],'grand_magic':True})
