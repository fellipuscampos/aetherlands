# Kit modular de floresta temperada

Dez assets independentes criados pelo **MCP do Blender**. Estética voxel/blocky, folhas sólidas e textura pixelizada, coerente com as árvores e construções existentes do jogo. O kit contém somente árvores e props separados para composição manual ou procedural.

[Galeria com quatro vistas](../../../../art_source/temperate_forest_review/index.html) · [Manifesto dos assets](manifest.json).

## Arquivos

- `godot/`: cenas `.tscn` para arrastar no mapa e malhas `.res` para MultiMesh; todas usam `forest_pixel_material.tres`.
- `models/<asset>/`: exportação `.glb`, fonte editável `.blend` com textura empacotada, relatório e quatro prévias.
- `textures/forest_pixel_atlas.png`: atlas único 512×512, com configuração de importação que gera mipmaps.
- `manifest.json`: categorias, caminhos, escala, dimensões, raio conservador da copa e contagem de triângulos.

## Catálogo

| Asset | Categoria | Dimensões no Blender (X/Y/Z) | Triângulos | Cena pronta |
|---|---|---|---:|---|
| `tree_oak_a` — Carvalho amplo | Árvore principal | 0.56 × 0.40 × 0.92 | 156 | [tree_oak_a.tscn](godot/tree_oak_a.tscn) |
| `tree_oak_b` — Carvalho bifurcado | Árvore principal | 0.52 × 0.32 × 1.04 | 166 | [tree_oak_b.tscn](godot/tree_oak_b.tscn) |
| `tree_beech_a` — Faia vertical | Árvore principal | 0.40 × 0.36 × 1.08 | 116 | [tree_beech_a.tscn](godot/tree_beech_a.tscn) |
| `tree_pine_a` — Pinheiro adulto | Árvore principal | 0.48 × 0.48 × 1.16 | 220 | [tree_pine_a.tscn](godot/tree_pine_a.tscn) |
| `tree_oak_young` — Carvalho jovem | Árvore menor | 0.32 × 0.24 × 0.64 | 114 | [tree_oak_young.tscn](godot/tree_oak_young.tscn) |
| `tree_pine_young` — Pinheiro jovem | Árvore menor | 0.32 × 0.24 × 0.76 | 136 | [tree_pine_young.tscn](godot/tree_pine_young.tscn) |
| `shrub_hazel` — Arbusto de aveleira | Arbusto | 0.32 × 0.24 × 0.28 | 54 | [shrub_hazel.tscn](godot/shrub_hazel.tscn) |
| `shrub_bracken` — Arbusto de sub-bosque | Arbusto | 0.40 × 0.24 × 0.20 | 110 | [shrub_bracken.tscn](godot/shrub_bracken.tscn) |
| `fallen_log` — Tronco caído | Tronco caído | 0.64 × 0.28 × 0.16 | 74 | [fallen_log.tscn](godot/fallen_log.tscn) |
| `rock_root_small` — Pedra com musgo e raiz | Decoração | 0.28 × 0.16 × 0.20 | 56 | [rock_root_small.tscn](godot/rock_root_small.tscn) |

**Total: 1.202 triângulos**, de 54 a 220 por asset. Cada asset tem uma malha e uma superfície de renderização. As superfícies externas foram unidas, com remoção de faces internas; as malhas são fechadas e têm normais planas. Folhas opacas evitam o custo e a ordenação de transparência.

## Escala, pivôs e composição

Use **escala base 1.0**: as árvores adultas têm altura de 0.92 a 1.16 nas unidades nativas do mapa, cujo hexágono tem raio 1. A altura correspondente é o eixo Y no Godot. Os pivôs ficam no solo, na base do tronco ou no centro de apoio do prop. Nenhuma cena exige correção de rotação ou escala.

A variação sugerida é rotação ao redor de Y entre 0 e 360° e escala uniforme entre 0.85 e 1.12. Varie também a espécie e a posição. Evite escalar cada eixo separadamente: a escala uniforme mantém as proporções e o aspecto dos pixels. A densidade é **128 pixels por unidade em todos os modelos**; pequenas variações uniformes de instância alteram a densidade de maneira proporcional.

Para manter a copa dentro de um tile pointy-top de raio 1, uma regra conservadora independente da rotação é `distância_do_centro + footprint_radius * escala <= sqrt(3)/2 - margem`. O manifesto informa `footprint_radius` de cada asset. Uma margem de 0.02 funciona para afastar a silhueta da borda. Distribua os centros com espaço entre as copas; árvores jovens e arbustos permitem densidade visual sem repetir árvores grandes.

## MultiMesh no Godot

Agrupe instâncias por variante, reutilizando a mesma malha e o material comum. Um MultiMesh por variante e por região do mapa permite variação de rotação, escala e tintura sem criar um nó por árvore. A divisão por regiões mantém o culling útil em mapas grandes. As cenas individuais permanecem disponíveis para edição manual.

```gdscript
const KIT := "res://assets/generated/nature/temperate_forest_v1"

var mesh: ArrayMesh = load(KIT + "/godot/tree_oak_a.res")
var batch := MultiMesh.new()
batch.transform_format = MultiMesh.TRANSFORM_3D
batch.use_colors = true
batch.mesh = mesh
batch.instance_count = placements.size()

for i in placements.size():
    var placement: Dictionary = placements[i]
    var basis := Basis(Vector3.UP, placement.angle).scaled(Vector3.ONE * placement.scale)
    batch.set_instance_transform(i, Transform3D(basis, placement.position))
    batch.set_instance_color(i, Color.WHITE)

var forest_variant := MultiMeshInstance3D.new()
forest_variant.multimesh = batch
add_child(forest_variant)
```

O material compartilhado usa amostragem nearest com mipmaps: pixels definidos de perto e menor cintilação de textura à distância. A textura tem variação em grupos de pixels, fibras da casca, marcas da faia, musgo e anéis no corte do tronco. As UVs são métricas, sem esticar as texturas para caber nas faces.

## Validação

Os dez GLBs passaram na verificação de malha única, superfície única, material opaco, culling, atlas compartilhado, pivô no solo, escala nativa, ausência de câmeras/luzes/rig/animações e densidade de UVs. Nenhuma sobreposição coplanar com área positiva foi detectada nas superfícies exportadas. As fontes `.blend` são isoladas, com atlas empacotado, volume positivo e malhas fechadas; as 467 cenas anteriores do Blender foram preservadas.

O Godot importou os dez modelos e recarregou as cenas e malhas compartilhando o mesmo material. Também foi verificada a configuração de 1.000 instâncias de MultiMesh por variante com transformações e tinturas: um teste de recursos e API em modo headless, sem benchmark de FPS.

[GLBs e UVs](../../../../docs/temperate_forest_validation.json) · [Fontes pelo MCP](../../../../docs/temperate_forest_source_validation.json) · [Godot](../../../../docs/temperate_forest_godot_validation.json).
