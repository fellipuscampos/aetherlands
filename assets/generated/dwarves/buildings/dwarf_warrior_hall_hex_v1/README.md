# Salão de Armas dos Anões

Construção original blocky para treinar a linha comum de guerreiros anões
no mapa 4X. Salão baixo e largo em granito, telhado de ardósia escura com
cumeeira transversal e cintas de cobre, portal com runas e emblema de
machado de duas lâminas e martelo de guerra cruzados sobre tecido azul.
A paleta repete o centro da cidade anã e o salão de tanks.

Abrigo lateral aberto com um machado e um martelo de reserva; pátio de
combate com dois manequins de palha marcados por golpes, marcas de postura,
pequena bigorna de manutenção, banco e estandarte militar azul.

**Somente asset: não cadastrado nem colocado no jogo.** É a versão visual
anã de `v2_building_warrior_hall`; esse ID na raiz é apenas metadado.
Nenhum catálogo, treinamento ou seletor de modelos foi alterado.

O relatório referencia a linha comum: `v2_unit_warrior`,
`v2_unit_swordsman` e `v2_unit_weapon_master`. O herói supremo
`v2_legendary_blade_hero` pertence ao prédio próprio de maestria e
permanece excluído. O modelo não define personagens anões.

- `dwarf_warrior_hall_hex_v1.blend`: cena isolada com 193 peças editáveis,
  atlas empacotados, câmera e iluminação de prévia.
- `dwarf_warrior_hall_hex_v1.glb`: 8 malhas, 1 material, 2.520 triângulos
  e texturas embutidas; sem câmera, luz, rig, skin ou animação.
- `dwarf_warrior_hall_hex_v1_albedo.png` e `_emission.png`: atlas 2048² nearest.
- `previews/`: três quartos, visão alta do mapa, topo e traseira.
- `dwarf_warrior_hall_hex_v1_report.json`: função, medidas e verificações.

Base militar hexagonal pointy-top de raio 0,92 para tile de raio 1.
Dimensões: 1,5935 × 1,84 × 1,004 unidades de mapa. Origem central no
chão Z=0; frente −Y no Blender / +Z no glTF. Na integração futura,
escalar uniformemente pelo raio do tile. Projeção máxima nas seis faces:
0,79674, dentro do apótema 0,86603, com margem de 0,06928. Todos os
vértices foram verificados, incluindo telhados, armas e estandarte.
Sem torre ou anel de muralhas ao redor do tile.

A malha `Faction` contém o tecido azul do emblema e o estandarte para
futura cor do dono. Ardósia, pedra, cobre, aço e madeira mantêm a paleta.
Geometria estática, original e sem dependência de modelos de unidades.

Geração pelo Blender aberto via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_warrior_hall_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_warrior_hall_hex_v1_finish.py
```

O construtor preserva as outras cenas e recusa sobrescrever uma cena
existente. A finalização pode renderizar e exportar novamente. O destino
está persistido em `asset_output_relative` na cena Blender.
