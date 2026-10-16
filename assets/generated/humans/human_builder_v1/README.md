# Construtor humano — v1

Unidade `v2_unit_builder`, derivada do colono `human_settler_v1` no Blender
via MCP. Conserva corpo, rosto, pele, roupas azuis, boné e botas da base
humana. A geometria copiada e os pixels originais do corpo e do rosto
foram preservados; o arquivo do colono não foi alterado.

Altura anatômica normalizada para 1,80 m, do chão ao topo da cabeça,
sem incluir boné ou martelo. O rig recebe escala uniforme de 1,05714285;
proporções, UVs e chaves das três animações são preservados.
Normalização: `tools/art_pipeline/normalize_builder_body_sizes_mcp.py`.
Medições no jogo: `art_source/builders_size_review/godot_body_sizes.json`.

Bagagem, rolo de dormir, pá e acessórios de viagem deram lugar a um
avental de trabalho, bolsa de pregos, reforços nos joelhos e martelo.
O braço direito adota uma pose de carregar ferramenta: cabo vertical
atravessando o punho, cabeça perpendicular e face de impacto apontada
para a frente do personagem. A mão esquerda fica vazia.

- 492 triângulos, uma malha, uma superfície e um material no GLB.
- 41 peças editáveis no Blender; rig de 16 ossos do colono.
- Clipes `idle` (3 s), `walk` (1,5 s) e `work` (3 s).
- Trabalho: inclina o tronco 16°, levanta o martelo, bate no ar e retorna
  à postura de carregar. Pés fixos; mão e martelo seguem o mesmo osso.
- Martelo ligado ao osso `hand_r`; única ferramenta empunhada.
- Atlas 1024 × 1024 com pixels originais sem resampling e regiões novas
  para avental, metal e madeira; nearest com mipmaps no Godot.

`UnitArtCatalog` associa a arte ao construtor **humano**. As outras raças
mantêm seus visuais atuais até receberem modelos próprios. Custo,
movimento, cargas e regras da unidade permanecem os mesmos. Ao melhorar
um recurso, toca `work` uma vez e volta ao idle. Na última carga, uma cópia
visual termina o gesto enquanto a unidade é consumida imediatamente.

Fontes: `human_builder_v1.blend`, `human_builder_v1.glb`,
`human_builder_v1_albedo.png` e `human_builder_v1_report.json`.
Prévias: `previews/three_quarter.png`, `previews/front.png`,
`previews/back.png` e `previews/godot_comparison.png`.

`godot_validation.json` verifica skin, textura e 75 poses dos três clipes,
incluindo fechamento dos loops e contato com o chão. `unit_validation.json`
confere `Unit.setup`, seleção de arte por raça, retorno ao idle e limpeza
da cópia visual da última carga. Prévias animadas: `previews/idle.gif`,
`previews/walk.gif` e `previews/work.gif`.

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/build_human_builder_mcp.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/animate_human_builder_mcp.py
python tools/art_pipeline/validate_human_builder_godot.py
godot --path . res://tools/art_pipeline/preview_human_builder.tscn
```

A geração aplica a revisão final de ferramentas automaticamente, protege
um GLB já existente e preserva as cenas abertas no Blender. A revisão
inicial está em `art_source/human_builder_review/initial_hammer`.

As validações do modelo e da reprodução na unidade passaram. A suíte
`test_v2_constructor` passou em 19 de 20 testes: a asserção de dois filhos
no marcador da mina falha porque o asset já referenciado
`assets/models/kaykit/buildings/building_blacksmith_blue.gltf` está ausente;
o marcador contém apenas o selo dourado. A animação não altera esse marcador.
