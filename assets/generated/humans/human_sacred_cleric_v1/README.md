# Clérigo — Escola Sagrada

Modelo humano idoso em estilo blocky/pixel art, criado via MCP do Blender.
Vestes marfim simples, mitra dourada e cajado solar.

- `human_sacred_cleric_v1.blend`: fonte editável, 39 peças separadas com rig de 16 ossos.
- `human_sacred_cleric_v1.glb`: exportação animada, 1 malha, 1 superfície, 1 material, 468 triângulos.
- Albedo e emissão: atlas PNG 512×512, UVs em 64 px/m, margem de 3 px. Texturas também incorporadas no GLB e empacotadas no Blender.
- Escala nativa em metros; multiplicador 1.0. Pivô nos pés (0,0,0); frente -Y no Blender e +Z no Godot.
- Postura: tronco inclinado 8°, ombros baixos, barba grisalha.
- Revisão de estilo 3: cabeça e rosto originais do humano, no tamanho original; cabelo branco pintado, barba pintada com pequena extensão abaixo do queixo. Capuzes pintados na cabeça. Mitra e chapéu azul em 3D. Corpo e postura preservados; roupas simplificadas na revisão 4.
- Rig de 16 ossos; animações `idle`, `walk` e `spell`. Banco de unidades inalterado.
- Importador Godot exclusivo mantém nearest com mipmaps. Preserve o arquivo `.glb.import`.
- Fonte corporal: humano colonizador aprovado; arquivo original preservado.
- Revisão: nenhum par exposto de faces coplanares; cajado encosta na mão e não cruza o antebraço.

As vistas de frente, perspectiva e costas estão em `previews/`.

## Animações

Criadas via MCP do Blender, preservando geometria, UVs e texturas aprovadas.

- `idle`: 3 s, loop.
- `walk`: 1,5 s, loop no lugar; velocidade de referência 0.290 m/s.
- `spell`: 3 s, execução única; liberação em 1.68 s. Casting comum às seis escolas desta raça: Invocação cerimonial.
- Blender: idle nos frames 1–145, walk 161–233, spell 241–385; 48 fps. O intervalo de prévia está no casting.
- Godot: preserve `.glb.import` e o post-import `school_mage_animation_import.gd`, que configura filtro pixelizado e loops. Escala nativa 1,0.

[Galeria das animações](../../../../art_source/school_mages_animation_review/index.html).

### Revisão 3 dos movimentos

Casting articulado pelo ombro e por um eixo fixo de cotovelo. Antebraço sem torção axial independente; mão acompanha o antebraço, com pequeno movimento controlado de punho na mão livre. Caminhada também usa o eixo anatômico do cotovelo. Verificados os frames completos, a suavidade angular, o contato mão/cetro, os pés e a ausência de cruzamentos de mãos/antebraços com o torso.

### Revisão 4 das roupas

Revisão 4 das roupas: removidos os adornos aplicados em 3D dos seis humanos. Mantidos as cores das escolas, anatomia, cabelos, barbas, capuzes pintados, chapéus, cajados e as animações idle, walk e spell aprovadas.
