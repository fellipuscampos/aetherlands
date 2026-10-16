"""Document the final assets and the scope verified against the approved roster."""
from orc_troop_assets import ROOT,ASSETS
lines=['# Tropas orcs','',
'20 personagens em cinco classes e quatro evoluções por classe. Comuns: **2 m**. Supremos lendários: **2,20 m**. A altura da cavalaria é a do cavaleiro com as pernas estendidas, sem incluir montaria ou lança. Cerco está fora deste lote.','',
'A revisão de roupas `leather_and_skeletal_v1` usa couro castanho com costuras, bordas e rebites, faixas ajustadas ao torso, cintos com fivelas metálicas vazadas, painéis de couro sobre tecido, ombreiras em 3D com chifres e braçadeiras reforçadas. Torso, braços e parte das pernas continuam expostos nas versões leves.','',
'Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria usam proteção de osso com costelas, esterno e ossos longos desenhados nos próprios blocos. A caveira do capacete é pintada na cabeça única; os espaços entre os ossos mostram pele verde. Ombreiras e reforços têm detalhes adicionais em 3D.','',
'As lâminas foram orientadas com o fio voltado para a frente por rotação axial das peças, preservando seus formatos, comprimentos, texturas e empunhaduras. Escudos, arcos, mãos, montarias e acessórios das armas mantêm a geometria aprovada, exceto as peças incluídas nessa rotação.','',
'Os 18 blocos corporais, a cabeça única, as seis peças das orelhas, as duas sobrancelhas, as presas, as alturas, os esqueletos e todas as curvas das **93 animações** continuam iguais à versão aprovada. As novas peças usam os ossos existentes.','',
'- [Galeria das 20 tropas](previews/orc_troops/roster_three_quarter.jpg), [frente](previews/orc_troops/roster_front.jpg), [costas](previews/orc_troops/roster_back.jpg).',
'- [Roupas antes e depois](previews/orc_troops/clothing_before_after.jpg).',
'- Blender: [conjunto editável](../assets/generated/orcs/orc_troops_review.blend).',
'- Godot: abra `res://_orc_troop_models_review.tscn` e pressione **F6**. A revisão permite escolher classe e animação, pausar, alterar velocidade, girar e aproximar.',
'- `.blend`, `.glb`, atlas e relatórios individuais: `assets/generated/orcs/`.',
'- Manifesto: `assets/generated/orcs/orc_troops_manifest.json`.','',
'| Classe | Inicial | Evolução 2 | Evolução 3 | Supremo (2,20 m) |','|---|---|---|---|---|']
for start in range(0,len(ASSETS),4):
    rows=ASSETS[start:start+4]
    links=['[%s](../assets/generated/orcs/%s/%s.blend)'%(r['name'],r['stem'],r['stem']) for r in rows]
    lines.append('| '+rows[0]['family_name']+' | '+' | '.join(links)+' |')
lines+=['','Verificação:',
'- `orc_clothing_refinement_validation.json`: comparação dos GLBs com a cópia aprovada; geometria, pesos, esqueleto, curvas, materiais protegidos e rotações das lâminas.',
'- `orc_troops_anatomy_validation.json`: 4.364 poses exportadas, continuidade das articulações e ausência de interseções das mãos com rosto e tronco.',
'- `orc_troops_validation.json`: alturas, clips, atlas embutidos, olhos simétricos e fontes protegidas.',
'- `orc_troops_blender_validation.json`: arquivos editáveis, blocos, pesos e animações salvas.',
'- `orc_troops_godot_validation.json`: importação, dimensões, atlas, animações e revisão das cinco classes.','',
'Para reaplicar esta revisão pelo MCP do Blender aberto: `python tools/art_pipeline/run_orc_clothing_mcp.py`. A fonte congelada está em `art_source/orc_troops/clothing_refinement/before_assets/`. As revisões anteriores e suas comparações permanecem arquivadas.','']
(ROOT/'docs/ORC_TROOPS_CATALOG.md').write_text('\n'.join(lines),encoding='utf-8')
print('Updated orc clothing catalog.')
