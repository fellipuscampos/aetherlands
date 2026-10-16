# Construtor elfo — v1

Unidade `v2_unit_builder`, derivada do colono `elf_settler_v1` no Blender
via MCP. Preserva anatomia, rosto, orelhas pontudas, cabelo loiro preso,
túnica verde, botas, cinto e pixels originais. O arquivo do colono permanece
intacto.

Altura anatômica normalizada para 1,80 m, do chão ao topo da cabeça,
sem incluir cabelo ou martelo. O rig recebe escala uniforme de 1,05714285;
proporções, UVs e chaves das três animações são preservados.
Normalização: `tools/art_pipeline/normalize_builder_body_sizes_mcp.py`.
Medições no jogo: `art_source/builders_size_review/godot_body_sizes.json`.

A mochila, o rolo de dormir, o estojo de sementes e o cajado dão lugar
a um avental verde claro, bolsa de pregos e reforços nos joelhos. A única
ferramenta empunhada é um martelo com cabo vertical e face de impacto
voltada para a frente. A mão esquerda fica vazia.

- 648 triângulos, uma malha, um material e 16 ossos no GLB.
- 54 peças editáveis no `.blend`; atlas 1024 × 1024 com a base preservada.
- `idle`: 3 segundos em loop; `walk`: 1,5 segundo em loop.
- `work`: 3 segundos, curva o tronco 16°, levanta o martelo, bate no ar e
  retorna à postura inicial. Pés fixos durante o trabalho.

`UnitArtCatalog` aplica este visual aos construtores de civilizações
élficas. Usa a reprodução de trabalho já disponível: termina em idle;
na última carga, a cópia visual completa o gesto após consumir a unidade.

`source_validation.json` confere a geometria e os pixels originais,
orelhas e cabelo preservados, mão esquerda vazia e orientação do martelo.
`godot_validation.json` verifica 75 poses, loops e contato com o chão.
`unit_validation.json` confere a reprodução usando `Unit.setup`.
Prévias em `previews/`: comparação com o colono, vistas estáticas e GIFs
de `idle`, `walk` e `work`.

Validação do catálogo de arte: 9/9 testes passaram, com 3217 asserções.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_elf_builder_mcp.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/verify_elf_builder_source_mcp.py
python tools/art_pipeline/validate_human_builder_godot.py --race elf
godot --headless --path . --editor --import
godot --path . res://tools/art_pipeline/preview_human_builder.tscn -- --race=elf
godot --path . res://tools/art_pipeline/render_human_builder_animations.tscn -- --race=elf
python tools/art_pipeline/encode_human_builder_animations.py --race elf
```

A geração protege um GLB existente. O script do elfo configura a mesma
pipeline do construtor humano, com a anatomia e a paleta do colono elfo.
