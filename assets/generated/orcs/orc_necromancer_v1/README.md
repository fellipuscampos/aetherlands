# Necromante Orc — Necromancia

Roxo, capuz pintado e cajado de osso com crânio entalhado.

Criado no Blender aberto, via MCP, com a anatomia do orc aprovado e as cores da escola humana correspondente. Cabeça, rosto, orelhas, presas e proporções nativas preservados. Crista, sobrancelhas e barbas grisalhas, postura levemente curvada, roupas simples, antebraços expostos, couro e madeira da paleta orc. Nenhum adorno geométrico aplicado às roupas.

- `orc_necromancer_v1.blend`: fonte editável com 48 peças separadas.
- `orc_necromancer_v1.glb`: modelo estático com uma malha, uma superfície, um material e 576 triângulos.
- Albedo e emissão 512×512, 64 px/m, margem de 3 pixels, nearest. Atlases incorporados no GLB e empacotados no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço. Sem faces coplanares expostas sobrepostas.
- Ainda sem rig ou animações nesta etapa de conferência. Cadastro de unidades inalterado.
- Fonte original: `assets/generated/orcs/orc_settler_v1/orc_settler_v1.blend`. Orc base, humanos e elfos aprovados preservados.

Frente, perspectiva e costas em `previews/`.

## Animações

Criadas via MCP do Blender, preservando geometria, UVs e texturas aprovadas.

- `idle`: 3 s, loop.
- `walk`: 1,5 s, loop no lugar; velocidade de referência 0.344 m/s.
- `spell`: 3 s, execução única; liberação em 1.80 s. Casting comum às seis escolas desta raça: Chamado xamânico.
- Blender: idle nos frames 1–145, walk 161–233, spell 241–385; 48 fps. O intervalo de prévia está no casting.
- Godot: preserve `.glb.import` e o post-import `school_mage_animation_import.gd`, que configura filtro pixelizado e loops. Escala nativa 1,0.

[Galeria das animações](../../../../art_source/school_mages_animation_review/index.html).

### Revisão 3 dos movimentos

Casting articulado pelo ombro e por um eixo fixo de cotovelo. Antebraço sem torção axial independente; mão acompanha o antebraço, com pequeno movimento controlado de punho na mão livre. Caminhada também usa o eixo anatômico do cotovelo. Verificados os frames completos, a suavidade angular, o contato mão/cetro, os pés e a ausência de cruzamentos de mãos/antebraços com o torso.
