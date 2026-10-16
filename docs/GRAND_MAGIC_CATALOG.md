# Grandes construções mágicas — modelos 3D

24 modelos criados pelo Blender MCP, um de cada vez, na ordem humanos, orcs, anões e elfos. Cada construção foi texturizada, conferida e salva antes de iniciar a seguinte.

Materiais e cores copiados das escolas revisadas da mesma civilização. Base de um tile pointy-top de raio 1, origem no solo e acabamento dos adereços físicos conferido. As manifestações associadas correspondem ao cadastro atual do jogo; a integração dos modelos permanece pendente.

Arquiteturas: catedral cruciforme de duas torres, círculo profano aberto, mausoléu com obelisco e efígies de esqueletos, bosque de árvore ancestral, torre de três corpos recuados e nexus de quatro torres elementais.

## Humanos

[Visão geral](../assets/generated/humans/buildings/grand_magic_three_quarter.jpg) · [Visão de mapa](../assets/generated/humans/buildings/grand_magic_game_top.jpg)

| Construção | Arquivos e quatro prévias | Triângulos |
|---|---|---:|
| Grande Catedral | [Abrir](../assets/generated/humans/buildings/sacred_ritual_hex_v1/README.md) | 2100 |
| Círculo Profano | [Abrir](../assets/generated/humans/buildings/infernal_ritual_hex_v1/README.md) | 1352 |
| Mausoléu Negro | [Abrir](../assets/generated/humans/buildings/necromancy_ritual_hex_v1/README.md) | 1740 |
| Bosque Ancestral | [Abrir](../assets/generated/humans/buildings/druidic_ritual_hex_v1/README.md) | 924 |
| Torre do Véu | [Abrir](../assets/generated/humans/buildings/arcane_ritual_hex_v1/README.md) | 1492 |
| Nexus dos Elementos | [Abrir](../assets/generated/humans/buildings/elemental_ritual_hex_v1/README.md) | 1392 |

## Orcs

[Visão geral](../assets/generated/orcs/buildings/grand_magic_three_quarter.jpg) · [Visão de mapa](../assets/generated/orcs/buildings/grand_magic_game_top.jpg)

| Construção | Arquivos e quatro prévias | Triângulos |
|---|---|---:|
| Grande Catedral | [Abrir](../assets/generated/orcs/buildings/orc_sacred_ritual_hex_v1/README.md) | 2688 |
| Círculo Profano | [Abrir](../assets/generated/orcs/buildings/orc_infernal_ritual_hex_v1/README.md) | 1464 |
| Mausoléu Negro | [Abrir](../assets/generated/orcs/buildings/orc_necromancy_ritual_hex_v1/README.md) | 2000 |
| Bosque Ancestral | [Abrir](../assets/generated/orcs/buildings/orc_druidic_ritual_hex_v1/README.md) | 1092 |
| Torre do Véu | [Abrir](../assets/generated/orcs/buildings/orc_arcane_ritual_hex_v1/README.md) | 1928 |
| Nexus dos Elementos | [Abrir](../assets/generated/orcs/buildings/orc_elemental_ritual_hex_v1/README.md) | 1580 |

## Anões

[Visão geral](../assets/generated/dwarves/buildings/grand_magic_three_quarter.jpg) · [Visão de mapa](../assets/generated/dwarves/buildings/grand_magic_game_top.jpg)

| Construção | Arquivos e quatro prévias | Triângulos |
|---|---|---:|
| Grande Catedral | [Abrir](../assets/generated/dwarves/buildings/dwarf_sacred_ritual_hex_v1/README.md) | 2364 |
| Círculo Profano | [Abrir](../assets/generated/dwarves/buildings/dwarf_infernal_ritual_hex_v1/README.md) | 1412 |
| Mausoléu Negro | [Abrir](../assets/generated/dwarves/buildings/dwarf_necromancy_ritual_hex_v1/README.md) | 1860 |
| Bosque Ancestral | [Abrir](../assets/generated/dwarves/buildings/dwarf_druidic_ritual_hex_v1/README.md) | 984 |
| Torre do Véu | [Abrir](../assets/generated/dwarves/buildings/dwarf_arcane_ritual_hex_v1/README.md) | 1732 |
| Nexus dos Elementos | [Abrir](../assets/generated/dwarves/buildings/dwarf_elemental_ritual_hex_v1/README.md) | 1704 |

## Elfos

[Visão geral](../assets/generated/elves/buildings/grand_magic_three_quarter.jpg) · [Visão de mapa](../assets/generated/elves/buildings/grand_magic_game_top.jpg)

| Construção | Arquivos e quatro prévias | Triângulos |
|---|---|---:|
| Grande Catedral | [Abrir](../assets/generated/elves/buildings/elf_sacred_ritual_hex_v1/README.md) | 2944 |
| Círculo Profano | [Abrir](../assets/generated/elves/buildings/elf_infernal_ritual_hex_v1/README.md) | 1816 |
| Mausoléu Negro | [Abrir](../assets/generated/elves/buildings/elf_necromancy_ritual_hex_v1/README.md) | 2196 |
| Bosque Ancestral | [Abrir](../assets/generated/elves/buildings/elf_druidic_ritual_hex_v1/README.md) | 1588 |
| Torre do Véu | [Abrir](../assets/generated/elves/buildings/elf_arcane_ritual_hex_v1/README.md) | 2212 |
| Nexus dos Elementos | [Abrir](../assets/generated/elves/buildings/elf_elemental_ritual_hex_v1/README.md) | 1708 |

Cada pasta contém `.blend` isolado e editável, `.glb` consolidado, atlas albedo/emissão, relatório JSON, README e quatro prévias. Caveiras e efígies reutilizam a geometria e a pintura do `skeleton_warrior_v1` aprovado.

Verificados: UVs, texturas embutidas, filtro nearest, malhas fechadas, origem no solo, as seis bordas do hexágono e importação dos 24 GLBs no Godot. A conferência dos apoios usa conectividade de caixas das peças e revisão visual; três núcleos mágicos levitam por intenção de design.

Preservados por comparação de hashes: 244 arquivos das escolas anteriores e do código de gameplay.

[Relatório dos assets](grand_magic_validation.json) · [Importação no Godot](grand_magic_godot_validation.json).

Produção: `tools/art_pipeline/grand_magic_model.py`, `grand_magic_finish.py` e `run_grand_magic_batch.py`.
