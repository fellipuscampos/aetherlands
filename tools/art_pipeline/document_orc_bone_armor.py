"""Update the catalog without replacing the approved leather revision history."""
from orc_troop_assets import ROOT
path=ROOT/'docs/ORC_TROOPS_CATALOG.md'
text=path.read_text(encoding='utf-8')
old='Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria usam proteção de osso com costelas, esterno e ossos longos desenhados nos próprios blocos. A caveira do capacete é pintada na cabeça única; os espaços entre os ossos mostram pele verde. Ombreiras e reforços têm detalhes adicionais em 3D.'
new='Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria receberam a revisão `closed_carapace_v1`: armaduras de osso que cobrem quase todo o corpo, com placas corticais sobrepostas, bordas esculpidas, fissuras discretas e frestas estreitas de pele verde. O capacete fechado de crânio de javali é pintado no bloco original da cabeça, com relevo nasal e chifres laterais em 3D abaixo da altura da cabeça. Ombreiras largas, braçadeiras, manoplas, coxas, canelas e pés completam a proteção. Cintos, couro, tecidos e fivelas aprovados foram preservados.'
assert old in text or new in text
text=text.replace(old,new)
text=text.replace('Escudos, arcos, mãos, montarias e acessórios das armas mantêm','Arcos, mãos, montarias e acessórios das armas mantêm')
paragraph='Os escudos da linha de guardiões agora têm apenas o reforço central quadrado de ferro sobre a madeira: os quatro quadrados brancos das evoluções foram removidos. O escudo do escudeiro inicial já tinha esse acabamento e continua intacto.\n\n'
if paragraph not in text:text=text.replace('As lâminas foram orientadas',paragraph+'As lâminas foram orientadas')
entry='- [Armaduras de osso antes e depois](previews/orc_troops/bone_armor_before_after.jpg).\n'
if entry not in text:text=text.replace('- [Roupas antes e depois]',entry+'- [Roupas antes e depois]')
entry='- `orc_bone_armor_validation.json`: cobertura de osso, capacete fechado na cabeça única, olhos simétricos, curvas e geometria protegidas, armas e couro intactos, e os outros 15 modelos byte a byte preservados.\n'
if entry not in text:text=text.replace('- `orc_clothing_refinement_validation.json`',entry+'- `orc_clothing_refinement_validation.json`')
text=text.replace('Para reaplicar esta revisão pelo MCP do Blender aberto: `python tools/art_pipeline/run_orc_clothing_mcp.py`.','Para reaplicar a última revisão pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_bone_all_mcp.py --timeout 1200`. A fonte aprovada para esta rodada está em `art_source/orc_troops/bone_armor_refinement/before_assets/`. A revisão anterior de couro pode ser reaplicada com `python tools/art_pipeline/run_orc_clothing_mcp.py`.')
path.write_text(text,encoding='utf-8')
print('Updated closed bone armor catalog.')
