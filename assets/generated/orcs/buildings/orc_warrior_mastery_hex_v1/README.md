# Arena dos Campeões — Orcs

Arena orc aberta: fosso de areia, três arquibancadas pesadas separadas, tribuna do chefe e entrada baixa entre presas monumentais. Madeira, cintas de ferro e coberturas vermelhas evoluem o salão de armas do clã.

Doutrina: `warrior`. Grande construção associada a `v2_legendary_blade_hero`; requisito no cadastro: `v2_building_warrior_hall`.

Referência militar básica da própria civilização: `assets/generated/orcs/buildings/orc_warrior_hall_hex_v1`. Planta e volumes avançados próprios, sem copiar a arquitetura entre raças.

- `.blend`: cena isolada, peças editáveis e texturas empacotadas.
- `.glb`: grupos consolidados, atlas embutidos e nearest, sem rig/animação/câmera/luz.
- Dois atlas PNG, relatório JSON e quatro prévias.

110 peças, 1416 triângulos, atlas 1024².

Origem central no solo; frente −Y no Blender / +Z no Godot. Base pointy-top raio 0,92 para tile raio 1, escala 1; todas as peças dentro das seis bordas.

Criado, finalizado e salvo pelo Blender MCP. Integração ao cadastro do jogo permanece pendente.

Revisão de acabamento: acessos desobstruídos, mastros fora das coberturas e faces coincidentes corrigidas. Arquitetura e paleta da civilização preservadas. [Revisão](../../../../../docs/GRAND_MILITARY_FINISH_REVIEW.md).
