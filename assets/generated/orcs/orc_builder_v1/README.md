# Construtor orc — v1

Unidade `v2_unit_builder`, derivada do colono `orc_settler_v1` no Blender
via MCP. Preserva porte, pele verde, rosto, orelhas, presas, sobrancelhas,
roupa de couro, botas e cinto. Geometria copiada e pixels originais
permanecem intactos; o arquivo do colono não foi alterado.

Altura anatômica conferida em 2,00 m, do chão ao topo da cabeça,
sem incluir o martelo; mantém a escala uniforme da base orc.
Medições no jogo: `art_source/builders_size_review/godot_body_sizes.json`.

Mochila, rolo de dormir, saco de sementes e malho de viagem dão lugar
a um avental marrom escuro, bolsa de pregos e reforços nos joelhos.
O martelo tem dimensões 25% maiores que a versão humana, cabo vertical
e face de impacto voltada para a frente. A mão esquerda fica vazia.

- 600 triângulos, uma malha, um material e 16 ossos no GLB.
- 50 peças editáveis no `.blend`; atlas 1024 × 1024 com a base preservada.
- `idle`: 3 segundos em loop; `walk`: 1,5 segundo em loop.
- `work`: 3 segundos, curva o tronco 16°, levanta o martelo, bate no ar
  e retorna à postura inicial. Pés fixos durante o trabalho.

A batida usa rotações de ombro e cotovelo em um único plano, sem abrir
o cotovelo para o lado. Punho, mão e martelo acompanham o antebraço
como um conjunto. `work_validation.json` verifica 289 poses, incluindo
interpolação entre quadros: plano da batida, ausência de torção no punho,
comprimento dos segmentos e continuidade das rotações.
O braço direito usa a hierarquia `chest → upper_arm_r → forearm_r → hand_r`,
mantendo as junções rígidas também durante a interpolação no Godot.
`carry_validation.json` compara idle e walk com o modelo anterior à correção.

`UnitArtCatalog` aplica o visual aos construtores de civilizações orcs.
A animação de trabalho termina em idle. Na última carga, uma cópia
visual completa o gesto após consumir a unidade pelas regras existentes.

`source_validation.json` confere anatomia e pixels originais, orientação
do martelo e mão esquerda vazia. `godot_validation.json` verifica
75 poses dos três clipes, loops e contato com o chão.
`unit_validation.json` confere a reprodução usando `Unit.setup`.
Prévias em `previews/`: comparação com o colono, vistas estáticas e
GIFs de `idle`, `walk` e `work`.

Validação do catálogo de arte: 9/9 testes passaram, com 3224 asserções.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_orc_builder_mcp.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/verify_orc_builder_source_mcp.py
python tools/art_pipeline/validate_human_builder_godot.py --race orc
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/art_pipeline/verify_orc_builder_work.gd
godot --path . res://tools/art_pipeline/preview_human_builder.tscn -- --race=orc
godot --path . res://tools/art_pipeline/render_human_builder_animations.tscn -- --race=orc
python tools/art_pipeline/encode_human_builder_animations.py --race orc
```

A geração protege um GLB existente e preserva as cenas abertas no Blender.
A correção isolada do trabalho pode ser reaplicada com
`python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/fix_orc_builder_work_mcp.py`.
