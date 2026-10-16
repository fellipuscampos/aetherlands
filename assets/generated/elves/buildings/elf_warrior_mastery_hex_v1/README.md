# Arena dos Campeões — Elfos

Arena élfica de duelo em pétalas: piso hexagonal claro, três terraços pequenos com árvores de sombra, tribuna leve e portal de galhos abertos. Mantém espadas finas, madeira e folhas do salão de armas élfico.

Doutrina: `warrior`. Grande construção associada a `v2_legendary_blade_hero`; requisito no cadastro: `v2_building_warrior_hall`.

Referência militar básica da própria civilização: `assets/generated/elves/buildings/elf_warrior_hall_hex_v1`. Planta e volumes avançados próprios, sem copiar a arquitetura entre raças.

- `.blend`: cena isolada, peças editáveis e texturas empacotadas.
- `.glb`: grupos consolidados, atlas embutidos e nearest, sem rig/animação/câmera/luz.
- Dois atlas PNG, relatório JSON e quatro prévias.

137 peças, 1852 triângulos, atlas 1024².

Origem central no solo; frente −Y no Blender / +Z no Godot. Base pointy-top raio 0,92 para tile raio 1, escala 1; todas as peças dentro das seis bordas.

Criado, finalizado e salvo pelo Blender MCP. Integração ao cadastro do jogo permanece pendente.

Revisão de acabamento: acessos desobstruídos, mastros fora das coberturas e faces coincidentes corrigidas. Arquitetura e paleta da civilização preservadas. [Revisão](../../../../../docs/GRAND_MILITARY_FINISH_REVIEW.md).
