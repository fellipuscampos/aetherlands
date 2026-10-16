# Construção humana — canteiro genérico

Os antebraços foram encurtados em cerca de 27%, de 0,109–0,111 para 0,080–0,081. O pedreiro segura o malho ao lado da pedra, com o cabo acima do bloco; a cabeça levanta em arco de 55° e desce sobre a talhadeira. O ciclo tem preparação mais lenta, uma pausa no alto e descida mais rápida. O trabalhador do andaime foi aproximado da argamassa para manter alcance com os braços mais curtos. As mangas articuladas continuam formando os ombros, sem blocos estáticos extras.

Revisão 6: canteiro medieval voxel para qualquer edifício humano em produção. O visual usa alvenaria incompleta e materiais de obra, sem janela, arco, porta, planta de um prédio ou base hexagonal. Os dois trabalhadores no solo ficam diretamente na superfície do terreno; o terceiro trabalha sobre o andaime.

A pedra cinza `(131,141,145)`, cantaria `(172,179,174)`, ardósia azul `(49,79,127)` e ardósia escura `(37,59,95)` vêm da paleta dos edifícios humanos. Dez telhas soltas em dois feixes, madeira e uma caixa de fixadores deixam clara a identidade da civilização sem representar um edifício específico.

Cena pronta: `assets/generated/humans/buildings/human_construction_site_hex_v1/human_construction_site_hex_v1.tscn`. Exportação: 4116 triângulos, duas malhas, um material, atlas 512×512 e 25 ossos; estúdio, câmeras e luzes ficam fora do GLB. Todas as peças são cuboides fechados. Cabeça, rosto pintado e proporções fixas dos humanos foram preservados.

O clip `construction` dura 6 s, a 30 fps, e repete automaticamente. Os pés e a raiz ficam fixos. Os braços dobram em planos estáveis: cotovelos entre 29,23° e 111,12°, com variação máxima de 1,70° por frame. As mãos não se cruzam. A serra mantém contato com a tábua e a mão de apoio fica sobre ela; malho/talhadeira e colher/argamassa também mantêm contato. As 181 poses foram verificadas no Blender e novamente após importar no Godot. O cabo do malho fica pelo menos 0,0725 acima da pedra, e a cabeça percorre um arco vertical de 0,1273 antes do impacto.

O footprint virtual respeita os cantos de `HexMetrics.corner`, com raio 0,9 dentro de um tile de raio 1 e margem mínima de 0,0388. Não há malha de chão nem pedestal. O contorno azul em `previews/hex_alignment.png` é uma referência do estúdio excluída do export.

## Uso no mapa

`HexGrid.refresh_construction_markers()` instancia o visual quando a cidade dona pertence à raça `human`, na superfície do tile do prédio em produção. Aplica `hex_size` uma vez e mantém a barra de progresso acima do andaime. O canteiro é removido ao concluir ou cancelar a obra. Na conclusão, `HexGrid.place_building` retira o canteiro no mesmo instante em que o prédio nasce (prédio e canteiro nunca dividem o tile); sobra só um aceno curto — a barra pula para 100% e some em menos de um segundo (na hora, com Reduced Motion). No cancelamento some sem aceno. Produção, custos e névoa continuam nas rotinas existentes. As quatro raças agora usam seus próprios canteiros.

## Revisão e validação

- Godot/F6: `scenes/art_review/HumanConstructionReview.tscn`.
- Blender: cena `Human_Construction_Site_V1` e `.blend` na pasta do modelo.
- Página de revisão: `art_source/human_construction_review/index.html`.
- Loop: `construction.gif` e `construction.mp4` na pasta de revisão.
- Geometria, material e limites dos braços: `human_construction_site_hex_v1_report.json` na pasta do modelo.
- Import, pés no solo, footprint e reprodução: `docs/human_construction_godot_validation.json`.
- Contato de ferramentas: `art_source/human_construction_review/contacts_validation.json`.
- Testes de marcador, escala, conclusão/cancelamento e névoa: `docs/human_construction_regression_validation.json`.

A revisão 5 está em `art_source/human_construction_review/before_forearm_hammer_revision/`. O close animado do pedreiro está em `art_source/human_construction_review/hammer_detail.gif` e `hammer_detail.mp4`. A criação ocorre no Blender aberto via MCP; a importação é conferida primeiro em projeto Godot isolado.
