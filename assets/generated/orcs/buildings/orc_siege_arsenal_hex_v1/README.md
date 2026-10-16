# Arsenal de Guerra dos Orcs

Oficina original blocky para produzir a linha comum de máquinas de cerco
no mapa 4X. Galpão largo com uma baia de montagem aberta, madeira pesada,
basalto, cintas de ferro, telhado vermelho-ferrugem e presas na cumeeira.
Emblema de engrenagem prateada com presas sobre tecido vermelho do clã.
Uma pequena chaminé marca a área de forja do galpão.

No pátio: catapulta de quatro rodas, braço elevado e colher aberta com
uma pedra carregada, frente reforçada com ferro e presas; guindaste de
madeira com corrente, gancho e eixo sobressalente suspenso. Rodas, madeira,
bandeja de munição, bigorna, martelo e desenho de montagem completam a oficina.

**Somente asset: não cadastrado nem colocado no jogo.** É a versão visual
orc de `v2_building_siege_arsenal`; o ID na raiz é metadado para integração
futura. Nenhum catálogo, regra de treinamento ou seleção de modelo foi alterado.

O relatório referencia `v2_unit_catapult`, `v2_unit_trebuchet` e
`v2_unit_bombard`. O lendário `v2_legendary_siege_colossus` pertence ao
prédio próprio de maestria e permanece excluído.

- `orc_siege_arsenal_hex_v1.blend`: cena isolada com 223 peças editáveis,
  atlas empacotados, câmera e iluminação de prévia.
- `orc_siege_arsenal_hex_v1.glb`: 8 malhas, 1 material, 3.576 triângulos
  e texturas embutidas; sem câmera, luz, rig, skin ou animação.
- `orc_siege_arsenal_hex_v1_albedo.png` e `_emission.png`: atlas 2048² nearest.
- `previews/`: três quartos, visão alta do mapa, topo e traseira.
- `orc_siege_arsenal_hex_v1_report.json`: função, medidas e verificações.

Base hexagonal pointy-top de raio 0,92 para tile de raio 1. Dimensões:
1,5935 × 1,84 × 1,281 unidades de mapa. Origem central no chão Z=0;
frente −Y no Blender / +Z no glTF. Na integração futura, escalar
uniformemente pelo raio do tile. Projeção máxima nas seis faces: 0,79783,
dentro do apótema do tile 0,86603, com margem de 0,06820. Todos os
vértices foram verificados, incluindo telhado, presas, guindaste e catapulta.
Não há anel de muralhas. A baia aberta mede aproximadamente 0,69 × 0,427.

A catapulta e o guindaste são adereços estáticos da construção. Não
definem nem implementam o modelo futuro de uma unidade de cerco orc.
A malha `Faction` contém o tecido atrás da engrenagem e a placa da
catapulta para futura cor do dono. Telhado, pedra, madeira, ferro,
cordas, presas e munição preservam a paleta da família orc.

Geração pelo Blender aberto via MCP localhost:9876:

```powershell
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_siege_arsenal_hex_v1_model.py
python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/orc_siege_arsenal_hex_v1_finish.py
```

O construtor preserva as outras cenas e recusa sobrescrever uma cena
existente. A finalização pode renderizar e exportar novamente. O destino
está persistido em `asset_output_relative` na cena Blender.
