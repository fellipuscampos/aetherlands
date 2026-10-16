# Salão dos Guardiões dos Anões

Construção original blocky para treinar a linha comum de tanks anões no
mapa 4X. Granito pesado, pilares com runas de cobre, telhado de ardósia
escura em degraus e emblema de escudo angular em aço/cobre com centro azul.
A paleta repete o centro da Cidade Anã I. Uma torre baixa de pedra com
merlões quadrados e estandarte de escudo marca a função defensiva.

Pátio aberto com dois manequins de treino de escudos, pequenos capacetes
metálicos sobre cabeças de palha, marcas de postura e dois escudos de
reserva em suporte lateral. Entrada central livre com degraus de granito.

**Somente asset: não cadastrado nem colocado no jogo.** É a versão visual
anã de `v2_building_guardian_hall`; o ID na raiz é apenas metadado para
integração futura. Nenhum catálogo, treinamento ou seletor foi alterado.

O relatório referencia a mesma linha comum: `v2_unit_shieldbearer`,
`v2_unit_guardian` e `v2_unit_sentinel`. O herói supremo
`v2_legendary_guardian_champion` pertence ao prédio próprio de maestria
e permanece excluído. O modelo não define personagens anões.

- `dwarf_guardian_hall_hex_v1.blend`: cena isolada com 194 peças editáveis,
  atlas empacotados, câmera e iluminação de prévia.
- `dwarf_guardian_hall_hex_v1.glb`: 8 malhas, 1 material, 2.684 triângulos
  e texturas embutidas; sem câmera, luz, rig, skin ou animação.
- `dwarf_guardian_hall_hex_v1_albedo.png` e `_emission.png`: atlas 2048² nearest.
- `previews/`: três quartos, visão alta do mapa, topo e traseira.
- `dwarf_guardian_hall_hex_v1_report.json`: função, medidas e verificações.

Base militar hexagonal pointy-top de raio 0,92 para tile de raio 1,
maior que a base de raio 0,84 do centro da cidade. Dimensões:
1,5935 × 1,84 × 1,184 unidades de mapa. Origem central no chão Z=0;
frente −Y no Blender / +Z no glTF. Na integração futura, escalar
uniformemente pelo raio do tile. Projeção máxima nas seis faces: 0,79674,
dentro do apótema 0,86603, com margem de 0,06928. Todos os vértices
foram verificados, incluindo telhado, torre, escudos e estandarte.
Sem anel de muralhas ao redor do tile; a torre pertence ao edifício.

A malha `Faction` contém os centros azuis dos escudos e o estandarte
para futura cor do dono. Pedra, ardósia, cobre, aço e madeira mantêm
suas cores. Fonte inteiramente estática e sem dependência de unidades.

Geração pelo Blender aberto via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_guardian_hall_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/dwarf_guardian_hall_hex_v1_finish.py
```

O construtor preserva as outras cenas e recusa sobrescrever uma cena
existente. A finalização pode renderizar e exportar novamente. O destino
está persistido em `asset_output_relative` na cena Blender.
