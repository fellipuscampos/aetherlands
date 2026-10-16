"""Validate every new grand landmark and produce civilization preview catalogs."""
import argparse
import hashlib
import json
from pathlib import Path
from grand_magic_assets import CIVS, RECIPES, ROOFS, folder_name
from verify_magic_school_batch import validate, sheet

ROOT=Path(__file__).resolve().parents[2]

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--civ',choices=tuple(CIVS))
    args=parser.parse_args()
    baseline=json.loads((ROOT/'docs/grand_magic_source_baseline.json').read_text(encoding='utf-8'))
    for row in baseline:
        assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
    assets,sheets=[],{}
    recipes={school:recipe[:3] for school,recipe in RECIPES.items()}
    for civ in ([args.civ] if args.civ else CIVS):
        entries=[]
        for school,(_,_,_,previous) in RECIPES.items():
            entry=validate(civ,school,recipes,'v2_manifestation_')
            folder=ROOT/entry['folder']
            report=json.loads((folder/(folder.name+'_report.json')).read_text(encoding='utf-8'))
            assert report['grand_magic'] and report['requires_building']=='v2_building_'+previous
            assert report['craft']['roof_rgb']==ROOFS[civ]
            assert not report['craft']['physical_attachment_remaining'],(folder.name,report['craft']['physical_attachment_remaining'])
            assert report['craft']['material_reference']=='assets/generated/'+CIVS[civ][0]+'/buildings/'+('' if civ=='human' else civ+'_')+previous+'_hex_v1'
            entry['roof_rgb']=report['craft']['roof_rgb']
            entry['material_reference']=report['craft']['material_reference']
            entries.append(entry)
        assets+=entries
        sheets[civ]={view:sheet(civ,entries,view,'grand_magic','Grandes construções mágicas') for view in ('three_quarter','game_top')}
    if not args.civ:
        godot=json.loads((ROOT/'docs/grand_magic_godot_validation.json').read_text(encoding='utf-8'))
        assert godot['status']=='PASS' and godot['verified']==24
        doc='# Grandes construções mágicas — modelos 3D\n\n'
        doc+='24 modelos criados pelo Blender MCP, um de cada vez, na ordem humanos, orcs, anões e elfos. Cada construção foi texturizada, conferida e salva antes de iniciar a seguinte.\n\n'
        doc+='Materiais e cores copiados das escolas revisadas da mesma civilização. Base de um tile pointy-top de raio 1, origem no solo e acabamento dos adereços físicos conferido. As manifestações associadas correspondem ao cadastro atual do jogo; a integração dos modelos permanece pendente.\n\n'
        doc+='Arquiteturas: catedral cruciforme de duas torres, círculo profano aberto, mausoléu com obelisco e efígies de esqueletos, bosque de árvore ancestral, torre de três corpos recuados e nexus de quatro torres elementais.\n\n'
        for civ,(_,label) in CIVS.items():
            doc+='## '+label+'\n\n[Visão geral](../'+sheets[civ]['three_quarter']+') · [Visão de mapa](../'+sheets[civ]['game_top']+')\n\n'
            doc+='| Construção | Arquivos e quatro prévias | Triângulos |\n|---|---|---:|\n'
            for entry in assets:
                if entry['civilization']==civ:
                    doc+='| '+entry['label']+' | [Abrir](../'+entry['folder']+'/README.md) | '+str(entry['triangles'])+' |\n'
            doc+='\n'
        doc+='Cada pasta contém `.blend` isolado e editável, `.glb` consolidado, atlas albedo/emissão, relatório JSON, README e quatro prévias. Caveiras e efígies reutilizam a geometria e a pintura do `skeleton_warrior_v1` aprovado.\n\n'
        doc+='Verificados: UVs, texturas embutidas, filtro nearest, malhas fechadas, origem no solo, as seis bordas do hexágono e importação dos 24 GLBs no Godot. A conferência dos apoios usa conectividade de caixas das peças e revisão visual; três núcleos mágicos levitam por intenção de design.\n\n'
        doc+=f'Preservados por comparação de hashes: {len(baseline)} arquivos das escolas anteriores e do código de gameplay.\n\n'
        doc+='[Relatório dos assets](grand_magic_validation.json) · [Importação no Godot](grand_magic_godot_validation.json).\n\n'
        doc+='Produção: `tools/art_pipeline/grand_magic_model.py`, `grand_magic_finish.py` e `run_grand_magic_batch.py`.\n'
        (ROOT/'docs/GRAND_MAGIC_CATALOG.md').write_text(doc,encoding='utf-8')
        (ROOT/'docs/grand_magic_validation.json').write_text(json.dumps({'verified':24,'preserved_source_files':len(baseline),'assets':assets,'sheets':sheets},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'verified':len(assets),'preserved_source_files':len(baseline),'sheets':sheets},ensure_ascii=True,indent=2))
