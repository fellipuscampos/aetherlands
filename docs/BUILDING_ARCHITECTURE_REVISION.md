# Revisão da arquitetura das civilizações

Revisão de 2026-10-09: **66 prédios corrigidos pelo Blender MCP**, após inspeção de 104 assets, incluindo protótipos históricos. As cidades e as construções que já seguiam sua arquitetura foram preservadas.

| Civilização | Prédios corrigidos | Arquitetura aplicada |
|---|---:|---|
| Humanos | 20 | Blocos de pedra e cantaria, pilares com bases e capitéis, telhados azuis. Portões, móveis, cercas e mecanismos usam madeira quando a função exige. |
| Elfos | 18 | Pedra clara, madeira esbelta e contraventamentos em forma de galhos. Pavilhões mais abertos, telhados verdes com cantos facetados e coberturas mais altas. |
| Anões | 16 | Granito, pilares espessos, sapatas escalonadas, cintas de cobre e ardósia escura. Coberturas mais baixas e maciças; os marcos druídicos recebem bases e capitéis de engenharia anã. |
| Orcs | 12 | Madeira grossa, cintas de ferro e contraventamentos diagonais. Coberturas ferrugem compactas; os marcos dos rituais tornam-se totens de madeira cintada. Pedra nas fundações e câmaras funerárias. |

Foram atualizados os modelos editáveis .blend, as exportações .glb, os atlas albedo/emissão, os relatórios e as quatro prévias de cada prédio. Os caminhos e IDs usados pelo catálogo do jogo foram mantidos. A revisão muda a apresentação visual dos assets.

Os arquivos anteriores estão em [buildings_before_architecture_revision](../art_source/buildings_before_architecture_revision/), com hashes no manifesto. A inspeção original está em [audit_before.json](../art_source/building_architecture_review/audit_before.json).

A [comparação interativa antes/depois](../art_source/building_architecture_review/index.html) permite selecionar civilização, construção e ângulo da câmera.

## Comparação das famílias

| Civilização | Antes | Depois |
|---|---|---|
| Humanos | [Ver conjunto original](../art_source/building_architecture_review/humans_before.jpg) | [Ver conjunto revisado](../art_source/building_architecture_review/humans_after.jpg) |
| Elfos | [Ver conjunto original](../art_source/building_architecture_review/elves_before.jpg) | [Ver conjunto revisado](../art_source/building_architecture_review/elves_after.jpg) |
| Anões | [Ver conjunto original](../art_source/building_architecture_review/dwarves_before.jpg) | [Ver conjunto revisado](../art_source/building_architecture_review/dwarves_after.jpg) |
| Orcs | [Ver conjunto original](../art_source/building_architecture_review/orcs_before.jpg) | [Ver conjunto revisado](../art_source/building_architecture_review/orcs_after.jpg) |

## Prédios corrigidos

