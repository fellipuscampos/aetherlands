# Clérigo Élfico — Escola Sagrada

Vestes simples em marfim, gola e cinto verdes, diadema dourado e cajado solar em madeira.

Criado via MCP do Blender a partir da linguagem aprovada dos magos humanos e da anatomia do elfo do projeto. Cabeça, rosto e orelhas originais preservados, cabelo claro da paleta élfica e vestes simples com gola e cinto verdes. Adornos geométricos sobre as roupas removidos. Capuzes pintados diretamente na cabeça; chapéu e diademas em 3D.

- `elf_sacred_cleric_v1.blend`: fonte editável, 52 peças separadas.
- `elf_sacred_cleric_v1.glb`: modelo estático para revisão, 1 malha, 1 superfície, 1 material, 624 triângulos.
- Texturas albedo/emissão 512×512, 64 px/m, margem de 3 pixels, nearest; incorporadas no GLB e empacotadas no Blender.
- Metros, escala 1.0, pivô nos pés. Frente -Y no Blender e +Z no Godot.
- Cajado em contato com a mão, separado do antebraço. Nenhuma face coplanar exposta sobreposta.
- Sem rig ou animações nesta etapa de revisão. O cadastro de unidades permanece inalterado.
- Fonte original: `assets/generated/elves/elf_settler_v1/elf_settler_v1.blend`. Os modelos humanos aprovados também foram preservados.

Vistas de frente, perspectiva e costas em `previews/`.

## Animações

Criadas via MCP do Blender, preservando geometria, UVs e texturas aprovadas.

- `idle`: 3 s, loop.
- `walk`: 1,5 s, loop no lugar; velocidade de referência 0.312 m/s.
- `spell`: 3 s, execução única; liberação em 1.74 s. Casting comum às seis escolas desta raça: Arco de canalização.
- Blender: idle nos frames 1–145, walk 161–233, spell 241–385; 48 fps. O intervalo de prévia está no casting.
- Godot: preserve `.glb.import` e o post-import `school_mage_animation_import.gd`, que configura filtro pixelizado e loops. Escala nativa 1,0.

[Galeria das animações](../../../../art_source/school_mages_animation_review/index.html).

### Revisão 3 dos movimentos

Casting articulado pelo ombro e por um eixo fixo de cotovelo. Antebraço sem torção axial independente; mão acompanha o antebraço, com pequeno movimento controlado de punho na mão livre. Caminhada também usa o eixo anatômico do cotovelo. Verificados os frames completos, a suavidade angular, o contato mão/cetro, os pés e a ausência de cruzamentos de mãos/antebraços com o torso.
