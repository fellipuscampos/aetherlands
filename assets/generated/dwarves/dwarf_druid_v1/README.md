# Druida Anão — Druidismo

Verde, faixa de couro e cajado com raízes, pedra e folhas em blocos.

Criado via MCP do Blender com a anatomia do anão aprovado. Cabeça, nariz, barba em dezoito mechas, bigode e proporções nativas preservados. Cabelos, barba e sobrancelhas grisalhos; postura levemente curvada; vestes simples nas cores humanas das escolas. Couro, cobre, aço e pedra da paleta anã. Antebraços largos originais, mão livre relaxada, sem livros ou ornamentos geométricos aplicados às roupas.

- `dwarf_druid_v1.blend`: fonte editável com 67 peças separadas.
- `dwarf_druid_v1.glb`: uma malha, uma superfície, um material e 804 triângulos.
- Albedo e emissão 512×512, 64 px/m, margem de 3 pixels, nearest. Atlases incorporados no GLB e empacotados no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço; sem faces coplanares expostas sobrepostas.
- Rig de 16 ossos; animações `idle`, `walk` e `spell`. Banco de unidades inalterado.
- Fonte: `assets/generated/dwarves/dwarf_settler_v1/dwarf_settler_v1.blend`. Os personagens já aprovados foram preservados.

Prévias de frente, perspectiva e costas em `previews/`.

## Animações

Criadas via MCP do Blender, preservando geometria, UVs e texturas aprovadas.

- `idle`: 3 s, loop.
- `walk`: 1,5 s, loop no lugar; velocidade de referência 0.151 m/s.
- `spell`: 3 s, execução única; liberação em 1.62 s. Casting comum às seis escolas desta raça: Selo da forja.
- Blender: idle nos frames 1–145, walk 161–233, spell 241–385; 48 fps. O intervalo de prévia está no casting.
- Godot: preserve `.glb.import` e o post-import `school_mage_animation_import.gd`, que configura filtro pixelizado e loops. Escala nativa 1,0.

[Galeria das animações](../../../../art_source/school_mages_animation_review/index.html).

### Revisão 3 dos movimentos

Casting articulado pelo ombro e por um eixo fixo de cotovelo. Antebraço sem torção axial independente; mão acompanha o antebraço, com pequeno movimento controlado de punho na mão livre. Caminhada também usa o eixo anatômico do cotovelo. Verificados os frames completos, a suavidade angular, o contato mão/cetro, os pés e a ausência de cruzamentos de mãos/antebraços com o torso.
