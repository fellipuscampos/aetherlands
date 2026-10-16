# Revisão de acabamento das grandes construções militares

Os 24 modelos existentes foram ajustados pelo Blender MCP, uma construção de cada vez, e salvos com novos `.blend`, `.glb`, atlas e quatro prévias. As plantas próprias, os materiais e as cores das quatro civilizações foram preservados.

A revisão corrigiu pilares de esquina à frente de portas hexagonais, um abrigo vizinho invadindo a entrada, brasões baixos sobre aberturas, cercas e mobiliário atravessando aproximações. As entradas receberam fachadas planas e os elementos decorativos mantêm apoios físicos. A escadaria elevada do refúgio élfico termina no patamar da porta.

Mastros e bandeiras foram afastados das coberturas. Poleiros humanos, orcs e anões agora começam em bases sobre o telhado; o ninho élfico aproveita o tronco vivo e não mantém um segundo poste coincidente.

Faces coincidentes de degraus, arquibancadas, cintas, cumeeiras e pequenos detalhes foram recuadas dentro das peças vizinhas, conservando volumes fechados. Peças duplicadas ou substituídas foram arquivadas no grupo de estúdio e excluídas das prévias e da exportação.

## Conferência

| Verificação | Resultado |
|---|---:|
| Modelos revisados | 24 |
| Portas verificadas | 13 |
| Passagens e aproximações verificadas | 26 |
| Obstruções nos acessos verificados | 0 |
| Mastros atravessando telhados | 0 |
| Pares de faces coplanares expostas detectados | 0 |
| Importações no Godot | 24 aprovadas |
| Arquivos originais preservados em backup | 240 |

A sobreposição foi conferida por interseção de triângulos coplanares, com raios para excluir contatos internos. Os mastros foram comparados com a geometria das coberturas. Portas e passagens usam envelopes de aproximação e raios contra as peças reais. Esses testes complementam a revisão visual; não representam navegação de unidades, pois estes assets ainda não estão integrados ao cadastro do jogo.

Também foram conferidos UVs, malhas fechadas, texturas embutidas, nearest, origem no solo, seis limites do tile e 24 geometrias distintas. Os arquivos anteriores de construções e gameplay continuam preservados pela comparação de hashes.

## Modelos e prévias

### Humanos

- [Bastião de Maestria — Humanos](../assets/generated/humans/buildings/guardian_mastery_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/guardian_mastery_hex_v1/previews/three_quarter.png).
- [Arena dos Campeões — Humanos](../assets/generated/humans/buildings/warrior_mastery_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/warrior_mastery_hex_v1/previews/three_quarter.png).
- [Torre dos Patrulheiros — Humanos](../assets/generated/humans/buildings/ranger_mastery_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/ranger_mastery_hex_v1/previews/three_quarter.png).
- [Ordem da Cavalaria — Humanos](../assets/generated/humans/buildings/cavalry_mastery_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/cavalry_mastery_hex_v1/previews/three_quarter.png).
- [Refúgio das Sombras — Humanos](../assets/generated/humans/buildings/rogue_mastery_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/rogue_mastery_hex_v1/previews/three_quarter.png).
- [Grande Arsenal — Humanos](../assets/generated/humans/buildings/grand_arsenal_hex_v1/README.md) · [Prévia](../assets/generated/humans/buildings/grand_arsenal_hex_v1/previews/three_quarter.png).

### Orcs

- [Bastião de Maestria — Orcs](../assets/generated/orcs/buildings/orc_guardian_mastery_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_guardian_mastery_hex_v1/previews/three_quarter.png).
- [Arena dos Campeões — Orcs](../assets/generated/orcs/buildings/orc_warrior_mastery_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_warrior_mastery_hex_v1/previews/three_quarter.png).
- [Torre dos Patrulheiros — Orcs](../assets/generated/orcs/buildings/orc_ranger_mastery_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_ranger_mastery_hex_v1/previews/three_quarter.png).
- [Ordem da Cavalaria — Orcs](../assets/generated/orcs/buildings/orc_cavalry_mastery_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_cavalry_mastery_hex_v1/previews/three_quarter.png).
- [Refúgio das Sombras — Orcs](../assets/generated/orcs/buildings/orc_rogue_mastery_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_rogue_mastery_hex_v1/previews/three_quarter.png).
- [Grande Arsenal — Orcs](../assets/generated/orcs/buildings/orc_grand_arsenal_hex_v1/README.md) · [Prévia](../assets/generated/orcs/buildings/orc_grand_arsenal_hex_v1/previews/three_quarter.png).

### Anões

- [Bastião de Maestria — Anões](../assets/generated/dwarves/buildings/dwarf_guardian_mastery_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_guardian_mastery_hex_v1/previews/three_quarter.png).
- [Arena dos Campeões — Anões](../assets/generated/dwarves/buildings/dwarf_warrior_mastery_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_warrior_mastery_hex_v1/previews/three_quarter.png).
- [Torre dos Patrulheiros — Anões](../assets/generated/dwarves/buildings/dwarf_ranger_mastery_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_ranger_mastery_hex_v1/previews/three_quarter.png).
- [Ordem da Cavalaria — Anões](../assets/generated/dwarves/buildings/dwarf_cavalry_mastery_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_cavalry_mastery_hex_v1/previews/three_quarter.png).
- [Refúgio das Sombras — Anões](../assets/generated/dwarves/buildings/dwarf_rogue_mastery_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_rogue_mastery_hex_v1/previews/three_quarter.png).
- [Grande Arsenal — Anões](../assets/generated/dwarves/buildings/dwarf_grand_arsenal_hex_v1/README.md) · [Prévia](../assets/generated/dwarves/buildings/dwarf_grand_arsenal_hex_v1/previews/three_quarter.png).

### Elfos

- [Bastião de Maestria — Elfos](../assets/generated/elves/buildings/elf_guardian_mastery_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_guardian_mastery_hex_v1/previews/three_quarter.png).
- [Arena dos Campeões — Elfos](../assets/generated/elves/buildings/elf_warrior_mastery_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_warrior_mastery_hex_v1/previews/three_quarter.png).
- [Torre dos Patrulheiros — Elfos](../assets/generated/elves/buildings/elf_ranger_mastery_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_ranger_mastery_hex_v1/previews/three_quarter.png).
- [Ordem da Cavalaria — Elfos](../assets/generated/elves/buildings/elf_cavalry_mastery_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_cavalry_mastery_hex_v1/previews/three_quarter.png).
- [Refúgio das Sombras — Elfos](../assets/generated/elves/buildings/elf_rogue_mastery_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_rogue_mastery_hex_v1/previews/three_quarter.png).
- [Grande Arsenal — Elfos](../assets/generated/elves/buildings/elf_grand_arsenal_hex_v1/README.md) · [Prévia](../assets/generated/elves/buildings/elf_grand_arsenal_hex_v1/previews/three_quarter.png).

[Catálogo](GRAND_MILITARY_CATALOG.md) · [Geometria final](grand_military_geometry_after.json) · [Godot](grand_military_godot_validation.json).