| Civilização | Construção | Prévia | Triângulos |
|---|---|---|---:|
| Humanos | [Estábulo de Guerra](../assets/generated/humans/buildings/war_stable_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/war_stable_hex_v1/previews/three_quarter.png) | 2348 |
| Elfos | [Estábulo de Guerra dos Elfos](../assets/generated/elves/buildings/elf_war_stable_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_war_stable_hex_v1/previews/three_quarter.png) | 3072 |
| Anões | [Estábulo de Guerra dos Anões](../assets/generated/dwarves/buildings/dwarf_war_stable_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_war_stable_hex_v1/previews/three_quarter.png) | 2680 |
| Orcs | [Conclave Arcano — Orcs](../assets/generated/orcs/buildings/orc_arcane_conclave_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_arcane_conclave_hex_v1/previews/three_quarter.png) | 2640 |
| Humanos | [Salão de Armas](../assets/generated/humans/buildings/warrior_hall_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/warrior_hall_hex_v1/previews/three_quarter.png) | 2404 |
| Humanos | [Campo dos Patrulheiros](../assets/generated/humans/buildings/ranger_camp_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/ranger_camp_hex_v1/previews/three_quarter.png) | 3220 |
| Humanos | [Guilda dos Ladinos](../assets/generated/humans/buildings/rogue_guild_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/rogue_guild_hex_v1/previews/three_quarter.png) | 2728 |
| Humanos | [Arsenal de Cerco](../assets/generated/humans/buildings/siege_arsenal_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/siege_arsenal_hex_v1/previews/three_quarter.png) | 3316 |
| Humanos | [Ordem da Cavalaria — Humanos](../assets/generated/humans/buildings/cavalry_mastery_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/cavalry_mastery_hex_v1/previews/three_quarter.png) | 2412 |
| Humanos | [Refúgio das Sombras — Humanos](../assets/generated/humans/buildings/rogue_mastery_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/rogue_mastery_hex_v1/previews/three_quarter.png) | 1888 |
| Humanos | [Grande Arsenal — Humanos](../assets/generated/humans/buildings/grand_arsenal_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/grand_arsenal_hex_v1/previews/three_quarter.png) | 2172 |
| Humanos | [Torre dos Patrulheiros — Humanos](../assets/generated/humans/buildings/ranger_mastery_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/ranger_mastery_hex_v1/previews/three_quarter.png) | 1532 |
| Humanos | [Arena dos Campeões — Humanos](../assets/generated/humans/buildings/warrior_mastery_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/warrior_mastery_hex_v1/previews/three_quarter.png) | 1700 |
| Humanos | [Templo Sagrado — Humanos](../assets/generated/humans/buildings/sacred_temple_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/sacred_temple_hex_v1/previews/three_quarter.png) | 1620 |
| Humanos | [Grande Catedral — Humanos](../assets/generated/humans/buildings/sacred_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/sacred_ritual_hex_v1/previews/three_quarter.png) | 2100 |
| Humanos | [Santuário Infernal — Humanos](../assets/generated/humans/buildings/infernal_sanctum_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/infernal_sanctum_hex_v1/previews/three_quarter.png) | 1540 |
| Humanos | [Círculo Profano — Humanos](../assets/generated/humans/buildings/infernal_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/infernal_ritual_hex_v1/previews/three_quarter.png) | 1400 |
| Humanos | [Ossuário — Humanos](../assets/generated/humans/buildings/necromancy_ossuary_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/necromancy_ossuary_hex_v1/previews/three_quarter.png) | 1992 |
| Humanos | [Mausoléu Negro — Humanos](../assets/generated/humans/buildings/necromancy_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/necromancy_ritual_hex_v1/previews/three_quarter.png) | 1740 |
| Humanos | [Conclave Arcano — Humanos](../assets/generated/humans/buildings/arcane_conclave_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/arcane_conclave_hex_v1/previews/three_quarter.png) | 2116 |
| Humanos | [Torre do Véu — Humanos](../assets/generated/humans/buildings/arcane_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/arcane_ritual_hex_v1/previews/three_quarter.png) | 1492 |
| Humanos | [Observatório Elemental — Humanos](../assets/generated/humans/buildings/elemental_observatory_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/elemental_observatory_hex_v1/previews/three_quarter.png) | 1868 |
| Humanos | [Nexus dos Elementos — Humanos](../assets/generated/humans/buildings/elemental_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/humans/buildings/elemental_ritual_hex_v1/previews/three_quarter.png) | 1392 |
| Elfos | [Salão dos Guardiões dos Elfos](../assets/generated/elves/buildings/elf_guardian_hall_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_guardian_hall_hex_v1/previews/three_quarter.png) | 2948 |
| Elfos | [Salão de Armas dos Elfos](../assets/generated/elves/buildings/elf_warrior_hall_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_warrior_hall_hex_v1/previews/three_quarter.png) | 2776 |
| Elfos | [Campo dos Patrulheiros dos Elfos](../assets/generated/elves/buildings/elf_ranger_camp_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_ranger_camp_hex_v1/previews/three_quarter.png) | 4088 |
| Elfos | [Guilda dos Ladinos dos Elfos](../assets/generated/elves/buildings/elf_rogue_guild_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_rogue_guild_hex_v1/previews/three_quarter.png) | 3268 |
| Elfos | [Arsenal de Guerra dos Elfos](../assets/generated/elves/buildings/elf_siege_arsenal_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_siege_arsenal_hex_v1/previews/three_quarter.png) | 4096 |
| Anões | [Campo dos Patrulheiros dos Anões](../assets/generated/dwarves/buildings/dwarf_ranger_camp_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_ranger_camp_hex_v1/previews/three_quarter.png) | 3694 |
| Anões | [Guilda dos Ladinos dos Anões](../assets/generated/dwarves/buildings/dwarf_rogue_guild_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_rogue_guild_hex_v1/previews/three_quarter.png) | 3180 |
| Anões | [Arsenal de Guerra dos Anões](../assets/generated/dwarves/buildings/dwarf_siege_arsenal_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_siege_arsenal_hex_v1/previews/three_quarter.png) | 3872 |
| Elfos | [Templo Sagrado — Elfos](../assets/generated/elves/buildings/elf_sacred_temple_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_sacred_temple_hex_v1/previews/three_quarter.png) | 2448 |
| Elfos | [Grande Catedral — Elfos](../assets/generated/elves/buildings/elf_sacred_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_sacred_ritual_hex_v1/previews/three_quarter.png) | 3296 |
| Elfos | [Santuário Infernal — Elfos](../assets/generated/elves/buildings/elf_infernal_sanctum_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_infernal_sanctum_hex_v1/previews/three_quarter.png) | 2316 |
| Elfos | [Círculo Profano — Elfos](../assets/generated/elves/buildings/elf_infernal_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_infernal_ritual_hex_v1/previews/three_quarter.png) | 2056 |
| Elfos | [Ossuário — Elfos](../assets/generated/elves/buildings/elf_necromancy_ossuary_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_necromancy_ossuary_hex_v1/previews/three_quarter.png) | 2872 |
| Elfos | [Mausoléu Negro — Elfos](../assets/generated/elves/buildings/elf_necromancy_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_necromancy_ritual_hex_v1/previews/three_quarter.png) | 2452 |
| Elfos | [Círculo Druídico — Elfos](../assets/generated/elves/buildings/elf_druidic_circle_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_druidic_circle_hex_v1/previews/three_quarter.png) | 2460 |
| Elfos | [Bosque Ancestral — Elfos](../assets/generated/elves/buildings/elf_druidic_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_druidic_ritual_hex_v1/previews/three_quarter.png) | 1732 |
| Elfos | [Conclave Arcano — Elfos](../assets/generated/elves/buildings/elf_arcane_conclave_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_arcane_conclave_hex_v1/previews/three_quarter.png) | 2904 |
| Elfos | [Torre do Véu — Elfos](../assets/generated/elves/buildings/elf_arcane_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_arcane_ritual_hex_v1/previews/three_quarter.png) | 2356 |
| Elfos | [Observatório Elemental — Elfos](../assets/generated/elves/buildings/elf_elemental_observatory_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_elemental_observatory_hex_v1/previews/three_quarter.png) | 2728 |
| Elfos | [Nexus dos Elementos — Elfos](../assets/generated/elves/buildings/elf_elemental_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/elves/buildings/elf_elemental_ritual_hex_v1/previews/three_quarter.png) | 1900 |
| Anões | [Templo Sagrado — Anões](../assets/generated/dwarves/buildings/dwarf_sacred_temple_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_sacred_temple_hex_v1/previews/three_quarter.png) | 2056 |
| Anões | [Grande Catedral — Anões](../assets/generated/dwarves/buildings/dwarf_sacred_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_sacred_ritual_hex_v1/previews/three_quarter.png) | 2716 |
| Anões | [Santuário Infernal — Anões](../assets/generated/dwarves/buildings/dwarf_infernal_sanctum_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_infernal_sanctum_hex_v1/previews/three_quarter.png) | 1864 |
| Anões | [Círculo Profano — Anões](../assets/generated/dwarves/buildings/dwarf_infernal_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_infernal_ritual_hex_v1/previews/three_quarter.png) | 1724 |
| Anões | [Ossuário — Anões](../assets/generated/dwarves/buildings/dwarf_necromancy_ossuary_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_necromancy_ossuary_hex_v1/previews/three_quarter.png) | 2272 |
| Anões | [Mausoléu Negro — Anões](../assets/generated/dwarves/buildings/dwarf_necromancy_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_necromancy_ritual_hex_v1/previews/three_quarter.png) | 2116 |
| Anões | [Círculo Druídico — Anões](../assets/generated/dwarves/buildings/dwarf_druidic_circle_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_druidic_circle_hex_v1/previews/three_quarter.png) | 1444 |
| Anões | [Bosque Ancestral — Anões](../assets/generated/dwarves/buildings/dwarf_druidic_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_druidic_ritual_hex_v1/previews/three_quarter.png) | 1128 |
| Anões | [Conclave Arcano — Anões](../assets/generated/dwarves/buildings/dwarf_arcane_conclave_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_arcane_conclave_hex_v1/previews/three_quarter.png) | 2488 |
| Anões | [Torre do Véu — Anões](../assets/generated/dwarves/buildings/dwarf_arcane_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_arcane_ritual_hex_v1/previews/three_quarter.png) | 1876 |
| Anões | [Observatório Elemental — Anões](../assets/generated/dwarves/buildings/dwarf_elemental_observatory_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_elemental_observatory_hex_v1/previews/three_quarter.png) | 2240 |
| Anões | [Nexus dos Elementos — Anões](../assets/generated/dwarves/buildings/dwarf_elemental_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/dwarves/buildings/dwarf_elemental_ritual_hex_v1/previews/three_quarter.png) | 1896 |
| Orcs | [Templo Sagrado — Orcs](../assets/generated/orcs/buildings/orc_sacred_temple_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_sacred_temple_hex_v1/previews/three_quarter.png) | 2204 |
| Orcs | [Grande Catedral — Orcs](../assets/generated/orcs/buildings/orc_sacred_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_sacred_ritual_hex_v1/previews/three_quarter.png) | 2688 |
| Orcs | [Santuário Infernal — Orcs](../assets/generated/orcs/buildings/orc_infernal_sanctum_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_infernal_sanctum_hex_v1/previews/three_quarter.png) | 1988 |
| Orcs | [Círculo Profano — Orcs](../assets/generated/orcs/buildings/orc_infernal_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_infernal_ritual_hex_v1/previews/three_quarter.png) | 1512 |
| Orcs | [Ossuário — Orcs](../assets/generated/orcs/buildings/orc_necromancy_ossuary_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_necromancy_ossuary_hex_v1/previews/three_quarter.png) | 2324 |
| Orcs | [Mausoléu Negro — Orcs](../assets/generated/orcs/buildings/orc_necromancy_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_necromancy_ritual_hex_v1/previews/three_quarter.png) | 2000 |
| Orcs | [Círculo Druídico — Orcs](../assets/generated/orcs/buildings/orc_druidic_circle_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_druidic_circle_hex_v1/previews/three_quarter.png) | 1536 |
| Orcs | [Bosque Ancestral — Orcs](../assets/generated/orcs/buildings/orc_druidic_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_druidic_ritual_hex_v1/previews/three_quarter.png) | 1236 |
| Orcs | [Torre do Véu — Orcs](../assets/generated/orcs/buildings/orc_arcane_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_arcane_ritual_hex_v1/previews/three_quarter.png) | 1928 |
| Orcs | [Observatório Elemental — Orcs](../assets/generated/orcs/buildings/orc_elemental_observatory_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_elemental_observatory_hex_v1/previews/three_quarter.png) | 2212 |
| Orcs | [Nexus dos Elementos — Orcs](../assets/generated/orcs/buildings/orc_elemental_ritual_hex_v1/README.md) | [Ver modelo](../assets/generated/orcs/buildings/orc_elemental_ritual_hex_v1/previews/three_quarter.png) | 1580 |

