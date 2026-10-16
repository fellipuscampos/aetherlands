# Canteiro humano genérico

Os antebraços foram encurtados em cerca de 27%. O malho levanta em arco e golpeia a talhadeira com a cabeça, mantendo a mão ao lado da pedra e o cabo acima do bloco. As mangas articuladas continuam formando os ombros, sem blocos estáticos extras.

Revisão 6. Canteiro medieval voxel para qualquer edifício humano em produção. Não exporta tile, placa de chão, janela, arco ou planta de um prédio. A terra vem do mapa; os dois trabalhadores no solo têm os pés em Y=0 no Godot. O terceiro permanece apoiado no andaime.

Um trecho de alvenaria incompleta, pedra sobre bancada, tábuas e blocos soltos representam a obra. Dez peças de ardósia azul estão empilhadas em dois feixes sobre um pequeno pallet; uma caixa guarda fixadores de telhado. Pedra cinza, cantaria clara e ardósia azul usam a paleta dos edifícios humanos, definida em `tools/art_pipeline/guardian_hall_paint_save.py`.

Os trabalhadores preservam a cabeça, rosto pintado e proporções fixas de `human_settler_v1`, em escala uniforme de 0,24. Todas as 343 peças são cuboides fechados, sem chanfros e sem sombreamento suave.

- `human_construction_site_hex_v1.blend`: fonte editável com materiais, rig e animação.
- `human_construction_site_hex_v1.glb`: 4116 triângulos, 2 malhas, 1 material, atlas 512×512 embutido e 25 ossos.
- `human_construction_site_hex_v1.tscn`: cena pronta; inicia e repete `construction` automaticamente.
- `previews/`: cenário, mapa, traseira, superior, closes dos trabalhadores e referência de limite do tile.

O loop dura 6 segundos, a 30 fps. O pedreiro usa malho e talhadeira, o carpinteiro serra uma tábua mantendo a mão de apoio sobre ela, e o trabalhador do andaime alisa a argamassa. Os braços dobram em planos estáveis, sem torção axial ou mudança brusca de cotovelo. As mãos e ferramentas continuam unidas ao rig. Pés e raiz permanecem fixos; o loop fecha sem salto.

O footprint virtual permanece dentro de um hexágono pointy-top de raio 0,9, alinhado aos tiles de raio 1 do mapa, com margem mínima de 0,0388. Esse footprint é apenas uma restrição de posicionamento, não uma malha. O contorno azul da prévia é apenas referência do estúdio e não entra no GLB.

O mapa instancia o canteiro humano no tile do prédio em produção, aplica `hex_size` uma vez e posiciona a barra acima do andaime. O canteiro desaparece na conclusão ou no cancelamento. Abra `scenes/art_review/HumanConstructionReview.tscn` com F6 para revisar.

Vídeo e GIF: `art_source/human_construction_review/construction.mp4` e `construction.gif`. Close do golpe do pedreiro: `hammer_detail.mp4` e `hammer_detail.gif` na mesma pasta. Validações: relatório do modelo, `docs/human_construction_godot_validation.json` e `art_source/human_construction_review/contacts_validation.json`.

A revisão anterior está preservada em `art_source/human_construction_review/before_forearm_hammer_revision/`. Modelado, animado e renderizado pelo MCP do Blender aberto; as demais cenas foram preservadas.
