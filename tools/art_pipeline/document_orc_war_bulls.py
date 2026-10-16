"""Publish the current cavalry mount description, retaining earlier artifacts."""
import json,re
from orc_troop_assets import ROOT,OUT

manifest=OUT/'orc_troops_manifest.json';rows=json.loads(manifest.read_text(encoding='utf-8'))
for row in rows:
    if row['family']=='cavalry':row['mount_species']='war_bull'
manifest.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
path=ROOT/'docs/ORC_TROOPS_CATALOG.md';text=path.read_text(encoding='utf-8')
paragraph='''A revisão `war_bull_v2` substitui as quatro montarias da cavalaria por touros de guerra inspirados na referência fornecida: corpo compacto, peito volumoso com pelagem mais escura, cabeça alongada e inclinada, focinho escuro, olhos pequenos nas laterais, chifres curtos voltados para cima, cauda com tufo e cascos divididos em duas peças. Os painéis de couro ocre acompanham a sela. A pelagem usa marrom avermelhado escuro e castanho quase negro; as duas evoluções pesadas têm reforços de osso ajustados à testa e aos flancos. Cavaleiros, alturas, roupas, armas, sela, estribos e os segmentos das rédeas junto às mãos foram preservados. Somente a ponta das rédeas junto ao animal foi reposicionada. Os 12 ossos existentes do quadrúpede e todas as 16 animações montadas foram reaproveitados sem alterar curvas ou criar clips; os nomes internos `horse_*` permanecem por compatibilidade. Os outros 16 orcs e as fontes das demais raças continuam intactos.

'''
if 'A revisão `war_bull_v2`' not in text:
    text=re.sub(r'A revisão `war_(?:boar_v1|bull_v1)`.*?\n\n',lambda _:paragraph,text,count=1,flags=re.S)
    text=text.replace('- [Javalis de guerra e cavaleiros](previews/orc_troops/war_boars_three_quarter.jpg), [detalhes das montarias](previews/orc_troops/war_boars_mount_closeup.jpg).',
        '- [Touros de guerra e cavaleiros](previews/orc_troops/war_bulls_three_quarter.jpg), [detalhes das montarias](previews/orc_troops/war_bulls_mount_closeup.jpg).')
    text=re.sub(r'- `orc_war_boars_validation.json`:.*?\n',
        '- `orc_war_bulls_validation.json`: quatro touros; cavaleiros, armas, sela, estribos, materiais protegidos, esqueleto e 16 clips intactos; contatos de rédeas e pernas e separação dos chifres em relação a mãos e cabeça verificados em todos os frames; outros 16 orcs e 475 arquivos das demais raças preservados.\n',text,count=1)
    text=re.sub(r'Para reaplicar os javalis.*?\n',
        'Para reaplicar os touros pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_orc_war_bulls_mcp.py --timeout 1200`. A fonte congelada antes dos touros está em `art_source/orc_troops/war_bulls/before_assets/`.\n',text,count=1)
path.write_text(text,encoding='utf-8')
