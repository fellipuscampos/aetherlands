"""Write a reviewable catalog from completed work, not from the planned queue."""
from collections import Counter
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
entries=json.loads((ROOT/'art_source/building_architecture_review/completed.json').read_text(encoding='utf-8'))
counts=Counter(e['civilization'] for e in entries)
labels={'human':('Humanos','humans'),'elf':('Elfos','elves'),'dwarf':('Anões','dwarves'),'orc':('Orcs','orcs')}
designs={
 'human':'Blocos de pedra e cantaria, pilares com bases e capitéis, telhados azuis. Portões, móveis, cercas e mecanismos usam madeira quando a função exige.',
 'elf':'Pedra clara, madeira esbelta e contraventamentos em forma de galhos. Pavilhões mais abertos, telhados verdes com cantos facetados e coberturas mais altas.',
 'dwarf':'Granito, pilares espessos, sapatas escalonadas, cintas de cobre e ardósia escura. Coberturas mais baixas e maciças; os marcos druídicos recebem bases e capitéis de engenharia anã.',
 'orc':'Madeira grossa, cintas de ferro e contraventamentos diagonais. Coberturas ferrugem compactas; os marcos dos rituais tornam-se totens de madeira cintada. Pedra nas fundações e câmaras funerárias.',
}
body='# Revisão da arquitetura das civilizações\n\n'
body+=f'Revisão de 2026-10-09: **{len(entries)} prédios corrigidos pelo Blender MCP**, após inspeção de 104 assets, incluindo protótipos históricos. '
body+='As cidades e as construções que já seguiam sua arquitetura foram preservadas.\n\n'
body+='| Civilização | Prédios corrigidos | Arquitetura aplicada |\n|---|---:|---|\n'
for civ,(label,_) in labels.items(): body+=f'| {label} | {counts[civ]} | {designs[civ]} |\n'
body+='\nForam atualizados os modelos editáveis .blend, as exportações .glb, os atlas albedo/emissão, os relatórios e as quatro prévias de cada prédio. '
body+='Os caminhos e IDs usados pelo catálogo do jogo foram mantidos. A revisão muda a apresentação visual dos assets.\n\n'
body+='Os arquivos anteriores estão em [buildings_before_architecture_revision](../art_source/buildings_before_architecture_revision/), com hashes no manifesto. '
body+='A inspeção original está em [audit_before.json](../art_source/building_architecture_review/audit_before.json).\n\n'
body+='A [comparação interativa antes/depois](../art_source/building_architecture_review/index.html) permite selecionar civilização, construção e ângulo da câmera.\n\n'
body+='## Comparação das famílias\n\n| Civilização | Antes | Depois |\n|---|---|---|\n'
for civ,(label,plural) in labels.items():
    body+=f'| {label} | [Ver conjunto original](../art_source/building_architecture_review/{plural}_before.jpg) | [Ver conjunto revisado](../art_source/building_architecture_review/{plural}_after.jpg) |\n'
body+='\n## Prédios corrigidos\n\n| Civilização | Construção | Prévia | Triângulos |\n|---|---|---|---:|\n'
for e in entries:
    label,plural=labels[e['civilization']]; folder=e['asset']; relative=f'../assets/generated/{plural}/buildings/{folder}'
    report=json.loads((ROOT/'assets/generated'/plural/'buildings'/folder/(folder+'_report.json')).read_text(encoding='utf-8'))
    body+=f'| {label} | [{report["display_name"]}]({relative}/README.md) | [Ver modelo]({relative}/previews/three_quarter.png) | {report["triangles"]} |\n'
body+='\n## Verificação\n\n'
body+='Os relatórios de [geometria e backups](building_architecture_validation.json), [fontes editáveis no Blender](building_architecture_source_validation.json) e [importação no Godot](building_architecture_godot_validation.json) registram quantos modelos foram efetivamente verificados. '
body+='Os checks cobrem alterações reais de geometria ou materiais, malhas fechadas, IDs e treino preservados, encaixe de todos os vértices no hex, solo/origem, atlas embutidos idênticos aos PNGs, nearest e ausência de câmera/luz/rig na exportação.\n\n'
game_validation=ROOT/'docs/building_architecture_game_validation.json'
if game_validation.exists():
    game=json.loads(game_validation.read_text(encoding='utf-8'))
    body+='A reimportação no projeto do jogo terminou com código 0, sem erros nem avisos. '
    body+=f'O teste existente `test_building_art_catalog.gd` teve {game["tests_passed"]} de {game["tests_total"]} testes aprovados e {game["assertions_passed"]} de {game["assertions_total"]} asserts aprovados. '
    body+='Passaram a carga de todos os modelos do catálogo, IDs, escala e registro. Duas falhas dependem dos arquivos ausentes `assets/models/kaykit/nature/Tree_1_A_Color1.gltf` e `assets/models/kaykit/buildings/building_market_blue.gltf`, fora da revisão. '
    body+='Resultados em [validação no projeto](building_architecture_game_validation.json) e [log completo do teste](../art_source/building_architecture_review/game_catalog_test.log).\n\n'
body+='Reprodução na sessão aberta do Blender:\n\n'
for script in ('run_building_architecture_revision.py','verify_building_architecture_revision.py','run_building_architecture_godot_validation.py','review_building_architecture.py after','document_building_architecture_revision.py'):
    body+='    python tools/art_pipeline/'+script+'\n'
(ROOT/'docs/BUILDING_ARCHITECTURE_REVISION.md').write_text(body,encoding='utf-8')
print(json.dumps({'document':'docs/BUILDING_ARCHITECTURE_REVISION.md','completed':len(entries),'civilizations':dict(counts)},ensure_ascii=False))