## Verificação

Os relatórios de [geometria e backups](building_architecture_validation.json), [fontes editáveis no Blender](building_architecture_source_validation.json) e [importação no Godot](building_architecture_godot_validation.json) registram quantos modelos foram efetivamente verificados. Os checks cobrem alterações reais de geometria ou materiais, malhas fechadas, IDs e treino preservados, encaixe de todos os vértices no hex, solo/origem, atlas embutidos idênticos aos PNGs, nearest e ausência de câmera/luz/rig na exportação.

A reimportação no projeto do jogo terminou com código 0, sem erros nem avisos. O teste existente `test_building_art_catalog.gd` teve 6 de 8 testes aprovados e 879 de 883 asserts aprovados. Passaram a carga de todos os modelos do catálogo, IDs, escala e registro. Duas falhas dependem dos arquivos ausentes `assets/models/kaykit/nature/Tree_1_A_Color1.gltf` e `assets/models/kaykit/buildings/building_market_blue.gltf`, fora da revisão. Resultados em [validação no projeto](building_architecture_game_validation.json) e [log completo do teste](../art_source/building_architecture_review/game_catalog_test.log).

Reprodução na sessão aberta do Blender:

    python tools/art_pipeline/run_building_architecture_revision.py
    python tools/art_pipeline/verify_building_architecture_revision.py
    python tools/art_pipeline/run_building_architecture_godot_validation.py
    python tools/art_pipeline/review_building_architecture.py after
    python tools/art_pipeline/document_building_architecture_revision.py
