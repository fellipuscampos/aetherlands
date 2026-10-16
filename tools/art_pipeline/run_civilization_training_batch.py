"""Run the ten authorized assets strictly in order via the open Blender MCP."""
import argparse
import contextlib
import io
import json
from pathlib import Path
from blender_mcp_client import execute

PIPELINE=Path(__file__).resolve().parent
PROJECT=PIPELINE.parent.parent
QUEUE=[('dwarf',r) for r in ('ranged','cavalry','rogue','siege')]+[
    ('elf',r) for r in ('tank','warrior','ranged','cavalry','rogue','siege')]
STEMS={'tank':'guardian_hall','warrior':'warrior_hall','ranged':'ranger_camp',
       'cavalry':'war_stable','rogue':'rogue_guild','siege':'siege_arsenal'}

def asset_names(civ,role):
    stem=STEMS[role]
    return civ+'_'+stem+'_hex_v1',civ.title()+'_'+stem.title()+'_Hex_V1'

def write_wrappers():
    for civ,role in QUEUE:
        folder,name=asset_names(civ,role)
        for suffix,code in (
            ('model',f"BATCH_CIV,BATCH_ROLE={civ!r},{role!r}\n"),
            ('finish',f"ASSET_NAME,ASSET_FOLDER={name!r},{folder!r}\n")):
            shared='civilization_training_batch_'+suffix+'.py'
            body='from pathlib import Path\n'+code+f"exec((Path(__file__).resolve().parent/{shared!r}).read_text(encoding='utf-8'))\n"
            # MCP execution does not supply __file__; wrappers use the fixed project pipeline.
            body=body.replace('Path(__file__).resolve().parent',repr(str(PIPELINE)).join(['Path(',')']))
            p=PIPELINE/(folder+'_'+suffix+'.py')
            if not p.exists():
                p.write_text(body,encoding='utf-8')

def call(script):
    # Capture the socket client's JSON/log output; return compact progress only.
    with contextlib.redirect_stdout(io.StringIO()):
        response=execute(script.read_text(encoding='utf-8'))
    return response.get('result',{})

def write_readme(folder,civ):
    out=PROJECT/'assets/generated'/('dwarves' if civ=='dwarf' else 'elves')/'buildings'/folder
    report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    dims=report['dimensions_m']; texture=report['texture']['size'][0]
    body=f"# {report['display_name']}\n\n"
    body+='**Somente asset: sem integração no jogo.** Nenhuma regra, catálogo ou seleção de modelos foi alterada.\n\n'
    body+='Visual adaptado para esta civilização sobre o layout de treino validado de `'+report['layout_source']+'`. A fonte anterior permanece intacta.\n\n'
    body+='Descrição de produção: '+report['design']+'\n\n'
    body+='Linha comum (metadados): '+', '.join('`'+x+'`' for x in report['trains'])+'.\n'
    body+='Supremo excluído, com prédio separado: '+', '.join('`'+x+'`' for x in report['excludes'])+'.\n\n'
    body+=f"- `{folder}.blend`: {report['editable_parts']} peças editáveis, atlas empacotados, cena isolada.\n"
    body+=f"- `{folder}.glb`: {report['triangles']} triângulos, {report['export']['meshes']} malhas, 1 material, atlas embutidos.\n"
    body+=f"- Atlas albedo/emissão: {texture}², nearest. Sem rig, animação, câmera ou luz no GLB.\n"
    body+='- `previews/`: três quartos, visão alta do mapa, topo e traseira.\n- Relatório JSON com medidas, treino e verificações.\n\n'
    body+=f"Base militar hexadecimal pointy-top de raio 0,92, tile de raio 1. Dimensões: {dims[0]:.4f} × {dims[1]:.4f} × {dims[2]:.4f}. Origem central Z=0; frente −Y no Blender / +Z no glTF. Escala futura uniforme pelo raio do tile. Todos os vértices conferidos nas seis bordas. Sem anel de muralhas.\n\n"
    if report['unit_class']=='cavalry':
        body+='Dois cavalos são adereços estáticos genéricos da fonte humana `cavalier_v1`, sem cavaleiro/rig. Pelagem original repintada no atlas e mantas na cor do clã. Não definem o modelo futuro da unidade desta civilização.\n\n'
    body+='Geração via Blender MCP aberto:\n\n```powershell\n'
    body+=f"python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/{folder}_model.py\npython tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/{folder}_finish.py\n```\n"
    (out/'README.md').write_text(body,encoding='utf-8')

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--wrappers-only',action='store_true'); args=parser.parse_args()
    write_wrappers()
    if not args.wrappers_only:
        for i,(civ,role) in enumerate(QUEUE):
            if i<args.start: continue
            folder,name=asset_names(civ,role)
            print(f'BUILD {i+1}/10 {folder}',flush=True)
            built=call(PIPELINE/(folder+'_model.py'))
            print(json.dumps({'built':built}),flush=True)
            exported=call(PIPELINE/(folder+'_finish.py'))
            write_readme(folder,civ)
            print(json.dumps({'DONE':folder,'export':exported}),flush=True)
        print('ALL_TEN_ASSETS_EXPORTED',flush=True)
