"""Record the last narrowly scoped asset pass in the current catalog."""
import json
from orc_troop_assets import ROOT,OUT,ASSETS
path=ROOT/'docs/ORC_TROOPS_CATALOG.md';text=path.read_text(encoding='utf-8')
text=text.replace('chifres laterais em 3D abaixo da altura da cabeça','chifres grandes em 3D nas têmporas dianteiras, curvados para a frente e para cima')
paragraph='A revisão `forward_horns_and_painted_hoods_v1` aumenta e traz para a frente os chifres dos quatro capacetes de osso, preservando o corpo e as alturas anatômicas de 2 m / 2,20 m; os chifres são acessórios acima dessa altura. Os escudos de braço e seus reforços foram removidos do Cavaleiro Couraçado e do Campeão da Cavalaria. Os quatro arqueiros têm capuz de tecido verde-oliva desenhado diretamente na cabeça original, com costura central, borda acabada e abertura que preserva olhos, sobrancelhas, nariz, boca e presas.\n\n'
if paragraph not in text:text=text.replace('Os escudos da linha de guardiões',paragraph+'Os escudos da linha de guardiões')
entry='- [Chifres e capuzes antes e depois](previews/orc_troops/horns_hoods_before_after.jpg).\n'
if entry not in text:text=text.replace('- [Armaduras de osso antes e depois]',entry+'- [Armaduras de osso antes e depois]')
entry='- [Detalhes dos novos chifres e capuzes](previews/orc_troops/horns_hoods_details.jpg).\n'
if entry not in text:text=text.replace('- [Chifres e capuzes antes e depois]',entry+'- [Chifres e capuzes antes e depois]')
entry='- `orc_horns_hoods_validation.json`: chifres maiores e dianteiros, capuzes sem nova cabeça, retirada real dos escudos montados, materiais e geometria protegidos, esqueleto e curvas preservados; os outros 12 modelos continuam byte a byte intactos.\n'
if entry not in text:text=text.replace('- `orc_bone_armor_validation.json`',entry+'- `orc_bone_armor_validation.json`')
text=text.replace('Para reaplicar a última revisão pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_bone_all_mcp.py --timeout 1200`.','Para reaplicar a última revisão pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_horns_hoods_all_mcp.py --timeout 1200`. A fonte aprovada para chifres e capuzes está em `art_source/orc_troops/horns_and_hoods/before_assets/`. A revisão de armadura fechada está em `orc_bone_all_mcp.py`.')
path.write_text(text,encoding='utf-8')
for row in ASSETS:
    if row['family']!='ranger':continue
    path=OUT/row['stem']/(row['stem']+'_report.json');report=json.loads(path.read_text(encoding='utf-8'))
    assert report.get('finishing_revision')=='forward_horns_and_painted_hoods_v1'
    if 'head_audit' in report['texture']:report['texture']['head_audit']['mode']='painted_cloth_hood'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Updated horns and hoods catalog.')
