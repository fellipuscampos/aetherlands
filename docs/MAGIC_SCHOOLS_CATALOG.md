# Escolas de magia — modelos 3D

[Abrir as grandes construções mágicas das quatro civilizações](GRAND_MAGIC_CATALOG.md).

[Abrir as grandes construções militares das quatro civilizações](GRAND_MILITARY_CATALOG.md).

24 prédios criados pelo Blender MCP, um por vez, na ordem humanos, orcs, anões e elfos.

Cada pasta possui `.blend`, `.glb`, atlas albedo/emissão, relatório, README e quatro prévias. Assets preparados; integração no jogo pendente.

## Humanos

[Visão geral](../assets/generated/humans/buildings/magic_schools_three_quarter.jpg) · [Visão de mapa](../assets/generated/humans/buildings/magic_schools_game_top.jpg)

| Escola | Modelo e arquivos | Triângulos |
|---|---|---:|
| Templo Sagrado | [Abrir](../assets/generated/humans/buildings/sacred_temple_hex_v1/README.md) | 1452 |
| Santuário Infernal | [Abrir](../assets/generated/humans/buildings/infernal_sanctum_hex_v1/README.md) | 1444 |
| Ossuário | [Abrir](../assets/generated/humans/buildings/necromancy_ossuary_hex_v1/README.md) | 1992 |
| Círculo Druídico | [Abrir](../assets/generated/humans/buildings/druidic_circle_hex_v1/README.md) | 1204 |
| Conclave Arcano | [Abrir](../assets/generated/humans/buildings/arcane_conclave_hex_v1/README.md) | 1852 |
| Observatório Elemental | [Abrir](../assets/generated/humans/buildings/elemental_observatory_hex_v1/README.md) | 1820 |

## Orcs

[Visão geral](../assets/generated/orcs/buildings/magic_schools_three_quarter.jpg) · [Visão de mapa](../assets/generated/orcs/buildings/magic_schools_game_top.jpg)

| Escola | Modelo e arquivos | Triângulos |
|---|---|---:|
| Templo Sagrado | [Abrir](../assets/generated/orcs/buildings/orc_sacred_temple_hex_v1/README.md) | 1796 |
| Santuário Infernal | [Abrir](../assets/generated/orcs/buildings/orc_infernal_sanctum_hex_v1/README.md) | 1796 |
| Ossuário | [Abrir](../assets/generated/orcs/buildings/orc_necromancy_ossuary_hex_v1/README.md) | 2324 |
| Círculo Druídico | [Abrir](../assets/generated/orcs/buildings/orc_druidic_circle_hex_v1/README.md) | 1392 |
| Conclave Arcano | [Abrir](../assets/generated/orcs/buildings/orc_arcane_conclave_hex_v1/README.md) | 2160 |
| Observatório Elemental | [Abrir](../assets/generated/orcs/buildings/orc_elemental_observatory_hex_v1/README.md) | 2164 |

## Anões

[Visão geral](../assets/generated/dwarves/buildings/magic_schools_three_quarter.jpg) · [Visão de mapa](../assets/generated/dwarves/buildings/magic_schools_game_top.jpg)

| Escola | Modelo e arquivos | Triângulos |
|---|---|---:|
| Templo Sagrado | [Abrir](../assets/generated/dwarves/buildings/dwarf_sacred_temple_hex_v1/README.md) | 1572 |
| Santuário Infernal | [Abrir](../assets/generated/dwarves/buildings/dwarf_infernal_sanctum_hex_v1/README.md) | 1624 |
| Ossuário | [Abrir](../assets/generated/dwarves/buildings/dwarf_necromancy_ossuary_hex_v1/README.md) | 2112 |
| Círculo Druídico | [Abrir](../assets/generated/dwarves/buildings/dwarf_druidic_circle_hex_v1/README.md) | 1300 |
| Conclave Arcano | [Abrir](../assets/generated/dwarves/buildings/dwarf_arcane_conclave_hex_v1/README.md) | 1996 |
| Observatório Elemental | [Abrir](../assets/generated/dwarves/buildings/dwarf_elemental_observatory_hex_v1/README.md) | 2168 |

## Elfos

[Visão geral](../assets/generated/elves/buildings/magic_schools_three_quarter.jpg) · [Visão de mapa](../assets/generated/elves/buildings/magic_schools_game_top.jpg)

| Escola | Modelo e arquivos | Triângulos |
|---|---|---:|
| Templo Sagrado | [Abrir](../assets/generated/elves/buildings/elf_sacred_temple_hex_v1/README.md) | 2096 |
| Santuário Infernal | [Abrir](../assets/generated/elves/buildings/elf_infernal_sanctum_hex_v1/README.md) | 2124 |
| Ossuário | [Abrir](../assets/generated/elves/buildings/elf_necromancy_ossuary_hex_v1/README.md) | 2712 |
| Círculo Druídico | [Abrir](../assets/generated/elves/buildings/elf_druidic_circle_hex_v1/README.md) | 2316 |
| Conclave Arcano | [Abrir](../assets/generated/elves/buildings/elf_arcane_conclave_hex_v1/README.md) | 2592 |
| Observatório Elemental | [Abrir](../assets/generated/elves/buildings/elf_elemental_observatory_hex_v1/README.md) | 2728 |

Verificados: arquivos e imagens válidos, seis bordas do hex, origem no solo, UVs, atlas embutidos idênticos aos PNGs, nearest, malhas fechadas, ausência de rig/animação/câmeras/luzes no GLB e código de jogo preservado.

Acabamento revisado sobre os modelos existentes: volumes principais preservados, mastros fundados e tecido fixado, apoios físicos conferidos, telhados uniformes por civilização e detalhes próprios de cada raça. Ossuários usam a caveira, mandíbula e pintura das costelas do esqueleto aprovado, com relevos de ossos e prateleiras.

Importação direta dos 24 GLBs no Godot 4.7.1: PASS. [Relatório do Godot](magic_schools_godot_validation.json).

[Relatório dos assets](magic_schools_validation.json).

Scripts de produção: `tools/art_pipeline/magic_school_model.py`, `magic_school_finish.py` e `run_magic_school_batch.py`. Cada modelo foi finalizado e salvo antes de iniciar o próximo.

A revisão usa `tools/art_pipeline/magic_school_polish.py` e `run_magic_school_polish.py` para ajustar as cenas existentes pelo Blender MCP, sem executar o construtor original. [Detalhes da revisão](MAGIC_SCHOOLS_FINISH_REVIEW.md). Cópias anteriores preservadas em `art_source/magic_schools_before_finish_pass/`.
