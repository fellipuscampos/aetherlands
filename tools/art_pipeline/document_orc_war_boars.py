"""Update the cavalry catalog without replacing earlier approved revisions."""
import json
from orc_troop_assets import ROOT,OUT

manifest=OUT/'orc_troops_manifest.json'
rows=json.loads(manifest.read_text(encoding='utf-8'))
for row in rows:
    if row['family']=='cavalry':row['mount_species']='war_boar'
manifest.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
path=ROOT/'docs/ORC_TROOPS_CATALOG.md';text=path.read_text(encoding='utf-8')
paragraph='''A revisão `war_boar_v1` substitui os quatro cavalos da cavalaria por javalis de guerra. Corpo largo e facetado, pescoço curto, cabeça baixa, focinho com narinas, duas presas curvas, cerdas no dorso, cauda curta e cascos fendidos diferenciam a montaria. Os javalis das duas evoluções pesadas levam reforços de osso. Cavaleiros, alturas, roupas, armas, sela, estribos e os segmentos das rédeas junto às mãos foram preservados. Somente a ponta das rédeas junto ao animal foi reposicionada. Os 12 ossos existentes do quadrúpede e todas as 16 animações montadas foram reaproveitados sem alterar curvas ou criar novos clips; os nomes internos `horse_*` foram mantidos por compatibilidade. Os outros 16 orcs e as fontes das demais raças permanecem intactos.

'''
if 'A revisão `war_boar_v1`' not in text:
    text=text.replace('- [Galeria das 20 tropas]',paragraph+'- [Galeria das 20 tropas]',1)
    text=text.replace('- [Detalhes dos capacetes','- [Javalis de guerra e cavaleiros](previews/orc_troops/war_boars_three_quarter.jpg), [detalhes das montarias](previews/orc_troops/war_boars_mount_closeup.jpg).\n- [Detalhes dos capacetes',1)
    text=text.replace('Verificação:\n','Verificação:\n- `orc_war_boars_validation.json`: quatro montarias novas; cavaleiros, armas, sela, estribos, materiais protegidos, esqueleto e 16 clips preservados, contatos de rédeas e pernas avaliados em todos os frames; outros 16 orcs e 475 arquivos das demais raças intactos.\n',1)
    text+='\nPara reaplicar os javalis pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_orc_war_boars_mcp.py --timeout 1200`. A fonte aprovada com os cavalos está em `art_source/orc_troops/war_boars/before_assets/`.\n'
path.write_text(text,encoding='utf-8')
