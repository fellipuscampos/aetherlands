# Construtor anão — v1

Unidade `v2_unit_builder`, derivada de `dwarf_settler_v1` no Blender via
MCP. Preserva porte de 1,35 m, rosto, nariz, barba, bigode, boné azul,
roupa, botas e cinto do colono. Geometria copiada e pixels originais
permanecem intactos; o arquivo do colono não foi alterado.

Altura anatômica conferida em 1,35 m, do chão ao topo da cabeça,
sem incluir boné ou martelo; mantém o porte da base anã.
Medições no jogo: `art_source/builders_size_review/godot_body_sizes.json`.

Mochila, caixa de ferramentas de viagem, rolo de dormir, picareta,
lanterna e painéis antigos do avental dão lugar a um avental de couro,
bolsa de pregos e reforços nos joelhos. A única ferramenta empunhada
é um martelo com cabeça grossa, cabo vertical e face de impacto voltada
para a frente. A mão esquerda fica vazia.

- 792 triângulos, uma malha, um material e 16 ossos no GLB.
- 66 peças editáveis no `.blend`; atlas 1024 × 1024 com a base preservada.
- `idle`: 3 segundos em loop; `walk`: 1,5 segundo em loop.
- `work`: 3 segundos, curva o tronco 16°, levanta o martelo, bate no ar
  e retorna à postura inicial. Pés apoiados durante o trabalho.

A batida usa ombro e cotovelo no mesmo plano. Punho, mão e martelo
acompanham o antebraço. A hierarquia do braço direito é
`chest → upper_arm_r → forearm_r → hand_r`, mantendo as junções estáveis
durante a interpolação no Godot.

`UnitArtCatalog` aplica o visual às civilizações anãs, completando os
construtores das quatro raças. A animação de trabalho termina em idle;
na última carga, uma cópia visual completa o gesto após consumir a
unidade pelas regras existentes.

`source_validation.json` verifica anatomia, barba, boné, pixels originais
e orientação do martelo. `godot_validation.json` verifica 75 poses,
loops e contato com o chão. `work_validation.json` confere 289 poses,
incluindo intervalos entre quadros: plano da batida, punho, junções e
continuidade. `unit_validation.json` confere a reprodução na unidade.
Prévias estáticas e GIFs de `idle`, `walk` e `work` em `previews/`.

Validação do catálogo de arte: 9/9 testes passaram, com 3298 asserções,
incluindo os construtores das quatro raças.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_dwarf_builder_mcp.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/verify_dwarf_builder_source_mcp.py
python tools/art_pipeline/validate_human_builder_godot.py --race dwarf
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/art_pipeline/verify_orc_builder_work.gd -- --race=dwarf
godot --path . res://tools/art_pipeline/preview_human_builder.tscn -- --race=dwarf
godot --path . res://tools/art_pipeline/render_human_builder_animations.tscn -- --race=dwarf
python tools/art_pipeline/encode_human_builder_animations.py --race dwarf
```

A geração protege um GLB existente e preserva as cenas abertas no Blender.
